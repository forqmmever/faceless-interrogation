# -*- coding: utf-8 -*-
"""把从 AU 补的水手服 / 连衣裙 / 晚礼服 / 三套暴露装叠到小人身上，拼一张对照图。

输出：screenshots/_new_outfits.png

为什么要有这张图：
  用户口径（第二十五轮）：「导入一套白色水手服的上装下装和一套裙长最短的水手服的上装下装
             一套连衣裙一套晚礼服 三套暴露度高的服装 …… 现在内裤会显示在下装上面
             请修复这个问题」。这张图用肉眼验四件事：
    1. 新贴图**位置对、颜色分得开**（白水手服 / 藏青水手服 / 米白连衣裙 / 酒红晚礼服）；
    2. 三套暴露装确实露得多（胸衣 / 洛丽塔 / 开胸上衣）；
    3. **内裤层级修好了**：最后四格是「修之前 vs 修之后」的对照 ——
       修之前（源图取 AU 的 `gstring`）内裤腰带会从长裤 / 长裙的腰上方露出来，
       修之后（换成 `lacepanties`）被下装盖得干干净净；
    4. 晚礼服那一格同时暴露一处**已知裁边**：这条舞会裙比共用取景框宽，
       左边 18 px 被裁掉（烘 AU 时也会打印同样的警告）。

  第二十六轮的变更：连衣裙 / 晚礼服不再拆成「上衣 + 下装」两件，
  而是 dress 槽位的**一整件** —— 所以那两格里现在各只有一个 id。

用法：
  python tools/new_outfits_sheet.py                 # 用当前图包（assets/dol_au + data/doll_au.json）
  python tools/new_outfits_sheet.py --au-root <图包目录>   # 换 AU 原图包位置（只为「修之前」那两格）
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

AU_ROOT_DEFAULT = 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3'

# 「修之前」那两格用的哨兵 id：源图是 AU 的 gstring（高腰系带画法），
# 需要拿原图包现烘一层 —— 这条映射第二十五轮已经换成 lacepanties 了。
OLD_PANTIES = "__panties_old__"
OLD_PANTIES_SRC = ('clothes', 'under-lower', 'gstring', 'full.png')
PANTIES_BLACK = (0.13, 0.13, 0.15)      # dol_map.BLACK

WHITE_SET = ["top_sailor_white", "bottom_sailor_white"]
NAVY_SET = ["top_sailor_navy", "bottom_sailor_navy"]
# ★ 第二十六轮：连衣裙 / 晚礼服从「上衣 + 下装」两件合并成 dress 槽位的**一整件**
#   （用户口径：「如果是一整件衣服 如晚礼服 不能分开成下装和上装应该单开一个栏目」）。
#   所以这里也改成单个 id —— 它们各自就是一层整件式贴图。
DRESS_SET = ["dress_sundress"]
GOWN_SET = ["dress_eveninggown"]
LEWD_1 = ["top_bustier", "bottom_hotpants"]
# ★ 第二十七轮：`bottom_lolita`（洛丽塔短裙）已删 —— 这一格改用高开衩短裙，
#   和第三套的差别只剩上衣（洛丽塔胸衣 vs 开胸上衣）。
LEWD_2 = ["top_lolita", "bottom_slit"]
LEWD_3 = ["top_keyhole", "bottom_slit"]

# (标题, 要叠的物品 id) —— 空列表 = 只有身体
ROWS = [
    ("裸身", []),
    ("白水手服", WHITE_SET),
    ("藏青水手服", NAVY_SET),
    ("连衣裙", DRESS_SET),
    ("晚礼服", GOWN_SET),
    ("暴露①胸衣+皮短裤", LEWD_1),
    ("暴露②洛丽塔", LEWD_2),
    ("暴露③开胸+高开衩", LEWD_3),
    ("修前·长裤", ["bottom_trousers", OLD_PANTIES]),
    ("修后·长裤", ["bottom_trousers", "panties_lace"]),
    ("修前·校裙", ["bottom_knee", OLD_PANTIES]),
    ("修后·校裙", ["bottom_knee", "panties_lace"]),
]

SCALE = 3
GAP = 10
LABEL_H = 0        # 不画文字（项目里的字体资源不适合在这里排版，标题写进 README）


def bake_old_panties(au_root, frame, crop, tint):
    """按 dol_prepare 的口径现烘一层：取原图 → 裁到全身像那一列 → 套取景框 → 染色。

    AU 的 under-lower 图层没有 align / scale 的额外搬移，所以这一小段等价于管线结果
    （拿 lacepanties 复核过，逐像素 0 差异）。
    """
    p = os.path.join(au_root, *OLD_PANTIES_SRC)
    if not os.path.exists(p):
        return None
    raw = Image.open(p).convert('RGBA')
    clip = Image.new('RGBA', frame, (0, 0, 0, 0))
    clip.paste(raw.crop((0, 0, frame[0], frame[1])), (0, 0))
    im = clip.crop(crop)
    r, g, b = tint
    px = im.load()
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            cr, cg, cb, a = px[x, y]
            if a == 0:
                continue
            lum = (cr * 299 + cg * 587 + cb * 114) / 1000.0 / 255.0
            op[x, y] = (int(r * lum * 255), int(g * lum * 255), int(b * lum * 255), a)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join('screenshots', '_new_outfits.png'))
    ap.add_argument('--au-root', default=AU_ROOT_DEFAULT,
                    help='AU 原图包目录（只为「修之前」那两格现烘一层 gstring）')
    args = ap.parse_args()

    asset_dir, json_rel = PACK
    root = os.path.join(PROJ, asset_dir)
    with io.open(os.path.join(PROJ, json_rel), encoding='utf-8') as f:
        doll = json.load(f)
    # 槽位 → z：衣服的绘制顺序按槽位定（不是按层自带的 z，那里面全是 100）
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

    old_panties = None
    if any(OLD_PANTIES in ids for _t, ids in ROWS):
        old_panties = bake_old_panties(
            args.au_root, tuple(doll['frame']), tuple(doll['crop']), PANTIES_BLACK)

    cols = len(ROWS)
    canvas = Image.new('RGBA', (cols * (w + GAP), h + LABEL_H), (24, 26, 30, 255))
    missing = []
    skipped = []

    for i, (title, ids) in enumerate(ROWS):
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        stack = list(base)
        for it in ids:
            if it == OLD_PANTIES:
                if old_panties is None:
                    skipped.append(title)
                    continue
                stack.append((slot_z.get('panties', 67.0), None))
                continue
            info = items.get(it)
            if not info:
                missing.append(it)
                continue
            z = slot_z.get(slot_of.get(it, ''), info['layers'][0]['z'] if info['layers'] else 100.0)
            for L in info.get('layers', []):
                stack.append((z, L['file']))
        stack.sort(key=lambda t: t[0])
        for _z, rel in stack:
            if rel is None:
                img.alpha_composite(old_panties)
                continue
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
    if skipped:
        print("★ 这几格需要 AU 原图包（%s）才能现烘旧丁字裤，已跳过：%s"
              % (args.au_root, skipped))
    if missing:
        print("★ 图层表里缺这些物品（会被跳过）: %s" % missing)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
