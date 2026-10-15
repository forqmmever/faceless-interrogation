# -*- coding: utf-8 -*-
"""把「这一轮新加的 / 用来开门的」那几件外衣，按图层表叠到小人身上，拼成一张对照图。

输出：screenshots/_gate_new_items.png

为什么要有这张图：
  第二十二轮给内衣内裤加了「曝光门控」——只有**看得见**时才算暴露值与反差值。
  看得见的三条路是：透明外衣 / 镂空开档 / 直接外穿。
  这张图就是用肉眼验一件事：标了 see（透明 / 镂空）和标了 bare（不穿）的那几件，
  在小人身上**确实长得像那么回事**（不是一坨占位图、也没错位）。

用法：
  python tools/gate_items_sheet.py            # 用当前图包（assets/dol_au + data/doll_au.json）
"""

import argparse
import io
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)

PACK = ('assets/dol_au', 'data/doll_au.json')

# (标题, 要叠的物品 id) —— 空列表 = 只有身体
ROWS = [
    ("裸身", []),
    ("top_sheer 透明", ["top_sheer"]),
    ("top_lace 透明", ["top_lace"]),
    ("top_corset 镂空", ["top_corset"]),
    ("top_crop 镂空（新）", ["top_crop"]),
    ("top_offshoulder 镂空（新）", ["top_offshoulder"]),
    ("bottom_pleat 透明（新）", ["bottom_pleat"]),
    ("bottom_cut 普通（第二十七轮降级）", ["bottom_cut"]),
    ("bottom_mini 镂空", ["bottom_mini"]),
    ("bottom_school_navy 普通（第二十七轮降级）", ["bottom_school_navy"]),
    ("bottom_school_green 普通（新）", ["bottom_school_green"]),
    ("bottom_hotpants 镂空（新）", ["bottom_hotpants"]),
    ("bottom_slit 普通（第二十七轮降级）", ["bottom_slit"]),
    ("bra_lace + top_lace（透出来）", ["bra_lace", "top_lace"]),
    ("bra_lace + top_highneck（藏起来）", ["bra_lace", "top_highneck"]),
    ("panties_lace + bottom_mini（门控开着）", ["panties_lace", "bottom_mini"]),
    ("panties_lace + bottom_slit（降级后：藏起来）", ["panties_lace", "bottom_slit"]),
    ("panties_lace + bottom_longskirt（藏起来）", ["panties_lace", "bottom_longskirt"]),
    # ★ 第二十六轮：`dress` 成了 bra 与 panties **共同的**开门人 —— 一条连衣裙
    #   上半截盖住内衣、下半截盖住内裤。这两格就是把新门控拍下来。
    ("bra_lace + dress_sundress（被连衣裙盖住）", ["bra_lace", "dress_sundress"]),
    ("panties_lace + dress_sundress（被连衣裙盖住）", ["panties_lace", "dress_sundress"]),
]

SCALE = 3
GAP = 10
LABEL_H = 0        # 不画文字（项目里的字体资源不适合在这里排版，标题写进 README）


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join('screenshots', '_gate_new_items.png'))
    args = ap.parse_args()

    asset_dir, json_rel = PACK
    root = os.path.join(PROJ, asset_dir)
    with io.open(os.path.join(PROJ, json_rel), encoding='utf-8') as f:
        doll = json.load(f)

    w, h = doll['size']
    items = doll['items']
    base = [(L['z'], L['file']) for L in doll['base']]

    def layer(rel):
        p = os.path.join(root, rel)
        if not os.path.exists(p):
            return None
        return Image.open(p).convert('RGBA')

    cols = len(ROWS)
    canvas = Image.new('RGBA', (cols * (w + GAP), h + LABEL_H), (24, 26, 30, 255))
    missing = []

    for i, (title, ids) in enumerate(ROWS):
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        stack = list(base)
        for it in ids:
            info = items.get(it)
            if not info:
                missing.append(it)
                continue
            for L in info.get('layers', []):
                stack.append((L['z'], L['file']))
        stack.sort(key=lambda t: t[0])
        for _z, rel in stack:
            im = layer(rel)
            if im is not None:
                img.alpha_composite(im)
        canvas.alpha_composite(img, (i * (w + GAP), 0))

    out_path = os.path.join(PROJ, args.out)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    big = canvas.resize((canvas.width * SCALE, canvas.height * SCALE), Image.NEAREST)
    big.convert('RGB').save(out_path)

    print("图包 %s ｜ 取景框 %s ｜ %d 格 → %s  %dx%d" % (
        'au', doll.get('crop'), cols, args.out, big.width, big.height))
    if missing:
        print("★ 图层表里缺这些物品（会被跳过）: %s" % missing)
        return 1
    print("顺序：" + " ｜ ".join(t for t, _ in ROWS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
