# -*- coding: utf-8 -*-
"""第二十七轮的对照图：眼镜三副 + 成装（与上装 / 下装互斥）。

输出：screenshots/_round27_new.png

为什么要有这张图：
  用户口径：「降级成普通下装，连衣裙那一栏改名为，成装并且装备时应和上装和下装互斥，
             眉钉去掉 洛丽塔短裙去掉 手套一栏去掉 单片金链眼睛和黑色墨镜去掉增加两副眼镜，
             两副眼镜已经现在的圆框眼镜反差值设定均设定为3，头饰一栏去掉」

  这张图用肉眼验四件事：
    1. **眼镜三副都落在脸上、颜色分得开**（金框圆镜 / 酒红猫眼 / 深灰方框）——
       其中 `square` 烘出来比另两副高（27×17），那是**镜腿绕到耳后**的部分，
       用「落在身体 / 头发上的像素」核过，悬空 0 px。
    2. **成装是「一整件」**：`dress_sundress` / `dress_eveninggown` 各自就是一层，
       上半截盖住胸、下半截盖住腿。
    3. **互斥**：最后三格是「上装 + 下装」「叠上成装」「只留成装」的对照 ——
       中间那格把三件都画上去，实际游戏里 `_apply_exclusive` 会在穿上成装的瞬间
       把上装 / 下装脱掉，所以最终状态就是第三格的样子（成装压在最外面、上下装已空）。
    4. **降级后的下装**：`bottom_cut` / `bottom_school_navy` / `bottom_slit` 现在
       会把 `panties_lace` 盖得严严实实（不再开门控）。

用法：
  python tools/round27_sheet.py                 # 当前图包（assets/dol_au + data/doll_au.json）
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

# (标题, [物品 id]) —— 空列表 = 只有身体
ROWS = [
    ("裸身", []),
    ("眼镜·圆框（金）", ["glasses_round"]),
    ("眼镜·猫眼（酒红）", ["glasses_cateye"]),
    ("眼镜·方框（深灰）", ["glasses_square"]),
    ("成装·吊带连衣裙", ["dress_sundress"]),
    ("成装·晚礼服", ["dress_eveninggown"]),
    ("上衣 + 下装（成装为空）", ["top_longsleeve", "bottom_trousers"]),
    ("成装 + 上衣 + 下装（三件都在，仅示意）", ["dress_sundress", "top_longsleeve", "bottom_trousers"]),
    ("成装 + 内裤（被成装盖住）", ["dress_sundress", "panties_lace"]),
    ("下装降级对照：开衩短裙 + 蕾丝内裤", ["bottom_cut", "panties_lace"]),
    ("下装降级对照：超短校服裙 + 蕾丝内裤", ["bottom_school_navy", "panties_lace"]),
    ("下装降级对照：高开衩短裙 + 蕾丝内裤", ["bottom_slit", "panties_lace"]),
]

SCALE = 3
GAP = 10


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join('screenshots', '_round27_new.png'))
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

    cols = len(ROWS)
    canvas = Image.new('RGBA', (cols * (w + GAP), h), (24, 26, 30, 255))
    missing = []

    for i, (_title, ids) in enumerate(ROWS):
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        stack = list(base)
        for it in ids:
            info = items.get(it)
            if not info:
                missing.append(it)
                continue
            # 用槽位 z（图层表里自带的 100.0 是兜底值，按 slot_z 覆盖）
            z = slot_z.get(slot_of.get(it, ''), info['layers'][0]['z'] if info['layers'] else 100.0)
            for L in info.get('layers', []):
                stack.append((z, L['file']))
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
    print("顺序：" + " ｜ ".join(t for t, _ in ROWS))
    if missing:
        print("★ 图层表里缺这些物品（已被跳过）: %s" % sorted(set(missing)))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
