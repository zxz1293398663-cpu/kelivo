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
DATA_DIR = Path.home() / ".kelivo" / "environment-hub"
CONTEXT_FILE = DATA_DIR / "current_context.json"
OBSERVATIONS_FILE = DATA_DIR / "observations.jsonl"


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


def _write_json(path, payload):
    _ensure_dir()
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


def environment_status(args):
    context = _read_json(CONTEXT_FILE, {})
    observations = _read_jsonl(OBSERVATIONS_FILE)
    return {
        "ok": True,
        "service": "environment-hub",
        "dataDir": str(DATA_DIR),
        "hasCurrentContext": bool(context),
        "observations": len(observations),
        "now": _now_iso(),
    }


def environment_set_context(args):
    payload = {
        "location": str(args.get("location", "")).strip(),
        "room": str(args.get("room", "")).strip(),
        "activity": str(args.get("activity", "")).strip(),
        "device": str(args.get("device", "")).strip(),
        "bodyState": str(args.get("bodyState", "")).strip(),
        "weather": str(args.get("weather", "")).strip(),
        "ambient": str(args.get("ambient", "")).strip(),
        "note": str(args.get("note", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "updatedAt": _now_iso(),
    }
    _write_json(CONTEXT_FILE, payload)
    return payload


def environment_get_context(args):
    return _read_json(CONTEXT_FILE, {})


def environment_append_observation(args):
    text = str(args.get("text", "")).strip()
    if not text:
        raise ValueError("text is required")
    payload = {
        "id": str(uuid.uuid4()),
        "kind": str(args.get("kind", "observation")).strip() or "observation",
        "text": text,
        "source": str(args.get("source", "manual")).strip() or "manual",
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(OBSERVATIONS_FILE, payload)
    return payload


def environment_list_observations(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    tag = str(args.get("tag", "")).strip().lower()
    kind = str(args.get("kind", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    items = _read_jsonl(OBSERVATIONS_FILE)
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    if kind:
        items = [item for item in items if str(item.get("kind", "")).lower() == kind]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(OBSERVATIONS_FILE), "count": len(items), "items": items[-limit:]}


def environment_search(args):
    query = str(args.get("query", "")).strip()
    if not query:
        raise ValueError("query is required")
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    context = _read_json(CONTEXT_FILE, {})
    observations = [item for item in _read_jsonl(OBSERVATIONS_FILE) if _matches(item, query)]
    return {
        "query": query,
        "contextMatches": _matches(context, query) if context else False,
        "currentContext": context if context and _matches(context, query) else None,
        "observationCount": len(observations),
        "observations": observations[-limit:],
    }


def environment_summary(args):
    observations = _read_jsonl(OBSERVATIONS_FILE)
    tags = {}
    kinds = {}
    for item in observations:
        kind = str(item.get("kind", "observation")) or "observation"
        kinds[kind] = kinds.get(kind, 0) + 1
        for tag in item.get("tags", []):
            tags[str(tag)] = tags.get(str(tag), 0) + 1
    return {
        "currentContext": _read_json(CONTEXT_FILE, {}),
        "observationCount": len(observations),
        "kinds": kinds,
        "tags": tags,
        "recentObservations": observations[-10:],
    }


TOOLS = {
    "environment_status": {
        "description": "[environment] Return environment hub status and counts.",
        "inputSchema": _object_schema(),
        "handler": environment_status,
    },
    "environment_set_context": {
        "description": "[environment] Set current manually provided environment context.",
        "inputSchema": _object_schema({"location": {"type": "string", "default": ""}, "room": {"type": "string", "default": ""}, "activity": {"type": "string", "default": ""}, "device": {"type": "string", "default": ""}, "bodyState": {"type": "string", "default": ""}, "weather": {"type": "string", "default": ""}, "ambient": {"type": "string", "default": ""}, "note": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}}),
        "handler": environment_set_context,
    },
    "environment_get_context": {
        "description": "[environment] Get current manually provided environment context.",
        "inputSchema": _object_schema(),
        "handler": environment_get_context,
    },
    "environment_append_observation": {
        "description": "[environment] Append an environment, device, body, or activity observation.",
        "inputSchema": _object_schema({"text": {"type": "string"}, "kind": {"type": "string", "default": "observation"}, "source": {"type": "string", "default": "manual"}, "tags": {"type": "array", "items": {"type": "string"}}}, ["text"]),
        "handler": environment_append_observation,
    },
    "environment_list_observations": {
        "description": "[environment] List environment observations with optional filters.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "kind": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": environment_list_observations,
    },
    "environment_search": {
        "description": "[environment] Keyword-search current context and observations.",
        "inputSchema": _object_schema({"query": {"type": "string"}, "limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}}, ["query"]),
        "handler": environment_search,
    },
    "environment_summary": {
        "description": "[environment] Summarize current context, observation kinds, tags, and recent observations.",
        "inputSchema": _object_schema(),
        "handler": environment_summary,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "environment-hub", "version": "1.0.0"}})
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
