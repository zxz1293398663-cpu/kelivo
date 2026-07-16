#!/usr/bin/env python3
import base64
import ctypes
import json
import subprocess
import sys
import time
from ctypes import wintypes


user32 = ctypes.windll.user32
SUPPORTED_PROTOCOL_VERSIONS = {
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05",
}
DEFAULT_PROTOCOL_VERSION = "2025-11-25"


def _read_messages():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except Exception as exc:
            _write_error(None, -32700, f"Parse error: {exc}")


def _write(payload):
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _write_result(request_id, result):
    if request_id is not None:
        _write({"jsonrpc": "2.0", "id": request_id, "result": result})


def _write_error(request_id, code, message):
    if request_id is not None:
        _write(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": code, "message": message},
            }
        )


def _text(text):
    return {"content": [{"type": "text", "text": str(text)}]}


def _json_text(value):
    return _text(json.dumps(value, ensure_ascii=False, indent=2))


def _object_schema(properties=None, required=None):
    schema = {
        "type": "object",
        "properties": properties or {},
        "additionalProperties": False,
    }
    if required:
        schema["required"] = required
    return schema


def screen_size(_args):
    return {
        "width": int(user32.GetSystemMetrics(0)),
        "height": int(user32.GetSystemMetrics(1)),
    }


def move_mouse(args):
    x = int(args.get("x", 0))
    y = int(args.get("y", 0))
    user32.SetCursorPos(x, y)
    return {"moved": True, "x": x, "y": y}


def click(args):
    x = args.get("x")
    y = args.get("y")
    if x is not None and y is not None:
        user32.SetCursorPos(int(x), int(y))

    button = str(args.get("button", "left")).lower()
    double = bool(args.get("double", False))
    if button == "right":
        down, up = 0x0008, 0x0010
    elif button == "middle":
        down, up = 0x0020, 0x0040
    else:
        down, up = 0x0002, 0x0004

    count = 2 if double else 1
    for _ in range(count):
        user32.mouse_event(down, 0, 0, 0, 0)
        user32.mouse_event(up, 0, 0, 0, 0)
        time.sleep(0.05)
    return {"clicked": True, "button": button, "double": double}


def type_text(args):
    text = str(args.get("text", ""))
    if not text:
        return {"typed": False, "reason": "empty text"}

    script = "Set-Clipboard -Value ([Console]::In.ReadToEnd())"
    proc = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
        input=text,
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "Set-Clipboard failed")

    # Ctrl+V
    user32.keybd_event(0x11, 0, 0, 0)
    user32.keybd_event(0x56, 0, 0, 0)
    user32.keybd_event(0x56, 0, 0x0002, 0)
    user32.keybd_event(0x11, 0, 0x0002, 0)
    return {"typed": True, "length": len(text)}


def screenshot(_args):
    script = r"""
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()
[Convert]::ToBase64String($ms.ToArray())
"""
    proc = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "screenshot failed")
    data = proc.stdout.strip()
    # Validate base64 before returning it to the client.
    base64.b64decode(data, validate=True)
    return {"content": [{"type": "image", "data": data, "mimeType": "image/png"}]}


def list_windows(args):
    limit = int(args.get("limit", 50))
    limit = max(1, min(limit, 200))
    items = []

    enum_windows_proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def callback(hwnd, _lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buffer, length + 1)
        title = buffer.value.strip()
        if title:
            rect = wintypes.RECT()
            user32.GetWindowRect(hwnd, ctypes.byref(rect))
            items.append(
                {
                    "hwnd": int(hwnd),
                    "title": title,
                    "x": int(rect.left),
                    "y": int(rect.top),
                    "width": int(rect.right - rect.left),
                    "height": int(rect.bottom - rect.top),
                }
            )
        return len(items) < limit

    user32.EnumWindows(enum_windows_proc(callback), 0)
    return {"windows": items}


TOOLS = {
    "screen_size": {
        "description": "Get primary screen size in pixels.",
        "inputSchema": _object_schema(),
        "handler": screen_size,
    },
    "screenshot": {
        "description": "Take a screenshot of the primary screen and return a PNG image.",
        "inputSchema": _object_schema(),
        "handler": screenshot,
    },
    "list_windows": {
        "description": "List visible desktop windows.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 50}}),
        "handler": list_windows,
    },
    "move_mouse": {
        "description": "Move mouse cursor to screen coordinates.",
        "inputSchema": _object_schema(
            {"x": {"type": "number"}, "y": {"type": "number"}}, ["x", "y"]
        ),
        "handler": move_mouse,
    },
    "click": {
        "description": "Click at current position or at provided screen coordinates.",
        "inputSchema": _object_schema(
            {
                "x": {"type": "number"},
                "y": {"type": "number"},
                "button": {"type": "string", "enum": ["left", "right", "middle"]},
                "double": {"type": "boolean", "default": False},
            }
        ),
        "handler": click,
    },
    "type_text": {
        "description": "Paste text into the active window using clipboard and Ctrl+V.",
        "inputSchema": _object_schema({"text": {"type": "string"}}, ["text"]),
        "handler": type_text,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}

    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = (
            client_version
            if client_version in SUPPORTED_PROTOCOL_VERSIONS
            else DEFAULT_PROTOCOL_VERSION
        )
        return _write_result(
            request_id,
            {
                "protocolVersion": protocol_version,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "screen-control", "version": "1.0.0"},
            },
        )
    if method == "notifications/initialized":
        return None
    if method == "tools/list":
        tools = []
        for name, meta in TOOLS.items():
            tools.append(
                {
                    "name": name,
                    "description": meta["description"],
                    "inputSchema": meta["inputSchema"],
                }
            )
        return _write_result(request_id, {"tools": tools})
    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        if name not in TOOLS:
            return _write_error(request_id, -32602, f"Unknown tool: {name}")
        try:
            result = TOOLS[name]["handler"](args)
            if isinstance(result, dict) and "content" in result:
                return _write_result(request_id, result)
            return _write_result(request_id, _json_text(result))
        except Exception as exc:
            return _write_result(
                request_id,
                {"content": [{"type": "text", "text": f"Error: {exc}"}], "isError": True},
            )

    if method and method.startswith("notifications/"):
        return None
    return _write_error(request_id, -32601, f"Method not found: {method}")


def main():
    if not sys.platform.startswith("win"):
        raise SystemExit("screen-control MCP currently supports Windows only")
    for message in _read_messages():
        handle(message)


if __name__ == "__main__":
    main()
