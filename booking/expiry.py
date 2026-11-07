#!/usr/bin/env python3
"""End unauthorized SSH sessions on managed machines."""
import argparse
import json
import os
from pathlib import Path
import pwd
import socket
import subprocess
import sys

import yaml

from access import is_administrator, remote_lookup
from api import require_user
from runtime import load_inventory


def command(*args):
    return subprocess.run(args, capture_output=True, text=True, check=True, timeout=10).stdout


def settings(root):
    if "# BEGIN ODEV BOOKING ADMISSION" not in Path("/etc/pam.d/sshd").read_text():
        return None
    with (root / "vars.yml").open() as stream:
        paths = yaml.safe_load(stream)["paths"]
    inventory = load_inventory(paths.get("booking", "/opt/booking.yml"))
    local = socket.gethostname().split(".")[0]
    if any(entry["name"] == local for entry in inventory["servers"]):
        return None
    return next((entry for entry in inventory["servers"] if local in entry["managed_servers"]), None)


def eligible(uid, minimum_uid):
    user = pwd.getpwuid(uid)
    # System accounts are outside booking enforcement.
    if uid == 0 or uid < minimum_uid or is_administrator(user.pw_name):
        return False
    try:
        require_user(user.pw_name)
    except ValueError:
        return False
    return True


def session_properties(session):
    output = command("loginctl", "show-session", session, "--no-pager",
                     "--property=User", "--property=Service", "--property=Leader")
    return dict(line.split("=", 1) for line in output.splitlines() if "=" in line)


def sweep(root, dry_run=False):
    config = settings(root)
    if config is None:
        return
    result = json.loads(remote_lookup(config["name"], "@active-users"))
    allowed = result["users"]
    if not isinstance(allowed, list) or any(not isinstance(user, str) or not user for user in allowed):
        raise ValueError("Invalid booking authorization response")
    terminate_jobs = config.get("terminate_jobs", False)
    minimum_uid = 1000
    for line in Path("/etc/login.defs").read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0] == "UID_MIN":
            minimum_uid = int(fields[1])
            break
    sessions = {}
    for line in command("loginctl", "list-sessions", "--no-legend", "--no-pager").splitlines():
        session = line.split()[0]
        try:
            properties = session_properties(session)
        except subprocess.CalledProcessError:
            continue  # A session can end while the list is being read.
        if properties.get("Service") == "sshd":
            uid = int(properties["User"])
            sessions.setdefault(uid, []).append((session, properties))
    candidates = set(sessions)
    if terminate_jobs:
        # Include users whose jobs outlive their SSH session.
        for line in command("loginctl", "list-users", "--no-legend", "--no-pager").splitlines():
            candidates.add(int(line.split()[0]))
    for uid in sorted(candidates):
        try:
            if not eligible(uid, minimum_uid):
                continue
            username = pwd.getpwuid(uid).pw_name
        except KeyError:
            continue
        if username in allowed:
            continue
        # A CMDB update can release a machine while a lookup is in progress.
        if settings(root) != config:
            return
        if terminate_jobs:
            print(f"Booking expired: {username}; terminate sessions and jobs", flush=True)
            if not dry_run:
                command("loginctl", "terminate-user", str(uid))
        else:
            for session, original in sessions.get(uid, []):
                try:
                    if session_properties(session) != original:
                        continue
                except subprocess.CalledProcessError:
                    continue
                print(f"Booking expired: {username}; disconnect session {session}", flush=True)
                if not dry_run:
                    command("loginctl", "kill-session", "--kill-whom=leader", "--signal=SIGTERM", session)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise PermissionError("Booking expiry requires root")
    sweep(Path(__file__).resolve().parents[1], args.dry_run)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Booking expiry check failed: {error}", file=sys.stderr)
        sys.exit(1)
