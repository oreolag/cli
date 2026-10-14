#!/usr/bin/env python3
"""Determine the local booking-server role from the shared inventory."""

import argparse
import socket
import sys
from pathlib import Path

import yaml


def is_booking_server(path, hostname, participant=False):
    if not path or not str(path).strip():
        raise ValueError("booking inventory path must not be empty")
    with Path(path).open(encoding="utf-8") as stream:
        data = yaml.safe_load(stream)
    if not isinstance(data, dict) or not isinstance(data.get("servers"), list):
        raise ValueError("booking inventory must contain a servers list")
    names = set()
    managed = set()
    for entry in data["servers"]:
        if not isinstance(entry, dict):
            raise ValueError("each booking server must be a mapping")
        name = entry.get("name")
        if not isinstance(name, str) or not name.strip() or name != name.strip() or "." in name:
            raise ValueError("booking server names must be nonempty short hostnames")
        if name in names:
            raise ValueError(f"duplicate booking server: {name}")
        names.add(name)
        if not isinstance(entry.get("terminate_jobs", False), bool):
            raise ValueError(f"terminate_jobs for {name} must be true or false")
        machines = entry.get("managed_servers")
        if not isinstance(machines, list):
            raise ValueError(f"managed_servers for {name} must be a list")
        for machine in machines:
            if not isinstance(machine, str) or not machine.strip() or machine != machine.strip() or "." in machine:
                raise ValueError("managed server names must be nonempty short hostnames")
            if machine in managed:
                raise ValueError(f"duplicate managed server assignment: {machine}")
            managed.add(machine)
        duration = entry.get("maximum_duration_hours")
        if isinstance(duration, bool) or not isinstance(duration, (int, float)) or not 0 < duration < float("inf"):
            raise ValueError(f"maximum_duration_hours for {name} must be a positive finite number")
    local = hostname.split(".")[0]
    return local in names or (participant and local in managed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, help="Path to booking.yml")
    parser.add_argument("--participant", action="store_true", help="Include managed machines")
    args = parser.parse_args()
    try:
        result = is_booking_server(args.db, socket.gethostname(), args.participant)
    except (OSError, ValueError, yaml.YAMLError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(int(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
