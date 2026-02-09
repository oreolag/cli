#!/usr/bin/env python3
"""
constants_get.py

Read a vars.yml-style YAML file and print a value.

Usage:
  constants_get.py <section> <key> [--db PATH] [--sep SEP]

Examples:
  ./constants_get.py paths tmp
  ./constants_get.py --db /opt/vars.yml users docker # -> jmoya82,helen
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Any, Dict, Optional

try:
    import yaml  # PyYAML
except ImportError:
    print("ERROR: PyYAML not installed. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def load_yaml(path: Path) -> Dict[str, Any]:
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        sys.exit(2)
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
        return data if isinstance(data, dict) else {}


def resolve_db_path(arg_db: Optional[str]) -> Path:
    """
    Resolve vars DB path:
      1) --db PATH
      2) $VARS_DB_FILE
      3) ./vars.yml
      4) /opt/vars.yml
    """
    if arg_db:
        return Path(arg_db)

    env_db = os.environ.get("VARS_DB_FILE")
    if env_db:
        return Path(env_db)

    local = Path("./vars.yml")
    if local.exists():
        return local

    return Path("/opt/vars.yml")


def format_value(val: Any, sep: str) -> str:
    if val is None:
        return ""

    # For lists (e.g., users.docker): join with separator (default comma)
    if isinstance(val, list):
        return sep.join(str(x) for x in val)

    # For simple scalars: print as-is
    if isinstance(val, (str, int, float, bool)):
        return str(val)

    # For dicts/other: YAML one-liner-ish (stable enough)
    if isinstance(val, dict):
        # keep minimal: key=value pairs joined
        return ", ".join(f"{k}={v}" for k, v in val.items())

    return str(val)


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("section", help="Top-level section (e.g. nvidia, mpi, users, network, system)")
    ap.add_argument("key", help="Key within the section (e.g. CUDA_HOME, MPI_HOME, docker, mtu_default)")
    ap.add_argument("--db", default=None, help="Path to vars YAML. If omitted: $VARS_DB_FILE, ./vars.yml, or /opt/vars.yml")
    ap.add_argument("--sep", default=",", help="Separator for list output (default: ',')")

    args = ap.parse_args()

    db_path = resolve_db_path(args.db)
    data = load_yaml(db_path)

    section_obj = data.get(args.section)
    if not isinstance(section_obj, dict):
        return 0

    val = section_obj.get(args.key)
    out = format_value(val, args.sep)
    if out != "":
        print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# author: https://github.com/jmoya82