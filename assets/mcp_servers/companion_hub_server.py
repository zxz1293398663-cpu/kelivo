#!/usr/bin/env python3
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


SUPPORTED_PROTOCOL_VERSIONS = {
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05",
}
DEFAULT_PROTOCOL_VERSION = "2025-11-25"
STARTED_AT = time.time()
DATA_DIR = Path.home() / ".kelivo" / "companion-hub"
HEARTBEATS_FILE = DATA_DIR / "heartbeats.jsonl"
PRESENCE_FILE = DATA_DIR / "presence.json"
NOTES_FILE = DATA_DIR / "journal_notes.jsonl"
CHECKINS_FILE = DATA_DIR / "daily_checkins.jsonl"
MEMORY_EVENTS_FILE = DATA_DIR / "memory_events.jsonl"


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


def _json_text(value):
    return {"content": [{"type": "text", "text": json.dumps(value, ensure_ascii=False, indent=2)}]}


def _object_schema(properties=None, required=None):
    schema = {
        "type": "object",
        "properties": properties or {},
        "additionalProperties": False,
    }
    if required:
        schema["required"] = required
    return schema


def _ensure_data_dir():
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _utc_iso(timestamp):
    return datetime.fromtimestamp(timestamp, tz=timezone.utc).isoformat()


def _append_jsonl(path, payload):
    _ensure_data_dir()
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


def _write_json(path, payload):
    _ensure_data_dir()
    with path.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)


def _read_json(path, default):
    if not path.exists():
        return default
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return default


def _limited_int(value, default, minimum, maximum):
    try:
        number = int(value)
    except Exception:
        number = default
    return max(minimum, min(number, maximum))


def _string_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        raw = value
    else:
        raw = [value]
    return [str(item).strip() for item in raw if str(item).strip()]


def _contains_query(item, query):
    if not query:
        return True
    haystack = json.dumps(item, ensure_ascii=False).lower()
    return query.lower() in haystack


def system_status(args):
    now = time.time()
    return {
        "ok": True,
        "service": "companion-hub",
        "now": _utc_iso(now),
        "startedAt": _utc_iso(STARTED_AT),
        "uptimeSeconds": round(now - STARTED_AT, 3),
        "dataDir": str(DATA_DIR),
        "platform": platform.platform(),
        "python": platform.python_version(),
    }


def system_time_context(args):
    timezone_label = str(args.get("timezone", "UTC")).strip() or "UTC"
    now = datetime.now(timezone.utc)
    hour = now.hour
    greeting = "still up late" if hour < 5 else "good morning" if hour < 12 else "good afternoon" if hour < 18 else "good evening"
    return {
        "timezone": timezone_label,
        "now": now.isoformat(),
        "date": now.date().isoformat(),
        "weekday": now.strftime("%A"),
        "hour": hour,
        "minute": now.minute,
        "greeting": greeting,
    }


def presence_record_heartbeat(args):
    label = str(args.get("label", "companion-hub")).strip() or "companion-hub"
    status = str(args.get("status", "ok")).strip() or "ok"
    note = str(args.get("note", "")).strip()
    now = time.time()
    payload = {
        "kind": "heartbeat",
        "label": label,
        "status": status,
        "note": note,
        "timestamp": _utc_iso(now),
        "uptimeSeconds": round(now - STARTED_AT, 3),
    }
    _append_jsonl(HEARTBEATS_FILE, payload)
    return payload


def presence_recent_heartbeats(args):
    limit = _limited_int(args.get("limit", 10), 10, 1, 50)
    items = _read_jsonl(HEARTBEATS_FILE)
    return {"file": str(HEARTBEATS_FILE), "count": len(items), "items": items[-limit:]}


def presence_set_status(args):
    payload = {
        "status": str(args.get("status", "present")).strip() or "present",
        "mood": str(args.get("mood", "")).strip(),
        "activity": str(args.get("activity", "")).strip(),
        "note": str(args.get("note", "")).strip(),
        "updatedAt": _now_iso(),
    }
    _write_json(PRESENCE_FILE, payload)
    return payload


