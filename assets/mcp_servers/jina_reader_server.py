#!/usr/bin/env python3
import json
import platform
import subprocess
import sys
import time
from datetime import datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


SUPPORTED_PROTOCOL_VERSIONS = {
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05",
}
DEFAULT_PROTOCOL_VERSION = "2025-11-25"
STARTED_AT = time.time()
MAX_CHARS = 200000


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
        _write({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}})


def _json_text(value):
    return {"content": [{"type": "text", "text": json.dumps(value, ensure_ascii=False, indent=2)}]}


def _object_schema(properties=None, required=None):
    schema = {"type": "object", "properties": properties or {}, "additionalProperties": False}
    if required:
        schema["required"] = required
    return schema


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _limited_int(value, default, minimum, maximum):
    try:
        number = int(value)
    except Exception:
        number = default
    return max(minimum, min(number, maximum))


def _normalize_url(raw_url):
    url = str(raw_url or "").strip()
    if not url:
        raise ValueError("url is required")
    parsed = urlparse(url)
    if not parsed.scheme:
        url = "https://" + url
        parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("url must be an http or https URL")
    return url


def _reader_url(url):
    return "https://r.jina.ai/http://" + url


def jina_status(args):
    return {
        "ok": True,
        "service": "jina-reader",
        "readerEndpoint": "https://r.jina.ai/http://<url>",
        "startedAt": datetime.fromtimestamp(STARTED_AT, tz=timezone.utc).isoformat(),
        "uptimeSeconds": round(time.time() - STARTED_AT, 3),
        "now": _now_iso(),
    }


def jina_read(args):
    url = _normalize_url(args.get("url"))
    timeout = _limited_int(args.get("timeoutSeconds", 30), 30, 5, 120)
    max_chars = _limited_int(args.get("maxChars", 60000), 60000, 1000, MAX_CHARS)
    reader = _reader_url(url)
    headers = {
        "User-Agent": "Kelivo Jina Reader MCP/1.0",
        "Accept": "text/plain, text/markdown, */*",
    }
    request = Request(reader, headers=headers)
    try:
        with urlopen(request, timeout=timeout) as response:
            raw = response.read(max_chars + 1)
            text = raw.decode("utf-8", errors="replace")
            truncated = len(raw) > max_chars
            if truncated:
                text = text[:max_chars]
            return {
                "url": url,
                "readerUrl": reader,
                "status": getattr(response, "status", None),
                "truncated": truncated,
                "maxChars": max_chars,
                "content": text,
                "fetchedAt": _now_iso(),
            }
    except HTTPError as exc:
        raise ValueError(f"Jina Reader HTTP {exc.code}: {exc.reason}")
    except URLError as exc:
        text = _read_with_powershell(reader, timeout)
        if text is None:
            raise ValueError(f"Jina Reader request failed: {exc.reason}")
        truncated = len(text) > max_chars
        return {
            "url": url,
            "readerUrl": reader,
            "status": None,
            "truncated": truncated,
            "maxChars": max_chars,
            "content": text[:max_chars] if truncated else text,
            "fetchedAt": _now_iso(),
        }


def _read_with_powershell(url, timeout):
    if platform.system().lower() != "windows":
        return None
    script = (
        "$ProgressPreference='SilentlyContinue'; "
        "$r = Invoke-WebRequest -Uri $args[0] -UseBasicParsing -TimeoutSec $args[1]; "
        "$r.Content"
    )
    try:
        completed = subprocess.run(
            ["powershell", "-NoProfile", "-Command", script, url, str(timeout)],
            check=True,
            capture_output=True,
            text=True,
            timeout=timeout + 5,
        )
    except Exception:
        return None
    return completed.stdout


TOOLS = {
    "jina_status": {
        "description": "[jina] Return Jina Reader MCP status.",
        "inputSchema": _object_schema(),
        "handler": jina_status,
    },
    "jina_read": {
        "description": "[jina] Read a public web page as clean Markdown/text through the free Jina Reader endpoint.",
        "inputSchema": _object_schema({"url": {"type": "string"}, "maxChars": {"type": "number", "default": 60000, "minimum": 1000, "maximum": MAX_CHARS}, "timeoutSeconds": {"type": "number", "default": 30, "minimum": 5, "maximum": 120}}, ["url"]),
        "handler": jina_read,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "jina-reader", "version": "1.0.0"}})
    if method == "notifications/initialized":
        return None
    if method == "tools/list":
        return _write_result(request_id, {"tools": [{"name": name, "description": meta["description"], "inputSchema": meta["inputSchema"]} for name, meta in TOOLS.items()]})
    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") or {}
        if name not in TOOLS:
            return _write_error(request_id, -32602, f"Unknown tool: {name}")
        try:
            return _write_result(request_id, _json_text(TOOLS[name]["handler"](args)))
        except Exception as exc:
            return _write_result(request_id, {"content": [{"type": "text", "text": f"Error: {exc}"}], "isError": True})
    if method and method.startswith("notifications/"):
        return None
    return _write_error(request_id, -32601, f"Method not found: {method}")


def main():
    for message in _read_messages():
        handle(message)


if __name__ == "__main__":
    main()
