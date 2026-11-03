#!/usr/bin/env python3
"""Access bookings through the local HTTP API on a booking server."""
import argparse
from datetime import datetime
import http.client
import json
from pathlib import Path
import socket
import sys
from zoneinfo import ZoneInfo

import yaml
from urllib.parse import urlencode

from api import SOCKET_PATH
from runtime import load_inventory
from table import print_bookings


class Connection(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.host)


def local_request(request, path=SOCKET_PATH, endpoint="/bookings", expected_status=201):
    connection = Connection(str(path), timeout=15)
    try:
        body = json.dumps(request)
        connection.request("POST", endpoint, body, {"Content-Type": "application/json"})
        response = connection.getresponse()
        value = json.loads(response.read(16384))
        if response.status != expected_status:
            raise ValueError(value.get("error", "Booking request failed"))
        return value["booking_id"]
    finally:
        connection.close()


def local_listing(day, path=SOCKET_PATH, history=False):
    connection = Connection(str(path), timeout=15)
    try:
        connection.request("GET", "/bookings?" + urlencode({"date": day, "history": int(history)}))
        response = connection.getresponse()
        value = json.loads(response.read())
        if response.status != 200:
            raise ValueError(value.get("error", "Booking request failed"))
        return value
    finally:
        connection.close()


def local_cancellation(booking, confirm=False, path=SOCKET_PATH):
    connection = Connection(str(path), timeout=15)
    try:
        if confirm:
            connection.request("POST", "/bookings/cancel", json.dumps({"booking": booking}),
                               {"Content-Type": "application/json"})
        else:
            connection.request("GET", "/bookings?" + urlencode({"booking": booking}))
        response = connection.getresponse()
        value = json.loads(response.read())
        if response.status != 200:
            raise ValueError(value.get("error", "Booking request failed"))
        return value
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--odev-path", default="/opt/odev")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--cancel")
    parser.add_argument("--share", nargs=3, metavar=("BOOKING", "ACTION", "USER"))
    parser.add_argument("--history", choices=["0", "1"], default="0")
    parser.add_argument("--server")
    parser.add_argument("--date")
    parser.add_argument("--start")
    parser.add_argument("--duration", default="1h")
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
    if args.share:
        booking, action, user = args.share
        local_request({"booking": booking, "action": action, "user": user},
                      endpoint="/bookings/share", expected_status=200)
        message = "Booking shared with" if action == "add" else "Booking collaborator removed"
        print(f"{message}: {user} ({booking})")
        return
    if args.cancel:
        booking = local_cancellation(args.cancel)
        zone = ZoneInfo(booking["timezone"])
        start = datetime.fromtimestamp(booking["start_time"], zone).strftime("%Y-%m-%d %H:%M")
        end = datetime.fromtimestamp(booking["end_time"], zone).strftime("%Y-%m-%d %H:%M")
        print(f"{booking['booking_id']}: {booking['server']} | {start} - {end} ({booking['timezone']})")
        try:
            answer = input("Cancel booking? [y/N]: ")
        except EOFError:
            return
        if answer.strip().lower() not in ["y", "yes"]:
            return
        local_cancellation(args.cancel, confirm=True)
        print(f"Booking cancelled: {args.cancel}")
        return
    if args.list:
        history = args.history == "1"
        print_bookings(local_listing(args.date, history=history), history=history)
        return
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
