#!/usr/bin/env python3
"""Determine the local booking-server role from the shared inventory."""

import argparse
import re
import socket
import sys
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import yaml


def booking_timezone(path):
    if not Path(path).exists():
        return "UTC"
    with Path(path).open(encoding="utf-8") as stream:
        data = yaml.safe_load(stream)
    if not isinstance(data, dict):
        raise ValueError("booking inventory must be a mapping")
    timezone = data.get("timezone", "UTC")
    if not isinstance(timezone, str) or not timezone:
        raise ValueError("booking timezone must be a valid timezone name")
    try:
        ZoneInfo(timezone)
    except (ZoneInfoNotFoundError, ValueError):
        raise ValueError(f"invalid booking timezone: {timezone}") from None
    return timezone


def load_inventory(path):
    if not path or not str(path).strip():
        raise ValueError("booking inventory path must not be empty")
    with Path(path).open(encoding="utf-8") as stream:
        data = yaml.safe_load(stream)
    if not isinstance(data, dict) or not isinstance(data.get("servers"), list):
        raise ValueError("booking inventory must contain a servers list")
    names = set()
    service_ids = set()
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
        service_id = entry.get("id")
        if not isinstance(service_id, str) or not re.fullmatch(r"[0-9]+", service_id) or int(service_id) == 0:
            raise ValueError(f"booking server id for {name} must be a quoted positive numeric string")
        if int(service_id) in service_ids:
            raise ValueError(f"duplicate booking server id: {service_id}")
        service_ids.add(int(service_id))
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
    return data


def is_booking_server(path, hostname, participant=False):
    data = load_inventory(path)
    local = hostname.split(".")[0]
    return any(entry["name"] == local or (participant and local in entry["managed_servers"])
               for entry in data["servers"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, help="Path to booking.yml")
    parser.add_argument("--participant", action="store_true", help="Include managed machines")
    parser.add_argument("--timezone", action="store_true", help="Print the booking timezone (defaults to UTC)")
    args = parser.parse_args()
    try:
        if args.timezone:
            print(booking_timezone(args.db))
            return 0
        result = is_booking_server(args.db, socket.gethostname(), args.participant)
    except (OSError, ValueError, yaml.YAMLError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(int(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
