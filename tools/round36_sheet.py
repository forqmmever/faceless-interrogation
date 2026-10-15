# -*- coding: utf-8 -*-
"""第三十六轮对照图：新补的四件刻字纹身（bitch / free-use / slave / cum-rag）。

输出：
  screenshots/_round36_tattoo.png
    上排 四件刻字各一张全身图（×3）
    下排 左：两两组合（演示「同时最多 2 件」）｜ 右：四件的部位放大

参数不另写一套 —— 直接读 `dol_map.AU_OVERRIDE` 里那一份，
保证图里看到的就是游戏里会看到的（同一套 layer_image -> tint -> transform）。

用法：
  python tools/round36_sheet.py
"""

import argparse
import io
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import dol_map as M            # noqa: E402
import dol_prepare as D        # noqa: E402

PACK = ('assets/dol_au', 'data/doll_au.json', 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3')

NEW = [
    ('tattoo_bitch',   '左大腿「bitch」'),
    ('tattoo_freeuse', '右大腿「free-use」'),
    ('tattoo_slave',   '胸口「slave」'),
    ('tattoo_cumrag',  '下腹「cum-rag」'),
]
PAIRS = [
    ('两件同时 · 上下各一', ['tattoo_bitch', 'tattoo_slave']),
    ('两件同时 · 左右大腿', ['tattoo_freeuse', 'tattoo_cumrag']),
]

ZOOM_AU = (14, 40, 62, 120)      # 68×203 取景框里的「躯干 + 大腿上段」


def font(sz):
    for c in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf',
              'C:/Windows/Fonts/arial.ttf']:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, sz)
            except Exception:
                pass
    return ImageFont.load_default()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join('screenshots', '_round36_tattoo.png'))
    args = ap.parse_args()

    asset_dir, json_rel, src_root = PACK
    root = os.path.join(PROJ, asset_dir)
    with io.open(os.path.join(PROJ, json_rel), encoding='utf-8') as f:
        doll = json.load(f)

    D.P = dict(D.PACKS['au'])
    D.P['name'] = 'au'
    D.P['root'] = src_root
    D.OUT = os.path.join(PROJ, asset_dir)
    D._IMG_CACHE.clear()
    D._CONTENT_CACHE.clear()

    w, h = doll['size']
    base = [(L['z'], L['file']) for L in doll['base']]
    crop = doll.get('crop') or [0, 0, w, h]

    def layer(rel):
        p = os.path.join(root, rel)
        if not os.path.exists(p):
            return None
        return Image.open(p).convert('RGBA')

    def compose(extra):
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        stack = list(base) + list(extra)
        stack.sort(key=lambda t: t[0])
        for _z, rel in stack:
            im = layer(rel) if isinstance(rel, str) else rel
            if im is not None:
                img.alpha_composite(im)
        return img

    def spec_of(item_id):
        """取这一件的烘焙参数（AU 走 AU_OVERRIDE，缺项回落到 ITEMS）。"""
        ov = M.AU_OVERRIDE.get(item_id)
        if ov:
            return ov
        return (M.ITEMS.get(item_id) or [{}])[0]

    def tattoo_layer(item_id):
        spec = spec_of(item_id)
        src = spec.get('src')
        if not src:
            return None
        p = D.resolve(src)
        if not p:
            print('  XX 找不到源图', item_id, src)
            return None
        im = D.layer_image(p)
        if spec.get('tint'):
            im = D.tint(im, spec['tint'])
        im = D.transform(im, spec.get('scale', 1.0), spec.get('align'))
        return im.crop((crop[0], crop[1], crop[0] + w, crop[1] + h))

    def label(dr, x, y, x1, text):
        dr.rectangle([x, y, x1, y + 26], fill=(20, 22, 26, 255))
        dr.text((x + 6, y + 5), text, fill=(255, 214, 130), font=font(14))

    Z1, Z2 = 3, 5
    CW1, CH1 = w * Z1, h * Z1
    tb = ZOOM_AU
    CW2, CH2 = (tb[2] - tb[0]) * Z2, (tb[3] - tb[1]) * Z2

    cells2 = len(PAIRS) + len(NEW)               # 2 张组合 + 4 张部位
    width = max(len(NEW) * (CW1 + 10) + 10, cells2 * (CW2 + 10) + 10)
    height = 34 + CH1 + 34 + 34 + CH2 + 34
    canvas = Image.new('RGBA', (width, height), (24, 26, 30, 255))
    dr = ImageDraw.Draw(canvas)

    # ---- ① 四件刻字各一张全身图 ----
    dr.text((10, 8), "① 四件刻字纹身（全身 ×%d）" % Z1, fill=(255, 214, 130), font=font(16))
    for i, (iid, title) in enumerate(NEW):
        img = compose([(M.SLOT_Z['tattoo'], tattoo_layer(iid))])
        big = img.resize((CW1, CH1), Image.NEAREST)
        x, y = 10 + i * (CW1 + 10), 34
        canvas.paste(big, (x, y), big)
        label(dr, x, y + CH1, x + CW1, title)

    # ---- ② 左：两两组合（同时 2 件）｜ 右：逐件部位放大 ----
    y2 = 34 + CH1 + 34
    dr.text((10, y2), "② 同时装备 2 件（上限 = 2）与逐件部位放大 ×%d" % Z2,
            fill=(255, 214, 130), font=font(16))
    idx = 0
    for title, ids in PAIRS:
        img = compose([(M.SLOT_Z['tattoo'], tattoo_layer(x)) for x in ids])
        cell = img.crop(tb).resize((CW2, CH2), Image.NEAREST)
        x, y = 10 + idx * (CW2 + 10), y2 + 26
        canvas.paste(cell, (x, y), cell)
        label(dr, x, y + CH2, x + CW2, title)
        idx += 1
    for iid, title in NEW:
        img = compose([(M.SLOT_Z['tattoo'], tattoo_layer(iid))])
        cell = img.crop(tb).resize((CW2, CH2), Image.NEAREST)
        x, y = 10 + idx * (CW2 + 10), y2 + 26
        canvas.paste(cell, (x, y), cell)
        label(dr, x, y + CH2, x + CW2, title)
        idx += 1

    out = os.path.join(PROJ, args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.convert('RGB').save(out)
    print("刻字纹身对照表 → %s  %dx%d" % (args.out, canvas.width, canvas.height))
    return 0


if __name__ == '__main__':
    sys.exit(main())
