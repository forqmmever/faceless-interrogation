# -*- coding: utf-8 -*-
"""README 体检：找出「会随轮次膨胀」和「已经过期」的东西。

为什么要有这个脚本（第 96 轮）：
    `交接.md` 烂掉 37 轮没人发现的根因不是写得差，是**写完就没有第二次写入**。
    README 正在走同一条路（6253 行 / 434 KB）。解法不是「以后小心点」，
    是给它一个**每轮能跑、跑完给结论**的检查节点。

用法：
    python tools/readme_check.py            # 出报告
    python tools/readme_check.py --strict   # 有问题就退出码 1（给 CI / 收尾流程用）

检查五件事：
    1. 带「第 N 轮」字样的小节  —— 逐轮历史属于 CHANGELOG，不属于 README
    2. 单节行数超预算           —— 一节超过 250 行说明它没被组织过
    3. 假标题                   —— 代码块围栏坏了，`# 注释` 会被当成一级标题
    4. 断言数字过期             —— 与 CHANGELOG 末尾测试表的最后一行比对
    5. 总量                     —— 行数 / 字符数 / 各段占比
"""

import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
README = os.path.join(ROOT, "README.md")
CHANGELOG = os.path.join(ROOT, "CHANGELOG.md")

SECTION_BUDGET = 250       # 单节行数预算
# ★ 全文基线：第 96 轮瘦身后实测 2576 行（原来 6253 行）。
#   不设「理想值」—— 设了只会每轮都报错，报多了就没人看。改成**盯增长**：
#   涨过基线的 10% 才报警，这时候通常又有人往里追加历史了。
BASELINE = 2576
GROWTH_LIMIT = 0.10
CN_NUM = "一二三四五六七八九十零百"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def sections(lines):
    """按 1~2 级标题切段，返回 [(起始行, 行数, 标题)]。代码块里的 `#` 不算标题。"""
    fence = False
    idx = []
    for i, l in enumerate(lines):
        if l.strip().startswith("```"):
            fence = not fence
            continue
        if not fence and re.match(r"^#{1,2} ", l):
            idx.append((i, l))
    out = []
    for k, (i, title) in enumerate(idx):
        end = idx[k + 1][0] if k + 1 < len(idx) else len(lines)
        out.append((i + 1, end - i, title))
    return out


def check_round_headers(lines):
    """判据 B：README 里出现「第 N 轮」就是历史记录，属于 CHANGELOG。"""
    hits = []
    fence = False
    for no, line in enumerate(lines, 1):
        if line.strip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if re.match(r"^#{1,2} ", line) and re.search(r"第\s*[\d%s]+\s*轮" % CN_NUM, line):
            hits.append((no, line.strip()))
    return hits


def check_big_sections(secs, lines):
    """超预算的节。

    ★ 判据要区分两种情况：
      - 节内**没有**子标题 → 按整节算（这才叫「没组织的墙」）；
      - 节内有子标题 → 按**最大子节**算（30 个小节的说明书长是正常的，不该报）。
    """
    out = []
    for no, n, title in secs:
        if n <= SECTION_BUDGET:
            continue
        body = lines[no - 1:no - 1 + n]
        fence = False
        subs = []
        for k, l in enumerate(body):
            if l.strip().startswith("```"):
                fence = not fence
                continue
            if not fence and re.match(r"^#{3,4} ", l):
                subs.append(k)
        if not subs:
            out.append((no, n, title, "整节无子标题"))
        else:
            subs.append(len(body))
            biggest = max(subs[i + 1] - subs[i] for i in range(len(subs) - 1))
            if biggest > SECTION_BUDGET:
                out.append((no, biggest, title, "最大子节 %d 行" % biggest))
    return out


def check_fake_headers(lines):
    """代码块外的 `#` 行如果像代码注释，说明围栏没闭合或者注释跑出来了。"""
    fence = False
    bad = []
    seen_title = False
    for no, line in enumerate(lines, 1):
        if line.strip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if re.match(r"^# ", line):
            if not seen_title:      # 第一行是文档主标题，不参与判断
                seen_title = True
                continue
            body = line[2:].strip()
            if re.search(r"[=（(]|\.gd\b|\.py\b|\.json\b|--\w", body):
                bad.append((no, body))
    return bad


