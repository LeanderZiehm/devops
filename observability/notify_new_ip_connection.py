#!/usr/bin/env python3

import subprocess
import time
import json
import urllib.request

NOTIFY_URL = "https://notify.leanderziehm.com/notify/me"
CHECK_INTERVAL = 1  # seconds


def get_connections():
    """Return currently established TCP connections as (local, remote) tuples."""
    result = subprocess.run(
        ["ss", "-tn", "state", "established"],
        capture_output=True,
        text=True,
        check=True,
    )

    connections = set()

    for line in result.stdout.splitlines()[1:]:
        parts = line.split()

        if len(parts) >= 5:
            local = parts[3]
            remote = parts[4]
            connections.add((local, remote))

    return connections


def notify(message):
    """Send a notification to the configured endpoint."""
    data = json.dumps({"text": message}).encode("utf-8")

    request = urllib.request.Request(
        NOTIFY_URL,
        data=data,
        headers={
            "accept": "application/json",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            print(f"Notification sent: HTTP {response.status}")
    except Exception as e:
        print(f"Failed to send notification: {e}")


def main():
    print("Watching for new TCP connections...")

    previous = get_connections()

    while True:
        try:
            current = get_connections()

            new_connections = current - previous

            for local, remote in new_connections:
                message = f"New connection: {remote} -> {local}"
                print(message)
                notify(message)

            previous = current
            time.sleep(CHECK_INTERVAL)

        except KeyboardInterrupt:
            print("\nStopped.")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
