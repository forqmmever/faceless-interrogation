#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
本地编辑服务：让 tools/story_editor.html **直接读写 data/story.json**。

为什么必须有它：
    浏览器不许网页写本地磁盘 —— `file://` 下连 fetch 都被拦，
    `showSaveFilePicker` 只能让用户手挑文件、也指定不了「就写 data/story.json」。
    所以「编辑器直接编辑那个文件」只能靠一个本地小服务：页面从它读、往它写。

用法：
    python tools/story_server.py              # 127.0.0.1:8765，并自动开浏览器
    python tools/story_server.py --no-open    # 只起服务（bat 里用这个）
    python tools/story_server.py --port 9000

接口：
    GET  /             → tools/story_editor.html（不缓存）
    GET  /api/story    → data/story.json 原文；文件不存在时 404
    POST /api/story    → 校验后覆盖写入 data/story.json（旧版备份为 story.json.bak）
    其他路径           → 以项目根为根目录的静态文件（图标之类）

★ 写入是「先写临时文件再 os.replace」——中途断电也不会留下半截 json。
★ 只监听 127.0.0.1，不对外网开放。
"""

import argparse
import io
import json
import os
import shutil
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
STORY = os.path.join(ROOT, "data", "story.json")
STORY_BAK = STORY + ".bak"
EDITOR = os.path.join(HERE, "story_editor.html")

DEFAULT_PORT = 8765


def read_story_bytes():
    with open(STORY, "rb") as f:
        return f.read()


def write_story_bytes(raw):
    """原子写入：临时文件 → os.replace。返回 (字节数, 是否生成了备份)。"""
    made_bak = False
    if os.path.exists(STORY):
        shutil.copyfile(STORY, STORY_BAK)
        made_bak = True
    tmp = STORY + ".tmp"
    with open(tmp, "wb") as f:
        f.write(raw)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, STORY)
    return len(raw), made_bak


class Handler(BaseHTTPRequestHandler):
    server_version = "FacelessStoryEditor/1.0"

    # 只打一行日志，别把控制台刷满
    def log_message(self, fmt, *args):
        sys.stderr.write("[story-server] " + (fmt % args) + "\n")

    # ---------- 工具 ----------
    def _send(self, code, body=b"", ctype="application/json; charset=utf-8", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"))

    # ---------- GET ----------
    def do_GET(self):
        path = self.path.split("?", 1)[0]

        if path in ("/", "/index.html"):
            try:
                with open(EDITOR, "rb") as f:
                    raw = f.read()
            except OSError as e:
                self._send(500, ("读不到编辑器：%s" % e).encode("utf-8"), "text/plain; charset=utf-8")
                return
            self._send(200, raw, "text/html; charset=utf-8")
            return

        if path == "/api/story":
            if not os.path.exists(STORY):
                self._json(404, {"ok": False, "error": "找不到 data/story.json"})
                return
            try:
                raw = read_story_bytes()
            except OSError as e:
                self._json(500, {"ok": False, "error": str(e)})
                return
            self._send(200, raw)
            return

        # 静态文件（限定在项目根内，防目录穿越）
        rel = path.lstrip("/")
        target = os.path.normpath(os.path.join(ROOT, rel))
        if not target.startswith(ROOT) or not os.path.isfile(target):
            self._json(404, {"ok": False, "error": "not found: " + path})
            return
        ext = os.path.splitext(target)[1].lower()
        ctype = {
            ".html": "text/html; charset=utf-8",
            ".js": "text/javascript; charset=utf-8",
            ".css": "text/css; charset=utf-8",
            ".json": "application/json; charset=utf-8",
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".svg": "image/svg+xml",
            ".webp": "image/webp",
        }.get(ext, "application/octet-stream")
        with open(target, "rb") as f:
            self._send(200, f.read(), ctype)

    # ---------- POST ----------
    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path != "/api/story":
            self._json(404, {"ok": False, "error": "not found: " + path})
            return

        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        if length <= 0:
            self._json(400, {"ok": False, "error": "空请求体"})
            return

        raw = self.rfile.read(length)

        # ① 必须是合法 JSON
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as e:
            self._json(400, {"ok": False, "error": "不是 UTF-8：%s" % e})
            return
        try:
            obj = json.loads(text)
        except Exception as e:
            self._json(400, {"ok": False, "error": "JSON 解析失败：%s" % e})
            return

        # ② 结构守卫：没有 backgrounds 就拒收（防手滑把整份数据写废）
        if not isinstance(obj, dict) or not isinstance(obj.get("backgrounds"), list):
            self._json(400, {"ok": False, "error": "缺少 backgrounds 数组 —— 拒收（防止把数据写废）"})
            return
        if not obj["backgrounds"]:
            self._json(400, {"ok": False, "error": "backgrounds 是空的 —— 拒收"})
            return

        # ③ 统一成 LF（仓库里 story.json 就是 LF），补一个结尾换行
        text = text.replace("\r\n", "\n")
        if not text.endswith("\n"):
            text += "\n"

        try:
            n, made_bak = write_story_bytes(text.encode("utf-8"))
        except OSError as e:
            self._json(500, {"ok": False, "error": "写盘失败：%s" % e})
            return

        self._json(200, {"ok": True, "bytes": n, "backup": made_bak,
                         "backgrounds": len(obj["backgrounds"])})


def main():
    ap = argparse.ArgumentParser(description="story.json 本地编辑服务")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--no-open", action="store_true", help="不自动开浏览器")
    args = ap.parse_args()

    if not os.path.exists(EDITOR):
        sys.exit("找不到编辑器：%s" % EDITOR)

    try:
        srv = ThreadingHTTPServer((args.host, args.port), Handler)
    except OSError as e:
        sys.exit("端口 %d 起不来（%s）—— 可能已经有一个在跑了，或者换 --port" % (args.port, e))

    url = "http://%s:%d/" % (args.host, args.port)
    print("story 编辑器：%s" % url)
    print("  读 / 写：%s" % STORY)
    print("  关掉这个窗口就停服务。Ctrl+C 也可以。")
    if not args.no_open:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[story-server] 停止")
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()