def changelog_numbers():
    """从 CHANGELOG 末尾「测试规模的变化」表里取最后一行的三个数。"""
    txt = read(CHANGELOG)
    rows = re.findall(r"^\|\s*第\s*\d+\s*轮末[^|]*\|\s*\**(\d+)\**\s*\|\s*\**(\d+)\**\s*\|\s*\**(\d+)\**\s*\|", txt, re.M)
    return tuple(rows[-1]) if rows else None


def readme_numbers(txt):
    """README 里「N 项断言」出现的数字，带行号。同一个数字被手写多处是重点。"""
    out = []
    for no, line in enumerate(txt.split("\n"), 1):
        for m in re.finditer(r"(\d+)\s*项断言", line):
            out.append((no, m.group(1)))
    return out


def main():
    strict = "--strict" in sys.argv
    txt = read(README)
    lines = txt.split("\n")
    secs = sections(lines)
    problems = 0

    print("=" * 66)
    print("README 体检")
    print("=" * 66)

    print("\n[总量]")
    print("  行数 %d   字符 %d   大小 %.1f KB" % (len(lines), len(txt), len(txt.encode("utf-8")) / 1024.0))
    cap = int(BASELINE * (1 + GROWTH_LIMIT))
    print("  基线 %d 行，涨过 %d 行（+%d%%）就报" % (BASELINE, cap, int(GROWTH_LIMIT * 100)))
    if len(lines) > cap:
        print("  !! 比基线涨了 %.1f%% —— 先查是不是又追加了逐轮记录" % (100.0 * len(lines) / BASELINE - 100))
        problems += 1
    else:
        print("  在基线附近（%+.1f%%）" % (100.0 * len(lines) / BASELINE - 100))

    print("\n[1] 带「第 N 轮」字样的小节（属于 CHANGELOG）")
    hits = check_round_headers(lines)
    if hits:
        span = 0
        for no, t in hits:
            for s_no, s_n, s_t in secs:
                if s_no == no:
                    span += s_n
                    break
        print("  !! %d 个，合计 %d 行（占全文 %.1f%%）" % (len(hits), span, 100.0 * span / len(lines)))
        for no, t in hits:
            print("     %5d  %s" % (no, t[:56]))
        problems += 1
    else:
        print("  无")

    print("\n[2] 单节超 %d 行（有子标题的按最大子节算）" % SECTION_BUDGET)
    big = check_big_sections(secs, lines)
    if big:
        print("  !! %d 节" % len(big))
        for no, n, t, why in big:
            print("     %5d  %4d 行  %s  [%s]" % (no, n, t[:48], why))
        problems += 1
    else:
        print("  无")

    print("\n[3] 假标题（围栏坏了，注释跑成标题）")
    fake = check_fake_headers(lines)
    if fake:
        print("  !! %d 处" % len(fake))
        for no, t in fake[:10]:
            print("     %5d  # %s" % (no, t[:56]))
        problems += 1
    else:
        print("  无")

    print("\n[4] 断言数字是否过期")
    ch = changelog_numbers()
    rd = readme_numbers(txt)
    if not ch:
        print("  ?? CHANGELOG 里没找到测试规模表，跳过")
    elif not rd:
        print("  README 里没有「N 项断言」，无需比对")
    else:
        print("  CHANGELOG 最新一行（权威）：%s / %s / %s" % ch)
        stale = [(no, n) for no, n in rd if n not in ch]
        uniq = sorted(set(n for _, n in rd))
        print("  README 里手写了 %d 处，共 %d 个不同数字：%s" % (len(rd), len(uniq), " / ".join(uniq)))
        if stale:
            print("  !! 其中 %d 处是过期数字（不在权威集合里）" % len(stale))
            for no, n in stale[:12]:
                print("     %5d  %s" % (no, n))
            if len(stale) > 12:
                print("     …还有 %d 处" % (len(stale) - 12))
            problems += 1
        else:
            print("  全部与权威值一致")

    print("\n" + "=" * 66)
    if problems:
        print("结论：%d 类问题。README 正在变成第二份 CHANGELOG。" % problems)
    else:
        print("结论：干净。")
    print("=" * 66)
    return 1 if (strict and problems) else 0


if __name__ == "__main__":
    sys.exit(main())
