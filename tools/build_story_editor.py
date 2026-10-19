#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
把 data/story.json 内嵌进 tools/story_editor.html 的「内置快照」区。

为什么需要内置快照：
    编辑器可以直接用浏览器的 File System Access API 就地读写 data/story.json，
    但如果只是双击打开 HTML（file://），浏览器多半不让 fetch 本地文件。
    这时候页面上仍要有一份可用数据 —— 就是这段快照。

用法：
    python tools/build_story_editor.py

改完 story.json 后跑一次，快照就跟上了。游戏本身读的始终是 data/story.json，
快照只影响「编辑器首次打开时看到的内容」。
"""

import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
STORY = os.path.join(ROOT, "data", "story.json")
EDITOR = os.path.join(HERE, "story_editor.html")

BEGIN = "<!--STORY_DATA_BEGIN-->"
END = "<!--STORY_DATA_END-->"


def main():
    if not os.path.exists(STORY):
        sys.exit("找不到 %s —— 先跑 tools/DumpStory.tscn 生成它" % STORY)
    if not os.path.exists(EDITOR):
        sys.exit("找不到 %s" % EDITOR)

    with io.open(STORY, encoding="utf-8") as f:
        raw = f.read()

    # 先确认它真的是合法 JSON，别把坏数据塞进页面
    try:
        data = json.loads(raw)
    except ValueError as e:
        sys.exit("data/story.json 不是合法 JSON：%s" % e)

    for key in ("backgrounds", "traits"):
        if not data.get(key):
            sys.exit("data/story.json 缺少 %s" % key)

    # 内嵌时要压掉缩进（页面里不需要好看），并转义 < 免得提前闭合 script 标签
    compact = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    compact = compact.replace("<", "\\u003c")

    with io.open(EDITOR, encoding="utf-8") as f:
        html = f.read()

    i = html.find(BEGIN)
    j = html.find(END)
    if i < 0 or j < 0 or j < i:
        sys.exit("story_editor.html 里找不到 %s / %s 标记" % (BEGIN, END))

    block = (
        BEGIN
        + '\n<script id="seed" type="application/json">'
        + compact
        + "</script>\n"
        + END
    )
    out = html[:i] + block + html[j + len(END):]

    with io.open(EDITOR, "w", encoding="utf-8") as f:
        f.write(out)

    # ★ 第九十二轮：`item_desc` 随「外貌情报」删掉了，这里不再统计它。
    print(
        "已内嵌快照：%d 套背景 / %d 种性情（JSON %d 字节 → 页面 %d 字节）"
        % (
            len(data.get("backgrounds") or []),
            len(data.get("traits") or []),
            len(compact),
            len(out),
        )
    )


if __name__ == "__main__":
    main()
