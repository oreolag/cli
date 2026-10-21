"""Shared configuration and database initialization for the booking service."""
import fcntl
import json
import os
from pathlib import Path
import sqlite3
import sys
import tempfile

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from booking_is_server import booking_timezone, load_inventory


def configuration(odev_path, hostname):
    root = Path(odev_path)
    with (root / "vars.yml").open(encoding="utf-8") as stream:
        settings = yaml.safe_load(stream)
    paths = settings["paths"]
    inventory_path = Path(paths.get("booking", "/opt/booking.yml"))
    database_path = Path(paths.get("booking_db", "/var/lib/odev-booking/booking.db"))
    if not inventory_path.is_absolute() or not database_path.is_absolute():
        raise ValueError("booking paths must be absolute")
    inventory = load_inventory(inventory_path)
    timezone = booking_timezone(inventory_path)
    entry = next((item for item in inventory["servers"]
                  if item["name"] == hostname.split(".")[0]), None)
    return {"database": str(database_path), "timezone": timezone, "server": entry}


def signature(config):
    return json.dumps(config, sort_keys=True)


def validate_database(connection, service_id):
    if connection.execute("PRAGMA user_version").fetchone()[0] != 1:
        raise ValueError("unsupported booking database schema version")
    columns = {
        "booking_metadata": {"singleton", "service_id", "last_sequence"},
        "bookings": {"booking_id", "server", "owner", "start_time", "end_time", "created_at",
                     "cancelled_at", "cancelled_by"},
        "booking_shares": {"booking_id", "username", "added_at"},
    }
    for table, expected in columns.items():
        actual = {row[1] for row in connection.execute(f"PRAGMA table_info({table})")}
        if actual != expected:
            raise ValueError(f"invalid booking database table: {table}")
    metadata = connection.execute("SELECT singleton, service_id, last_sequence FROM booking_metadata").fetchall()
    if len(metadata) != 1 or metadata[0][0] != 1 or metadata[0][1] != service_id:
        raise ValueError("booking database service ID does not match booking.yml")
    if not isinstance(metadata[0][2], int) or metadata[0][2] < 0:
        raise ValueError("invalid booking sequence")
    if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
        raise ValueError("booking database integrity check failed")
    if connection.execute("PRAGMA foreign_key_check").fetchall():
        raise ValueError("booking database foreign key check failed")


def initialize_database(database_path, service_id, schema_path):
    path = Path(database_path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Serialize initializers; publish a complete database atomically.
    with (path.parent / (path.name + ".init.lock")).open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if path.is_symlink():
            raise ValueError("booking database must not be a symlink")
        if path.exists():
            connection = sqlite3.connect(path.as_uri() + "?mode=rw", uri=True)
            try:
                connection.execute("PRAGMA foreign_keys = ON")
                validate_database(connection, service_id)
            finally:
                connection.close()
            return False
        descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
        os.close(descriptor)
        try:
            connection = sqlite3.connect(temporary)
            try:
                connection.executescript(Path(schema_path).read_text())
                connection.execute(
                    "INSERT INTO booking_metadata (singleton, service_id) VALUES (1, ?)", (service_id,))
                connection.commit()
                validate_database(connection, service_id)
            finally:
                connection.close()
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return True
