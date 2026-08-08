#!/usr/bin/env python3

import os
import re
import gzip
import json
import glob
import argparse
from collections import defaultdict

DEFAULT_LOG_PATHS = [
    "/var/log/nginx/access.log",
    "/var/log/nginx/access.log.*",
]

DEFAULT_OUTPUT = "nginx_requests_daily.json"

MONTHS = {
    "Jan": "01",
    "Feb": "02",
    "Mar": "03",
    "Apr": "04",
    "May": "05",
    "Jun": "06",
    "Jul": "07",
    "Aug": "08",
    "Sep": "09",
    "Oct": "10",
    "Nov": "11",
    "Dec": "12",
}

DATE_RE = re.compile(
    r"\[(\d{2})/(\w{3})/(\d{4}):"
)


def open_log(filename):
    if filename.endswith(".gz"):
        return gzip.open(filename, "rt", errors="ignore")
    return open(filename, "r", errors="ignore")


def find_logs(custom_path=None):
    paths = [custom_path] if custom_path else DEFAULT_LOG_PATHS

    logs = []

    for path in paths:
        logs.extend(glob.glob(path))

    return sorted(set(logs))


def parse_logs(logs):
    daily = defaultdict(int)

    for logfile in logs:
        print(f"Reading {logfile}")

        try:
            with open_log(logfile) as f:
                for line in f:
                    match = DATE_RE.search(line)

                    if not match:
                        continue

                    day, month, year = match.groups()

                    date = (
                        f"{year}-"
                        f"{MONTHS.get(month, '00')}-"
                        f"{day}"
                    )

                    daily[date] += 1

        except Exception as e:
            print(f"Skipping {logfile}: {e}")

    return daily


def main():

    parser = argparse.ArgumentParser(
        description="Generate daily nginx request statistics"
    )

    parser.add_argument(
        "--logs",
        help="Override nginx log path"
    )

    parser.add_argument(
        "--output",
        default=DEFAULT_OUTPUT,
        help="JSON output filename"
    )

    args = parser.parse_args()


    logs = find_logs(args.logs)

    if not logs:
        print("No nginx logs found.")
        print("Checked:")
        for p in DEFAULT_LOG_PATHS:
            print(" ", p)
        return


    stats = parse_logs(logs)

    result = [
        {
            "date": day,
            "requests": count
        }
        for day, count in sorted(stats.items())
    ]


    with open(args.output, "w") as f:
        json.dump(
            result,
            f,
            indent=2
        )


    print()
    print(f"Done.")
    print(f"Logs processed: {len(logs)}")
    print(f"Days found: {len(result)}")
    print(f"Saved: {args.output}")


if __name__ == "__main__":
    main()