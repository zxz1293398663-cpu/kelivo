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
DATA_DIR = Path.home() / ".kelivo" / "media-hub"
MEDIA_FILE = DATA_DIR / "media_items.jsonl"
SESSIONS_FILE = DATA_DIR / "listening_sessions.jsonl"
MOODS_FILE = DATA_DIR / "mood_playlists.jsonl"
PLAYER_STATE_FILE = DATA_DIR / "player_state.json"
PLAYER_EVENTS_FILE = DATA_DIR / "player_events.jsonl"


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


def _read_json(path, default):
    if not path.exists():
        return default
    try:
        with path.open("r", encoding="utf-8") as fh:
            value = json.load(fh)
    except Exception:
        return default
    return value if isinstance(value, dict) else default


def _write_json(path, payload):
    _ensure_dir()
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    with tmp_path.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    tmp_path.replace(path)


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


def media_status(args):
    player_state = _read_json(PLAYER_STATE_FILE, {})
    return {
        "ok": True,
        "service": "media-hub",
        "dataDir": str(DATA_DIR),
        "mediaItems": len(_read_jsonl(MEDIA_FILE)),
        "listeningSessions": len(_read_jsonl(SESSIONS_FILE)),
        "moodPlaylists": len(_read_jsonl(MOODS_FILE)),
        "playerStateFile": str(PLAYER_STATE_FILE),
        "playerStateUpdatedAt": player_state.get("updatedAt", ""),
        "playerEvents": len(_read_jsonl(PLAYER_EVENTS_FILE)),
        "now": _now_iso(),
    }


