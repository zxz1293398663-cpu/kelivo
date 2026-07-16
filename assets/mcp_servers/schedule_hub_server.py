#!/usr/bin/env python3
import json
import sys
import time
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
DATA_DIR = Path.home() / ".kelivo" / "schedule-hub"
ITEMS_FILE = DATA_DIR / "schedule_items.json"


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


def _parse_iso(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except Exception:
        return None


def _read_items():
    if not ITEMS_FILE.exists():
        return []
    try:
        with ITEMS_FILE.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def _write_items(items):
    _ensure_dir()
    with ITEMS_FILE.open("w", encoding="utf-8") as fh:
        json.dump(items, fh, ensure_ascii=False, indent=2)


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


def _matches_query(item, query):
    if not query:
        return True
    return query.lower() in json.dumps(item, ensure_ascii=False).lower()


def _sorted_items(items):
    def key(item):
        due = _parse_iso(item.get("dueAt"))
        return due.timestamp() if due else float("inf")

    return sorted(items, key=key)


def schedule_status(args):
    items = _read_items()
    open_items = [item for item in items if item.get("status") != "done"]
    due = schedule_due_items({"limit": 100})["items"]
    return {
        "ok": True,
        "service": "schedule-hub",
        "dataDir": str(DATA_DIR),
        "total": len(items),
        "open": len(open_items),
        "done": len(items) - len(open_items),
        "due": len(due),
        "now": _now_iso(),
    }


def schedule_add_item(args):
    title = str(args.get("title", "")).strip()
    if not title:
        raise ValueError("title is required")
    due_at = str(args.get("dueAt", "")).strip()
    if due_at and _parse_iso(due_at) is None:
        raise ValueError("dueAt must be ISO-8601, for example 2026-07-13T20:00:00+08:00")
    item = {
        "id": str(uuid.uuid4()),
        "kind": str(args.get("kind", "reminder")).strip() or "reminder",
        "title": title,
        "note": str(args.get("note", "")).strip(),
        "dueAt": due_at,
        "priority": _limited_int(args.get("priority", 3), 3, 1, 5),
        "tags": _string_list(args.get("tags")),
        "status": "open",
        "createdAt": _now_iso(),
        "completedAt": None,
    }
    items = _read_items()
    items.append(item)
    _write_items(items)
    return item


def schedule_list_items(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    status = str(args.get("status", "open")).strip().lower()
    tag = str(args.get("tag", "")).strip().lower()
    kind = str(args.get("kind", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    items = _read_items()
    if status and status != "all":
        items = [item for item in items if str(item.get("status", "")).lower() == status]
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    if kind:
        items = [item for item in items if str(item.get("kind", "")).lower() == kind]
    items = [item for item in items if _matches_query(item, query)]
    items = _sorted_items(items)
    return {"file": str(ITEMS_FILE), "count": len(items), "items": items[:limit]}


def schedule_due_items(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    now = datetime.now(timezone.utc)
    items = []
    for item in _read_items():
        if item.get("status") == "done":
            continue
        due = _parse_iso(item.get("dueAt"))
        if due is not None and due <= now:
            items.append(item)
    items = _sorted_items(items)
    return {"file": str(ITEMS_FILE), "count": len(items), "items": items[:limit], "now": now.isoformat()}


def schedule_complete_item(args):
    item_id = str(args.get("id", "")).strip()
    if not item_id:
        raise ValueError("id is required")
    items = _read_items()
    for item in items:
        if item.get("id") == item_id:
            item["status"] = "done"
            item["completedAt"] = _now_iso()
            _write_items(items)
            return item
    raise ValueError(f"item not found: {item_id}")


def schedule_delete_item(args):
    item_id = str(args.get("id", "")).strip()
    if not item_id:
        raise ValueError("id is required")
    items = _read_items()
    kept = [item for item in items if item.get("id") != item_id]
    if len(kept) == len(items):
        raise ValueError(f"item not found: {item_id}")
    _write_items(kept)
    return {"deleted": True, "id": item_id}


def schedule_search_items(args):
    query = str(args.get("query", "")).strip()
    if not query:
        raise ValueError("query is required")
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    items = [item for item in _read_items() if _matches_query(item, query)]
    return {"file": str(ITEMS_FILE), "query": query, "count": len(items), "items": _sorted_items(items)[:limit]}


TOOLS = {
    "schedule_status": {
        "description": "[schedule] Return schedule hub status and item counts.",
        "inputSchema": _object_schema(),
        "handler": schedule_status,
    },
    "schedule_add_item": {
        "description": "[schedule] Add a reminder, todo, appointment, or promise.",
        "inputSchema": _object_schema({"title": {"type": "string"}, "kind": {"type": "string", "default": "reminder"}, "note": {"type": "string", "default": ""}, "dueAt": {"type": "string", "default": ""}, "priority": {"type": "number", "default": 3, "minimum": 1, "maximum": 5}, "tags": {"type": "array", "items": {"type": "string"}}}, ["title"]),
        "handler": schedule_add_item,
    },
    "schedule_list_items": {
        "description": "[schedule] List schedule items with optional filters.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "status": {"type": "string", "default": "open"}, "kind": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": schedule_list_items,
    },
    "schedule_due_items": {
        "description": "[schedule] List open items whose dueAt is now or in the past.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}}),
        "handler": schedule_due_items,
    },
    "schedule_complete_item": {
        "description": "[schedule] Mark an item as done.",
        "inputSchema": _object_schema({"id": {"type": "string"}}, ["id"]),
        "handler": schedule_complete_item,
    },
    "schedule_delete_item": {
        "description": "[schedule] Delete an item by id.",
        "inputSchema": _object_schema({"id": {"type": "string"}}, ["id"]),
        "handler": schedule_delete_item,
    },
    "schedule_search_items": {
        "description": "[schedule] Keyword-search all schedule items.",
        "inputSchema": _object_schema({"query": {"type": "string"}, "limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}}, ["query"]),
        "handler": schedule_search_items,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "schedule-hub", "version": "1.0.0"}})
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
