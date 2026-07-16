#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


SUPPORTED_PROTOCOL_VERSIONS = {
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05",
}
DEFAULT_PROTOCOL_VERSION = "2025-11-25"
BASE_DIR = Path.home() / ".kelivo"
KNOWN_HUBS = [
    "companion-hub",
    "identity-hub",
    "affect-hub",
    "reading-hub",
    "schedule-hub",
    "media-hub",
    "sticker-hub",
    "environment-hub",
    "game-hub",
]


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


def _read_json(path):
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None


def _read_jsonl_tail(path, limit):
    if not path.exists():
        return []
    rows = []
    try:
        with path.open("r", encoding="utf-8") as fh:
            for line in fh:
                raw = line.strip()
                if not raw:
                    continue
                try:
                    rows.append(json.loads(raw))
                except Exception:
                    continue
    except Exception:
        return []
    return rows[-limit:]


def _count_jsonl(path):
    if not path.exists():
        return 0
    count = 0
    try:
        with path.open("r", encoding="utf-8") as fh:
            for line in fh:
                if line.strip():
                    count += 1
    except Exception:
        return 0
    return count


def _hub_dir(name):
    if name not in KNOWN_HUBS:
        raise ValueError(f"unknown hub: {name}")
    return BASE_DIR / name


def _file_summary(path, sample_limit):
    item = {
        "name": path.name,
        "path": str(path),
        "suffix": path.suffix,
        "sizeBytes": path.stat().st_size if path.exists() else 0,
    }
    if path.suffix == ".jsonl":
        item["rows"] = _count_jsonl(path)
        item["tail"] = _read_jsonl_tail(path, sample_limit)
    elif path.suffix == ".json":
        data = _read_json(path)
        item["type"] = type(data).__name__ if data is not None else None
        item["sample"] = data
    return item


def _hub_summary(name, sample_limit=3):
    path = _hub_dir(name)
    files = []
    if path.exists():
        for child in sorted(path.rglob("*")):
            if child.is_file() and child.suffix in {".json", ".jsonl", ".txt"}:
                files.append(_file_summary(child, sample_limit))
    return {
        "name": name,
        "path": str(path),
        "exists": path.exists(),
        "files": files,
        "fileCount": len(files),
    }


def continuity_status(args):
    hubs = [_hub_summary(name, 0) for name in KNOWN_HUBS]
    return {
        "ok": True,
        "service": "continuity-hub",
        "baseDir": str(BASE_DIR),
        "knownHubs": len(KNOWN_HUBS),
        "existingHubs": len([hub for hub in hubs if hub["exists"]]),
        "now": _now_iso(),
    }


def continuity_list_hubs(args):
    sample_limit = _limited_int(args.get("sampleLimit", 0), 0, 0, 20)
    return {"baseDir": str(BASE_DIR), "hubs": [_hub_summary(name, sample_limit) for name in KNOWN_HUBS]}


def continuity_hub_snapshot(args):
    name = str(args.get("hub", "")).strip()
    if not name:
        raise ValueError("hub is required")
    sample_limit = _limited_int(args.get("sampleLimit", 5), 5, 0, 50)
    return _hub_summary(name, sample_limit)


def continuity_export_manifest(args):
    sample_limit = _limited_int(args.get("sampleLimit", 3), 3, 0, 20)
    include_samples = bool(args.get("includeSamples", True))
    hubs = []
    for name in KNOWN_HUBS:
        hub = _hub_summary(name, sample_limit if include_samples else 0)
        if not include_samples:
            for file in hub["files"]:
                file.pop("tail", None)
                file.pop("sample", None)
        hubs.append(hub)
    return {"generatedAt": _now_iso(), "baseDir": str(BASE_DIR), "hubs": hubs}


def continuity_markdown_report(args):
    sample_limit = _limited_int(args.get("sampleLimit", 3), 3, 0, 10)
    lines = ["# Kelivo Companion Continuity Report", "", f"Generated: {_now_iso()}", ""]
    for name in KNOWN_HUBS:
        hub = _hub_summary(name, sample_limit)
        lines.append(f"## {name}")
        lines.append("")
        lines.append(f"Path: `{hub['path']}`")
        lines.append(f"Exists: `{hub['exists']}`")
        lines.append(f"Files: `{hub['fileCount']}`")
        lines.append("")
        for file in hub["files"]:
            lines.append(f"- `{file['name']}` size={file['sizeBytes']} bytes")
            if "rows" in file:
                lines.append(f"  rows={file['rows']}")
            if sample_limit and file.get("tail"):
                lines.append("  recent:")
                for row in file["tail"]:
                    one_line = json.dumps(row, ensure_ascii=False)
                    lines.append(f"  - {one_line[:500]}")
            if sample_limit and "sample" in file and file["sample"] is not None:
                one_line = json.dumps(file["sample"], ensure_ascii=False)
                lines.append(f"  sample: {one_line[:500]}")
        lines.append("")
    return {"markdown": "\n".join(lines)}


TOOLS = {
    "continuity_status": {
        "description": "[continuity] Return continuity hub status and known hub counts.",
        "inputSchema": _object_schema(),
        "handler": continuity_status,
    },
    "continuity_list_hubs": {
        "description": "[continuity] List local hub directories and files.",
        "inputSchema": _object_schema({"sampleLimit": {"type": "number", "default": 0, "minimum": 0, "maximum": 20}}),
        "handler": continuity_list_hubs,
    },
    "continuity_hub_snapshot": {
        "description": "[continuity] Return one hub snapshot with optional samples.",
        "inputSchema": _object_schema({"hub": {"type": "string"}, "sampleLimit": {"type": "number", "default": 5, "minimum": 0, "maximum": 50}}, ["hub"]),
        "handler": continuity_hub_snapshot,
    },
    "continuity_export_manifest": {
        "description": "[continuity] Export a manifest of all local hub files and optional samples.",
        "inputSchema": _object_schema({"sampleLimit": {"type": "number", "default": 3, "minimum": 0, "maximum": 20}, "includeSamples": {"type": "boolean", "default": True}}),
        "handler": continuity_export_manifest,
    },
    "continuity_markdown_report": {
        "description": "[continuity] Generate a Markdown continuity report from local hub data.",
        "inputSchema": _object_schema({"sampleLimit": {"type": "number", "default": 3, "minimum": 0, "maximum": 10}}),
        "handler": continuity_markdown_report,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "continuity-hub", "version": "1.0.0"}})
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
