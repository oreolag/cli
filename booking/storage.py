"""SQLite booking storage; called by the authenticated booking API."""
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
import sqlite3
import time
from zoneinfo import ZoneInfo

from booking_is_server import duration_seconds


class BookingConflict(ValueError):
    pass


def list_bookings(config, day, history=False):
    zone = ZoneInfo(config["timezone"])
    if not isinstance(day, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", day):
        raise ValueError(f"Invalid booking date: {day}")
    try:
        beginning = datetime.strptime(day, "%Y-%m-%d").replace(tzinfo=zone)
        ending = beginning + timedelta(days=1)
    except (ValueError, OverflowError):
        raise ValueError(f"Invalid booking date: {day}") from None
    entry = config["server"]
    if entry is None:
        raise ValueError("Booking service unavailable")
    connection = sqlite3.connect(Path(config["database"]).as_uri() + "?mode=ro", uri=True, timeout=10)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("BEGIN")
        if connection.execute("PRAGMA user_version").fetchone()[0] != 1:
            raise ValueError("Unsupported booking database schema version")
        metadata = connection.execute("SELECT service_id FROM booking_metadata WHERE singleton = 1").fetchone()
        if metadata is None or metadata[0] != entry["id"]:
            raise ValueError("Booking database service ID does not match booking.yml")
        rows = connection.execute(
            "SELECT booking_id, server, owner, start_time, end_time, cancelled_at FROM bookings "
            "WHERE (? OR cancelled_at IS NULL) AND start_time < ? AND end_time > ? ORDER BY server, start_time, booking_id",
            (history, int(ending.timestamp()), int(beginning.timestamp()))).fetchall()
        bookings = []
        for row in rows:
            if row["server"] not in entry["managed_servers"]:
                continue
            booking = dict(row)
            booking["shared"] = [share[0] for share in connection.execute(
                "SELECT username FROM booking_shares WHERE booking_id = ? ORDER BY username", (row["booking_id"],))]
            bookings.append(booking)
        return {"service": entry["name"], "timezone": config["timezone"], "date": day,
                "servers": entry["managed_servers"], "bookings": bookings}
    finally:
        connection.close()


def cancel_booking(config, username, booking_id, administrator=False, confirm=False):
    entry = config["server"]
    if entry is None:
        raise ValueError("Booking service unavailable")
    connection = sqlite3.connect(Path(config["database"]).as_uri() + "?mode=rw", uri=True, timeout=10)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("BEGIN IMMEDIATE" if confirm else "BEGIN")
        metadata = connection.execute("SELECT service_id FROM booking_metadata WHERE singleton = 1").fetchone()
        if metadata is None or metadata[0] != entry["id"]:
            raise ValueError("Booking database service ID does not match booking.yml")
        row = connection.execute("SELECT * FROM bookings WHERE booking_id = ?", (booking_id,)).fetchone()
        if row is None:
            raise ValueError(f"Invalid booking: {booking_id}")
        if row["owner"] != username and not administrator:
            raise PermissionError(f"Permission denied: {booking_id}")
        if row["cancelled_at"] is not None:
            raise ValueError(f"Booking already cancelled: {booking_id}")
        now = int(time.time())
        if row["end_time"] <= now:
            raise ValueError(f"Booking expired: {booking_id}")
        if confirm:
            connection.execute("UPDATE bookings SET cancelled_at = ?, cancelled_by = ? WHERE booking_id = ?",
                               (now, username, booking_id))
            connection.commit()
        return {"booking_id": booking_id, "server": row["server"], "owner": row["owner"],
                "start_time": row["start_time"], "end_time": row["end_time"], "timezone": config["timezone"]}
    finally:
        connection.close()


def share_booking(config, owner, booking_id, action, username):
    entry = config["server"]
    if entry is None:
        raise ValueError("Booking service unavailable")
    connection = sqlite3.connect(Path(config["database"]).as_uri() + "?mode=rw", uri=True, timeout=10)
    try:
        connection.execute("BEGIN IMMEDIATE")
        metadata = connection.execute("SELECT service_id FROM booking_metadata WHERE singleton = 1").fetchone()
        if metadata is None or metadata[0] != entry["id"]:
            raise ValueError("Booking database service ID does not match booking.yml")
        row = connection.execute("SELECT owner, end_time, cancelled_at FROM bookings WHERE booking_id = ?",
                                 (booking_id,)).fetchone()
        if row is None:
            raise ValueError(f"Invalid booking: {booking_id}")
        booking_owner, end_time, cancelled_at = row
        if booking_owner != owner:
            raise PermissionError(f"Permission denied: {booking_id}")
        now = int(time.time())
        if cancelled_at is not None:
            raise ValueError(f"Booking cancelled: {booking_id}")
        if end_time <= now:
            raise ValueError(f"Booking expired: {booking_id}")
        if username == owner:
            raise ValueError(f"Invalid collaborator: {username}")
        if action == "add":
            connection.execute("INSERT INTO booking_shares (booking_id, username, added_at) VALUES (?, ?, ?) "
                               "ON CONFLICT (booking_id, username) DO NOTHING", (booking_id, username, now))
        elif action == "remove":
            connection.execute("DELETE FROM booking_shares WHERE booking_id = ? AND username = ?",
                               (booking_id, username))
        else:
            raise ValueError("Invalid booking request")
        connection.commit()
    finally:
        connection.close()


def create_booking(config, owner, request):
    entry = config["server"]
    server = request.get("server")
    if entry is None or server not in entry["managed_servers"]:
        raise ValueError(f"Invalid server: {server}")
    day, start = request.get("date", ""), request.get("start", "")
    if not isinstance(day, str) or not isinstance(start, str) or not re.fullmatch(
            r"[0-9]{4}-[0-9]{2}-[0-9]{2} ([01][0-9]|2[0-3]):[0-5][0-9]", f"{day} {start}"):
        raise ValueError(f"Invalid start time: {day} {start}")
    zone = ZoneInfo(config["timezone"])
    try:
        local = datetime.strptime(f"{day} {start}", "%Y-%m-%d %H:%M").replace(tzinfo=zone)
        # Reject nonexistent or ambiguous local times at daylight-saving changes.
        if (local.astimezone(timezone.utc).astimezone(zone).replace(tzinfo=None) != local.replace(tzinfo=None)
                or local.utcoffset() != local.replace(fold=1).utcoffset()):
            raise ValueError()
        start_time = int(local.timestamp())
    except (ValueError, OverflowError):
        raise ValueError(f"Invalid start time: {day} {start}") from None
    end_time = start_time + duration_seconds(request.get("duration"), entry["maximum_duration_hours"])
    shared = request.get("shared", [])
    if not isinstance(shared, list) or any(not isinstance(user, str) or not user for user in shared):
        raise ValueError("Invalid shared users")
    shared = sorted(set(shared) - {owner})
    path = Path(config["database"])
    connection = sqlite3.connect(path.as_uri() + "?mode=rw", uri=True, timeout=10)
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("BEGIN IMMEDIATE")
        if connection.execute("PRAGMA user_version").fetchone()[0] != 1:
            raise ValueError("Unsupported booking database schema version")
        now = int(time.time())
        if start_time < now - now % 60:
            raise ValueError(f"Invalid start time: {day} {start}")
        metadata = connection.execute(
            "SELECT service_id, last_sequence FROM booking_metadata WHERE singleton = 1").fetchone()
        if metadata is None or metadata[0] != entry["id"]:
            raise ValueError("Booking database service ID does not match booking.yml")
        conflict = connection.execute(
            "SELECT booking_id FROM bookings WHERE server = ? AND cancelled_at IS NULL "
            "AND start_time < ? AND end_time > ? LIMIT 1", (server, end_time, start_time)).fetchone()
        if conflict:
            raise BookingConflict(f"Server already booked: {server} ({conflict[0]})")
        sequence = metadata[1] + 1
        booking_id = f"{entry['id']}-{sequence:04d}"
        connection.execute("UPDATE booking_metadata SET last_sequence = ? WHERE singleton = 1", (sequence,))
        connection.execute(
            "INSERT INTO bookings (booking_id, server, owner, start_time, end_time, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?)", (booking_id, server, owner, start_time, end_time, now))
        connection.executemany("INSERT INTO booking_shares (booking_id, username, added_at) VALUES (?, ?, ?)",
                               [(booking_id, user, now) for user in shared])
        connection.commit()
        return booking_id
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()
