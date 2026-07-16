#!/usr/bin/env python3
import json
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
DATA_DIR = Path.home() / ".kelivo" / "affect-hub"
STATE_FILE = DATA_DIR / "affect_state.json"
EVENTS_FILE = DATA_DIR / "affect_events.jsonl"
ANCHORS_FILE = DATA_DIR / "affect_anchors.jsonl"
DEFAULT_AXES = {
    "energy": 5,
    "stress": 3,
    "loneliness": 3,
    "curiosity": 5,
    "affection": 5,
    "trust": 5,
    "fatigue": 3,
}


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


def _read_json(path, default):
    if not path.exists():
        return default
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return default


def _write_json(path, payload):
    _ensure_dir()
    with path.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)


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


def _load_state():
    state = _read_json(STATE_FILE, {})
    if not state:
        state = {"mood": "neutral", "axes": dict(DEFAULT_AXES), "note": "", "updatedAt": None}
    state.setdefault("axes", dict(DEFAULT_AXES))
    for key, value in DEFAULT_AXES.items():
        state["axes"].setdefault(key, value)
    return state


def affect_status(args):
    return {
        "ok": True,
        "service": "affect-hub",
        "dataDir": str(DATA_DIR),
        "hasState": STATE_FILE.exists(),
        "events": len(_read_jsonl(EVENTS_FILE)),
        "anchors": len(_read_jsonl(ANCHORS_FILE)),
        "now": _now_iso(),
    }


def affect_set_state(args):
    state = _load_state()
    if "mood" in args:
        state["mood"] = str(args.get("mood", "neutral")).strip() or "neutral"
    if "note" in args:
        state["note"] = str(args.get("note", "")).strip()
    axes = args.get("axes")
    if isinstance(axes, dict):
        for key, value in axes.items():
            state["axes"][str(key)] = _limited_int(value, state["axes"].get(str(key), 5), 0, 10)
    state["updatedAt"] = _now_iso()
    _write_json(STATE_FILE, state)
    return state


def affect_get_state(args):
    return _load_state()


def affect_adjust_drive(args):
    name = str(args.get("name", "")).strip()
    if not name:
        raise ValueError("name is required")
    delta = _limited_int(args.get("delta", 0), 0, -10, 10)
    state = _load_state()
    current = _limited_int(state["axes"].get(name, 5), 5, 0, 10)
    state["axes"][name] = max(0, min(10, current + delta))
    state["updatedAt"] = _now_iso()
    _write_json(STATE_FILE, state)
    return {"name": name, "old": current, "delta": delta, "new": state["axes"][name], "state": state}


def affect_append_event(args):
    text = str(args.get("text", "")).strip()
    if not text:
        raise ValueError("text is required")
    payload = {
        "id": str(uuid.uuid4()),
        "kind": str(args.get("kind", "event")).strip() or "event",
        "text": text,
        "mood": str(args.get("mood", "")).strip(),
        "impact": args.get("impact") if isinstance(args.get("impact"), dict) else {},
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(EVENTS_FILE, payload)
    impact = payload["impact"]
    if impact:
        state = _load_state()
        for key, value in impact.items():
            current = _limited_int(state["axes"].get(str(key), 5), 5, 0, 10)
            state["axes"][str(key)] = max(0, min(10, current + _limited_int(value, 0, -10, 10)))
        if payload["mood"]:
            state["mood"] = payload["mood"]
        state["updatedAt"] = _now_iso()
        _write_json(STATE_FILE, state)
        payload["stateAfter"] = state
    return payload


def affect_list_events(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    kind = str(args.get("kind", "")).strip().lower()
    tag = str(args.get("tag", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    items = _read_jsonl(EVENTS_FILE)
    if kind:
        items = [item for item in items if str(item.get("kind", "")).lower() == kind]
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(EVENTS_FILE), "count": len(items), "items": items[-limit:]}


def affect_add_anchor(args):
    title = str(args.get("title", "")).strip()
    text = str(args.get("text", "")).strip()
    if not title or not text:
        raise ValueError("title and text are required")
    payload = {
        "id": str(uuid.uuid4()),
        "title": title,
        "text": text,
        "mood": str(args.get("mood", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(ANCHORS_FILE, payload)
    return payload


def affect_list_anchors(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    query = str(args.get("query", "")).strip()
    tag = str(args.get("tag", "")).strip().lower()
    items = _read_jsonl(ANCHORS_FILE)
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(ANCHORS_FILE), "count": len(items), "items": items[-limit:]}


def affect_summary(args):
    events = _read_jsonl(EVENTS_FILE)
    anchors = _read_jsonl(ANCHORS_FILE)
    kinds = {}
    tags = {}
    for item in events + anchors:
        kind = str(item.get("kind", "anchor" if item in anchors else "event"))
        kinds[kind] = kinds.get(kind, 0) + 1
        for tag in item.get("tags", []):
            tags[str(tag)] = tags.get(str(tag), 0) + 1
    return {
        "state": _load_state(),
        "eventCount": len(events),
        "anchorCount": len(anchors),
        "kinds": kinds,
        "tags": tags,
        "recentEvents": events[-10:],
        "recentAnchors": anchors[-10:],
    }


TOOLS = {
    "affect_status": {
        "description": "[affect] Return affect hub status and counts.",
        "inputSchema": _object_schema(),
        "handler": affect_status,
    },
    "affect_set_state": {
        "description": "[affect] Set explicit affect mood and axis values from 0 to 10.",
        "inputSchema": _object_schema({"mood": {"type": "string", "default": "neutral"}, "axes": {"type": "object"}, "note": {"type": "string", "default": ""}}),
        "handler": affect_set_state,
    },
    "affect_get_state": {
        "description": "[affect] Get current affect state.",
        "inputSchema": _object_schema(),
        "handler": affect_get_state,
    },
    "affect_adjust_drive": {
        "description": "[affect] Adjust one affect drive by a delta, clamped to 0..10.",
        "inputSchema": _object_schema({"name": {"type": "string"}, "delta": {"type": "number", "default": 0}}, ["name"]),
        "handler": affect_adjust_drive,
    },
    "affect_append_event": {
        "description": "[affect] Append an affect event and optionally apply axis impacts.",
        "inputSchema": _object_schema({"text": {"type": "string"}, "kind": {"type": "string", "default": "event"}, "mood": {"type": "string", "default": ""}, "impact": {"type": "object"}, "tags": {"type": "array", "items": {"type": "string"}}}, ["text"]),
        "handler": affect_append_event,
    },
    "affect_list_events": {
        "description": "[affect] List affect events with optional filters.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "kind": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": affect_list_events,
    },
    "affect_add_anchor": {
        "description": "[affect] Add a text-native affect anchor for later emotional continuity.",
        "inputSchema": _object_schema({"title": {"type": "string"}, "text": {"type": "string"}, "mood": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}}, ["title", "text"]),
        "handler": affect_add_anchor,
    },
    "affect_list_anchors": {
        "description": "[affect] List affect anchors with optional filters.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": affect_list_anchors,
    },
    "affect_summary": {
        "description": "[affect] Summarize current affect state, events, anchors, kinds, and tags.",
        "inputSchema": _object_schema(),
        "handler": affect_summary,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "affect-hub", "version": "1.0.0"}})
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
