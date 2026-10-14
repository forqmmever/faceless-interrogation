# -*- coding: utf-8 -*-
"""把「四类题目各一套结构」迁移成「一份统一的题目清单」。

背景（第二十九轮）
------------------
用户口径：「阶段二的问题我想不再给问题分类，直接让我编辑对问题进行编辑」。

改造前，题目根本不是一份清单，而是 `RunData.questions_for_level()` 里 42 行
**编排代码**按固定位置拼出来的（第 3 道固定同行者、第 6 道固定盲区、
第 7 道固定跨关复问），而且四类题目各有一套互不相同的 JSON 结构：

    questions[]            {card, q, answer, leak, bluff, evade}
    facts[]                {id, prompts[2], values[3]}        ← 运行时转成题
    companion_questions[]  {fact, line, options[{text,delta,value}]}
    blind_questions[]      {id, q, setup, made_up, bluff, evade}

改造后只有一份 `questions[]`，每道题是一个自带全部属性的对象
（题面 / 选项 / QTE 类型与延迟 / 是否抖动 / 触发什么结局 / 每个选项的怀疑值）。

`facts[]` **保留**，但降级成「可选骨架」：题目可以用 `fact` 字段挂上去
（参与「跨关不许改口」的检查），也可以完全不挂 —— 那就只是一道独立题。

字段设计的两条原则
------------------
1. **一切可缺省** —— 不写就继承全局（`rules` 段与内置默认）。
   例如选项的 `suspicion` 留空 = 仍按「档案卡归属 + 审问官性情」的老规则算；
   写上就是硬覆盖。这样既能逐题精调，又不会把现有的性情机制弄丢。
2. **纯数据、无隐藏耦合** —— 判对错不再依赖「这道题属于哪一类」，
   而是看选项自己的 `tone`（语义标签）。

用法
----
    python tools/migrate_questions.py --in data/story.json --dry-run
    python tools/migrate_questions.py --in data/story.json --out data/story.json.pre29
"""

import argparse
import io
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)

# 选项的语义标签（tone）—— 判定逻辑只看它，不看题目属于哪一类
TONE_CORRECT = "correct"      # 照实答且答对（B 卡 / 对的那个版本）
TONE_VERSION = "version"      # 事实题的一个版本，对错看「你之前立过什么说法」
TONE_BLUFF = "bluff"          # 撒谎
TONE_EVADE = "evade"          # 回避
TONE_LEAK = "leak"            # 说漏嘴（A 卡的致命项，直接触发出局）
TONE_SILENCE = "silence"      # 沉默（代价固定，与性情无关）
TONE_MADE_UP = "made_up"      # 盲区题：硬编一个不存在的细节

# QTE 类型的合法取值（与 OutfitData.QTE_* 对齐）
QTE_KINDS = ["auto", "none", "expression", "interference", "combo"]

# 通用池的 level 标记：不属于任何特定一关，每关按需抽取
LEVEL_ANY = -1


def _card_owner(cards, card_id):
    for c in cards:
        if c.get("id") == card_id:
            return str(c.get("owner", "B"))
    return "B"


def _norm_option(text, tone, suspicion=None, value="", ending="",
                 shake=None, requires=None):
    """一格选项。只写非空字段 —— 文件干净，人也看得懂。"""
    o = {"text": text, "tone": tone}
    if suspicion is not None:
        o["suspicion"] = suspicion
    if value:
        o["value"] = value
    if ending:
        o["ending"] = ending
    if shake is not None:
        o["shake"] = shake
    if requires:
        o["requires"] = requires
    return o


def _question(qid, level, text, options, speaker="interrogator", setup="",
              fact="", card="", recall=False, plant="", qte=None, shake=None,
              answer_key=None, note=""):
    q = {"id": qid, "level": level, "speaker": speaker, "text": text}
    if setup:
        q["setup"] = setup
    if fact:
        q["fact"] = fact
    if card:
        q["card"] = card
    if recall:
        q["recall"] = True
    if plant:
        q["plant"] = plant
    q["options"] = options
    if qte:
        q["qte"] = qte
    if shake is not None:
        q["shake"] = shake
    if answer_key is not None:
        q["answer_key"] = answer_key
    if note:
        q["note"] = note
    return q


