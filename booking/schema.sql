-- SQLite database for one booking service.
-- All timestamps are UTC Unix seconds. Times use [start_time, end_time).
-- Enable foreign_keys on every connection, not only during initialization.
PRAGMA foreign_keys = ON;

BEGIN;

-- Initialize service_id from booking.yml once and preserve it with the database.
-- Allocate IDs by incrementing last_sequence and inserting the booking in the
-- same write transaction. Format with at least four digits, e.g. 01-0001.
-- Never decrement the sequence or reuse a retired service_id.
CREATE TABLE booking_metadata (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    service_id TEXT NOT NULL UNIQUE CHECK (
        length(service_id) > 0
        AND service_id NOT GLOB '*[^0-9]*'
        AND CAST(service_id AS INTEGER) > 0
    ),
    last_sequence INTEGER NOT NULL DEFAULT 0 CHECK (last_sequence >= 0)
);

CREATE TABLE bookings (
    booking_id TEXT PRIMARY KEY NOT NULL CHECK (length(booking_id) > 0),
    server TEXT NOT NULL CHECK (length(server) > 0),
    owner TEXT NOT NULL CHECK (length(owner) > 0),
    start_time INTEGER NOT NULL CHECK (start_time >= 0),
    end_time INTEGER NOT NULL CHECK (end_time > start_time),
    created_at INTEGER NOT NULL CHECK (created_at >= 0),
    cancelled_at INTEGER CHECK (cancelled_at >= created_at),
    cancelled_by TEXT,
    CHECK (
        (cancelled_at IS NULL AND cancelled_by IS NULL)
        OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL
            AND length(cancelled_by) > 0)
    )
);

CREATE TABLE booking_shares (
    booking_id TEXT NOT NULL REFERENCES bookings (booking_id) ON DELETE RESTRICT,
    username TEXT NOT NULL CHECK (length(username) > 0),
    added_at INTEGER NOT NULL CHECK (added_at >= 0),
    PRIMARY KEY (booking_id, username)
);

CREATE INDEX bookings_server_time ON bookings (server, start_time, end_time)
    WHERE cancelled_at IS NULL;
CREATE INDEX bookings_owner_time ON bookings (owner, start_time)
    WHERE cancelled_at IS NULL;
CREATE INDEX booking_shares_user ON booking_shares (username, booking_id);

-- Active, upcoming and expired states are derived from timestamps.
-- Overlap checks and policy validation belong to the storage/service layer;
-- checking availability and inserting a reservation must be one write transaction.
PRAGMA user_version = 1;

COMMIT;