def media_add_item(args):
    title = str(args.get("title", "")).strip()
    if not title:
        raise ValueError("title is required")
    payload = {
        "id": str(uuid.uuid4()),
        "kind": str(args.get("kind", "song")).strip() or "song",
        "title": title,
        "artist": str(args.get("artist", "")).strip(),
        "album": str(args.get("album", "")).strip(),
        "url": str(args.get("url", "")).strip(),
        "mood": str(args.get("mood", "")).strip(),
        "note": str(args.get("note", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
    }
    _append_jsonl(MEDIA_FILE, payload)
    return payload


def media_list_items(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    mood = str(args.get("mood", "")).strip().lower()
    tag = str(args.get("tag", "")).strip().lower()
    kind = str(args.get("kind", "")).strip().lower()
    query = str(args.get("query", "")).strip()
    items = _read_jsonl(MEDIA_FILE)
    if mood:
        items = [item for item in items if str(item.get("mood", "")).lower() == mood]
    if kind:
        items = [item for item in items if str(item.get("kind", "")).lower() == kind]
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(MEDIA_FILE), "count": len(items), "items": items[-limit:]}


def media_search(args):
    query = str(args.get("query", "")).strip()
    if not query:
        raise ValueError("query is required")
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    items = [item for item in _read_jsonl(MEDIA_FILE) if _matches(item, query)]
    sessions = [item for item in _read_jsonl(SESSIONS_FILE) if _matches(item, query)]
    return {"query": query, "mediaCount": len(items), "sessionCount": len(sessions), "media": items[-limit:], "sessions": sessions[-limit:]}


def media_record_listening_session(args):
    title = str(args.get("title", "")).strip()
    if not title:
        raise ValueError("title is required")
    payload = {
        "id": str(uuid.uuid4()),
        "title": title,
        "artist": str(args.get("artist", "")).strip(),
        "moodBefore": str(args.get("moodBefore", "")).strip(),
        "moodAfter": str(args.get("moodAfter", "")).strip(),
        "withCompanion": bool(args.get("withCompanion", True)),
        "note": str(args.get("note", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(SESSIONS_FILE, payload)
    return payload


def media_list_listening_sessions(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    query = str(args.get("query", "")).strip()
    tag = str(args.get("tag", "")).strip().lower()
    items = _read_jsonl(SESSIONS_FILE)
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(SESSIONS_FILE), "count": len(items), "items": items[-limit:]}


def media_save_mood_playlist(args):
    mood = str(args.get("mood", "")).strip()
    if not mood:
        raise ValueError("mood is required")
    payload = {
        "id": str(uuid.uuid4()),
        "mood": mood,
        "title": str(args.get("title", f"{mood} playlist")).strip() or f"{mood} playlist",
        "items": _string_list(args.get("items")),
        "note": str(args.get("note", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
    }
    _append_jsonl(MOODS_FILE, payload)
    return payload


def media_list_mood_playlists(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    mood = str(args.get("mood", "")).strip().lower()
    items = _read_jsonl(MOODS_FILE)
    if mood:
        items = [item for item in items if str(item.get("mood", "")).lower() == mood]
    return {"file": str(MOODS_FILE), "count": len(items), "items": items[-limit:]}


def _track_from_args(args):
    title = str(args.get("title", "")).strip()
    if not title:
        raise ValueError("title is required")
    return {
        "id": str(args.get("id", "")).strip() or str(uuid.uuid4()),
        "title": title,
        "artist": str(args.get("artist", "")).strip(),
        "album": str(args.get("album", "")).strip(),
        "url": str(args.get("url", "")).strip(),
        "coverUrl": str(args.get("coverUrl", "")).strip(),
        "durationSeconds": _limited_int(args.get("durationSeconds", 0), 0, 0, 24 * 60 * 60),
        "source": str(args.get("source", "media-hub")).strip() or "media-hub",
        "note": str(args.get("note", "")).strip(),
        "tags": _string_list(args.get("tags")),
    }


def _default_player_state():
    return {
        "schemaVersion": 1,
        "enabled": True,
        "status": "stopped",
        "positionSeconds": 0,
        "repeatMode": "off",
        "shuffle": False,
        "nowPlaying": None,
        "queue": [],
        "updatedAt": "",
    }


def _read_player_state():
    state = _default_player_state()
    state.update(_read_json(PLAYER_STATE_FILE, {}))
    queue = state.get("queue")
    state["queue"] = queue if isinstance(queue, list) else []
    return state


def _write_player_state(state):
    state["schemaVersion"] = 1
    state["updatedAt"] = _now_iso()
    _write_json(PLAYER_STATE_FILE, state)
    return {"file": str(PLAYER_STATE_FILE), "state": state}


def media_get_player_state(args):
    return {"file": str(PLAYER_STATE_FILE), "state": _read_player_state()}


def media_set_now_playing(args):
    state = _read_player_state()
    status = str(args.get("status", "playing")).strip().lower() or "playing"
    if status not in {"playing", "paused", "stopped"}:
        raise ValueError("status must be playing, paused, or stopped")
    track = _track_from_args(args)
    state["enabled"] = bool(args.get("enabled", state.get("enabled", True)))
    state["status"] = status
    state["positionSeconds"] = _limited_int(args.get("positionSeconds", 0), 0, 0, 24 * 60 * 60)
    state["nowPlaying"] = track
    if bool(args.get("appendToQueue", False)):
        state["queue"].append(track)
    return _write_player_state(state)


def media_update_player_state(args):
    state = _read_player_state()
    if "status" in args:
        status = str(args.get("status", "")).strip().lower()
        if status not in {"playing", "paused", "stopped"}:
            raise ValueError("status must be playing, paused, or stopped")
        state["status"] = status
    if "positionSeconds" in args:
        state["positionSeconds"] = _limited_int(args.get("positionSeconds"), 0, 0, 24 * 60 * 60)
    if "repeatMode" in args:
        repeat_mode = str(args.get("repeatMode", "off")).strip().lower() or "off"
        if repeat_mode not in {"off", "one", "all"}:
            raise ValueError("repeatMode must be off, one, or all")
        state["repeatMode"] = repeat_mode
    if "shuffle" in args:
        state["shuffle"] = bool(args.get("shuffle"))
    if "enabled" in args:
        state["enabled"] = bool(args.get("enabled"))
    return _write_player_state(state)


def media_add_to_player_queue(args):
    state = _read_player_state()
    track = _track_from_args(args)
    state["queue"].append(track)
    if state.get("nowPlaying") is None and bool(args.get("playIfIdle", False)):
        state["nowPlaying"] = track
        state["status"] = "playing"
    return _write_player_state(state)


def media_clear_player_queue(args):
    state = _read_player_state()
    state["queue"] = []
    if bool(args.get("stop", False)):
        state["status"] = "stopped"
        state["positionSeconds"] = 0
        state["nowPlaying"] = None
    return _write_player_state(state)


def media_record_player_event(args):
    event = str(args.get("event", "")).strip()
    if not event:
        raise ValueError("event is required")
    payload = {
        "id": str(uuid.uuid4()),
        "event": event,
        "title": str(args.get("title", "")).strip(),
        "artist": str(args.get("artist", "")).strip(),
        "positionSeconds": _limited_int(args.get("positionSeconds", 0), 0, 0, 24 * 60 * 60),
        "note": str(args.get("note", "")).strip(),
        "timestamp": _now_iso(),
    }
    _append_jsonl(PLAYER_EVENTS_FILE, payload)
    return {"file": str(PLAYER_EVENTS_FILE), "event": payload}


def media_open_player_context(args):
    limit = _limited_int(args.get("limit", 10), 10, 1, 50)
    return {
        "dataDir": str(DATA_DIR),
        "playerStateFile": str(PLAYER_STATE_FILE),
        "eventFile": str(PLAYER_EVENTS_FILE),
        "state": _read_player_state(),
        "recentEvents": _read_jsonl(PLAYER_EVENTS_FILE)[-limit:],
    }


TOOLS = {
    "media_status": {
        "description": "[media] Return local media hub counts and storage path.",
        "inputSchema": _object_schema(),
        "handler": media_status,
    },
    "media_add_item": {
        "description": "[media] Add a song, album, playlist, video, or other media reference.",
        "inputSchema": _object_schema({"title": {"type": "string"}, "kind": {"type": "string", "default": "song"}, "artist": {"type": "string", "default": ""}, "album": {"type": "string", "default": ""}, "url": {"type": "string", "default": ""}, "mood": {"type": "string", "default": ""}, "note": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}}, ["title"]),
        "handler": media_add_item,
    },
    "media_list_items": {
        "description": "[media] List media references by mood, kind, tag, or query.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "mood": {"type": "string", "default": ""}, "kind": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": media_list_items,
    },
    "media_search": {
        "description": "[media] Keyword-search media references and listening sessions.",
        "inputSchema": _object_schema({"query": {"type": "string"}, "limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}}, ["query"]),
        "handler": media_search,
    },
    "media_record_listening_session": {
        "description": "[media] Record a listening session or shared media moment.",
        "inputSchema": _object_schema({"title": {"type": "string"}, "artist": {"type": "string", "default": ""}, "moodBefore": {"type": "string", "default": ""}, "moodAfter": {"type": "string", "default": ""}, "withCompanion": {"type": "boolean", "default": True}, "note": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}}, ["title"]),
        "handler": media_record_listening_session,
    },
    "media_list_listening_sessions": {
        "description": "[media] List shared listening sessions.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "query": {"type": "string", "default": ""}, "tag": {"type": "string", "default": ""}}),
        "handler": media_list_listening_sessions,
    },
    "media_save_mood_playlist": {
        "description": "[media] Save a mood playlist note with track names or references.",
        "inputSchema": _object_schema({"mood": {"type": "string"}, "title": {"type": "string", "default": ""}, "items": {"type": "array", "items": {"type": "string"}}, "note": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}}, ["mood"]),
        "handler": media_save_mood_playlist,
    },
    "media_list_mood_playlists": {
        "description": "[media] List saved mood playlists.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "mood": {"type": "string", "default": ""}}),
        "handler": media_list_mood_playlists,
    },
    "media_get_player_state": {
        "description": "[media] Read the local player bridge state for Kelivo's NetEase-style player.",
        "inputSchema": _object_schema(),
        "handler": media_get_player_state,
    },
    "media_set_now_playing": {
        "description": "[media] Set the current track in player_state.json for the local player bridge.",
        "inputSchema": _object_schema({"title": {"type": "string"}, "artist": {"type": "string", "default": ""}, "album": {"type": "string", "default": ""}, "url": {"type": "string", "default": ""}, "coverUrl": {"type": "string", "default": ""}, "durationSeconds": {"type": "number", "default": 0, "minimum": 0}, "positionSeconds": {"type": "number", "default": 0, "minimum": 0}, "status": {"type": "string", "default": "playing"}, "source": {"type": "string", "default": "media-hub"}, "note": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}, "appendToQueue": {"type": "boolean", "default": False}, "enabled": {"type": "boolean", "default": True}}, ["title"]),
        "handler": media_set_now_playing,
    },
    "media_update_player_state": {
        "description": "[media] Update playback flags such as status, position, repeat, shuffle, or bridge enabled state.",
        "inputSchema": _object_schema({"status": {"type": "string"}, "positionSeconds": {"type": "number", "minimum": 0}, "repeatMode": {"type": "string"}, "shuffle": {"type": "boolean"}, "enabled": {"type": "boolean"}}),
        "handler": media_update_player_state,
    },
    "media_add_to_player_queue": {
        "description": "[media] Append a track to the local player bridge queue.",
        "inputSchema": _object_schema({"title": {"type": "string"}, "artist": {"type": "string", "default": ""}, "album": {"type": "string", "default": ""}, "url": {"type": "string", "default": ""}, "coverUrl": {"type": "string", "default": ""}, "durationSeconds": {"type": "number", "default": 0, "minimum": 0}, "source": {"type": "string", "default": "media-hub"}, "note": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}, "playIfIdle": {"type": "boolean", "default": False}}, ["title"]),
        "handler": media_add_to_player_queue,
    },
    "media_clear_player_queue": {
        "description": "[media] Clear the local player bridge queue and optionally stop playback.",
        "inputSchema": _object_schema({"stop": {"type": "boolean", "default": False}}),
        "handler": media_clear_player_queue,
    },
    "media_record_player_event": {
        "description": "[media] Append a player event such as play, pause, skip, favorite, or finish.",
        "inputSchema": _object_schema({"event": {"type": "string"}, "title": {"type": "string", "default": ""}, "artist": {"type": "string", "default": ""}, "positionSeconds": {"type": "number", "default": 0, "minimum": 0}, "note": {"type": "string", "default": ""}}, ["event"]),
        "handler": media_record_player_event,
    },
    "media_open_player_context": {
        "description": "[media] Return bridge file paths, current player state, and recent player events.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 10, "minimum": 1, "maximum": 50}}),
        "handler": media_open_player_context,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "media-hub", "version": "1.0.0"}})
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
