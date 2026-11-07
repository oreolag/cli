# Booking

Booking reserves a server for an owner and optional collaborators.

**Tailscale is required for remote booking commands.** Connect the machine to
the tailnet before using booking commands that contact another service.

## Version 1 notes

Booking creation, sharing, cancellation, cross-service listing and commands,
generated Ansible inventories and remote playbook execution are implemented.
OpenSSH admission has been validated for owners, collaborators, unbooked users,
administrators, booking-service failure and removal of a managed-server assignment.

Managed machines check session authorization every 30 seconds. Users without an
active owned or shared booking are disconnected after expiry, cancellation or
removal from sharing. Root and `odev-admins` are exempt. The `terminate_jobs`
setting controls cleanup of remaining user jobs.

Each service stores reservations in its own SQLite database. Back up that
database for recovery. Reassigning a managed server in `booking.yml` does not
transfer its existing reservations to the new service.

Remote booking commands require Tailscale and working user SSH access.
Tailscale SSH can request browser approval even when the node is connected.
The OpenSSH admission lookup uses a separate machine credential and can work
without Tailscale when its configured endpoint is reachable through another network.

## Configuration

Management copies `cmdb/booking.yml` to `/opt/booking.yml` on every server:

```yaml
servers:
  - name: odev-booking-01
    id: "01"
    timezone: Europe/Madrid
    managed_servers:
      - incus-01
      - incus-02
    maximum_duration_hours: 5
    terminate_jobs: true
```

Each booking service manages its own reservations. Assign each managed server to
only one service. Booking servers require normal authentication but no reservation.
Set `timezone` inside each booking server entry, for example `Europe/Madrid` or
`Europe/Oslo`. Prompts, validation and tables use that service's timezone;
database timestamps always remain UTC.
Booking servers support all booking commands. Managed machines can also run
all four booking subcommands using their assigned service over SSH.
On a managed machine, the add prompt defaults to that machine and uses the
assigned service's timezone. Machines listed
nowhere return `Command not available: odev booking`.

Service IDs are quoted positive numbers, unique across the inventory. Keep them
unchanged when reordering entries or renaming hosts; never reuse an ID for another
booking database. Booking IDs combine this prefix with an expanding local sequence,
for example `01-0001`, then `01-10000` after `01-9999`.

## Service

Installation prepares the same account, code, database directory and systemd
service on every server. The daemon starts at boot and checks the inventory every
30 seconds. It activates booking storage when listed as a booking server and
otherwise stays idle. No timer or separate configuration service is needed.

```bash
systemctl status odev-booking.service
sudo journalctl -u odev-booking.service -n 30 --no-pager
```

The daemon creates the database at `paths.booking_db` (by default
`/var/lib/odev-booking/booking.db`) and records the permanent service ID. Later
starts verify the schema and ID without resetting reservations or the sequence.
Removing the booking role returns the daemon to idle and preserves the database.
Invalid configuration or a mismatched database ID is logged; the daemon stays
inactive and retries after configuration is corrected.

On a booking server, the daemon serves a local HTTP API at
`/run/odev-booking/api.sock`. The socket is accessible to `odev-users`; Linux peer
credentials identify the caller. Remote booking commands reach the service
over SSH and use the same local API there. Log into the booking server using
your normal credentials and an account in `odev-users`:

```bash
ssh odev-booking-01
```

The API derives ownership from the local connection rather than accepting a
username supplied in the request. Managed machines still run an idle daemon.

Remote booking commands require Ansible, working SSH access and a connected
Tailscale node. A disconnected node returns `Login failed: tailscale`.
For example, on `incus-01`, this creates a booking through its remote service:

```bash
odev booking add --server incus-01 --duration 5m
```

The same command on `odev-booking-01`, when it manages `incus-01`, uses its
local API and works without Tailscale. Local sharing and cancellation work the
same way for reservations stored on that service.

Listing contacts all configured services, so even a booking server needs
Tailscale when the list includes remote services. With only one configured
service, listing on that service uses only its local API.

Tailscale connectivity and Tailscale SSH approval are separate checks. A
connected node may still receive a browser approval request when opening SSH.
The OpenSSH booking admission lookup uses the dedicated machine credential
and configured `access.host` and `access.port`. It works without Tailscale
when that endpoint is reachable through another network.

## Database

`booking/schema.sql` defines the SQLite database. Each booking service owns its
local database. Booking commands access it through that server's local API.

### Bookings

Each reservation is one row in `bookings`:

| Column | Meaning |
|---|---|
| `booking_id` | Unique ID, for example `01-0001` |
| `server` | Reserved server inventory name |
| `owner` | Owner's username |
| `start_time`, `end_time` | Reservation boundaries |
| `created_at` | Creation time |
| `cancelled_at`, `cancelled_by` | Cancellation time and user; both null until cancelled |

All timestamps are UTC Unix seconds. Active, future and expired states are derived
from the timestamps. The end is exclusive: a booking ending at 16:00 does not
conflict with one starting at 16:00. Cancelled rows remain as history.

### Collaborators

`booking_shares` contains one row per collaborator:

| Column | Meaning |
|---|---|
| `booking_id` | References the same ID in `bookings` |
| `username` | Collaborator's username |
| `added_at` | Time added, in UTC Unix seconds |

The pair `(booking_id, username)` is unique. Removing a collaborator deletes that
row. Cancelling a reservation preserves its collaborator rows.

