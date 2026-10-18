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
    python tools/story_server.py --log x.log  # 把启动信息 / 报错写进文件（bat 里用这个）

★ 第七十七轮（续）：`--log` 是为「双击 bat 起不来、但最小化的窗口一闪就没了」加的 ——
  服务被 `start /min` 起来时，`sys.exit("端口起不来…")` 那句话根本没人看得见，
  用户只看到浏览器报「127.0.0.1 拒绝访问」。现在这些话都落进日志，bat 会把它打出来。

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
import socket
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


def port_in_use(host, port):
    """这个端口上已经有东西在听吗？

    ★ 第七十七轮（续）：**不能用「bind 失败」来判断占用** —— Windows 的
      `HTTPServer` 默认带 SO_REUSEADDR，而它在 Windows 上的语义是「允许绑到
      已经被占用的端口」：bind 会成功，两个进程同时监听同一个端口，
      请求落到谁手上不确定。所以先主动连一下，连得上就是有人在。
    """
    s = socket.socket()
    s.settimeout(0.25)
    try:
        s.connect((host, port))
        return True
    except OSError:
        return False
    finally:
        try:
            s.close()
        except OSError:
            pass


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


class Server(ThreadingHTTPServer):
    """把「客户端提前断开」这类噪声从日志里滤掉。

    ★ 第七十七轮（续）：浏览器切页 / curl 超时都会让写回线程抛
      ConnectionAbortedError，默认实现会把整段 traceback 打进日志 ——
      而日志是给人看「服务为什么没起来」的，被这种噪声刷屏就没用了。
    """

    daemon_threads = True

    def handle_error(self, request, client_address):
        exc = sys.exc_info()[1]
        if isinstance(exc, (ConnectionAbortedError, ConnectionResetError, BrokenPipeError)):
            return
        super().handle_error(request, client_address)


def main():
    ap = argparse.ArgumentParser(description="story.json 本地编辑服务")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--no-open", action="store_true", help="不自动开浏览器")
    ap.add_argument("--log", default="", help="把启动信息与报错写进这个文件（双击 bat 时用）")
    ap.add_argument("--auto-port", type=int, default=0,
                    help="主端口被占时，往后顺延几个端口试试（bat 里用 3）")
    args = ap.parse_args()

    # ★ 先把输出接进日志，**再**做可能失败的检查 —— 否则失败原因直接丢进关闭的窗口。
    # ★ 别用 `sys.exit("一句话")` 报错：那是靠解释器在退出时把它打到 sys.stderr 上，
    #   而这时日志文件可能还没被完整 flush —— 实测 `--log` 里一个字都留不下。
    #   统一走 die()：先写、先 flush、再退出。
    logf = None
    if args.log:
        try:
            logf = open(args.log, "w", encoding="utf-8", buffering=1)
            sys.stdout = logf
            sys.stderr = logf
        except OSError:
            logf = None

    def die(msg):
        print(msg)
        try:
            sys.stdout.flush()
            sys.stderr.flush()
        except Exception:
            pass
        sys.exit(1)

    def note(msg):
        print(msg)
        try:
            sys.stdout.flush()
        except Exception:
            pass

    if not os.path.exists(EDITOR):
        die("找不到编辑器：%s" % EDITOR)

    # 端口：主端口被占就往后顺延（最多 --auto-port 个）。
    # 每一行都写一条 `URL=`，bat 就靠它知道最终开哪个地址 ——
    # 顺延之后浏览器不能还去敲原来的端口。
    srv = None
    port = args.port
    for cand in range(args.port, args.port + max(0, args.auto_port) + 1):
        if port_in_use(args.host, cand):
            note("端口 %d 上已经有东西在听 —— 换下一个" % cand)
            continue
        try:
            srv = Server((args.host, cand), Handler)
            port = cand
            break
        except OSError as e:
            note("端口 %d 起不来（%s）—— 换下一个" % (cand, e))
            continue

    if srv is None:
        die("端口 %d~%d 全都不可用 —— 关掉占用它们的程序，或者用 --port 换一个"
            % (args.port, args.port + max(0, args.auto_port)))

    url = "http://%s:%d/" % (args.host, port)
    print("URL=%s" % url)          # ← bat 找的就是这一行
    note("story 编辑器：%s" % url)
    note("  读 / 写：%s" % STORY)
    note("  关掉这个窗口就停服务。Ctrl+C 也可以。")
    if not args.no_open:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        note("\n[story-server] 停止")
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()
