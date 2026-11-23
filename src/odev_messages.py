#!/usr/bin/env python3
"""Messages for CLI users, usable from Python or Bash.

Keep internal service, configuration, and database diagnostics in their modules."""

import argparse
import sys


MESSAGES = {
    "command_not_found": "Command not found: {0}",
    "unknown_flag": "Unknown flag: {0}",
    "missing_value": "Missing value: {0}",
    "missing_required_flag": "Missing required flag: {0}",
    "invalid_value": "Invalid value for {0}: '{1}' (expected: {2})",
    "invalid_playbook_variables": "Invalid playbook variables: {0}",
    "project_already_exists": "Project already exists: {0}",
    "invalid_devices_format": "Invalid devices format: {0}",
    "invalid_device_index": "Invalid device index: {0}",
    "no_booked_remote_hosts": "No booked remote hosts: {0}",
    "ssh_check_failed": "SSH check failed: {0}",
    "ssh_check_timed_out": "SSH check timed out: {0}",
    "booked_hosts_lookup_failed": "Could not retrieve booked hosts for {0}",
    "invalid_inventory": "Invalid inventory: {0}",
    "missing_prerequisite": "Missing prerequisite: {0}",
    "invalid_numa": "Invalid NUMA: {0}",
    "invalid_device": "Invalid device: {0}",
    "invalid_port": "Invalid port: {0}",
    "invalid_interface": "Invalid interface: {0}",
    "unknown_option": "Unknown option: {0}",
    "invalid_git_repository": "Invalid Git repository: {0}",
    "file_not_found": "File not found: {0}",
    "permission_denied": "Permission denied: {0}",
    "missing_tool": "Missing tool: {0}",
    "login_failed": "Login failed: {0}",
    "workflow_already_exists": "Workflow already exists: {0}",
    "repository_already_exists": "Repository already exists: {0}",
    "template_not_found": "Template not found: {0}",
    "project_not_found": "Project not found: {0}",
    "invalid_workflow_name": "Invalid workflow name: {0}",
    "link_creation_failed": "Link creation failed: {0}",
    "created_workflow": "Workflow created: {0}",
    "playbook_not_found": "Playbook not found: {0}",
    "playbook_already_exists": "Playbook already exists: {0}",
    "invalid_playbook_name": "Invalid playbook name: {0}",
    "playbook_branch_required": "Switch to the playbook branch before creating: {0}",
    "created_playbook": "Playbook created: {0}",
    "workflow_not_found": "Workflow not found: {0}",
    "playbook_cannot_be_deleted": "Playbook cannot be deleted: {0}",
    "workflow_cannot_be_deleted": "Workflow cannot be deleted: {0}",
    "playbook_delete_branch_required": "Switch to the playbook branch before deleting: {0}",
    "workflow_delete_branch_required": "Switch to the workflow branch before deleting: {0}",
    "deleted_playbook": "Playbook deleted: {0}",
    "deleted_workflow": "Workflow deleted: {0}",
    # Booking command validation and results.
    "invalid_duration": "Invalid duration: {0}",
    "invalid_booking_date": "Invalid booking date: {0}",
    "invalid_start_time": "Invalid start time: {0} {1}",
    "invalid_start_value": "Invalid value for --start: '{0}' (expected HH:MM from 00:00 to 23:59)",
    "invalid_user": "Invalid user: {0}",
    "invalid_server": "Invalid server: {0}",
    "invalid_booking": "Invalid booking: {0}",
    "invalid_collaborator": "Invalid collaborator: {0}",
    "conflicting_flags": "Conflicting flags: {0} and {1}",
    "command_not_available": "Command not available: {0}",
    "booking_request_failed": "Booking request failed",
    "invalid_shared_users": "Invalid shared users",
    "booking_service_unavailable": "Booking service unavailable",
    "booking_already_cancelled": "Booking already cancelled: {0}",
    "booking_cancelled": "Booking cancelled: {0}",
    "booking_expired": "Booking expired: {0}",
    "created_booking": "Booking created: {0}",
    "booking_share_updated": "Share {0}: {1} ({2})",
    "server_already_booked": "Server already booked: {0} ({1})",
    "booking_start_required": "Booking date and start time are required",
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
