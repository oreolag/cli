#!/usr/bin/env python3
"""Read-only machine lookup for booking admission."""
import argparse
import http.client
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
from urllib.parse import urlencode

import yaml

from api import ACCESS_ACCOUNT, SOCKET_PATH
from client import Connection
from runtime import load_inventory


ACCESS_PATH = Path("/etc/odev/booking-access")


def serve(server):
    username = os.environ.get("SSH_ORIGINAL_COMMAND", "")
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_.-]*\$?", username):
        raise ValueError("Invalid booking access user")
    connection = Connection(SOCKET_PATH, timeout=2)
    try:
        connection.request("GET", "/access?" + urlencode({"server": server, "user": username}))
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError("Booking access lookup failed")
        result = json.load(response)
        print("allow" if result["allowed"] is True else "deny")
    finally:
        connection.close()


def check(root, username):
    with (root / "vars.yml").open() as stream:
        settings = yaml.safe_load(stream)
    inventory = load_inventory(settings["paths"].get("booking", "/opt/booking.yml"))
    hostname = socket.gethostname().split(".")[0]
    service = next((entry["name"] for entry in inventory["servers"] if hostname in entry["managed_servers"]), None)
    if service is None:
        raise ValueError(f"No booking service assigned to {hostname}")
    endpoint = json.loads((ACCESS_PATH / "endpoint.json").read_text())
    if endpoint["service"] != service:
        raise ValueError(f"Booking access endpoint does not match {service}")
    result = subprocess.run(
        ["/usr/bin/ssh", "-F", "/dev/null", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=3",
         "-o", "StrictHostKeyChecking=yes", "-o", "GlobalKnownHostsFile=/dev/null",
         "-o", f"UserKnownHostsFile={ACCESS_PATH / 'known_hosts'}", "-o", f"HostKeyAlias={service}",
         "-o", "IdentitiesOnly=yes", "-i", str(ACCESS_PATH / "id_ed25519"),
         "-p", str(endpoint["port"]), "-l", ACCESS_ACCOUNT, "--", endpoint["address"], username],
        capture_output=True, text=True, timeout=5)
    decision = result.stdout.strip()
    if result.returncode or decision not in {"allow", "deny"}:
        raise ValueError(result.stderr.strip() or f"Booking access lookup failed on {service}")
    if decision == "allow":
        print(f"Access allowed: {username}")
        return 0
    print(f"Access denied: {username}", file=sys.stderr)
    return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", metavar="USER")
    mode.add_argument("--serve", metavar="SERVER")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve)
        return 0
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_.-]*\$?", args.check):
        raise ValueError("Invalid booking access user")
    return check(Path(__file__).resolve().parents[1], args.check)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, http.client.HTTPException, subprocess.TimeoutExpired, yaml.YAMLError) as error:
        print(f"Booking access unavailable: {error}", file=sys.stderr)
        sys.exit(2)
