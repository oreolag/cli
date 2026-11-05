#!/usr/bin/env python3
"""Access bookings through the local HTTP API on a booking server."""
import argparse
from datetime import datetime, timedelta
import http.client
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
from zoneinfo import ZoneInfo

import yaml
from urllib.parse import urlencode

from api import SOCKET_PATH
from runtime import booking_timezone, load_inventory
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


def list_remote_bookings(root, peers, date=None):
    command = [str(root / "odev"), "booking", "list"]
    if date is not None:
        command.extend(["--date", date])
    run_remote_booking(root, peers, command, "list bookings")


def run_remote_booking(root, peers, command, operation, capture=False):
    if not peers:
        return
    sys.stdout.flush()
    with tempfile.TemporaryDirectory(prefix="odev-booking-") as directory:
        inventory = Path(directory) / "inventory.yml"
        results = Path(directory) / "results.json"
        inventory.write_text(yaml.safe_dump({"booking_peers": {"hosts": {peer: {} for peer in peers}}}))
        variables = {"booking_list_command": command, "booking_list_results": str(results)}
        run = subprocess.run(["ansible-playbook", "-i", str(inventory), "--ssh-extra-args=-o BatchMode=yes",
                              "--extra-vars", json.dumps(variables),
                              str(root / "cmd/booking/booking_list_all.yml")],
                             capture_output=True, text=True)
        if run.returncode:
            raise ValueError(f"Could not {operation} remotely:\n{run.stderr.strip() or run.stdout.strip()}")
        remote = json.loads(results.read_text())
        failed = False
        outputs = []
        for peer in peers:
            result = remote.get(peer, {})
            if result.get("rc") == 0:
                if capture:
                    outputs.append(result["stdout"])
                else:
                    print(result["stdout"])
            else:
                detail = result.get("stderr") or result.get("msg") or "No result"
                print(f"Could not {operation} on {peer}: {detail}", file=sys.stderr)
                failed = True
        if failed:
            sys.exit(1)
        if capture:
            return "\n".join(outputs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--odev-path", default="/opt/odev")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--local-only", action="store_true")
    parser.add_argument("--all", choices=["0", "1"], default="0")
    parser.add_argument("--cancel")
    parser.add_argument("--cancel-stage", choices=["preview", "confirm"], help=argparse.SUPPRESS)
    parser.add_argument("--share", nargs=3, metavar=("BOOKING", "ACTION", "USER"))
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
    if entry is None and args.local_only:
        raise ValueError("Command not available: odev booking")
    assigned = None
    if entry is None:
        assigned = next((item for item in inventory["servers"] if local in item["managed_servers"]), None)
        if assigned is None:
            raise ValueError("Command not available: odev booking")
    if args.share:
        booking, action, user = args.share
        if assigned is not None:
            command = ["/usr/bin/python3", str(root / "booking/client.py"), "--odev-path", str(root),
                       "--local-only", "--share", booking, action, user]
            run_remote_booking(root, [assigned["name"]], command, "update booking collaborators")
            return
        local_request({"booking": booking, "action": action, "user": user},
                      endpoint="/bookings/share", expected_status=200)
        message = "Booking shared with" if action == "add" else "Booking collaborator removed"
        print(f"{message}: {user} ({booking})")
        return
    if args.cancel:
        if args.cancel_stage:
            if not args.local_only:
                raise ValueError("Invalid cancellation request")
            result = local_cancellation(args.cancel, confirm=args.cancel_stage == "confirm")
            print(json.dumps(result))
            return
        if assigned is None:
            booking = local_cancellation(args.cancel)
        else:
            peers = [assigned["name"]]
            command = ["/usr/bin/python3", str(root / "booking/client.py"), "--odev-path", str(root),
                       "--local-only", "--cancel", args.cancel, "--cancel-stage"]
            booking = json.loads(run_remote_booking(root, peers, command + ["preview"],
                                                   "preview cancellation", capture=True))
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
        if assigned is None:
            local_cancellation(args.cancel, confirm=True)
        else:
            run_remote_booking(root, peers, command + ["confirm"], "cancel booking", capture=True)
        print(f"Booking cancelled: {args.cancel}")
        return
    if args.list:
        full_day = args.date is not None
        if full_day and args.all == "1":
            raise ValueError("Invalid flags: --all and --date")
        if assigned is not None:
            peers = [assigned["name"]]
            if args.all == "1":
                peers.extend(item["name"] for item in inventory["servers"] if item["name"] != assigned["name"])
            list_remote_bookings(root, peers, args.date)
            return
        date = args.date
        relative_days = {"yesterday": -1, "today": 0, "tomorrow": 1}
        if not full_day or date in relative_days:
            zone = ZoneInfo(booking_timezone(inventory_path, local))
            date = (datetime.now(zone).date() + timedelta(days=relative_days.get(date, 0))).isoformat()
        print_bookings(local_listing(date, history=full_day), full_day=full_day)
        if args.all == "1":
            peers = [item["name"] for item in inventory["servers"] if item["name"] != local]
            list_remote_bookings(root, peers)
        return
    service = assigned if assigned is not None else entry
    if args.server not in service["managed_servers"]:
        raise ValueError(f"Invalid server: {args.server}")
    if assigned is not None:
        if args.date is None or args.start is None:
            raise ValueError("Booking date and start time are required")
        command = ["/usr/bin/python3", str(root / "booking/client.py"), "--odev-path", str(root),
                   "--local-only", "--server", args.server, "--date", args.date, "--start", args.start,
                   "--duration", args.duration, "--shared", args.shared]
        run_remote_booking(root, [service["name"]], command, "create booking")
        return
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
