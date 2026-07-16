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
DATA_DIR = Path.home() / ".kelivo" / "game-hub"
GAMES_FILE = DATA_DIR / "games.json"
EVENTS_FILE = DATA_DIR / "events.jsonl"


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


def _read_games():
    if not GAMES_FILE.exists():
        return []
    try:
        with GAMES_FILE.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def _write_games(games):
    _ensure_dir()
    with GAMES_FILE.open("w", encoding="utf-8") as fh:
        json.dump(games, fh, ensure_ascii=False, indent=2)


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


def _find_game(games, game_id):
    for game in games:
        if game.get("id") == game_id:
            return game
    return None


def _matches(item, query):
    if not query:
        return True
    return query.lower() in json.dumps(item, ensure_ascii=False).lower()


def game_status(args):
    games = _read_games()
    return {
        "ok": True,
        "service": "game-hub",
        "dataDir": str(DATA_DIR),
        "games": len(games),
        "activeGames": len([g for g in games if g.get("status") == "active"]),
        "events": len(_read_jsonl(EVENTS_FILE)),
        "now": _now_iso(),
    }


def game_create(args):
    name = str(args.get("name", "")).strip()
    if not name:
        raise ValueError("name is required")
    game = {
        "id": str(uuid.uuid4()),
        "name": name,
        "kind": str(args.get("kind", "toy")).strip() or "toy",
        "status": "active",
        "scene": str(args.get("scene", "")).strip(),
        "rules": str(args.get("rules", "")).strip(),
        "resources": args.get("resources") if isinstance(args.get("resources"), dict) else {},
        "inventory": _string_list(args.get("inventory")),
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
        "updatedAt": _now_iso(),
    }
    games = _read_games()
    games.append(game)
    _write_games(games)
    return game


