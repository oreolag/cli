#!/usr/bin/env python3
"""
cmdb_get.py

Usage:
  cmdb_get.py <category> [device_id_or_field] [field_or_subid] [subfield_or_portid] [--db PATH]

Default DB resolution (if --db not provided):
  1) $CMDB_DB_FILE (if set)
  2) /opt/<local_hostname_short>.yml

Notes:
  - device_id is OPTIONAL for singleton categories (e.g. cpu) or when the category is
    stored as a single dict in the YAML. For categories with multiple entries (list),
    device_id is required unless the list has exactly one element.
  - Flexible positional argument parsing supports these common calls:
      cmdb_get.py cpu model                -> category=cpu, field=model
      cmdb_get.py cpu 0 memory            -> category=cpu, device_id=0, field=memory
      cmdb_get.py cpu numa                 -> category=cpu, field=numa
      cmdb_get.py cpu numa 0               -> category=cpu, field=numa, sub_id=0  (print NUMA entry)
      cmdb_get.py cpu numa 0 memory        -> category=cpu, field=numa, sub_id=0, subfield=memory
      cmdb_get.py endata 0 ip_address 0   -> category=endata, device_id=0, field=ip_address, port_id=0
"""

from __future__ import annotations

import argparse
import os
import socket
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml  # PyYAML
except ImportError:
    print(
        "ERROR: PyYAML not installed. Install with: python3 -m pip install pyyaml",
        file=sys.stderr,
    )
    sys.exit(1)


def load_yaml(path: Path) -> Dict[str, Any]:
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        sys.exit(2)
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
        return data if isinstance(data, dict) else {}


def find_by_id(items: Any, target_id: int) -> Optional[Dict[str, Any]]:
    if not isinstance(items, list):
        return None
    for it in items:
        if isinstance(it, dict) and it.get("id") == target_id:
            return it
    return None


def dump_nice(obj: Dict[str, Any], indent: int = 0) -> str:
    """Minimal, stable pretty printer: key: value with nested lists/dicts."""
    lines: List[str] = []
    pad = " " * indent
    for k, v in obj.items():
        if v is None:
            continue
        if isinstance(v, dict):
            if not v:
                continue
            lines.append(f"{pad}{k}:")
            nested = dump_nice(v, indent + 2)
            if nested:
                lines.append(nested)
        elif isinstance(v, list):
            if not v:
                continue
            lines.append(f"{pad}{k}:")
            for item in v:
                if isinstance(item, dict):
                    lines.append(f"{pad}  -")
                    nested = dump_nice(item, indent + 4)
                    if nested:
                        lines.append(nested)
                else:
                    lines.append(f"{pad}  - {item}")
        else:
            lines.append(f"{pad}{k}: {v}")

    return "\n".join([ln for ln in "\n".join(lines).splitlines() if ln.strip() != ""])


def format_value(val: Any) -> str:
    """Output format for field values."""
    if val is None:
        return ""
    if isinstance(val, list):
        return " ".join(str(x) for x in val)
    if isinstance(val, dict):
        return dump_nice(val)
    return str(val)


def resolve_db_path(arg_db: Optional[str]) -> Path:
    """
    Resolve DB path:
      1) --db PATH
      2) $CMDB_DB_FILE
      3) /opt/<local_hostname_short>.yml
    """
    if arg_db:
        return Path(arg_db)

    env_db = os.environ.get("CMDB_DB_FILE")
    if env_db:
        return Path(env_db)

    local_short = socket.gethostname().split(".")[0]
    return Path("/opt") / f"{local_short}.yml"


