#!/usr/bin/env python3
import hashlib
import json
import re
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
DATA_DIR = Path.home() / ".kelivo" / "reading-hub"
DOCS_DIR = DATA_DIR / "documents"
INDEX_FILE = DATA_DIR / "documents.jsonl"
NOTES_FILE = DATA_DIR / "reading_notes.jsonl"
DEFAULT_CHUNK_SIZE = 1800


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


def _ensure_dirs():
    DOCS_DIR.mkdir(parents=True, exist_ok=True)


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _append_jsonl(path, payload):
    _ensure_dirs()
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


def _write_jsonl(path, items):
    _ensure_dirs()
    with path.open("w", encoding="utf-8") as fh:
        for item in items:
            fh.write(json.dumps(item, ensure_ascii=False))
            fh.write("\n")


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


def _slug(text):
    text = re.sub(r"[^a-zA-Z0-9_-]+", "-", text.strip().lower()).strip("-")
    return text[:64] or "document"


def _doc_path(doc_id):
    return DOCS_DIR / f"{doc_id}.txt"


def _load_doc(doc_id):
    path = _doc_path(doc_id)
    if not path.exists():
        raise ValueError(f"document not found: {doc_id}")
    return path.read_text(encoding="utf-8")


def _find_doc(doc_id):
    for item in _read_jsonl(INDEX_FILE):
        if item.get("id") == doc_id:
            return item
    return None


def _chunk_text(text, chunk_size):
    chunks = []
    start = 0
    while start < len(text):
        end = min(len(text), start + chunk_size)
        if end < len(text):
            split = max(text.rfind("\n", start, end), text.rfind("。", start, end), text.rfind(".", start, end))
            if split > start + chunk_size // 2:
                end = split + 1
        chunks.append(text[start:end].strip())
        start = end
    return [chunk for chunk in chunks if chunk]


def reading_status(args):
    return {
        "ok": True,
        "service": "reading-hub",
        "dataDir": str(DATA_DIR),
        "documents": len(_read_jsonl(INDEX_FILE)),
        "notes": len(_read_jsonl(NOTES_FILE)),
        "now": _now_iso(),
    }


def reading_import_text(args):
    title = str(args.get("title", "")).strip()
    text = str(args.get("text", ""))
    if not title:
        raise ValueError("title is required")
    if not text.strip():
        raise ValueError("text is required")
    source = str(args.get("source", "manual")).strip() or "manual"
    tags = _string_list(args.get("tags"))
    digest = hashlib.sha256(f"{title}\n{text}".encode("utf-8")).hexdigest()[:16]
    doc_id = f"{_slug(title)}-{digest}"
    _ensure_dirs()
    _doc_path(doc_id).write_text(text, encoding="utf-8")
    docs = [item for item in _read_jsonl(INDEX_FILE) if item.get("id") != doc_id]
    chunks = _chunk_text(text, DEFAULT_CHUNK_SIZE)
    item = {
        "id": doc_id,
        "title": title,
        "source": source,
        "tags": tags,
        "chars": len(text),
        "chunks": len(chunks),
        "createdAt": _now_iso(),
    }
    docs.append(item)
    _write_jsonl(INDEX_FILE, docs)
    return item


