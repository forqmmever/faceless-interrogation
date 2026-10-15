# -*- coding: utf-8 -*-
"""第三十四轮对照图：新补的 3 个妆容 + 3 个配饰，以及 AU 全部刺青图案的挑选表。

输出：
  screenshots/_round34_new.png        妆容（头部放大）+ 配饰（全身）
  screenshots/_tattoo_pick.png        AU bodywriting 全部图案落在左大腿上的对照表

为什么要有纹身那张：
  用户口径：「列出 au 中纹身的名字，我想从中挑选几个」。
  光列名字不够 —— 名字对不上画出来什么样，所以把 AU `bodywriting/` 下
  每个图案都按**真实的烘焙参数**贴到小人左大腿上，排成一行给人挑。

  参数不是另写一套，而是直接 import dol_prepare / dol_map，走同一套
  layer_image → tint → transform，保证图里看到的就是游戏里会看到的。

用法：
  python tools/round34_sheet.py                # 当前图包（au）
  python tools/round34_sheet.py --pack dol
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

PACKS = {
    'au': ('assets/dol_au', 'data/doll_au.json', 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3'),
    'dol': ('assets/dol', 'data/doll.json', 'E:/DOWNLOAD/Degrees of Lewdity/img'),
}

# AU bodywriting 下的 14 个图案 → 中文名（`text` 是一个目录集，另附图注）
TATTOO_CN = {
    'butterfly': '蝴蝶',
    'circle': '圆圈',
    'cross': '十字',
    'flame': '火焰',
    'flower': '花',
    'heart': '爱心',
    'paw print': '爪印',
    'skull': '骷髅',
    'square': '方块',
    'star': '星星',
    'text': '文字（32 种）',
    'triangle': '三角',
    'triquetra': '凯尔特结',
    'unicorn': '独角兽',
}

# 妆容 / 配饰两组： (标题, [物品 id])
MAKEUP_ROW = [
    ("（素颜）", []),
    ("淡妆（旧）", ["makeup_light"]),
    ("浓艳烟熏妆（旧）", ["makeup_heavy"]),
    ("烈焰红唇 ★新", ["makeup_lip"]),
    ("绯色腮红 ★新", ["makeup_blush"]),
    ("点出来的雀斑 ★新", ["makeup_freckles"]),
]
ACC_ROW = [
    ("（不戴）", []),
    ("束腰皮带（原有）", ["acc_belt"]),
    ("银质心形吊坠 ★新", ["acc_locket"]),
    ("金脚链 ★新", ["acc_anklet"]),
    ("金色手铐 ★新", ["acc_shackle"]),
]

# 头部取景（在烘焙后的 68×203 取景框里）—— AU 头心大约在 (44, 30)
HEAD_BOX_AU = (22, 6, 66, 54)
HEAD_BOX_DOL = (8, 4, 40, 36)


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
    ap.add_argument('--pack', default='au', choices=sorted(PACKS))
    ap.add_argument('--out-new', default=os.path.join('screenshots', '_round34_new.png'))
    ap.add_argument('--out-tat', default=os.path.join('screenshots', '_tattoo_pick.png'))
    args = ap.parse_args()

    asset_dir, json_rel, src_root = PACKS[args.pack]
    root = os.path.join(PROJ, asset_dir)
    with io.open(os.path.join(PROJ, json_rel), encoding='utf-8') as f:
        doll = json.load(f)

    # ---- 让 dol_prepare 按这个图包工作（它平时只在 __main__ 里设这几个全局）----
    D.P = dict(D.PACKS[args.pack])
    D.P['name'] = args.pack
    D.P['root'] = src_root
    D.OUT = os.path.join(PROJ, asset_dir)
    D.DOL_ROOT = D.PACKS['dol']['root']

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

    def compose(ids, extra=None):
        """把一组物品叠到基础层上，返回整幅 68×203 的图。"""
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        stack = list(base)
        for it in ids:
            info = items.get(it)
            if not info:
                continue
            z = slot_z.get(slot_of.get(it, ''),
                           info['layers'][0]['z'] if info['layers'] else 100.0)
            for L in info.get('layers', []):
                stack.append((z, L['file']))
        for e in (extra or []):
            stack.append(e)
        stack.sort(key=lambda t: t[0])
        for _z, rel in stack:
            im = layer(rel) if isinstance(rel, str) else rel
            if im is not None:
                img.alpha_composite(im)
        return img

    def label(dr, x0, y0, x1, text, ok=True):
        dr.rectangle([x0, y0, x1, y0 + 26], fill=(20, 22, 26, 255))
        dr.text((x0 + 6, y0 + 5), text, fill=(232, 232, 232) if ok else (240, 150, 150),
                font=font(15))

    # ================= 图 1：妆容 + 配饰 =================
    HB = HEAD_BOX_AU if args.pack == 'au' else HEAD_BOX_DOL
    ZOOM = 8
    cw = (HB[2] - HB[0]) * ZOOM
    ch = (HB[3] - HB[1]) * ZOOM
    BW = w * 3
    total_w = max(len(MAKEUP_ROW) * (cw + 8), len(ACC_ROW) * (BW + 10) + 10)
    total_h = (ch + 30) + 16 + (h * 3 + 30)
    canvas = Image.new('RGBA', (total_w + 10, total_h + 10), (24, 26, 30, 255))
    dr = ImageDraw.Draw(canvas)

    dr.text((10, 4), "① 妆容（头部放大 ×%d）" % ZOOM, fill=(255, 214, 130), font=font(17))
    for i, (title, ids) in enumerate(MAKEUP_ROW):
        img = compose(ids)
        cell = img.crop(HB).resize((cw, ch), Image.NEAREST)
        x, y = 10 + i * (cw + 8), 30
        canvas.paste(cell, (x, y), cell)
        label(dr, x, y + ch, x + cw, title, '★' in title)

    y2 = 30 + ch + 30
    dr.text((10, y2), "② 配饰（全身 ×3）", fill=(255, 214, 130), font=font(17))
    for i, (title, ids) in enumerate(ACC_ROW):
        img = compose(ids)
        big = img.resize((w * 3, h * 3), Image.NEAREST)
        x, y = 10 + i * (BW + 10), y2 + 26
        canvas.paste(big, (x, y), big)
        label(dr, x, y + h * 3, x + BW, title, '★' in title)

    out_new = os.path.join(PROJ, args.out_new)
    os.makedirs(os.path.dirname(out_new), exist_ok=True)
    canvas.convert('RGB').save(out_new)
    print("妆容/配饰表 → %s  %dx%d" % (args.out_new, canvas.width, canvas.height))

    # ================= 图 2：刺青挑选表 =================
    # 每个图案按「左大腿」位置贴（名字取 bodywriting 目录名；text 取 text/default）。
    designs = sorted(d for d in os.listdir(os.path.join(src_root, 'bodywriting'))
                     if os.path.isdir(os.path.join(src_root, 'bodywriting', d)))
    head_h = 30
    CW = int(w * 2.2)
    CH = int(h * 2.2)
    cols = 7
    rows = (len(designs) + cols - 1) // cols
    tat = Image.new('RGBA', (cols * (CW + 8) + 8, rows * (CH + head_h + 8) + 40),
                    (24, 26, 30, 255))
    dr = ImageDraw.Draw(tat)
    dr.text((10, 8), "AU bodywriting 全部 %d 个图案 · 统一落在「左大腿」（缩放 ×2.2）"
            % len(designs), fill=(255, 214, 130), font=font(17))

    miss = []
    for k, name in enumerate(designs):
        sub = 'default' if name == 'text' else None
        rel = os.path.join(src_root, 'bodywriting', name)
        if sub:
            rel = os.path.join(rel, sub)
        # 从候选文件名里挑一个「大腿」层
        cand = None
        for fn in sorted(os.listdir(rel)):
            if fn.startswith(('left-thigh', 'thigh')):
                cand = os.path.join(rel, fn)
                break
        if cand is None:
            for fn in sorted(os.listdir(rel)):
                if fn.startswith(('forehead', 'left-cheek', 'left-shoulder')):
                    cand = os.path.join(rel, fn)
                    break
        if cand is None:
            miss.append(name)
            continue
        im = D.layer_image(cand)
        bb = im.getbbox()
        # 把 bbox 中心反算回 DoL 坐标系（和 dol_map.PACK_OVERRIDE['au'] 同一套换算）
        cx, cy = (bb[0] + bb[2]) / 2.0, (bb[1] + bb[3]) / 2.0
        ax = (cx - D.P['align_origin'][0]) / D.P['align_scale'] + D.DOL_HEAD[0]
        ay = (cy - D.P['align_origin'][1]) / D.P['align_scale'] + D.DOL_HEAD[1]
        lay = D.transform(D.tint(im, M.INK), 1.5 / D.P['align_scale'],
                          ("bbox_center", ax, ay))
        # 落到取景框里
        cr = doll.get('crop') or [0, 0, w, h]
        crop2 = (cr[0], cr[1], cr[0] + w, cr[1] + h)
        lay = lay.crop(crop2)
        img = compose([], extra=[(M.SLOT_Z['tattoo'], lay)])
        big = img.resize((CW, CH), Image.NEAREST)
        x = 8 + (k % cols) * (CW + 8)
        y = 40 + (k // cols) * (CH + head_h + 8)
        tat.paste(big, (x, y), big)
        cn = TATTOO_CN.get(name, name)
        label(dr, x, y + CH, x + CW, "%s / %s" % (cn, name))

    out_tat = os.path.join(PROJ, args.out_tat)
    tat.convert('RGB').save(out_tat)
    print("刺青挑选表 → %s  %dx%d" % (args.out_tat, tat.width, tat.height))
    if miss:
        print("★ 这些图案没找到可用图层，已跳过：%s" % miss)
    return 0


if __name__ == '__main__':
    sys.exit(main())
