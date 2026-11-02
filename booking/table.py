"""Print booking tables using examine's borders and colon-separated columns."""
import curses
from datetime import datetime
import sys
import time
from zoneinfo import ZoneInfo


def print_bookings(result):
    zone = ZoneInfo(result["timezone"])
    now = int(time.time())
    headers = ["Booking ID", "Server", "Owner", "Start", "End", "Shared with", "Status"]
    rows = []
    def display_time(timestamp):
        value = datetime.fromtimestamp(timestamp, zone)
        return value.strftime("%H:%M" if value.date().isoformat() == result["date"] else "%Y-%m-%d %H:%M")
    for server in result["servers"]:
        bookings = [row for row in result["bookings"] if row["server"] == server]
        if not bookings:
            rows.append(["-", server, "-", "-", "-", "-", "Free"])
        for booking in bookings:
            status = "Active" if booking["start_time"] <= now < booking["end_time"] else (
                "Upcoming" if now < booking["start_time"] else "Expired")
            rows.append([booking["booking_id"], server, booking["owner"],
                         display_time(booking["start_time"]), display_time(booking["end_time"]),
                         ", ".join(booking["shared"]) or "-", status])
    widths = [max(len(header), *(len(row[index]) for row in rows)) if rows else len(header)
              for index, header in enumerate(headers)]
    title = f"{result['service']} ({result['date']} {result['timezone']})"
    inner = sum(widths) + 3 * (len(headers) - 1) + 2
    bold = reset = ""
    if sys.stdout.isatty():
        try:
            curses.setupterm()
            bold = (curses.tigetstr("bold") or b"").decode()
            reset = (curses.tigetstr("sgr0") or b"").decode()
        except curses.error:
            pass
    def rule(left="+", right="+"):
        print(left + "-" * inner + right)
    def line(cells, heading=False):
        values = [value.ljust(width) for value, width in zip(cells, widths)]
        if heading:
            values[0] = bold + cells[0] + reset + " " * (widths[0] - len(cells[0]))
        print("| " + " : ".join(values) + " |")
    print(title.rjust(inner + 2))
    rule()
    line(headers, heading=True)
    rule("|", "|")
    for row in rows:
        line(row)
    rule()
