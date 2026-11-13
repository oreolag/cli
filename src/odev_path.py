#!/usr/bin/env python3
"""Resolve an odev user-data directory without creating or modifying files."""
import argparse
import os
from pathlib import Path
import pwd
import re
import sys

import yaml


CONFIG_PATH = Path("/opt/odev_path.yml")
DIRECTORIES = ("models", "projects", "workflows", "playbooks")
USER_VARIABLE = re.compile(r"\$\{(HOME|USER)\}|\$(HOME|USER)\b")


def invoking_user():
    """Use sudo's original UID only while running as root; otherwise use self."""
    uid = os.geteuid()
    if uid == 0 and "SUDO_UID" in os.environ:
        value = os.environ["SUDO_UID"]
        if not value.isdecimal():
            raise ValueError("Invalid SUDO_UID")
        uid = int(value)
    try:
        return pwd.getpwuid(uid)
    except KeyError:
        raise ValueError(f"No account found for UID {uid}") from None


def resolve_path(directory=None, config_path=CONFIG_PATH):
    if directory is not None and directory not in DIRECTORIES:
        raise ValueError(f"Unknown odev data directory: {directory}")
    with Path(config_path).open(encoding="utf-8") as stream:
        config = yaml.safe_load(stream)
    value = config.get("data_path") if isinstance(config, dict) else None
    if not isinstance(value, str) or not value.strip():
        raise ValueError("data_path must be a nonempty string")
    if any(character in value for character in ("\x00", "\n", "\r")):
        raise ValueError("data_path must be a single path without control characters")

    user = invoking_user()
    variables = {"HOME": user.pw_dir, "USER": user.pw_name}
    expanded = USER_VARIABLE.sub(lambda match: variables[match.group(1) or match.group(2)], value)
    if "$" in expanded:
        raise ValueError("Only HOME and USER variables are supported in data_path")
    if expanded == "~" or expanded.startswith("~/"):
        expanded = user.pw_dir + expanded[1:]
    if not os.path.isabs(expanded):
        raise ValueError("data_path must resolve to an absolute path")
    root = Path(os.path.normpath(expanded))
    return root / directory if directory is not None else root


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", choices=DIRECTORIES,
                        help="Omit to print the data root")
    parser.add_argument("--db", type=Path, default=CONFIG_PATH,
                        help="Configuration file (default: /opt/odev_path.yml)")
    args = parser.parse_args(argv)
    try:
        path = resolve_path(args.directory, args.db)
    except (OSError, ValueError, yaml.YAMLError) as error:
        print(f"Cannot resolve odev data path: {error}", file=sys.stderr)
        return 1
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
