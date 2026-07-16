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
DATA_DIR = Path.home() / ".kelivo" / "identity-hub"
PROFILE_FILE = DATA_DIR / "profile.json"
PREFERENCES_FILE = DATA_DIR / "preferences.jsonl"
BOUNDARIES_FILE = DATA_DIR / "boundaries.jsonl"
RELATIONSHIP_FILE = DATA_DIR / "relationship_notes.jsonl"


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


def identity_status(args):
    return {
        "ok": True,
        "service": "identity-hub",
        "dataDir": str(DATA_DIR),
        "hasProfile": PROFILE_FILE.exists(),
        "preferences": len(_read_jsonl(PREFERENCES_FILE)),
        "boundaries": len(_read_jsonl(BOUNDARIES_FILE)),
        "relationshipNotes": len(_read_jsonl(RELATIONSHIP_FILE)),
        "now": _now_iso(),
    }


def identity_set_profile(args):
    existing = _read_json(PROFILE_FILE, {})
    profile = {
        **existing,
        "displayName": str(args.get("displayName", existing.get("displayName", ""))).strip(),
        "pronouns": str(args.get("pronouns", existing.get("pronouns", ""))).strip(),
        "relationshipLabel": str(args.get("relationshipLabel", existing.get("relationshipLabel", ""))).strip(),
        "tone": str(args.get("tone", existing.get("tone", ""))).strip(),
        "companionRole": str(args.get("companionRole", existing.get("companionRole", ""))).strip(),
        "notes": str(args.get("notes", existing.get("notes", ""))).strip(),
        "updatedAt": _now_iso(),
    }
    _write_json(PROFILE_FILE, profile)
    return profile


def identity_get_profile(args):
    return _read_json(PROFILE_FILE, {})


def identity_add_preference(args):
    key = str(args.get("key", "")).strip()
    value = str(args.get("value", "")).strip()
    if not key or not value:
        raise ValueError("key and value are required")
    payload = {
        "id": str(uuid.uuid4()),
        "key": key,
        "value": value,
        "category": str(args.get("category", "general")).strip() or "general",
        "strength": _limited_int(args.get("strength", 3), 3, 1, 5),
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(PREFERENCES_FILE, payload)
    return payload


def identity_list_preferences(args):
    limit = _limited_int(args.get("limit", 50), 50, 1, 200)
    category = str(args.get("category", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    items = _read_jsonl(PREFERENCES_FILE)
    if category:
        items = [item for item in items if str(item.get("category", "")).lower() == category]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(PREFERENCES_FILE), "count": len(items), "items": items[-limit:]}


def identity_add_boundary(args):
    text = str(args.get("text", "")).strip()
    if not text:
        raise ValueError("text is required")
    payload = {
        "id": str(uuid.uuid4()),
        "text": text,
        "category": str(args.get("category", "general")).strip() or "general",
        "severity": str(args.get("severity", "normal")).strip() or "normal",
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(BOUNDARIES_FILE, payload)
    return payload


def identity_list_boundaries(args):
    limit = _limited_int(args.get("limit", 50), 50, 1, 200)
    category = str(args.get("category", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    items = _read_jsonl(BOUNDARIES_FILE)
    if category:
        items = [item for item in items if str(item.get("category", "")).lower() == category]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(BOUNDARIES_FILE), "count": len(items), "items": items[-limit:]}


def identity_add_relationship_note(args):
    text = str(args.get("text", "")).strip()
    if not text:
        raise ValueError("text is required")
    payload = {
        "id": str(uuid.uuid4()),
        "text": text,
        "kind": str(args.get("kind", "note")).strip() or "note",
        "importance": _limited_int(args.get("importance", 3), 3, 1, 5),
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(RELATIONSHIP_FILE, payload)
    return payload


def identity_list_relationship_notes(args):
    limit = _limited_int(args.get("limit", 50), 50, 1, 200)
    query = str(args.get("query", "")).strip()
    items = [item for item in _read_jsonl(RELATIONSHIP_FILE) if _matches(item, query)]
    return {"file": str(RELATIONSHIP_FILE), "count": len(items), "items": items[-limit:]}


def identity_summary(args):
    preferences = _read_jsonl(PREFERENCES_FILE)
    boundaries = _read_jsonl(BOUNDARIES_FILE)
    notes = _read_jsonl(RELATIONSHIP_FILE)
    return {
        "profile": _read_json(PROFILE_FILE, {}),
        "recentPreferences": preferences[-10:],
        "recentBoundaries": boundaries[-10:],
        "recentRelationshipNotes": notes[-10:],
        "counts": {
            "preferences": len(preferences),
            "boundaries": len(boundaries),
            "relationshipNotes": len(notes),
        },
    }


TOOLS = {
    "identity_status": {
        "description": "[identity] Return identity hub status and counts.",
        "inputSchema": _object_schema(),
        "handler": identity_status,
    },
    "identity_set_profile": {
        "description": "[identity] Set explicit user/relationship profile fields.",
        "inputSchema": _object_schema({"displayName": {"type": "string", "default": ""}, "pronouns": {"type": "string", "default": ""}, "relationshipLabel": {"type": "string", "default": ""}, "tone": {"type": "string", "default": ""}, "companionRole": {"type": "string", "default": ""}, "notes": {"type": "string", "default": ""}}),
        "handler": identity_set_profile,
    },
    "identity_get_profile": {
        "description": "[identity] Get explicit user/relationship profile fields.",
        "inputSchema": _object_schema(),
        "handler": identity_get_profile,
    },
    "identity_add_preference": {
        "description": "[identity] Add an explicit user preference.",
        "inputSchema": _object_schema({"key": {"type": "string"}, "value": {"type": "string"}, "category": {"type": "string", "default": "general"}, "strength": {"type": "number", "default": 3, "minimum": 1, "maximum": 5}, "tags": {"type": "array", "items": {"type": "string"}}}, ["key", "value"]),
        "handler": identity_add_preference,
    },
    "identity_list_preferences": {
        "description": "[identity] List explicit user preferences.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 50, "minimum": 1, "maximum": 200}, "category": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": identity_list_preferences,
    },
    "identity_add_boundary": {
        "description": "[identity] Add an explicit boundary or constraint.",
        "inputSchema": _object_schema({"text": {"type": "string"}, "category": {"type": "string", "default": "general"}, "severity": {"type": "string", "default": "normal"}, "tags": {"type": "array", "items": {"type": "string"}}}, ["text"]),
        "handler": identity_add_boundary,
    },
    "identity_list_boundaries": {
        "description": "[identity] List explicit boundaries or constraints.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 50, "minimum": 1, "maximum": 200}, "category": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": identity_list_boundaries,
    },
    "identity_add_relationship_note": {
        "description": "[identity] Add an explicit relationship note.",
        "inputSchema": _object_schema({"text": {"type": "string"}, "kind": {"type": "string", "default": "note"}, "importance": {"type": "number", "default": 3, "minimum": 1, "maximum": 5}, "tags": {"type": "array", "items": {"type": "string"}}}, ["text"]),
        "handler": identity_add_relationship_note,
    },
    "identity_list_relationship_notes": {
        "description": "[identity] List explicit relationship notes.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 50, "minimum": 1, "maximum": 200}, "query": {"type": "string", "default": ""}}),
        "handler": identity_list_relationship_notes,
    },
    "identity_summary": {
        "description": "[identity] Summarize explicit profile, preferences, boundaries, and relationship notes.",
        "inputSchema": _object_schema(),
        "handler": identity_summary,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "identity-hub", "version": "1.0.0"}})
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
