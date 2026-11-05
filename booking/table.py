"""Print booking tables using examine's borders and colon-separated columns."""
import ast
import curses
from datetime import datetime
from pathlib import Path
import sys
import time
from zoneinfo import ZoneInfo


def print_bookings(result, full_day=False):
    zone = ZoneInfo(result["timezone"])
    now = int(time.time())
    headers = ["Booking ID", "Server", "Owner", "Start", "End", "Shared with", "Status"]
    own_active = "username" in result
    if own_active:
        headers[2] = "Service"
    rows = []
    def display_time(timestamp):
        value = datetime.fromtimestamp(timestamp, zone)
        return value.strftime("%H:%M" if value.date().isoformat() == result["date"] else "%Y-%m-%d %H:%M")
    for server in result["servers"]:
        bookings = [row for row in result["bookings"] if row["server"] == server
                    and (full_day or (row.get("cancelled_at") is None and row["end_time"] > now))]
        active = any(row["start_time"] <= now < row["end_time"] for row in bookings)
        today = datetime.fromtimestamp(now, zone).date().isoformat()
        if not full_day and (not bookings or (result["date"] == today and not active)):
            rows.append(["-", server, "-", "-", "-", "-", "Free"])
        for booking in bookings:
            if own_active and not booking["start_time"] <= now < booking["end_time"]:
                continue
            status = "Cancelled" if booking.get("cancelled_at") is not None else (
                "Active" if booking["start_time"] <= now < booking["end_time"] else (
                    "Upcoming" if now < booking["start_time"] else "Expired"))
            rows.append([booking["booking_id"], server, booking["service" if own_active else "owner"],
                         display_time(booking["start_time"]), display_time(booking["end_time"]),
                         ", ".join(booking["shared"]) or "-", status])
    minimum_widths = [10, 12, 12, 5, 5, 16, 9]
    if own_active:
        headers.pop()
        minimum_widths.pop()
        rows = [row[:-1] for row in rows]
    widths = [max(minimum, len(header), *(len(row[index]) for row in rows))
              for index, (header, minimum) in enumerate(zip(headers, minimum_widths))]
    service = result["username"] if own_active else result["service"]
    title = f"{service} | Date: {result['date']} | Timezone: {result['timezone']}"
    inner = sum(widths) + 3 * (len(headers) - 1) + 2
    widths[-1] += max(0, len(title) + 2 - inner)
    inner = max(inner, len(title) + 2)
    bold = reset = passed = failed = ""
    if sys.stdout.isatty():
        try:
            curses.setupterm()
            bold = (curses.tigetstr("bold") or b"").decode()
            reset = (curses.tigetstr("sgr0") or b"").decode()
            passed = ast.literal_eval((Path(__file__).resolve().parents[1] / "src/COLOR_PASSED").read_text().strip())
            failed = ast.literal_eval((Path(__file__).resolve().parents[1] / "src/COLOR_FAILED").read_text().strip())
        except curses.error:
            pass
    def rule(left="+", right="+"):
        print(left + "-" * inner + right)
    def line(cells, heading=False):
        values = [value.ljust(width) for value, width in zip(cells, widths)]
        if not heading and not own_active and not full_day and cells[-1] == "Free" and passed:
            values[-1] = passed + cells[-1] + reset + " " * (widths[-1] - len(cells[-1]))
        elif not own_active and full_day and cells[-1] == "Cancelled" and failed:
            values[-1] = failed + cells[-1] + reset + " " * (widths[-1] - len(cells[-1]))
        print("| " + " : ".join(values) + " |")
    rule()
    print("| " + bold + service + reset + title[len(service):].ljust(inner - 2 - len(service)) + " |")
    rule()
    line(headers, heading=True)
    rule("|", "|")
    for row in rows:
        line(row)
    rule()