### Service and sequence

`booking_metadata` contains one row: `singleton = 1`, the permanent `service_id`
from the inventory, and `last_sequence`, initially zero. Schema version 1 is stored
in SQLite's `user_version`.

Storage checks conflicts, increments the sequence and inserts the reservation
and collaborators in one write transaction. Service `01` produces `01-0001`, then
`01-0002`, and eventually `01-10000`. Cancellation never resets the sequence.
Indexes support lookups by server, owner and collaborator.

To inspect the actual tables on a booking server without modifying the database:

```bash
sudo -u odev-booking sqlite3 -readonly /var/lib/odev-booking/booking.db '.schema'
```

Use the configured `paths.booking_db` if the default path was changed.

## List

```bash
odev booking list
odev booking list --history 2026-11-01
odev booking list --active
```

The default view shows availability and active or upcoming reservations for
today across all services. `--history` shows every reservation across all
services overlapping the selected day, including expired and cancelled bookings.
Use `YYYY-MM-DD`, `today`, `yesterday` or `tomorrow`. Relative dates use the
timezone of each service.

Both views print the local or assigned service's table first, then show tables
from the other services. Each service uses its own local date. Remote listing
uses the caller's existing SSH access and requires Ansible on the machine
running the command. Failed peers are reported by name.

`--active` shows the bookings you own and that are active now across all
services. The table uses the local or assigned service's timezone.
Use it on its own.

## Add

```bash
odev booking add --server incus-01
odev booking add --server incus-01 --date 2026-11-01 --start 14:15 --duration 2h
odev booking add --server incus-01 --shared javier,quico
```

The authenticated user owns the reservation. Missing required values open the
dialog. Dates use `YYYY-MM-DD`; times require `HH:MM`, including leading zeros.
Input and display use the configured timezone; database timestamps use UTC.

Duration accepts a positive whole number followed by `m` or `h`, for example
`5m`, `60m`, `1h` or `2h`. Plain numbers and decimal values are not accepted.
The date defaults to today, duration to `1h`, and start to the next five-minute
boundary. Availability-based suggestions will follow once storage is implemented.
Supplied start values are validated before prompting, then checked again afterward.

`add.sh` routes the request to the service that manages the target server.
Date and time inputs use that service's timezone. `booking/api.py` authenticates the caller and validates shared
users against `odev-users`. `booking/storage.py` performs the SQLite transaction.
The API repeats validation, including policy and conflict checks.

For example, after deploying `booking=true` on all machines, run this on the
booking server to create a reservation with a future start time:

```bash
odev booking add --server incus-01 --date 2026-11-01 --start 14:15 --duration 1h
# Booking created: 01-0001
```

On the booking server, inspect the saved row:

```bash
sudo -u odev-booking sqlite3 -readonly -header -column /var/lib/odev-booking/booking.db \
  'SELECT booking_id, server, owner, start_time, end_time FROM bookings;'
```

Reservations can start in the current minute or later and must have a positive duration within
`maximum_duration_hours`. They cannot overlap on the same server. A booking ending
at 16:00 allows another to start at 16:00.

## Share

```bash
odev booking share --booking 01-0001 --add javier
odev booking share --booking 01-0001 --remove quico
```

Only the owner can change sharing on active or upcoming bookings. Add or remove one user per invocation; the flags
cannot be combined. The user must exist and belong to `odev-users`. Adding an
existing collaborator preserves the list without duplicates. Without either flag,
the dialog asks for a user to add.

Collaborators receive reservation access with their normal account permissions.
They cannot share or cancel the owner's booking.

## Cancel

```bash
odev booking cancel --booking 01-0001
```

Owners and administrators can cancel active or future bookings. Show the server,
date and times before asking for confirmation, with No as the default. Keep
cancelled bookings as history.
Administrators are members of `odev-admins`. Cancellation preserves collaborators
and the booking ID; `odev booking list --history YYYY-MM-DD` includes the cancelled record.
Cancellation releases the reservation immediately. The next session expiry
check disconnects users who have no other active owned or shared booking.

## Access and session expiry

A new SSH session requires an active booking as owner or collaborator.
Expiration, cancellation or removal from sharing immediately revokes new login
access. The root-owned `odev-booking-expiry.timer` checks existing sessions
every 30 seconds, allowing a short lookup delay. Cleanup is independent of
whether another user logs in.

With `terminate_jobs: true`, systemd terminates the unauthorized user's sessions
and user-managed jobs. System services outside that user's login resources are
preserved. With `false` (the default), only SSH session leaders are signalled
to disconnect them; remaining jobs follow the system's normal logout policy.
Root, system accounts and `odev-admins` are exempt.

Checks run only where the OpenSSH booking admission hook is installed.
Each check reads the current local `booking.yml`. Removing a machine from
`managed_servers`, or promoting it to a booking service, stops expiry cleanup.

```bash
sudo python3 /opt/odev/booking/expiry.py --dry-run
systemctl status odev-booking-expiry.timer
sudo journalctl -u odev-booking-expiry.service -n 30 --no-pager
```

The dry run reports intended cleanup without disconnecting users.

If the booking service is unavailable, deny new bookings and new access to managed
servers. Existing sessions and jobs are preserved on a failed expiry lookup;
the timer retries. Booking servers remain accessible.
