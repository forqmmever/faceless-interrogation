# -*- coding: utf-8 -*-
"""把第二十四轮从 AU 补的两套校服叠到小人身上，拼成一张对照图。

输出：screenshots/_school_outfits.png

为什么要有这张图：
  用户口径：「从 au 导入一套裙长最短的校服 和一套颜色不一样的普通的校服」。
  这张图用肉眼验三件事：
    1. 两套校服的 8 件贴图**位置对、颜色分得开**（藏青一套 / 墨绿一套）；
    2. 「裙长最短」那一套确实比普通校裙短一截；
    3. 最短的那条标了 cutout —— 把内裤叠上去，两侧真的露得出来。

用法：
  python tools/school_outfit_sheet.py            # 用当前图包（assets/dol_au + data/doll_au.json）
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

NAVY = ["top_school_navy", "bottom_school_navy", "stockings_school_navy", "shoes_school_navy"]
GREEN = ["top_school_green", "bottom_school_green", "stockings_school_green", "shoes_school_green"]

# (标题, 要叠的物品 id) —— 空列表 = 只有身体
ROWS = [
    ("裸身", []),
    ("A 上衣", [NAVY[0]]),
    ("A 裙子（最短）", [NAVY[1]]),
    ("A 袜子", [NAVY[2]]),
    ("A 鞋", [NAVY[3]]),
    ("A 整套（藏青）", NAVY),
    ("B 上衣", [GREEN[0]]),
    ("B 裙子（普通）", [GREEN[1]]),
    ("B 袜子", [GREEN[2]]),
    ("B 鞋", [GREEN[3]]),
    ("B 整套（墨绿）", GREEN),
    ("旧校裙 bottom_knee", ["top_highneck", "bottom_knee"]),
    # ★ 第二十七轮：这条超短校服裙按用户口径「降级成普通下装」（去掉 cutout 旗）——
    #   现在它把内裤盖住了，格子标题也跟着改。
    ("A 裙 + 蕾丝内裤（降级后：藏起来）", ["panties_lace", NAVY[1]]),
]

SCALE = 3
GAP = 10
LABEL_H = 0        # 不画文字（项目里的字体资源不适合在这里排版，标题写进 README）


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join('screenshots', '_school_outfits.png'))
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