def reading_list_documents(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    tag = str(args.get("tag", "")).strip().lower()
    query = str(args.get("query", "")).strip().lower()
    items = _read_jsonl(INDEX_FILE)
    if tag:
        items = [item for item in items if tag in [str(t).lower() for t in item.get("tags", [])]]
    if query:
        items = [item for item in items if query in json.dumps(item, ensure_ascii=False).lower()]
    return {"file": str(INDEX_FILE), "count": len(items), "items": items[-limit:]}


def reading_get_chunk(args):
    doc_id = str(args.get("docId", "")).strip()
    if not doc_id:
        raise ValueError("docId is required")
    chunk_index = _limited_int(args.get("chunkIndex", 0), 0, 0, 100000)
    chunk_size = _limited_int(args.get("chunkSize", DEFAULT_CHUNK_SIZE), DEFAULT_CHUNK_SIZE, 300, 6000)
    text = _load_doc(doc_id)
    chunks = _chunk_text(text, chunk_size)
    if chunk_index >= len(chunks):
        raise ValueError(f"chunkIndex out of range: {chunk_index} >= {len(chunks)}")
    return {
        "docId": doc_id,
        "title": (_find_doc(doc_id) or {}).get("title"),
        "chunkIndex": chunk_index,
        "chunkCount": len(chunks),
        "text": chunks[chunk_index],
    }


def reading_append_note(args):
    doc_id = str(args.get("docId", "")).strip()
    note = str(args.get("note", "")).strip()
    if not note:
        raise ValueError("note is required")
    chunk_index = args.get("chunkIndex")
    payload = {
        "kind": "reading_note",
        "docId": doc_id,
        "title": (_find_doc(doc_id) or {}).get("title") if doc_id else None,
        "chunkIndex": int(chunk_index) if chunk_index is not None else None,
        "note": note,
        "tags": _string_list(args.get("tags")),
        "timestamp": _now_iso(),
    }
    _append_jsonl(NOTES_FILE, payload)
    return payload


def reading_list_notes(args):
    limit = _limited_int(args.get("limit", 20), 20, 1, 200)
    doc_id = str(args.get("docId", "")).strip()
    query = str(args.get("query", "")).strip().lower()
    items = _read_jsonl(NOTES_FILE)
    if doc_id:
        items = [item for item in items if item.get("docId") == doc_id]
    if query:
        items = [item for item in items if query in json.dumps(item, ensure_ascii=False).lower()]
    return {"file": str(NOTES_FILE), "count": len(items), "items": items[-limit:]}


def reading_search(args):
    query = str(args.get("query", "")).strip()
    if not query:
        raise ValueError("query is required")
    limit = _limited_int(args.get("limit", 10), 10, 1, 50)
    query_lower = query.lower()
    results = []
    for doc in _read_jsonl(INDEX_FILE):
        text = _load_doc(doc["id"])
        position = text.lower().find(query_lower)
        if position < 0:
            continue
        start = max(0, position - 180)
        end = min(len(text), position + len(query) + 180)
        results.append({"docId": doc["id"], "title": doc.get("title"), "position": position, "snippet": text[start:end]})
        if len(results) >= limit:
            break
    return {"query": query, "count": len(results), "items": results}


TOOLS = {
    "reading_status": {
        "description": "[reading] Return reading hub status and storage counts.",
        "inputSchema": _object_schema(),
        "handler": reading_status,
    },
    "reading_import_text": {
        "description": "[reading] Import a plain text document into local reading storage.",
        "inputSchema": _object_schema({"title": {"type": "string"}, "text": {"type": "string"}, "source": {"type": "string", "default": "manual"}, "tags": {"type": "array", "items": {"type": "string"}}}, ["title", "text"]),
        "handler": reading_import_text,
    },
    "reading_list_documents": {
        "description": "[reading] List imported documents, optionally filtered by tag or query.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "tag": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": reading_list_documents,
    },
    "reading_get_chunk": {
        "description": "[reading] Read one chunk from an imported document.",
        "inputSchema": _object_schema({"docId": {"type": "string"}, "chunkIndex": {"type": "number", "default": 0}, "chunkSize": {"type": "number", "default": DEFAULT_CHUNK_SIZE}}, ["docId"]),
        "handler": reading_get_chunk,
    },
    "reading_append_note": {
        "description": "[reading] Append a reading note linked to a document or chunk.",
        "inputSchema": _object_schema({"docId": {"type": "string", "default": ""}, "chunkIndex": {"type": "number"}, "note": {"type": "string"}, "tags": {"type": "array", "items": {"type": "string"}}}, ["note"]),
        "handler": reading_append_note,
    },
    "reading_list_notes": {
        "description": "[reading] List or search reading notes.",
        "inputSchema": _object_schema({"limit": {"type": "number", "default": 20, "minimum": 1, "maximum": 200}, "docId": {"type": "string", "default": ""}, "query": {"type": "string", "default": ""}}),
        "handler": reading_list_notes,
    },
    "reading_search": {
        "description": "[reading] Keyword-search imported documents and return snippets.",
        "inputSchema": _object_schema({"query": {"type": "string"}, "limit": {"type": "number", "default": 10, "minimum": 1, "maximum": 50}}, ["query"]),
        "handler": reading_search,
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
                "serverInfo": {"name": "reading-hub", "version": "1.0.0"},
            },
        )
    if method == "notifications/initialized":
        return None
    if method == "tools/list":
        return _write_result(
            request_id,
            {
                "tools": [
                    {"name": name, "description": meta["description"], "inputSchema": meta["inputSchema"]}
                    for name, meta in TOOLS.items()
                ]
            },
        )
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