def is_int(s: Optional[str]) -> bool:
    if s is None:
        return False
    try:
        int(s)
        return True
    except ValueError:
        return False


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("category", help="e.g. cpu, numa, endata, gpus, accel")
    # flexible positional parsing
    ap.add_argument("a", nargs="?", default=None, help="device_id or field (flexible)")
    ap.add_argument("b", nargs="?", default=None, help="field or sub_id/port_id (flexible)")
    ap.add_argument("c", nargs="?", default=None, help="subfield or port_id (flexible)")
    ap.add_argument("--db", default=None, help="Path to YAML DB. If omitted: $CMDB_DB_FILE or /opt/<hostname>.yml")
    args = ap.parse_args()

    db_path = resolve_db_path(args.db)
    data = load_yaml(db_path)

    # Interpret positional args into:
    # device_id (Optional[int]) -- for category devices lists
    # field (Optional[str])     -- the top-level field to fetch from the device (or 'numa' etc.)
    # sub_id (Optional[int])    -- a nested id inside 'field' when field is a list of dicts (e.g. numa id)
    # subfield (Optional[str])  -- field inside that nested dict
    # port_id (Optional[int])   -- numeric port id used for uplinks/access lookups
    device_id: Optional[int] = None
    field: Optional[str] = None
    sub_id: Optional[int] = None
    subfield: Optional[str] = None
    port_id: Optional[int] = None

    a = args.a
    b = args.b
    c = args.c

    # Case 1: first positional looks like an integer -> it's device_id
    if is_int(a):
        device_id = int(a)
        # then b is field (string) or maybe port id if numeric
        if b is not None and not is_int(b):
            field = b
            # c might be port_id
            if is_int(c):
                port_id = int(c)
        else:
            # b is numeric (maybe user typed: category device_id port_id) -> treat b as port_id
            if is_int(b):
                port_id = int(b)
                # c might be field (unlikely) - but we ignore that ambiguous case
            else:
                field = None if b is None else b
    else:
        # a is not integer -> treat as field
        field = a
        # if b is integer -> it's a sub-id (e.g., numa id) or port id (disambiguate later)
        if is_int(b):
            sub_id = int(b)
            # if c is non-int -> it's subfield name; if c is int -> it's port_id (but prefer subfield)
            if c is not None and not is_int(c):
                subfield = c
            elif is_int(c):
                port_id = int(c)
        else:
            # b is non-int -> could be subfield or port id; if b is non-int we treat it as subfield
            if b is not None:
                subfield = b
            # c might be port_id
            if is_int(c):
                port_id = int(c)

    # Load categories: prefer devices.{category}, fallback to top-level category
    devices = data.get("devices", {})
    if not isinstance(devices, dict):
        devices = {}

    dev_list = devices.get(args.category)
    if dev_list is None:
        dev_list = data.get(args.category)

    if dev_list is None:
        return 0

    dev = None

    # If category is a dict -> singleton
    if isinstance(dev_list, dict):
        dev = dev_list

    # If category is a list
    elif isinstance(dev_list, list):
        if device_id is None:
            # if list length == 1, assume the single element
            if len(dev_list) == 1:
                dev = dev_list[0]
            else:
                print("ERROR: device_id required for this category", file=sys.stderr)
                return 3
        else:
            dev = find_by_id(dev_list, device_id)
            if not dev:
                return 0
    else:
        return 0

    # If no field -> print whole device
    if not field:
        out = dump_nice(dev)
        if out:
            print(out)
        return 0

    # If user asked for a nested list field (e.g. field == 'numa') and provided sub_id:
    # return the nested entry or a nested field.
    if sub_id is not None and isinstance(dev.get(field), list):
        nested_list = dev.get(field)
        nested_entry = find_by_id(nested_list, sub_id)
        if not nested_entry:
            # allow sub_id to be index in list if ids are missing (fallback)
            try:
                nested_entry = nested_list[sub_id]
            except Exception:
                nested_entry = None
        if not nested_entry:
            return 0
        # If subfield requested -> print it
        if subfield:
            val = nested_entry.get(subfield)
            out = format_value(val)
            if out:
                print(out)
            return 0
        # else print the whole nested entry
        out = dump_nice(nested_entry)
        if out:
            print(out)
        return 0

    # If port_id provided -> inspect port-like lists (access/uplinks/downlinks/interfaces/ports)
    if port_id is not None:
        pid = port_id
        ports: List[Dict[str, Any]] = []

        # direct common keys
        for key in ("access", "uplinks", "downlinks", "interfaces", "ports"):
            v = dev.get(key)
            if isinstance(v, list):
                ports = v
                break

        # one-level nested search (e.g., dev['endata']['uplinks'])
        if not ports:
            for k, v in dev.items():
                if isinstance(v, dict):
                    for k2, v2 in v.items():
                        if isinstance(v2, list):
                            ports = v2
                            break
                    if ports:
                        break

        # final attempt: if this is an accel-like entry, look for endata.uplinks explicitly
        if not ports:
            nested = dev.get("endata")
            if isinstance(nested, dict):
                upl = nested.get("uplinks")
                if isinstance(upl, list):
                    ports = upl

        port = find_by_id(ports, pid)
        if not port:
            # fallback: if device has 'numa' list, treat pid as numa id and return its field (if requested)
            numa = dev.get("numa")
            if isinstance(numa, list):
                numa_entry = find_by_id(numa, pid)
                if numa_entry:
                    # if the requested field is a nested key inside numa
                    val = numa_entry.get(field)
                    out = format_value(val)
                    if out:
                        print(out)
                        return 0
            return 0

        val = port.get(field)
        out = format_value(val)
        if out:
            print(out)
        return 0

    # Device-level field
    val = dev.get(field)

    # Special case: field refers to nested list but user didn't pass sub_id; print list summary
    if isinstance(val, list) and val and isinstance(val[0], dict):
        # print each entry id on one line (or dump full list)
        out = dump_nice({field: val})
        if out:
            print(out)
        return 0

    out = format_value(val)
    if out:
        print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())