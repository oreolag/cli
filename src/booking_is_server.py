#!/usr/bin/env python3
"""Determine the local booking-server role from the shared inventory."""

import argparse
from decimal import Decimal, DecimalException
import re
import socket
import sys
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import yaml


def validate_timezone(timezone):
    if not isinstance(timezone, str) or not timezone:
        raise ValueError("booking timezone must be a valid timezone name")
    try:
        ZoneInfo(timezone)
    except (ZoneInfoNotFoundError, ValueError):
        raise ValueError(f"invalid booking timezone: {timezone}") from None
    return timezone


def duration_seconds(value, maximum_hours):
    try:
        if not isinstance(value, str) or len(value) > 32 or not re.fullmatch(r"[0-9]+[mh]", value):
            raise ValueError()
        seconds = int(value[:-1]) * (60 if value[-1] == "m" else 3600)
        if seconds <= 0 or seconds > Decimal(str(maximum_hours)) * 3600:
            raise ValueError()
        return seconds
    except (DecimalException, ValueError, OverflowError):
        raise ValueError(f"Invalid duration: {value}") from None


def booking_timezone(path, hostname=None):
    if not Path(path).exists():
        return "UTC"
    data = load_inventory(path)
    timezone = data.get("timezone", "UTC")
    local = (hostname or socket.gethostname()).split(".")[0]
    for entry in data.get("servers", []):
        if entry["name"] == local or local in entry["managed_servers"]:
            timezone = entry.get("timezone", timezone)
            break
    return validate_timezone(timezone)


def load_inventory(path):
    if not path or not str(path).strip():
        raise ValueError("booking inventory path must not be empty")
    with Path(path).open(encoding="utf-8") as stream:
        data = yaml.safe_load(stream)
    if not isinstance(data, dict) or not isinstance(data.get("servers"), list):
        raise ValueError("booking inventory must contain a servers list")
    validate_timezone(data.get("timezone", "UTC"))
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
        if "timezone" in entry:
            validate_timezone(entry["timezone"])
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
    parser.add_argument("--server", help="Check a managed booking target")
    parser.add_argument("--duration", help="Check duration against this booking host's limit")
    parser.add_argument("--default-server", action="store_true", help="Print the default booking target")
    args = parser.parse_args()
    try:
        if args.server is not None or args.duration is not None or args.default_server:
            data = load_inventory(args.db)
            local = socket.gethostname().split(".")[0]
            entry = next((item for item in data["servers"] if item["name"] == local), None)
            if entry is None and args.participant:
                entry = next((item for item in data["servers"] if local in item["managed_servers"]), None)
            if entry is None:
                raise ValueError("Command not available: odev booking")
            if args.default_server:
                print("-" if entry["name"] == local else local)
                return 0
            if args.server is not None:
                entry = next((item for item in data["servers"] if args.server in item["managed_servers"]), None)
                if entry is None:
                    print(f"Invalid server: {args.server}", file=sys.stderr)
                    return 1
            if args.duration is not None:
                duration_seconds(args.duration, entry["maximum_duration_hours"])
            if args.timezone:
                print(validate_timezone(entry.get("timezone", data.get("timezone", "UTC"))))
            return 0
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
