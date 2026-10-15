# -*- coding: utf-8 -*-
"""第二十八轮对照图：从 AU 补的 8 件高暴露款 + 它们各自「解开哪一条枷锁」。

输出：screenshots/_round28_new.png

为什么要有这张图：
  用户口径：「遇见反差值不足的情况下，可以从au添加暴露度高的服装」。

  这张图不只是「看看新衣服长什么样」—— 它是**三条路线的对照**。
  先用 tests/_ProbeCeiling 量过：反差天花板卡在 54，而暴露值预算大量闲置
  （第 4 关只用了 54 中的 21），真正的枷锁是「遮缺陷」与「拿反差」互锁：
    · top 必须穿长袖遮手背刺青 → 自己只能贡献 1~3 分；
    · 而那件长袖又把 bra 盖死（门控不计）、还逼得颈饰去顶颈侧烙印（只能拿 3 分）。
  所以新加的 8 件是按「解开哪一条」来配的，图里也按这个顺序排：
    上半张 —— 三件上衣，各开一条路：
        网纱透视（sheer）→ 透出 bra，走「内衣流」
        紧身针织衫（long_sleeve）→ 遮住刺青，自身 7 分反差
        高领军毛衣（high_collar + long_sleeve）→ **同时遮两处**，把颈饰整栏解放出来
    下半张 —— 三件下装（下装完全不受缺陷约束，是唯一能自由堆暴露的一栏）
        + 两件内衣 + 三条路线的完整搭配对照

用法：
  python tools/round28_sheet.py                 # 当前图包（assets/dol_au + data/doll_au.json）
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

# 两行，每行一组 (标题, [物品 id])。空列表 = 只有身体。
ROWS = {
    'a': [
        ("裸身", []),
        ("上衣·网纱透视（sheer）", ["top_mesh"]),
        ("上衣·紧身针织衫（long_sleeve）", ["top_virginkiller"]),
        ("上衣·高领军毛衣（high_collar+long_sleeve）", ["top_turtleneck"]),
        ("内衣·微型比基尼", ["bra_microkini"]),
        ("内衣·乳贴", ["bra_pasties"]),
        ("下装·网眼超短裙", ["bottom_fishnet"]),
        ("下装·漆皮迷你裙", ["bottom_pvc"]),
        ("下装·开衩短旗袍", ["bottom_qipao"]),
    ],
    'b': [
        ("裸身", []),
        ("原貌·高领长袖衬衫（基准）", ["top_highneck", "bottom_trousers", "panties_plain"]),
        ("路线A 内衣流：网纱 + 乳贴", ["top_mesh", "bra_pasties"]),
        ("路线B 长袖流：针织衫 + 漆皮裙", ["top_virginkiller", "bottom_pvc"]),
        ("路线C 高领流：高领军毛衣 + 尖刺项圈", ["top_turtleneck", "neck_spiked"]),
        ("下装开门：漆皮裙 + 蕾丝内裤", ["bottom_pvc", "panties_lace"]),
        ("下装开门：网眼裙 + 蕾丝内裤", ["bottom_fishnet", "panties_lace"]),
        ("高领流（带下装）", ["top_turtleneck", "bottom_fishnet", "neck_spiked"]),
    ],
}

SCALE = 3
GAP = 10
ROW_GAP = 10


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--rows', default='ab', choices=['a', 'b', 'ab'])
    ap.add_argument('--out', default=os.path.join('screenshots', '_round28_new.png'))
    args = ap.parse_args()

    asset_dir, json_rel = PACK
    root = os.path.join(PROJ, asset_dir)
    with io.open(os.path.join(PROJ, json_rel), encoding='utf-8') as f:
        doll = json.load(f)
    slot_of = {}
    story_p = os.path.join(PROJ, 'data', 'story.json')
    if os.path.exists(story_p):
        with io.open(story_p, encoding='utf-8') as f:
            for it in json.load(f).get('catalog', {}).get('items', []):
                slot_of[it['id']] = it['slot']
    slot_z = doll.get('slot_z', {})

    w, h = doll['size']
    items = doll['items']
    base = [(L['z'], L['file']) for L in doll['base']]

    def layer(rel):
        p = os.path.join(root, rel)
        if not os.path.exists(p):
            return None
        return Image.open(p).convert('RGBA')

    picked = [ROWS[k] for k in ('a', 'b') if k in args.rows]
    cols = max(len(r) for r in picked)
    rows = len(picked)
    canvas = Image.new('RGBA', (cols * (w + GAP), rows * h + (rows - 1) * ROW_GAP),
                       (24, 26, 30, 255))
    missing = []

    for ri, group in enumerate(picked):
        y0 = ri * (h + ROW_GAP)
        for i, (_title, ids) in enumerate(group):
            img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            stack = list(base)
            for it in ids:
                info = items.get(it)
                if not info:
                    missing.append(it)
                    continue
                z = slot_z.get(slot_of.get(it, ''),
                               info['layers'][0]['z'] if info['layers'] else 100.0)
                for L in info.get('layers', []):
                    stack.append((z, L['file']))
            stack.sort(key=lambda t: t[0])
            for _z, rel in stack:
                im = layer(rel)
                if im is not None:
                    img.alpha_composite(im)
            canvas.alpha_composite(img, (i * (w + GAP), y0))

    out_path = os.path.join(PROJ, args.out)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    big = canvas.resize((canvas.width * SCALE, canvas.height * SCALE), Image.NEAREST)
    big.convert('RGB').save(out_path)

    print("图包 %s ｜ 取景框 %s ｜ %d 行 × 最多 %d 格 → %s  %dx%d" % (
        'au', doll.get('crop'), rows, cols, args.out, big.width, big.height))
    for ri, group in enumerate(picked):
        print("  第 %d 行：" % (ri + 1) + " ｜ ".join(t for t, _ in group))
    if missing:
        print("★ 图层表里缺这些物品（已被跳过）: %s" % sorted(set(missing)))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
