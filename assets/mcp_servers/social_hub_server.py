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
DATA_DIR = Path.home() / ".kelivo" / "social-hub"
POSTS_FILE = DATA_DIR / "posts.jsonl"
COMMENTS_FILE = DATA_DIR / "comments.jsonl"
VISITS_FILE = DATA_DIR / "visits.jsonl"
DRAFTS_FILE = DATA_DIR / "moment_drafts.jsonl"


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


def _filter_items(path, args):
    limit = _limited_int(args.get("limit", 50), 50, 1, 200)
    query = str(args.get("query", "")).strip()
    tag = str(args.get("tag", "")).strip().lower()
    actor = str(args.get("actor", "")).strip().lower()
    items = _read_jsonl(path)
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    if actor:
        items = [item for item in items if str(item.get("actor", "")).lower() == actor]
    items = [item for item in items if _matches(item, query)]
    return {"file": str(path), "count": len(items), "items": items[-limit:]}


def _post_exists(post_id):
    if not post_id:
        return False
    return any(item.get("id") == post_id for item in _read_jsonl(POSTS_FILE))


def social_status(args):
    return {
        "ok": True,
        "service": "social-hub",
        "dataDir": str(DATA_DIR),
        "posts": len(_read_jsonl(POSTS_FILE)),
        "comments": len(_read_jsonl(COMMENTS_FILE)),
        "visits": len(_read_jsonl(VISITS_FILE)),
        "drafts": len(_read_jsonl(DRAFTS_FILE)),
        "now": _now_iso(),
    }


def social_add_post(args):
    text = str(args.get("text", "")).strip()
    if not text:
        raise ValueError("text is required")
    payload = {
        "id": str(uuid.uuid4()),
        "actor": str(args.get("actor", "companion")).strip() or "companion",
        "text": text,
        "mood": str(args.get("mood", "")).strip(),
        "visibility": str(args.get("visibility", "private")).strip() or "private",
        "attachments": _string_list(args.get("attachments")),
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
    }
    _append_jsonl(POSTS_FILE, payload)
    return payload


def social_list_posts(args):
    result = _filter_items(POSTS_FILE, args)
    mood = str(args.get("mood", "")).strip().lower()
    if mood:
        items = [item for item in result["items"] if str(item.get("mood", "")).lower() == mood]
        result = {**result, "count": len(items), "items": items}
    return result


def social_add_comment(args):
    post_id = str(args.get("postId", "")).strip()
    text = str(args.get("text", "")).strip()
    if not post_id or not text:
        raise ValueError("postId and text are required")
    if not _post_exists(post_id):
        raise ValueError("postId was not found")
    payload = {
        "id": str(uuid.uuid4()),
        "postId": post_id,
        "actor": str(args.get("actor", "user")).strip() or "user",
        "text": text,
        "mood": str(args.get("mood", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
    }
    _append_jsonl(COMMENTS_FILE, payload)
    return payload


def social_list_comments(args):
    result = _filter_items(COMMENTS_FILE, args)
    post_id = str(args.get("postId", "")).strip()
    if post_id:
        items = [item for item in result["items"] if item.get("postId") == post_id]
        result = {**result, "count": len(items), "items": items}
    return result


def social_record_visit(args):
    actor = str(args.get("actor", "")).strip()
    if not actor:
        raise ValueError("actor is required")
    payload = {
        "id": str(uuid.uuid4()),
        "actor": actor,
        "place": str(args.get("place", "timeline")).strip() or "timeline",
        "action": str(args.get("action", "visit")).strip() or "visit",
        "note": str(args.get("note", "")).strip(),
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
    }
    _append_jsonl(VISITS_FILE, payload)
    return payload


def social_list_visits(args):
    return _filter_items(VISITS_FILE, args)


def social_generate_moment_draft(args):
    seed = str(args.get("seed", "")).strip()
    if not seed:
        raise ValueError("seed is required")
    mood = str(args.get("mood", "")).strip()
    actor = str(args.get("actor", "companion")).strip() or "companion"
    text = str(args.get("text", "")).strip()
    if not text:
        prefix = f"{actor}"
        mood_part = f" feels {mood}" if mood else " shares a quiet moment"
        text = f"{prefix}{mood_part}: {seed}"
    payload = {
        "id": str(uuid.uuid4()),
        "actor": actor,
        "seed": seed,
        "text": text,
        "mood": mood,
        "status": "draft",
        "tags": _string_list(args.get("tags")),
        "createdAt": _now_iso(),
    }
    _append_jsonl(DRAFTS_FILE, payload)
    return payload


def social_list_moment_drafts(args):
    return _filter_items(DRAFTS_FILE, args)


def social_timeline(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 100)
    items = []
    for item in _read_jsonl(POSTS_FILE):
        items.append({**item, "kind": "post"})
    for item in _read_jsonl(COMMENTS_FILE):
        items.append({**item, "kind": "comment"})
    for item in _read_jsonl(VISITS_FILE):
        items.append({**item, "kind": "visit"})
    for item in _read_jsonl(DRAFTS_FILE):
        items.append({**item, "kind": "draft"})
    items.sort(key=lambda item: str(item.get("createdAt", "")))
    return {"count": len(items), "items": items[-limit:]}


def social_summary(args):
    limit = _limited_int(args.get("limit", 10), 10, 1, 50)
    return {
        "posts": _read_jsonl(POSTS_FILE)[-limit:],
        "comments": _read_jsonl(COMMENTS_FILE)[-limit:],
        "visits": _read_jsonl(VISITS_FILE)[-limit:],
        "drafts": _read_jsonl(DRAFTS_FILE)[-limit:],
    }


SOCIAL_ACTIONS = {
    "status": social_status,
    "add_post": social_add_post,
    "list_posts": social_list_posts,
    "add_comment": social_add_comment,
    "list_comments": social_list_comments,
    "record_visit": social_record_visit,
    "list_visits": social_list_visits,
    "generate_moment_draft": social_generate_moment_draft,
    "list_moment_drafts": social_list_moment_drafts,
    "timeline": social_timeline,
    "summary": social_summary,
}


def social_run(args):
    action = str(args.get("action", "")).strip()
    if action not in SOCIAL_ACTIONS:
        raise ValueError(f"unknown action: {action}")
    payload = args.get("payload") or {}
    if not isinstance(payload, dict):
        raise ValueError("payload must be an object")
    return SOCIAL_ACTIONS[action](payload)


TOOLS = {
    "social_run": {
        "description": "[social] Compact social hub dispatcher. Actions: status, add_post, list_posts, add_comment, list_comments, record_visit, list_visits, generate_moment_draft, list_moment_drafts, timeline, summary.",
        "inputSchema": _object_schema({"action": {"type": "string"}, "payload": {"type": "object"}}, ["action"]),
        "handler": social_run,
    },
}


def handle(request):
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}
    if method == "initialize":
        client_version = params.get("protocolVersion")
        protocol_version = client_version if client_version in SUPPORTED_PROTOCOL_VERSIONS else DEFAULT_PROTOCOL_VERSION
        return _write_result(request_id, {"protocolVersion": protocol_version, "capabilities": {"tools": {}}, "serverInfo": {"name": "social-hub", "version": "1.0.0"}})
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
