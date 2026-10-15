# -*- coding: utf-8 -*-
"""第三十五轮对照图：新补的两件大腿纹身（heart / paw print）与原有三件并排。

输出：
  screenshots/_round35_tattoo.png   上排五款纹身全身、下排三款大腿纹身放大

参数不是另写一套，而是直接 import dol_prepare / dol_map，走同一套
layer_image -> tint -> transform，保证图里看到的就是游戏里会看到的。

用法：
  python tools/round35_sheet.py
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

# (标题, 覆盖参数, 目标放大倍数) —— 目标倍数就是 dol_map.AU_OVERRIDE 里写的那个 s
ROW1 = [
    ("（无）", None, None),
    ("颈侧暗纹", ("flower", "left-shoulder"), 1.0),
    ("面颊刺青", ("star", "left-cheek"), 1.5),
    ("大腿藤蔓（旧）", ("flower", "left-thigh"), 1.5),
    ("大腿心形 ★新", ("heart", "left-thigh"), 0.7),
    ("大腿爪印 ★新", ("paw print", "left-thigh"), 4.0),
]
ROW2 = [
    ("大腿藤蔓（旧）", ("flower", "left-thigh"), 1.5),
    ("大腿心形 ★新", ("heart", "left-thigh"), 0.7),
    ("大腿爪印 ★新", ("paw print", "left-thigh"), 4.0),
]

THIGH_BOX_AU = (20, 90, 58, 175)     # 68×203 取景框里的大腿区


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
    ap.add_argument('--out', default=os.path.join('screenshots', '_round35_tattoo.png'))
    args = ap.parse_args()

    asset_dir, json_rel, src_root = PACK
    root = os.path.join(PROJ, asset_dir)
    with io.open(os.path.join(PROJ, json_rel), encoding='utf-8') as f:
        doll = json.load(f)

    D.P = dict(D.PACKS['au'])
    D.P['name'] = 'au'
    D.P['root'] = src_root
    D.OUT = os.path.join(PROJ, asset_dir)

    w, h = doll['size']
    base = [(L['z'], L['file']) for L in doll['base']]
    crop = doll.get('crop') or [0, 0, w, h]
    bodywriting = os.path.join(src_root, 'bodywriting')

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

    def tattoo_layer(src, target_s):
        """按 dol_map 同一套换算，把 bodywriting 图案贴到取景框里。"""
        im = D.layer_image(os.path.join(bodywriting, src[0], src[1] + '.png'))
        bb = im.getbbox()
        cx, cy = (bb[0] + bb[2]) / 2.0, (bb[1] + bb[3]) / 2.0
        ax = (cx - D.P['align_origin'][0]) / D.P['align_scale'] + D.DOL_HEAD[0]
        ay = (cy - D.P['align_origin'][1]) / D.P['align_scale'] + D.DOL_HEAD[1]
        lay = D.transform(D.tint(im, M.INK), target_s / D.P['align_scale'],
                          ("bbox_center", round(ax, 2), round(ay, 2)))
        return lay.crop((crop[0], crop[1], crop[0] + w, crop[1] + h))

    def label(dr, x, y, x1, text):
        dr.rectangle([x, y, x1, y + 26], fill=(20, 22, 26, 255))
        dr.text((x + 6, y + 5), text,
                fill=(255, 214, 130) if '★' in text else (232, 232, 232), font=font(14))

    Z1, Z2 = 3, 8
    CW1, CH1 = w * Z1, h * Z1
    tb = THIGH_BOX_AU
    CW2, CH2 = (tb[2] - tb[0]) * Z2, (tb[3] - tb[1]) * Z2

    width = max(len(ROW1) * (CW1 + 10) + 10, len(ROW2) * (CW2 + 10) + 10)
    height = 34 + CH1 + 30 + 34 + CH2 + 30
    canvas = Image.new('RGBA', (width, height), (24, 26, 30, 255))
    dr = ImageDraw.Draw(canvas)

    dr.text((10, 8), "① 五款纹身（全身 ×%d）" % Z1, fill=(255, 214, 130), font=font(16))
    for i, (title, src, s) in enumerate(ROW1):
        img = compose([]) if src is None else compose(
            [(M.SLOT_Z['tattoo'], tattoo_layer(src, s))])
        big = img.resize((CW1, CH1), Image.NEAREST)
        x, y = 10 + i * (CW1 + 10), 34
        canvas.paste(big, (x, y), big)
        label(dr, x, y + CH1, x + CW1, title)

    y2 = 34 + CH1 + 30
    dr.text((10, y2), "② 三款大腿纹身（大腿区放大 ×%d）" % Z2, fill=(255, 214, 130),
            font=font(16))
    for i, (title, src, s) in enumerate(ROW2):
        img = compose([(M.SLOT_Z['tattoo'], tattoo_layer(src, s))])
        cell = img.crop(tb).resize((CW2, CH2), Image.NEAREST)
        x, y = 10 + i * (CW2 + 10), y2 + 26
        canvas.paste(cell, (x, y), cell)
        label(dr, x, y + CH2, x + CW2, title)

    out = os.path.join(PROJ, args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.convert('RGB').save(out)
    print("纹身对照表 → %s  %dx%d" % (args.out, canvas.width, canvas.height))
    return 0


if __name__ == '__main__':
    sys.exit(main())