def game_list(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    status = str(args.get("status", "active")).strip().lower()
    query = str(args.get("query", "")).strip()
    games = _read_games()
    if status and status != "all":
        games = [game for game in games if str(game.get("status", "")).lower() == status]
    games = [game for game in games if _matches(game, query)]
    return {"file": str(GAMES_FILE), "count": len(games), "items": games[-limit:]}


def game_get(args):
    game_id = str(args.get("id", "")).strip()
    if not game_id:
        raise ValueError("id is required")
    game = _find_game(_read_games(), game_id)
    if not game:
        raise ValueError(f"game not found: {game_id}")
    events = [event for event in _read_jsonl(EVENTS_FILE) if event.get("gameId") == game_id]
    return {"game": game, "recentEvents": events[-20:]}


def game_update_state(args):
    game_id = str(args.get("id", "")).strip()
    if not game_id:
        raise ValueError("id is required")
    games = _read_games()
    game = _find_game(games, game_id)
    if not game:
        raise ValueError(f"game not found: {game_id}")
    for key in ["status", "scene", "rules"]:
        if key in args:
            game[key] = str(args.get(key, "")).strip()
    if isinstance(args.get("resources"), dict):
        game["resources"] = args["resources"]
    if "inventory" in args:
        game["inventory"] = _string_list(args.get("inventory"))
    game["updatedAt"] = _now_iso()
    _write_games(games)
    return game


def game_adjust_resource(args):
    game_id = str(args.get("id", "")).strip()
    name = str(args.get("name", "")).strip()
    if not game_id or not name:
        raise ValueError("id and name are required")
    delta = _limited_int(args.get("delta", 0), 0, -1000000, 1000000)
    games = _read_games()
    game = _find_game(games, game_id)
    if not game:
        raise ValueError(f"game not found: {game_id}")
    resources = game.setdefault("resources", {})
    current = _limited_int(resources.get(name, 0), 0, -1000000, 1000000)
    resources[name] = current + delta
    game["updatedAt"] = _now_iso()
    _write_games(games)
    return {"gameId": game_id, "name": name, "value": resources[name], "delta": delta, "resources": resources}


def game_append_event(args):
    game_id = str(args.get("gameId", "")).strip()
    text = str(args.get("text", "")).strip()
    if not game_id or not text:
        raise ValueError("gameId and text are required")
    event = {
        "id": str(uuid.uuid4()),
        "gameId": game_id,
        "kind": str(args.get("kind", "event")).strip() or "event",
        "text": text,
        "outcome": str(args.get("outcome", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(EVENTS_FILE, event)
    return event


def game_random_event(args):
    game_id = str(args.get("gameId", "")).strip()
    table = args.get("table")
    if not isinstance(table, list) or not table:
        table = [
            "A tiny lucky sign appears.",
            "Something unexpected shifts the mood.",
            "A quiet resource opportunity appears.",
            "A small obstacle asks for attention.",
        ]
    chosen = str(random.choice(table))
    event = {"chosen": chosen, "timestamp": _now_iso()}
    if game_id:
        event.update(game_append_event({"gameId": game_id, "text": chosen, "kind": "random"}))
    return event


def game_search_events(args):
    query = str(args.get("query", "")).strip()
    if not query:
        raise ValueError("query is required")
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    events = [event for event in _read_jsonl(EVENTS_FILE) if _matches(event, query)]
    return {"file": str(EVENTS_FILE), "query": query, "count": len(events), "items": events[-limit:]}


TOOLS = {
    "game_status": {
        "description": "[game] Return local game hub status and counts.",
        "inputSchema": _object_schema(),
        "handler": game_status,
    },
    "game_create": {
        "description": "[game] Create a lightweight companion toy/game state.",
        "inputSchema": _object_schema({"name": {"type": "string"}, "kind": {"type": "string", "default": "toy"}, "scene": {"type": "string", "default": ""}, "rules": {"type": "string", "default": ""}, "resources": {"type": "object"}, "inventory": {"type": "array", "items": {"type": "string"}}, "tags": {"type": "array", "items": {"type": "string"}}}, ["name"]),
        "handler": game_create,
    },
    "game_list": {
        "description": "[game] List lightweight games by status or query.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "status": {"type": "string", "default": "active"}, "query": {"type": "string", "default": ""}}),
        "handler": game_list,
    },
    "game_get": {
        "description": "[game] Get one game plus recent events.",
        "inputSchema": _object_schema({"id": {"type": "string"}}, ["id"]),
        "handler": game_get,
    },
    "game_update_state": {
        "description": "[game] Update scene, rules, status, resources, or inventory.",
        "inputSchema": _object_schema({"id": {"type": "string"}, "status": {"type": "string"}, "scene": {"type": "string"}, "rules": {"type": "string"}, "resources": {"type": "object"}, "inventory": {"type": "array", "items": {"type": "string"}}}, ["id"]),
        "handler": game_update_state,
    },
    "game_adjust_resource": {
        "description": "[game] Add or subtract a numeric game resource.",
        "inputSchema": _object_schema({"id": {"type": "string"}, "name": {"type": "string"}, "delta": {"type": "number", "default": 0}}, ["id", "name"]),
        "handler": game_adjust_resource,
    },
    "game_append_event": {
        "description": "[game] Append a game event or story beat.",
        "inputSchema": _object_schema({"gameId": {"type": "string"}, "text": {"type": "string"}, "kind": {"type": "string", "default": "event"}, "outcome": {"type": "string", "default": ""}, "tags": {"type": "array", "items": {"type": "string"}}}, ["gameId", "text"]),
        "handler": game_append_event,
    },
    "game_random_event": {
        "description": "[game] Pick a random event from a provided or default table, optionally logging it to a game.",
        "inputSchema": _object_schema({"gameId": {"type": "string", "default": ""}, "table": {"type": "array", "items": {"type": "string"}}}),
        "handler": game_random_event,
    },
    "game_search_events": {
        "description": "[game] Keyword-search game events.",
        "inputSchema": _object_schema({"query": {"type": "string"}, "limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}}, ["query"]),
        "handler": game_search_events,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "game-hub", "version": "1.0.0"}})
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
