import os
import re
import glob
import gzip
from datetime import datetime
import psycopg2


DATABASE_URL = os.getenv("DATABASE_URL")

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
    HTTP requests. Those are kept as raw requests but method/path/
    protocol are set to None.
    """

    parts = request.split(" ", 2)

    if len(parts) != 3:
        return None, None, None

    method, path, protocol = parts

    # Avoid putting arbitrary binary data into structured columns.
    if not re.match(r'^[A-Z]+$', method):
        return None, None, None

    if not protocol.startswith("HTTP/"):
        return None, None, None

    return method, path, protocol


def parse_line(line):
    match = LOG_PATTERN.match(line.strip())

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

    method, path, protocol = parse_request(data["request"])

    return {
        "request_time": timestamp,
        "ip": data["ip"],
        "method": method,
        "path": path,
        "protocol": protocol,
        "status": int(data["status"]),
        "response_bytes": int(data["bytes"]),
        "referer": None if data["referer"] == "-" else data["referer"],
        "user_agent": None if data["user_agent"] == "-" else data["user_agent"],
        "raw_log": line.strip(),
    }


def read_log_file(filename):
    """
    Supports both:
        access.log
        access.log.1
        access.log.2.gz
        ...
    """

    if filename.endswith(".gz"):
        with gzip.open(filename, "rt", encoding="utf-8", errors="replace") as f:
            for line in f:
                yield line
    else:
        with open(filename, "r", encoding="utf-8", errors="replace") as f:
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

    conn = psycopg2.connect(DATABASE_URL)

    inserted = 0
    skipped = 0
    malformed = 0

    try:
        with conn.cursor() as cur:

            for filename in files:

                print(f"Reading {filename}")

                for line in read_log_file(filename):

                    parsed = parse_line(line)

                    if parsed is None:
                        malformed += 1
                        continue

                    try:
                        cur.execute(
                            """
                            INSERT INTO nginx_requests (
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
                                raw_log
                            )
                            VALUES (
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
                                %(raw_log)s
                            )
                            ON CONFLICT (request_time, ip, raw_log)
                            DO NOTHING
                            """,
                            {
                                **parsed,
                                "source_file": filename,
                            }
                        )

                        if cur.rowcount == 1:
                            inserted += 1
                        else:
                            skipped += 1

                    except Exception as e:
                        print(f"Failed to insert log: {e}")
                        conn.rollback()
                        continue

        conn.commit()

    finally:
        conn.close()

    print()
    print("Done.")
    print(f"Inserted:  {inserted}")
    print(f"Skipped:   {skipped}")
    print(f"Malformed: {malformed}")


if __name__ == "__main__":
    upload_logs()