def presence_summary(args):
    label = str(args.get("label", "companion-hub")).strip() or "companion-hub"
    heartbeats = _read_jsonl(HEARTBEATS_FILE)
    last = next((item for item in reversed(heartbeats) if item.get("label") == label), None)
    last_seconds_ago = None
    if last and isinstance(last.get("timestamp"), str):
        try:
            last_seconds_ago = round(time.time() - datetime.fromisoformat(last["timestamp"].replace("Z", "+00:00")).timestamp(), 3)
        except Exception:
            last_seconds_ago = None
    return {
        "label": label,
        "heartbeatStatus": "active" if last else "idle",
        "lastHeartbeat": last,
        "lastHeartbeatSecondsAgo": last_seconds_ago,
        "manualPresence": _read_json(PRESENCE_FILE, {}),
        "sessionUptimeSeconds": round(time.time() - STARTED_AT, 3),
    }


def journal_append_note(args):
    text = str(args.get("text", "")).strip()
    if not text:
        raise ValueError("text is required")
    payload = {
        "kind": "journal_note",
        "text": text,
        "tags": _string_list(args.get("tags")),
        "source": str(args.get("source", "chat")).strip() or "chat",
        "timestamp": _now_iso(),
    }
    _append_jsonl(NOTES_FILE, payload)
    return payload


def journal_list_notes(args):
    limit = _limited_int(args.get("limit", 10), 10, 1, 100)
    tag = str(args.get("tag", "")).strip().lower()
    query = str(args.get("query", "")).strip().lower()
    items = _read_jsonl(NOTES_FILE)
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    items = [item for item in items if _contains_query(item, query)]
    return {"file": str(NOTES_FILE), "count": len(items), "items": items[-limit:]}


def journal_daily_checkin(args):
    payload = {
        "kind": "daily_checkin",
        "date": datetime.now(timezone.utc).date().isoformat(),
        "mood": str(args.get("mood", "")).strip(),
        "energy": _limited_int(args.get("energy", 0), 0, 0, 10),
        "sleep": str(args.get("sleep", "")).strip(),
        "focus": str(args.get("focus", "")).strip(),
        "note": str(args.get("note", "")).strip(),
        "timestamp": _now_iso(),
    }
    _append_jsonl(CHECKINS_FILE, payload)
    return payload


def journal_list_daily_checkins(args):
    limit = _limited_int(args.get("limit", 14), 14, 1, 60)
    items = _read_jsonl(CHECKINS_FILE)
    return {"file": str(CHECKINS_FILE), "count": len(items), "items": items[-limit:]}


def memory_append_event(args):
    title = str(args.get("title", "")).strip()
    content = str(args.get("content", "")).strip()
    if not title and not content:
        raise ValueError("title or content is required")
    payload = {
        "kind": "memory_event",
        "title": title,
        "content": content,
        "category": str(args.get("category", "general")).strip() or "general",
        "importance": _limited_int(args.get("importance", 3), 3, 1, 5),
        "tags": _string_list(args.get("tags")),
        "source": str(args.get("source", "chat")).strip() or "chat",
        "timestamp": _now_iso(),
    }
    _append_jsonl(MEMORY_EVENTS_FILE, payload)
    return payload


def memory_list_events(args):
    limit = _limited_int(args.get("limit", 10), 10, 1, 100)
    category = str(args.get("category", "")).strip().lower()
    min_importance = _limited_int(args.get("minImportance", 1), 1, 1, 5)
    items = _read_jsonl(MEMORY_EVENTS_FILE)
    if category:
        items = [item for item in items if str(item.get("category", "")).lower() == category]
    items = [item for item in items if int(item.get("importance", 1)) >= min_importance]
    return {"file": str(MEMORY_EVENTS_FILE), "count": len(items), "items": items[-limit:]}


def memory_search_events(args):
    query = str(args.get("query", "")).strip().lower()
    tag = str(args.get("tag", "")).strip().lower()
    limit = _limited_int(args.get("limit", 10), 10, 1, 100)
    items = _read_jsonl(MEMORY_EVENTS_FILE)
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    items = [item for item in items if _contains_query(item, query)]
    return {"file": str(MEMORY_EVENTS_FILE), "count": len(items), "items": items[-limit:]}


def memory_summary(args):
    items = _read_jsonl(MEMORY_EVENTS_FILE)
    categories = {}
    tags = {}
    for item in items:
        category = str(item.get("category", "general")) or "general"
        categories[category] = categories.get(category, 0) + 1
        for tag in item.get("tags", []):
            tags[str(tag)] = tags.get(str(tag), 0) + 1
    important = [item for item in items if int(item.get("importance", 1)) >= 4]
    return {
        "file": str(MEMORY_EVENTS_FILE),
        "count": len(items),
        "categories": categories,
        "tags": tags,
        "recentImportant": important[-10:],
    }


