# Booking

Booking reserves a server for an owner and optional collaborators.

The command interface, prompts and start-time validation are implemented. Actions
currently print parameter values. Database operations, availability tables,
confirmation and login enforcement are planned. The examples below describe the
agreed workflow.

## Configuration

Management copies `cmdb/booking.yml` to `/opt/booking.yml` on every server:

```yaml
timezone: Europe/Madrid
servers:
  - name: odev-booking-01
    id: "01"
    managed_servers:
      - incus-01
      - incus-02
    maximum_duration_hours: 5
    terminate_jobs: true
```

Each booking service manages its own reservations. Assign each managed server to
only one service. Booking servers require normal authentication but no reservation.
Machines listed nowhere return `Command not available: odev booking`.

Service IDs are quoted positive numbers, unique across the inventory. Keep them
unchanged when reordering entries or renaming hosts; never reuse an ID for another
booking database. Booking IDs combine this prefix with an expanding local sequence,
for example `01-0001`, then `01-10000` after `01-9999`.

## List

```bash
odev booking list
odev booking list --date 2026-11-01
odev booking list --all
odev booking list --all --date 2026-11-01
```

The default is today and the local or assigned booking service. `--all` includes
every booking service in the inventory. Tables follow `odev examine` styling and
show reservations and availability. An unreachable service has unknown availability.

## Add

```bash
odev booking add --server incus-01
odev booking add --server incus-01 --date 2026-11-01 --start 14:15 --duration 2
odev booking add --server incus-01 --shared javier,quico
```

The authenticated user owns the reservation. Missing required values open the
dialog. Dates use `YYYY-MM-DD`; times require `HH:MM`, including leading zeros.
Input and display use the configured timezone; database timestamps will use UTC.

The date defaults to today, duration to one hour, and start to the next five-minute
boundary. Availability-based suggestions will follow once storage is implemented.
Supplied start values are validated before prompting, then checked again afterward.

Reservations must start in the future and have a positive duration within
`maximum_duration_hours`. They cannot overlap on the same server. A booking ending
at 16:00 allows another to start at 16:00.

## Share

```bash
odev booking share --booking 303 --add javier
odev booking share --booking 303 --remove quico
```

Only the owner can change sharing. Add or remove one user per invocation; the flags
cannot be combined. The user must exist and belong to `odev-users`. Adding an
existing collaborator preserves the list without duplicates. Without either flag,
the dialog asks for a user to add.

Collaborators receive reservation access with their normal account permissions.
They cannot share or cancel the owner's booking.

## Cancel

```bash
odev booking cancel --booking 303
```

Owners and administrators can cancel active or future bookings. Show the server,
date and times before asking for confirmation, with No as the default. Keep
cancelled bookings as history.

## Access and handover

A new session requires an active booking as owner or collaborator. Expiration,
cancellation or removal from sharing revokes that access immediately but leaves
existing sessions running.

At the next authorized login, disconnect users without current reservation access.
With `terminate_jobs: true`, also terminate their remaining jobs. With `false`
(the default when omitted), preserve detached/background jobs. Preserve system
services and users authorized by the current reservation.

If the booking service is unavailable, deny new bookings and new access to managed
servers. Existing sessions continue, and booking servers remain accessible.
