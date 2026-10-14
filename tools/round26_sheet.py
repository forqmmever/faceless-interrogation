# -*- coding: utf-8 -*-
"""第二十六轮三组新东西的对照图：刺青（改用 AU bodywriting）/ 项圈 / 高暴露内裤。

输出：screenshots/_round26_new.png

为什么要有这张图：
  用户口径：「纹身 眉钉 颈饰有可能是不是au是原版的请换成au的 更正一下
             如果是一整件衣服 如晚礼服 不能分开成下装和上装应该单开一个栏目
             增加增加暴露度高的内裤款式和几款项圈」

  这张图用肉眼验四件事：
    1. **刺青换源了**：三处刺青现在是 AU 的 `bodywriting` 图案（蝴蝶/星/花），
       不再是「借头部小件 + 搬移」凑出来的抽象色块；位置与大小都按 AU 原生
       （落身率 100% / 100% / 96.5%，可用 tools/doll_audit.py 复算）。
    2. **项圈从 3 件到 8 件**：新增尖刺 / 环扣 / 蕾丝 / 金链 / 公开 五款，
       全部取 AU `clothes/neck/*` 的真实贴图（本来那三件也已经是 AU 的）。
    3. **高暴露内裤 4 款**：开裆 / 微型 / 牛仔丁字 / 丁字裤，与 `panties_lace`
       并排看，确认它们确实比普通内裤露得多。
    4. **整件式**：连衣裙 / 晚礼服现在是 `dress` 槽位的**一整件**贴图，
       不再拆成「上衣 + 下装」两件（用户口径：「不能分开成下装和上装 应该单开一个栏目」）。

用法：
  python tools/round26_sheet.py                 # 当前图包（assets/dol_au + data/doll_au.json）
  python tools/round26_sheet.py --pack dol      # 换成 DoL 那套
  python tools/round26_sheet.py --rows a        # 只出第一行（刺青 + 项圈）
"""

import argparse
import io
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)

PACKS = {
    'au': ('assets/dol_au', 'data/doll_au.json'),
    'dol': ('assets/dol', 'data/doll.json'),
}

# 每一行是一组 (标题, [物品 id])；空列表 = 只有身体。
ROWS = {
    'a': [
        ("裸身", []),
        ("刺青·颈侧", ["tattoo_neck"]),
        ("刺青·颊", ["tattoo_cheek"]),
        ("刺青·大腿", ["tattoo_thigh"]),
        ("项圈·尖刺（新）", ["neck_spiked"]),
        ("项圈·环扣（新）", ["neck_ringed"]),
        ("项圈·蕾丝（新）", ["neck_lace"]),
        ("项圈·金链（新）", ["neck_chain"]),
        ("项圈·公开（新）", ["neck_freeuse"]),
        ("项圈·布质（旧）", ["neck_choker"]),
    ],
    'b': [
        ("裸身", []),
        ("内裤·开裆（新）", ["panties_crotchless"]),
        ("内裤·微型（新）", ["panties_micro"]),
        ("内裤·牛仔丁字（新）", ["panties_janties"]),
        ("内裤·丁字（新）", ["panties_thong"]),
        ("内裤·蕾丝（旧）", ["panties_lace"]),
        ("内裤·素面（旧）", ["panties_plain"]),
        ("整件·吊带连衣裙", ["dress_sundress"]),
        ("整件·晚礼服", ["dress_eveninggown"]),
    ],
}

SCALE = 3
GAP = 10
ROW_GAP = 10


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--pack', default='au', choices=sorted(PACKS))
    ap.add_argument('--rows', default='ab', choices=['a', 'b', 'ab'])
    ap.add_argument('--out', default=os.path.join('screenshots', '_round26_new.png'))
    args = ap.parse_args()

    asset_dir, json_rel = PACKS[args.pack]
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

    picked = [ROWS[k] for k in ('a', 'b') if k in args.rows]
    cols = max(len(r) for r in picked)
    rows = len(picked)
    cw = cols * (w + GAP)
    ch = rows * h + (rows - 1) * ROW_GAP
    canvas = Image.new('RGBA', (cw, ch), (24, 26, 30, 255))
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
                for L in info.get('layers', []):
                    stack.append((L['z'], L['file']))
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
        args.pack, doll.get('crop'), rows, cols, args.out, big.width, big.height))
    for ri, group in enumerate(picked):
        print("  第 %d 行：" % (ri + 1) + " ｜ ".join(t for t, _ in group))
    if missing:
        print("★ 图层表里缺这些物品（已被跳过）: %s" % sorted(set(missing)))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
