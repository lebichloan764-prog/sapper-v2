#!/usr/bin/env python3
"""arena_stub.py — a local TSecBench-compatible arena so the sapper legion can
run without the Tencent platform.

Implements exactly the five endpoints lib/arena.py speaks:

    GET  /openapi/v1/challenges
    POST /openapi/v1/challenges/start?unique_code=CODE
    GET  /openapi/v1/challenges/hint?unique_code=CODE
    POST /openapi/v1/challenges/submit {unique_code, flag}
    POST /openapi/v1/challenges/close?unique_code=CODE

Targets come from targets.json next to this file:
  {"max_active": 3, "targets": [{"code","title","addr":[..],"budget_min",
                                 "accept_any":true,"flags":[..]}]}

State (active/closed/score) is kept in arena-state.json so restarts survive.
A submitted "flag" is a PROOF string (fork hash, tx hash, PASS line), not a
CTF flag — targets with accept_any score any submission as correct.
"""
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
TARGETS_PATH = os.path.join(HERE, "targets.json")
STATE_PATH = os.path.join(HERE, "arena-state.json")
TOKEN = os.environ.get("BENCHMARK_TOKEN", "local")


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return default


def atomic_write(path, payload):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def targets():
    return {t["code"]: t for t in load_json(TARGETS_PATH, {"targets": []})["targets"]}


def max_active():
    return int(load_json(TARGETS_PATH, {}).get("max_active", 3))


def state():
    st = load_json(STATE_PATH, {})
    st.setdefault("active", [])
    st.setdefault("closed", [])
    st.setdefault("score", {})
    st.setdefault("submitted", [])
    return st


def challenge_row(code, t, st):
    rec = st["score"].get(code) or {}
    return {
        "unique_code": code,
        "title": t.get("title", code),
        "difficulty": t.get("difficulty", "?"),
        "flag_count": int(t.get("flag_count", 1)),
        "correct_flag_count": int(rec.get("correct", 0)),
        "is_completed": code in st["closed"],
        "container_addr": t.get("addr", []),
        "budget_min": t.get("budget_min", 30),
        "note": t.get("note", ""),
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("[stub] %s - %s\n" % (self.address_string(), fmt % args))

    # -- helpers ---------------------------------------------------------
    def send_json(self, payload, status=200):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_err(self, status, code, message):
        self.send_json({"code": code, "message": message, "detail": {}}, status)

    def auth(self):
        if self.headers.get("BENCHMARK_TOKEN", "") != TOKEN:
            self.send_err(401, "unauthorized", "bad BENCHMARK_TOKEN")
            return False
        return True

    def read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception:
            return {}

    # -- routes ----------------------------------------------------------
    def do_GET(self):
        url = urlparse(self.path)
        st, tg = state(), targets()
        if url.path == "/openapi/v1/challenges":
            if not self.auth():
                return
            rows = [challenge_row(c, t, st) for c, t in tg.items()]
            return self.send_json(rows)
        if url.path == "/openapi/v1/challenges/hint":
            if not self.auth():
                return
            code = (parse_qs(url.query).get("unique_code") or [""])[0]
            t = tg.get(code)
            if not t:
                return self.send_err(404, "not_found", "unknown code %s" % code)
            return self.send_json({"unique_code": code, "hint": t.get("note", "")})
        if url.path in ("/health", "/"):
            return self.send_json({"ok": True, "targets": len(tg), "active": len(st["active"])})
        self.send_err(404, "not_found", self.path)

    def do_POST(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        st, tg = state(), targets()
        body = self.read_body()
        code = (q.get("unique_code") or [body.get("unique_code") or ""])[0]

        if url.path == "/openapi/v1/challenges/start":
            if not self.auth():
                return
            if code not in tg:
                return self.send_err(404, "not_found", "unknown code %s" % code)
            if code in st["closed"]:
                return self.send_err(409, "invalid_state", "challenge already closed")
            if code not in st["active"]:
                if len(st["active"]) >= max_active():
                    return self.send_err(409, "invalid_state", "max active")
                st["active"].append(code)
                atomic_write(STATE_PATH, st)
            return self.send_json({"unique_code": code, "container_addr": tg[code].get("addr", [])})

        if url.path == "/openapi/v1/challenges/submit":
            if not self.auth():
                return
            flag = str(body.get("flag") or "").strip()
            if code not in tg or not flag:
                return self.send_err(400, "bad_request", "need unique_code + flag")
            t = tg[code]
            rec = st["score"].setdefault(code, {"correct": 0, "submit": []})
            correct = True if t.get("accept_any") else flag in (t.get("flags") or [])
            if correct and flag not in rec["submit"]:
                rec["correct"] += 1
            rec["submit"].append({"flag": flag[:200], "correct": correct, "at": int(time.time())})
            st["submitted"].append({"code": code, "flag": flag[:200], "correct": correct,
                                    "at": int(time.time())})
            atomic_write(STATE_PATH, st)
            return self.send_json({"status": 200,
                                   "result": {"unique_code": code, "correct": correct,
                                              "correct_flag_count": rec["correct"]},
                                   "correct": correct,
                                   "correct_flag_count": rec["correct"]})

        if url.path == "/openapi/v1/challenges/close":
            if not self.auth():
                return
            if code not in tg:
                return self.send_err(404, "not_found", "unknown code %s" % code)
            if code in st["active"]:
                st["active"].remove(code)
            if code not in st["closed"]:
                st["closed"].append(code)
            atomic_write(STATE_PATH, st)
            return self.send_json({"unique_code": code, "closed": True})

        self.send_err(404, "not_found", self.path)


def main():
    port = int(os.environ.get("ARENA_PORT", "8899"))
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    sys.stderr.write("[stub] arena on 127.0.0.1:%d targets=%s\n"
                     % (port, ",".join(sorted(targets()))))
    srv.serve_forever()


if __name__ == "__main__":
    main()
