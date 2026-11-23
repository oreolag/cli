#!/usr/bin/env python3
"""Shared CLI messages, usable from Python or Bash."""

import argparse
import sys


MESSAGES = {
    "permission_denied": "Permission denied: {0}",
    "missing_tool": "Missing tool: {0}",
    "login_failed": "Login failed: {0}",
    "workflow_already_exists": "Workflow already exists: {0}",
    "repository_already_exists": "Repository already exists: {0}",
    "template_not_found": "Template not found: {0}",
    "invalid_workflow_name": "Invalid workflow name: {0}",
    "link_creation_failed": "Link creation failed: {0}",
    "created_workflow": "Workflow created: {0}",
    "playbook_already_exists": "Playbook already exists: {0}",
    "invalid_playbook_name": "Invalid playbook name: {0}",
    "playbook_branch_required": "Switch to the playbook branch before creating: {0}",
    "created_playbook": "Playbook created: {0}",
}


def message(key, *values):
    """Format a message without printing it."""
    if key not in MESSAGES:
        raise ValueError(f"Unknown message key: {key}")
    template = MESSAGES[key]
    expected = template.count("{")
    if len(values) != expected:
        raise ValueError(f"Message {key} expects {expected} values, got {len(values)}")
    return template.format(*values)


def print_message(key, *values, error=False):
    """Print to stdout, or stderr when error=True; the caller handles exiting."""
    print(message(key, *values), file=sys.stderr if error else sys.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    output = parser.add_mutually_exclusive_group(required=True)
    output.add_argument("--error", action="store_true", help="print to stderr")
    output.add_argument("--success", action="store_true", help="print to stdout")
    parser.add_argument("key", choices=MESSAGES)
    parser.add_argument("values", nargs="*")
    args = parser.parse_args()
    try:
        print_message(args.key, *args.values, error=args.error)
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
