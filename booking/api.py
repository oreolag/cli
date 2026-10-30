"""Local HTTP API. Unix peer credentials authenticate the caller on Linux."""
import grp
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

from runtime import configuration
from storage import BookingConflict, create_booking

SOCKET_PATH = "/run/odev-booking/api.sock"


def require_user(username):
    try:
        user = pwd.getpwnam(username)
        group = grp.getgrnam("odev-users")
        if group.gr_gid not in os.getgrouplist(username, user.pw_gid):
            raise KeyError(username)
    except (KeyError, TypeError):
        raise ValueError(f"Invalid user: {username}") from None


def peer_user(connection):
    credentials = connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
    _, uid, _ = struct.unpack("3i", credentials)
    try:
        username = pwd.getpwuid(uid).pw_name
        require_user(username)
        return username
    except (KeyError, ValueError):
        raise PermissionError("Permission denied: booking access") from None


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        try:
            self.connection.settimeout(10)
            owner = peer_user(self.connection)
            if self.path != "/bookings":
                self.reply(404, {"error": "Command not found: booking API"})
                return
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 16384:
                raise ValueError("Invalid booking request")
            request = json.loads(self.rfile.read(size))
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
