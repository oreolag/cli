#!/usr/bin/env python3
"""Create bookings through the local HTTP API on a booking server."""
import argparse
import http.client
import json
from pathlib import Path
import socket
import sys

import yaml

from api import SOCKET_PATH
from runtime import load_inventory


class Connection(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.host)


def local_request(request, path=SOCKET_PATH):
    connection = Connection(str(path), timeout=15)
    try:
        body = json.dumps(request)
        connection.request("POST", "/bookings", body, {"Content-Type": "application/json"})
        response = connection.getresponse()
        value = json.loads(response.read(16384))
        if response.status != 201:
            raise ValueError(value.get("error", "Booking request failed"))
        return value["booking_id"]
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--odev-path", default="/opt/odev")
    parser.add_argument("--server")
    parser.add_argument("--date")
    parser.add_argument("--start")
    parser.add_argument("--duration", default="1")
    parser.add_argument("--shared", default="-")
    args = parser.parse_args()
    root = Path(args.odev_path)
    with (root / "vars.yml").open() as stream:
        settings = yaml.safe_load(stream)
    inventory_path = settings["paths"].get("booking", "/opt/booking.yml")
    inventory = load_inventory(inventory_path)
    local = socket.gethostname().split(".")[0]
    entry = next((entry for entry in inventory["servers"] if entry["name"] == local), None)
    if entry is None:
        raise ValueError("Command not available: odev booking")
    if args.server not in entry["managed_servers"]:
        raise ValueError(f"Invalid server: {args.server}")
    shared = [] if args.shared == "-" else [user.strip() for user in args.shared.split(",")]
    request = {"server": args.server, "date": args.date, "start": args.start,
               "duration": args.duration, "shared": shared}
    booking_id = local_request(request)
    print(f"Booking created: {booking_id}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, http.client.HTTPException) as error:
        print(str(error) if isinstance(error, ValueError) else f"Booking service unavailable: {error}", file=sys.stderr)
        sys.exit(1)
