#!/usr/bin/env python3
"""Read-only machine lookup for booking admission."""
import argparse
import http.client
import json
import os
from pathlib import Path
import pwd
import re
import socket
import subprocess
import sys
import syslog
from urllib.parse import urlencode

import yaml

from api import ACCESS_ACCOUNT, SOCKET_PATH, is_administrator
from client import Connection
from runtime import load_inventory


ACCESS_PATH = Path("/etc/odev/booking-access")


def serve(server):
    username = os.environ.get("SSH_ORIGINAL_COMMAND", "")
    active_users = username == "@active-users"
    if not active_users and not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_.-]*\$?", username):
        raise ValueError("Invalid booking access user")
    query = {"server": server}
    if not active_users:
        query["user"] = username
    connection = Connection(SOCKET_PATH, timeout=2)
    try:
        connection.request("GET", "/access?" + urlencode(query))
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError("Booking access lookup failed")
        result = json.load(response)
        if active_users:
            print(json.dumps(result))
        else:
            print("allow" if result["allowed"] is True else "deny")
    finally:
        connection.close()


def assigned_service(root):
    with (root / "vars.yml").open() as stream:
        settings = yaml.safe_load(stream)
    inventory = load_inventory(settings["paths"].get("booking", "/opt/booking.yml"))
    hostname = socket.gethostname().split(".")[0]
    if any(entry["name"] == hostname for entry in inventory["servers"]):
        return None
    return next((entry["name"] for entry in inventory["servers"] if hostname in entry["managed_servers"]), None)


def remote_lookup(service, command):
    endpoint = json.loads((ACCESS_PATH / "endpoint.json").read_text())
    if endpoint["service"] != service:
        raise ValueError(f"Booking access endpoint does not match {service}")
    result = subprocess.run(
        ["/usr/bin/ssh", "-F", "/dev/null", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=3",
         "-o", "StrictHostKeyChecking=yes", "-o", "GlobalKnownHostsFile=/dev/null",
         "-o", f"UserKnownHostsFile={ACCESS_PATH / 'known_hosts'}", "-o", f"HostKeyAlias={service}",
         "-o", "IdentitiesOnly=yes", "-o", "IdentityAgent=none", "-i", str(ACCESS_PATH / "id_ed25519"),
         "-p", str(endpoint["port"]), "-l", ACCESS_ACCOUNT, "--", endpoint["address"], command],
        capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise ValueError(result.stderr.strip() or f"Booking access lookup failed on {service}")
    return result.stdout.strip()


def check(root, username, service=None):
    if service is None:
        service = assigned_service(root)
    if service is None:
        raise ValueError("No booking service assigned to this machine")
    decision = remote_lookup(service, username)
    if decision not in {"allow", "deny"}:
        raise ValueError(f"Booking access lookup failed on {service}")
    if decision == "allow":
        print(f"Access allowed: {username}")
        return 0
    print(f"Access denied: {username}", file=sys.stderr)
    return 1


def check_login(root):
    if os.geteuid() != 0 or os.environ.get("PAM_SERVICE") != "sshd" or os.environ.get("PAM_TYPE") != "account":
        raise ValueError("Invalid SSH account check")
    username = os.environ.get("PAM_USER", "")
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_.-]*\$?", username):
        raise ValueError("Invalid booking access user")
    if pwd.getpwnam(username).pw_uid == 0 or is_administrator(username):
        return 0
    service = assigned_service(root)
    if service is None:
        return 0
    result = check(root, username, service)
    if result:
        syslog.syslog(syslog.LOG_NOTICE, f"Booking required for SSH login: {username}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", metavar="USER")
    mode.add_argument("--serve", metavar="SERVER")
    mode.add_argument("--pam", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    if args.pam:
        syslog.openlog("odev-booking-access")
        return check_login(root)
    if args.serve:
        serve(args.serve)
        return 0
    if not re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_.-]*\$?", args.check):
        raise ValueError("Invalid booking access user")
    return check(root, args.check)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, http.client.HTTPException, subprocess.TimeoutExpired, yaml.YAMLError) as error:
        if "--pam" in sys.argv:
            syslog.syslog(syslog.LOG_ERR, f"Booking access unavailable: {error}")
        print(f"Booking access unavailable: {error}", file=sys.stderr)
        sys.exit(2)
