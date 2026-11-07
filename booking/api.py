"""Local HTTP API. Unix peer credentials authenticate the caller on Linux."""
import grp
from datetime import datetime
from http.server import BaseHTTPRequestHandler
import json
import os
from pathlib import Path
import pwd
import socket
from socketserver import ThreadingMixIn, UnixStreamServer
import struct
import sys
import threading
import time
from zoneinfo import ZoneInfo
from urllib.parse import parse_qs, urlsplit

from runtime import configuration
from storage import BookingConflict, booking_access_allowed, booking_access_users, booking_availability, cancel_booking, create_booking, list_bookings, share_booking

SOCKET_PATH = "/run/odev-booking/api.sock"
ACCESS_ACCOUNT = "odev-booking-check"


def require_user(username):
    try:
        user = pwd.getpwnam(username)
        group = grp.getgrnam("odev-users")
        if group.gr_gid not in os.getgrouplist(username, user.pw_gid):
            raise KeyError(username)
    except (KeyError, TypeError):
        raise ValueError(f"Invalid user: {username}") from None


def peer_identity(connection):
    credentials = connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
    _, uid, _ = struct.unpack("3i", credentials)
    return pwd.getpwuid(uid).pw_name


def peer_user(connection):
    try:
        username = peer_identity(connection)
        if username == ACCESS_ACCOUNT:
            raise PermissionError("Permission denied: booking access")
        require_user(username)
        return username
    except (KeyError, ValueError):
        raise PermissionError("Permission denied: booking access") from None


