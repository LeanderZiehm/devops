import os
import re
import glob
import gzip
import hashlib
from datetime import datetime

import psycopg2


DATABASE_URL = os.getenv("DATABASE_URL")
HOSTNAME = os.getenv("HOSTNAME")

print("HOSTNAME:",HOSTNAME)

BATCH_SIZE = 5000

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is missing from .env")


LOG_PATTERN = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ '
    r'\[(?P<timestamp>[^\]]+)\] '
    r'"(?P<request>.*?)" '
    r'(?P<status>\d{3}) '
    r'(?P<bytes>\d+) '
    r'"(?P<referer>.*?)" '
    r'"(?P<user_agent>.*?)"$'
)


def parse_request(request):
    """
    Parse:

        GET /foo HTTP/1.1

    Some scanner requests contain binary garbage or malformed
    HTTP requests. Those are kept as raw requests, but method/path/
    protocol are set to None.
    """

    parts = request.split(" ", 2)

    if len(parts) != 3:
        return None, None, None

    method, path, protocol = parts

    # Avoid putting arbitrary binary data into structured columns.
    if not re.match(r"^[A-Z]+$", method):
        return None, None, None

    if not protocol.startswith("HTTP/"):
        return None, None, None

    return method, path, protocol


def parse_line(line):
    """
    Parse one nginx access log line.

    Returns:
        dict if valid
        None if the line cannot be parsed
    """

    raw_log = line.strip()

    match = LOG_PATTERN.match(raw_log)

    if not match:
        return None

    data = match.groupdict()

    try:
        timestamp = datetime.strptime(
            data["timestamp"],
            "%d/%b/%Y:%H:%M:%S %z"
        )
    except ValueError:
        return None

    try:
        status = int(data["status"])
        response_bytes = int(data["bytes"])
    except ValueError:
        return None

    method, path, protocol = parse_request(data["request"])

    return {
        "request_time": timestamp,
        "ip": data["ip"],
        "method": method,
        "path": path,
        "protocol": protocol,
        "status": status,
        "response_bytes": response_bytes,
        "referer": (
            None
            if data["referer"] == "-"
            else data["referer"]
        ),
        "user_agent": (
            None
            if data["user_agent"] == "-"
            else data["user_agent"]
        ),
        "raw_log": raw_log,
    }


def process_line(line):
    """
    Parse the line and calculate its SHA-256 hash.

    The hash is used as the unique deduplication key.
    """

    parsed = parse_line(line)

    if parsed is None:
        return None

    parsed["raw_log_hash"] = hashlib.sha256(
        parsed["raw_log"].encode("utf-8")
    ).hexdigest()

    return parsed


def read_log_file(filename):
    """
    Supports:

        access.log
        access.log.1
        access.log.2.gz
        etc.
    """

    if filename.endswith(".gz"):
        with gzip.open(
            filename,
            "rt",
            encoding="utf-8",
            errors="replace"
        ) as f:
            for line in f:
                yield line

    else:
        with open(
            filename,
            "r",
            encoding="utf-8",
            errors="replace"
        ) as f:
            for line in f:
                yield line


def find_log_files():
    patterns = [
        "/var/log/nginx/access.log",
        "/var/log/nginx/access.log.*",
    ]

    files = []

    for pattern in patterns:
        files.extend(glob.glob(pattern))

    return sorted(set(files))


def upload_logs():
    files = find_log_files()

    print(f"Found {len(files)} log files")
    print(f"Batch size: {BATCH_SIZE}")
    print()

    conn = psycopg2.connect(DATABASE_URL)

    inserted = 0
    skipped = 0
    malformed = 0
    failed = 0
    processed_since_commit = 0
    total_processed = 0
    commit_number = 0

    try:
        with conn.cursor() as cur:

            for filename in files:

                print(f"Reading {filename}")

                for line in read_log_file(filename):

                    total_processed += 1

                    parsed = process_line(line)

                    # -------------------------------------------------
                    # The line itself could not be parsed.
                    # Nothing is sent to PostgreSQL.
                    # -------------------------------------------------
                    if parsed is None:
                        malformed += 1
                        continue

                    try:
                        # -------------------------------------------------
                        # Savepoint lets us roll back ONLY this INSERT.
                        #
                        # Without this, conn.rollback() would throw away
                        # every successful INSERT since the last COMMIT.
                        # -------------------------------------------------
                        cur.execute("SAVEPOINT insert_log")

                        cur.execute(
                            """
                            INSERT INTO nginx_requests (
                                hostname,
                                request_time,
                                ip,
                                method,
                                path,
                                protocol,
                                status,
                                response_bytes,
                                referer,
                                user_agent,
                                source_file,
                                raw_log,
                                raw_log_hash
                            )
                            VALUES (
                                %(hostname)s,
                                %(request_time)s,
                                %(ip)s,
                                %(method)s,
                                %(path)s,
                                %(protocol)s,
                                %(status)s,
                                %(response_bytes)s,
                                %(referer)s,
                                %(user_agent)s,
                                %(source_file)s,
                                %(raw_log)s,
                                %(raw_log_hash)s
                            )
                            ON CONFLICT (raw_log_hash)
                            DO NOTHING
                            """,
                            {
                                **parsed,
                                "hostname": HOSTNAME,
                                "source_file": filename,
                            }
                        )

                        if cur.rowcount == 1:
                            inserted += 1
                        else:
                            skipped += 1

                        processed_since_commit += 1

                        cur.execute("RELEASE SAVEPOINT insert_log")

                    except Exception as e:
                        # -------------------------------------------------
                        # Roll back ONLY this INSERT.
                        # Previous rows in this batch remain intact.
                        # -------------------------------------------------
                        try:
                            cur.execute(
                                "ROLLBACK TO SAVEPOINT insert_log"
                            )
                            cur.execute(
                                "RELEASE SAVEPOINT insert_log"
                            )
                        except Exception:
                            # If the savepoint itself failed, we cannot
                            # safely continue using this transaction.
                            conn.rollback()
                            processed_since_commit = 0

                        failed += 1

                        print(
                            f"Failed to insert row #{total_processed}: "
                            f"{e}"
                        )

                    # -----------------------------------------------------
                    # Commit every BATCH_SIZE processed database rows.
                    # -----------------------------------------------------
                    if processed_since_commit >= BATCH_SIZE:
                        conn.commit()

                        commit_number += 1

                        print(
                            f"COMMIT #{commit_number}: "
                            f"{inserted} inserted, "
                            f"{skipped} skipped, "
                            f"{failed} failed"
                        )

                        processed_since_commit = 0

            # -------------------------------------------------------------
            # Commit the final partial batch.
            # -------------------------------------------------------------
            if processed_since_commit > 0:
                conn.commit()

                commit_number += 1

                print(
                    f"COMMIT #{commit_number}: "
                    f"{inserted} inserted, "
                    f"{skipped} skipped, "
                    f"{failed} failed"
                )

    except Exception:
        # Something unexpected happened outside an individual INSERT.
        # Roll back anything that hasn't been committed yet.
        conn.rollback()
        raise

    finally:
        conn.close()

    print()
    print("=" * 50)
    print("Done.")
    print("=" * 50)
    print(f"Lines processed:       {total_processed}")
    print(f"Splits:                {commit_number}")
    print(f"Skipped (duplicates):  {skipped}")
    print(f"Malformed:             {malformed}")
    print(f"Failed database rows:  {failed}")
    print(f"Inserted:              {inserted}")


if __name__ == "__main__":
    upload_logs()