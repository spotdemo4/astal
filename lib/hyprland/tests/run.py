import json
import os
import pathlib
import socket
import subprocess
import sys
import tempfile


def client(address, grouped, visible):
    return {
        "address": f"0x{address}",
        "mapped": True,
        "hidden": False,
        "visible": visible,
        "at": [10, 20],
        "size": [800, 600],
        "workspace": {"id": 1, "name": "1"},
        "floating": False,
        "monitor": 1,
        "class": "fixture",
        "title": address,
        "initialClass": "fixture",
        "initialTitle": address,
        "pid": 100,
        "xwayland": False,
        "pinned": False,
        "fullscreen": 0,
        "fullscreenClient": 0,
        "grouped": [f"0x{member}" for member in grouped],
        "swallowing": "0x0",
        "focusHistoryID": 0,
    }


MONITORS = [
    {
        "id": 1,
        "name": "HEADLESS-1",
        "description": "fixture",
        "make": "fixture",
        "model": "fixture",
        "serial": "fixture",
        "width": 1920,
        "height": 1080,
        "refreshRate": 60.0,
        "x": 0,
        "y": 0,
        "activeWorkspace": {"id": 1, "name": "1"},
        "specialWorkspace": {"id": 0, "name": ""},
        "reserved": [0, 0, 0, 0],
        "scale": 1.0,
        "transform": 0,
        "focused": True,
        "dpmsStatus": True,
        "vrr": False,
        "activelyTearing": False,
        "disabled": False,
        "currentFormat": "XRGB8888",
        "availableModes": ["1920x1080@60.00Hz"],
    }
]
WORKSPACES = [
    {
        "id": 1,
        "name": "1",
        "monitor": "HEADLESS-1",
        "monitorID": 1,
        "windows": 2,
        "hasfullscreen": False,
        "lastwindow": "0xaaa",
        "lastwindowtitle": "aaa",
    }
]


def response(request, provider, state):
    if request == "j/monitors":
        return json.dumps(MONITORS)
    if request == "j/workspaces":
        return json.dumps(WORKSPACES)
    if request == "j/clients":
        if state == "initial":
            clients = [
                client("aaa", ["aaa", "bbb"], True),
                client("bbb", ["aaa", "bbb"], False),
            ]
        elif state == "opened":
            clients = [
                client("aaa", [], True),
                client("bbb", ["bbb", "ccc"], False),
                client("ccc", ["bbb", "ccc"], True),
            ]
        else:
            clients = [client("aaa", [], True), client("bbb", ["bbb"], False)]
        return json.dumps(clients)
    if request == "j/activeworkspace":
        return json.dumps({"id": 1, "name": "1"})
    if request == "j/activewindow":
        return json.dumps({"address": "0xaaa"})
    if request == "j/status":
        return (
            json.dumps({"configProvider": "lua", "backend": "headless"})
            if provider == "lua"
            else "unknown request"
        )
    return "ok"


def expected_dispatches(provider):
    if provider == "lua":
        return {
            'dispatch hl.dsp.window.close({ window = "address:0xaaa" })',
            'dispatch hl.dsp.focus({ window = "address:0xaaa" })',
            'dispatch hl.dsp.window.move({ window = "address:0xaaa", workspace = 1, follow = false })',
            'dispatch hl.dsp.window.float({ window = "address:0xaaa" })',
            "dispatch hl.dsp.focus({ workspace = 1 })",
            "dispatch hl.dsp.workspace.move({ workspace = 1, monitor = 1 })",
            "dispatch hl.dsp.focus({ monitor = 1 })",
            "dispatch hl.dsp.cursor.move({ x = 10, y = 20 })",
        }
    return {
        "dispatch closewindow address:0xaaa",
        "dispatch focuswindow address:0xaaa",
        "dispatch movetoworkspacesilent 1,address:0xaaa",
        "dispatch togglefloating address:0xaaa",
        "dispatch workspace 1",
        "dispatch moveworkspacetomonitor 1 1",
        "dispatch focusmonitor 1",
        "dispatch movecursor 10 20",
    }


def main():
    executable = pathlib.Path(sys.argv[1]).resolve()
    provider = sys.argv[2]
    with tempfile.TemporaryDirectory() as runtime:
        socket_dir = pathlib.Path(runtime) / "hypr" / "fixture"
        socket_dir.mkdir(parents=True)
        request_socket = socket.socket(socket.AF_UNIX)
        event_socket = socket.socket(socket.AF_UNIX)
        request_socket.bind(str(socket_dir / ".socket.sock"))
        event_socket.bind(str(socket_dir / ".socket2.sock"))
        request_socket.listen()
        event_socket.listen()

        env = os.environ.copy()
        env["XDG_RUNTIME_DIR"] = runtime
        env["HYPRLAND_INSTANCE_SIGNATURE"] = "fixture"
        process = subprocess.Popen([executable, provider], env=env)
        events, _ = event_socket.accept()
        requests = []
        state = "initial"
        request_socket.settimeout(0.1)

        while process.poll() is None:
            try:
                connection, _ = request_socket.accept()
            except TimeoutError:
                continue
            with connection:
                request = connection.recv(65536).decode()
                requests.append(request)
                if request == "test/update":
                    state = "updated"
                elif request == "test/open":
                    state = "opened"
                elif request == "test/close":
                    state = "closed"
                connection.sendall(response(request, provider, state).encode())
            event = {
                "test/update": b"moveoutofgroup>>aaa\n",
                "test/open": b"openwindow>>ccc,1,fixture,ccc\n",
                "test/close": b"closewindow>>ccc\n",
            }.get(request)
            if event:
                events.sendall(event)

        events.close()
        if process.wait() != 0:
            return process.returncode

        missing = expected_dispatches(provider).difference(requests)
        if missing:
            raise AssertionError(f"missing dispatcher requests: {sorted(missing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