def migrate_background(bg):
    """把一套背景的四段题目合成一份 questions[]。"""
    cards = bg.get("cards") or []
    facts = bg.get("facts") or []
    fact_index = {str(f.get("id", "")): i for i, f in enumerate(facts)}

    out = []

    # ---- ① 档案题 → 通用池 ----
    # 原来每关从同一个池子里随机抽 4~5 道，所以标成「通用」，
    # 运行时按 questions_per_level 抽。内容一字不改。
    for i, q in enumerate(bg.get("questions") or []):
        card_id = str(q.get("card", ""))
        owner = _card_owner(cards, card_id)
        opts = []
        if owner == "A":
            # A 卡：照实答就是当场说漏嘴 —— 这一项写成 leak，
            # 缺省 suspicion 仍由 rules.leak_delta 决定（迁移不写死数值）。
            opts.append(_norm_option(str(q.get("leak", "")), TONE_LEAK))
        else:
            opts.append(_norm_option(str(q.get("answer", "")), TONE_CORRECT))
        opts.append(_norm_option(str(q.get("bluff", "")), TONE_BLUFF))
        opts.append(_norm_option(str(q.get("evade", "")), TONE_EVADE))
        opts.append(_norm_option("", TONE_SILENCE))     # 空文本 = 用全局那句
        out.append(_question(
            "q_" + card_id, LEVEL_ANY, str(q.get("q", "")), opts,
            card=card_id,
            note="档案题（来自 %s 卡，归属 %s）" % (card_id, owner)))

    # ---- ② 事实题 → 每题按 fact 的序号落到对应的那一关 ----
    # facts[i] 是第 i 关新要问的那条口径；它的第 2 个问法（prompts[1]）
    # 是「换个说法再问一次」，也就是跨关复问用的那一道 —— 标 recall。
    for fi, f in enumerate(facts):
        fid = str(f.get("id", ""))
        prompts = f.get("prompts") or []
        values = f.get("values") or []
        if not prompts or not values:
            continue
        base_opts = [
            _norm_option(str(v.get("label", "")), TONE_VERSION,
                         value=str(v.get("id", "")))
            for v in values
        ]
        # 第 1 个问法：本关首次问这条事实
        out.append(_question(
            "q_fact_%s_new" % fid, fi, str(prompts[0]), [dict(o) for o in base_opts],
            fact=fid,
            note="事实题：本关新问的「%s」" % fid))
        # 第 2 个问法：换个说法复问 → 通用池（复问哪条是按关抽的）
        if len(prompts) > 1:
            out.append(_question(
                "q_fact_%s_recall" % fid, LEVEL_ANY, str(prompts[1]),
                [dict(o) for o in base_opts],
                fact=fid, recall=True,
                note="事实题：跨关复问「%s」（哪一关复问由运行时决定）" % fid))

    # ---- ③ 同行者提问 → 跟着它绑定的那条事实走 ----
    #   ★ 注意「不表态」那个选项：它的 `value` 是空的（不代表任何版本），
    #     语义上就是「回避」而不是「某个版本」—— 必须转成 evade，
    #     否则判定会把它当成一个空版本、参与跨关一致性检查，直接算出错误结论。
    #     （第一版迁移没区分这两者，是编辑器校验器抓出来的。）
    for j, cq in enumerate(bg.get("companion_questions") or []):
        fid = str(cq.get("fact", ""))
        lv = fact_index.get(fid, LEVEL_ANY)
        opts = []
        for o in (cq.get("options") or []):
            vid = str(o.get("value", ""))
            opts.append(_norm_option(
                str(o.get("text", "")),
                TONE_VERSION if vid != "" else TONE_EVADE,
                suspicion=float(o.get("delta", 0.0)),
                value=vid))
        out.append(_question(
            "q_companion_%s" % (fid or j), lv, str(cq.get("line", "")), opts,
            speaker="companion", fact=fid,
            plant=str(cq.get("plant", "")),
            note="同行者提问（他的问法是错的，看你能不能顶住）"))

    # ---- ④ 盲区题 → 第 i 关固定用第 i 条 ----
    #   ★ 「硬答」是可选的：题面没写就是「这题只有撒谎 / 回避两个选项」，
    #     那是合法的设计 —— 别生成一个空文本的选项出来（那样盘问里会出现空按钮）。
    #     同样是校验器抓出来的。
    for j, bq in enumerate(bg.get("blind_questions") or []):
        opts = []
        if str(bq.get("made_up", "")) != "":
            opts.append(_norm_option(str(bq.get("made_up", "")), TONE_MADE_UP))
        opts.append(_norm_option(str(bq.get("bluff", "")), TONE_BLUFF))
        opts.append(_norm_option(str(bq.get("evade", "")), TONE_EVADE))
        out.append(_question(
            "q_" + str(bq.get("id", "blind_%d" % j)), j, str(bq.get("q", "")), opts,
            setup=str(bq.get("setup", "")),
            note="盲区题：档案与短信里都没有，只能按他的脾性选"))

    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", default=os.path.join(PROJ, "data", "story.json"))
    ap.add_argument("--out", dest="dst", default=None,
                    help="默认原地覆盖（会先自动备份到 .workbuddy-ai/tmp/）")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    with io.open(args.src, encoding="utf-8") as f:
        doc = json.load(f)

    bgs = doc.get("backgrounds") or []
    if not bgs:
        print("★ story.json 里没有 backgrounds 段 —— 先跑一次 DumpStory 再迁移")
        return 1

    report = []
    for bg in bgs:
        old_n = (len(bg.get("questions") or []) + len(bg.get("facts") or [])
                 + len(bg.get("companion_questions") or [])
                 + len(bg.get("blind_questions") or []))
        qs = migrate_background(bg)
        by_level = {}
        for q in qs:
            by_level.setdefault(q["level"], []).append(q)
        report.append((str(bg.get("id", "?")), old_n, len(qs), by_level))
        if not args.dry_run:
            bg["questions"] = qs
            bg["questions_schema"] = "faceless-questions-v1"
            # 旧的四段：事实表**保留**（题目用 fact 字段引用它），其余三段删掉
            for key in ("companion_questions", "blind_questions"):
                bg.pop(key, None)

    print("=== 迁移预览 ===")
    for bid, old_n, new_n, by_level in report:
        parts = []
        for lv in sorted(by_level.keys(), key=lambda x: (x < 0, x)):
            tag = "通用池" if lv == LEVEL_ANY else "第%d关" % (lv + 1)
            parts.append("%s=%d" % (tag, len(by_level[lv])))
        print("  %-14s 旧 %2d 段 → 新 %2d 道题（%s）" % (bid, old_n, new_n, "，".join(parts)))

    if args.dry_run:
        print("\n（dry-run，未写文件）")
        return 0

    tmpdir = os.path.join(PROJ, ".workbuddy-ai", "tmp")
    os.makedirs(tmpdir, exist_ok=True)
    backup = os.path.join(tmpdir, "story.json.pre29")
    shutil.copy2(args.src, backup)
    dst = args.dst or args.src
    with io.open(dst, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    print("\n已写入 %s" % os.path.relpath(dst, PROJ))
    print("原文件备份 → %s" % os.path.relpath(backup, PROJ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