TOOLS = {
    "system_status": {
        "category": "system",
        "description": "Return companion hub service status and runtime information.",
        "inputSchema": _object_schema(),
        "handler": system_status,
    },
    "system_time_context": {
        "category": "system",
        "description": "Return current UTC time context and a simple greeting.",
        "inputSchema": _object_schema({"timezone": {"type": "string", "default": "UTC"}}),
        "handler": system_time_context,
    },
    "presence_record_heartbeat": {
        "category": "presence",
        "description": "Record a local companion heartbeat.",
        "inputSchema": _object_schema({"label": {"type": "string", "default": "companion-hub"}, "status": {"type": "string", "default": "ok"}, "note": {"type": "string", "default": ""}}),
        "handler": presence_record_heartbeat,
    },
    "presence_recent_heartbeats": {
        "category": "presence",
        "description": "List recent local companion heartbeats.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 10, "minimum": 1, "maximum": 50}}),
        "handler": presence_recent_heartbeats,
    },
    "presence_set_status": {
        "category": "presence",
        "description": "Set manual companion presence, mood, and activity.",
        "inputSchema": _object_schema({"status": {"type": "string", "default": "present"}, "mood": {"type": "string", "default": ""}, "activity": {"type": "string", "default": ""}, "note": {"type": "string", "default": ""}}),
        "handler": presence_set_status,
    },
    "presence_summary": {
        "category": "presence",
        "description": "Summarize companion presence from heartbeat and manual status.",
        "inputSchema": _object_schema({"label": {"type": "string", "default": "companion-hub"}}),
        "handler": presence_summary,
    },
    "journal_append_note": {
        "category": "journal",
        "description": "Append a local journal note with optional tags.",
        "inputSchema": _object_schema({"text": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}, "source": {"type": "string", "default": "chat"}}, ["text"]),
        "handler": journal_append_note,
    },
    "journal_list_notes": {
        "category": "journal",
        "description": "List or filter local journal notes.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 10, "minimum": 1, "maximum": 100}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": journal_list_notes,
    },
    "journal_daily_checkin": {
        "category": "journal",
        "description": "Record a daily mood, energy, sleep, focus, and note check-in.",
        "inputSchema": _object_schema({"mood": {"type": "string", "default": ""}, "energy": {"type": "number", "default": 0, "minimum": 0, "maximum": 10}, "sleep": {"type": "string", "default": ""}, "focus": {"type": "string", "default": ""}, "note": {"type": "string", "default": ""}}),
        "handler": journal_daily_checkin,
    },
    "journal_list_daily_checkins": {
        "category": "journal",
        "description": "List recent daily check-ins.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 14, "minimum": 1, "maximum": 60}}),
        "handler": journal_list_daily_checkins,
    },
    "memory_append_event": {
        "category": "memory",
        "description": "Append a long-term companion memory event.",
        "inputSchema": _object_schema({"title": {"type": "string", "default": ""}, "content": {"type": "string", "default": ""}, "category": {"type": "string", "default": "general"}, "importance": {"type": "number", "default": 3, "minimum": 1, "maximum": 5}, "tags": {"type": "array", "items": {"type": "string"}}, "source": {"type": "string", "default": "chat"}}),
        "handler": memory_append_event,
    },
    "memory_list_events": {
        "category": "memory",
        "description": "List long-term memory events by category and importance.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 10, "minimum": 1, "maximum": 100}, "category": {"type": "string", "default": ""}, "minImportance": {"type": "number", "default": 1, "minimum": 1, "maximum": 5}}),
        "handler": memory_list_events,
    },
    "memory_search_events": {
        "category": "memory",
        "description": "Keyword-search long-term memory events, optionally filtered by tag.",
        "inputSchema": _object_schema({"query": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}, "limit": {"type": "number", "default": 10, "minimum": 1, "maximum": 100}}),
        "handler": memory_search_events,
    },
    "memory_summary": {
        "category": "memory",
        "description": "Summarize memory event counts, categories, tags, and recent important events.",
        "inputSchema": _object_schema(),
        "handler": memory_summary,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}

    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(
            request_id,
            {
                "protocolVersion": protocol_version,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "companion-hub", "version": "1.0.0"},
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
                    "description": f"[{meta['category']}] {meta['description']}",
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
    for message in _read_messages():
        handle(message)


if __name__ == "__main__":
    main()
