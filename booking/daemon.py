#!/usr/bin/env python3
"""Run on every server, activating booking storage according to the inventory."""
import argparse
from pathlib import Path
import signal
import socket
import sys
import threading

from runtime import configuration, initialize_database, signature


def apply_configuration(config, previous, odev_path):
    current = signature(config)
    if current == previous:
        return previous
    if config["server"] is None:
        print("Booking service idle: this machine is not a booking server", flush=True)
    else:
        created = initialize_database(config["database"], config["server"]["id"],
                                      Path(odev_path) / "booking/schema.sql")
        print(f"Booking database {'created' if created else 'validated'}: {config['database']}", flush=True)
        print("Booking service ready (API not implemented)", flush=True)
    return current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--odev-path", default="/opt/odev")
    parser.add_argument("--interval", type=float, default=30, help="Configuration check interval in seconds")
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("--interval must be positive")
    stopped = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stopped.set())
    signal.signal(signal.SIGINT, lambda *_: stopped.set())
    current = None
    last_error = None
    while not stopped.is_set():
        try:
            config = configuration(args.odev_path, socket.gethostname())
            current = apply_configuration(config, current, args.odev_path)
            last_error = None
        except Exception as error:
            # Remain running but inactive until configuration/storage is valid.
            # Report a persistent error once rather than on every check.
            current = None
            if str(error) != last_error:
                print(f"ERROR: {error}", file=sys.stderr, flush=True)
                last_error = str(error)
        stopped.wait(args.interval)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