def is_administrator(username):
    user = pwd.getpwnam(username)
    try:
        group = grp.getgrnam("odev-admins")
    except KeyError:
        return False
    return group.gr_gid in os.getgrouplist(username, user.pw_gid)


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        try:
            url = urlsplit(self.path)
            query = parse_qs(url.query, keep_blank_values=True)
            if url.path == "/access":
                if peer_identity(self.connection) != ACCESS_ACCOUNT:
                    raise PermissionError("Permission denied: booking access")
                if set(query) not in [{"server"}, {"server", "user"}] or any(len(values) != 1 or not values[0] for values in query.values()):
                    raise ValueError("Invalid booking access request")
                config = configuration(self.server.odev_path, socket.gethostname())
                if "user" not in query:
                    self.reply(200, {"users": booking_access_users(config, query["server"][0])})
                    return
                allowed = booking_access_allowed(config, query["server"][0], query["user"][0])
                self.reply(200, {"allowed": allowed})
                return
            username = peer_user(self.connection)
            if url.path != "/bookings":
                self.reply(404, {"error": "Command not found: booking API"})
                return
            if query == {"availability": ["1"]}:
                config = configuration(self.server.odev_path, socket.gethostname())
                self.reply(200, booking_availability(config))
                return
            if query == {"active": ["1"]}:
                config = configuration(self.server.odev_path, socket.gethostname())
                if config["server"] is None:
                    self.reply(503, {"error": "Booking service unavailable"})
                    return
                now = int(time.time())
                day = datetime.fromtimestamp(now, ZoneInfo(config["timezone"])).date().isoformat()
                result = list_bookings(config, day)
                active = [row for row in result["bookings"] if row["start_time"] <= now < row["end_time"]]
                hosts = {row["server"] for row in active
                         if row["owner"] == username or username in row["shared"]}
                owned = [dict(row, service=result["service"]) for row in active if row["owner"] == username]
                self.reply(200, {"servers": sorted(hosts), "bookings": owned})
                return
            if set(query) == {"booking"} and len(query["booking"]) == 1:
                config = configuration(self.server.odev_path, socket.gethostname())
                self.reply(200, cancel_booking(config, username, query["booking"][0],
                                               administrator=is_administrator(username)))
                return
            if ("date" not in query or set(query) - {"date", "history"}
                    or any(len(values) != 1 for values in query.values())
                    or query.get("history", ["0"])[0] not in ["0", "1"]):
                raise ValueError("Invalid booking request")
            config = configuration(self.server.odev_path, socket.gethostname())
            if config["server"] is None:
                self.reply(503, {"error": "Booking service unavailable"})
                return
            self.reply(200, list_bookings(config, query["date"][0], history=query.get("history", ["0"])[0] == "1"))
        except PermissionError as error:
            self.reply(403, {"error": str(error)})
        except ValueError as error:
            self.reply(400, {"error": str(error)})
        except Exception as error:
            print(f"ERROR: {error}", file=sys.stderr, flush=True)
            self.reply(503, {"error": "Booking service unavailable"})

    def do_POST(self):
        try:
            self.connection.settimeout(10)
            owner = peer_user(self.connection)
            if self.path not in ["/bookings", "/bookings/cancel", "/bookings/share"]:
                self.reply(404, {"error": "Command not found: booking API"})
                return
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 16384:
                raise ValueError("Invalid booking request")
            request = json.loads(self.rfile.read(size))
            if self.path == "/bookings/share":
                if (not isinstance(request, dict) or set(request) != {"booking", "action", "user"}
                        or not all(isinstance(value, str) and value for value in request.values())
                        or request["action"] not in ["add", "remove"]):
                    raise ValueError("Invalid booking request")
                require_user(request["user"])
                config = configuration(self.server.odev_path, socket.gethostname())
                share_booking(config, owner, request["booking"], request["action"], request["user"])
                self.reply(200, {"booking_id": request["booking"]})
                return
            if self.path == "/bookings/cancel":
                if not isinstance(request, dict) or set(request) != {"booking"} or not isinstance(request["booking"], str):
                    raise ValueError("Invalid booking request")
                config = configuration(self.server.odev_path, socket.gethostname())
                result = cancel_booking(config, owner, request["booking"],
                                        administrator=is_administrator(owner), confirm=True)
                self.reply(200, result)
                return
            if not isinstance(request, dict) or set(request) - {"server", "date", "start", "duration", "shared"}:
                raise ValueError("Invalid booking request")
            shared = request.get("shared", [])
            if not isinstance(shared, list):
                raise ValueError("Invalid shared users")
            for user in shared:
                require_user(user)
            # Re-read configuration for every request, including role changes.
            config = configuration(self.server.odev_path, socket.gethostname())
            if config["server"] is None:
                self.reply(503, {"error": "Booking service unavailable"})
                return
            booking_id = create_booking(config, owner, request)
            self.reply(201, {"booking_id": booking_id})
        except PermissionError as error:
            self.reply(403, {"error": str(error)})
        except BookingConflict as error:
            self.reply(409, {"error": str(error)})
        except (ValueError, TypeError) as error:
            self.reply(400, {"error": str(error)})
        except Exception as error:
            print(f"ERROR: {error}", file=sys.stderr, flush=True)
            self.reply(503, {"error": "Booking service unavailable"})

    def log_message(self, *_):
        pass


class Server(ThreadingMixIn, UnixStreamServer):
    daemon_threads = True

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(10)
        return connection, address


def start_api(odev_path, path=SOCKET_PATH, group="odev-users"):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() or path.is_symlink():
        if not path.is_socket() or path.is_symlink():
            raise ValueError(f"Invalid booking socket: {path}")
        probe = socket.socket(socket.AF_UNIX)
        try:
            probe.connect(str(path))
        except ConnectionRefusedError:
            path.unlink()
        else:
            raise ValueError(f"Booking API already running: {path}")
        finally:
            probe.close()
    server = Server(str(path), Handler)
    try:
        server.odev_path = str(odev_path)
        if group is not None:
            os.chown(path, -1, grp.getgrnam(group).gr_gid)
        os.chmod(path, 0o660)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        return server
    except Exception:
        server.server_close()
        path.unlink(missing_ok=True)
        raise


def stop_api(server):
    if server is not None:
        server.shutdown()
        server.server_close()
        Path(server.server_address).unlink(missing_ok=True)
