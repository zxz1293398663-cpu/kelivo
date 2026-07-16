#!/usr/bin/env python3
import json
import random
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path


SUPPORTED_PROTOCOL_VERSIONS = {
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05",
}
DEFAULT_PROTOCOL_VERSION = "2025-11-25"
DATA_DIR = Path.home() / ".kelivo" / "sticker-hub"
STICKERS_FILE = DATA_DIR / "stickers.jsonl"
USAGE_FILE = DATA_DIR / "sticker_usage.jsonl"


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


def _ensure_dir():
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _append_jsonl(path, payload):
    _ensure_dir()
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(payload, ensure_ascii=False))
        fh.write("\n")


def _read_jsonl(path):
    if not path.exists():
        return []
    items = []
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            raw = line.strip()
            if not raw:
                continue
            try:
                items.append(json.loads(raw))
            except Exception:
                continue
    return items


def _limited_int(value, default, minimum, maximum):
    try:
        number = int(value)
    except Exception:
        number = default
    return max(minimum, min(number, maximum))


def _string_list(value):
    if value is None:
        return []
    raw = value if isinstance(value, list) else [value]
    return [str(item).strip() for item in raw if str(item).strip()]


def _matches(item, query):
    if not query:
        return True
    return query.lower() in json.dumps(item, ensure_ascii=False).lower()


def _find_sticker(sticker_id):
    for item in _read_jsonl(STICKERS_FILE):
        if item.get("id") == sticker_id:
            return item
    return None


def sticker_status(args):
    return {
        "ok": True,
        "service": "sticker-hub",
        "dataDir": str(DATA_DIR),
        "stickers": len(_read_jsonl(STICKERS_FILE)),
        "usage": len(_read_jsonl(USAGE_FILE)),
        "now": _now_iso(),
    }


def sticker_add(args):
    name = str(args.get("name", "")).strip()
    if not name:
        raise ValueError("name is required")
    payload = {
        "id": str(uuid.uuid4()),
        "name": name,
        "path": str(args.get("path", "")).strip(),
        "url": str(args.get("url", "")).strip(),
        "description": str(args.get("description", "")).strip(),
        "emotions": _string_list(args.get("emotions")),
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
    }
    _append_jsonl(STICKERS_FILE, payload)
    return payload


def sticker_list(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    emotion = str(args.get("emotion", "")).strip().lower()
    tag = str(args.get("tag", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    items = _read_jsonl(STICKERS_FILE)
    if emotion:
        items = [item for item in items if emotion in [str(e).lower() for e in item.get("emotions", [])]]
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(STICKERS_FILE), "count": len(items), "items": items[-limit:]}


def sticker_recommend(args):
    emotion = str(args.get("emotion", "")).strip().lower()
    tag = str(args.get("tag", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    count = _limited_int(args.get("count", 1), 1, 1, 20)
    items = sticker_list({"limit": 200, "emotion": emotion, "tag": tag, "query": query})["items"]
    if not items:
        items = _read_jsonl(STICKERS_FILE)
    if not items:
        return {"count": 0, "items": []}
    picked = random.sample(items, min(count, len(items)))
    return {"count": len(picked), "items": picked}


def sticker_record_usage(args):
    sticker_id = str(args.get("id", "")).strip()
    if not sticker_id:
        raise ValueError("id is required")
    sticker = _find_sticker(sticker_id)
    if not sticker:
        raise ValueError(f"sticker not found: {sticker_id}")
    payload = {
        "id": str(uuid.uuid4()),
        "stickerId": sticker_id,
        "stickerName": sticker.get("name"),
        "context": str(args.get("context", "")).strip(),
        "emotion": str(args.get("emotion", "")).strip(),
        "timestamp": _now_iso(),
    }
    _append_jsonl(USAGE_FILE, payload)
    return payload


def sticker_usage(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    query = str(args.get("query", "")).strip()
    items = [item for item in _read_jsonl(USAGE_FILE) if _matches(item, query)]
    return {"file": str(USAGE_FILE), "count": len(items), "items": items[-limit:]}


def sticker_summary(args):
    stickers = _read_jsonl(STICKERS_FILE)
    usage = _read_jsonl(USAGE_FILE)
    emotions = {}
    tags = {}
    used = {}
    for item in stickers:
        for emotion in item.get("emotions", []):
            emotions[str(emotion)] = emotions.get(str(emotion), 0) + 1
        for tag in item.get("tags", []):
            tags[str(tag)] = tags.get(str(tag), 0) + 1
    for item in usage:
        name = str(item.get("stickerName", item.get("stickerId", "unknown")))
        used[name] = used.get(name, 0) + 1
    return {"stickers": len(stickers), "usage": len(usage), "emotions": emotions, "tags": tags, "used": used}


TOOLS = {
    "sticker_status": {
        "description": "[sticker] Return sticker hub status and counts.",
        "inputSchema": _object_schema(),
        "handler": sticker_status,
    },
    "sticker_add": {
        "description": "[sticker] Add a sticker reference with optional path, URL, emotions, and tags.",
        "inputSchema": _object_schema({"name": {"type": "string"}, "path": {"type": "string", "default": ""}, "url": {"type": "string", "default": ""}, "description": {"type": "string", "default": ""}, "emotions": {"type": "array", "items": {"type": "string"}}, "tags": {"type": "array", "items": {"type": "string"}}}, ["name"]),
        "handler": sticker_add,
    },
    "sticker_list": {
        "description": "[sticker] List stickers by emotion, tag, or query.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "emotion": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": sticker_list,
    },
    "sticker_recommend": {
        "description": "[sticker] Recommend stickers by emotion, tag, or query.",
        "inputSchema": _object_schema({"emotion": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}, "count": {"type": "number", "default": 1, "minimum": 1, "maximum": 20}}),
        "handler": sticker_recommend,
    },
    "sticker_record_usage": {
        "description": "[sticker] Record that a sticker was used in a context.",
        "inputSchema": _object_schema({"id": {"type": "string"}, "context": {"type": "string", "default": ""}, "emotion": {"type": "string", "default": ""}}, ["id"]),
        "handler": sticker_record_usage,
    },
    "sticker_usage": {
        "description": "[sticker] List sticker usage records.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "query": {"type": "string", "default": ""}}),
        "handler": sticker_usage,
    },
    "sticker_summary": {
        "description": "[sticker] Summarize sticker emotions, tags, and usage counts.",
        "inputSchema": _object_schema(),
        "handler": sticker_summary,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "sticker-hub", "version": "1.0.0"}})
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
