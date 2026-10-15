# -*- coding: utf-8 -*-
"""第三十八轮清点：把 AU 图包里还没接入的四类（masks / genitals / props / belly）
渲成对照图，让人能直接看见「里面到底有什么」。

输出（screenshots/）：
  _scan_masks_genitals.png   masks 6 张 + genitals 7 个独立图案 + belly 的遮罩一族
  _scan_belly.png            怀孕小腹系统：body/pregnant-belly 24 阶 + clothes/belly 各层
  _scan_props_a.png          props 前五个子类（general / antique / book / child toy / drink）
  _scan_props_b.png          props 后六个子类（food / furniture / ingredient / tending / sex toy / npc）
  _scan_props_general.png    props/general 单独放大（219 张，最大的一个）

裁切口径与烘焙一致：只取**全身像列**（x < 130），再裁到内容 bbox，
等比放大到单元格里 —— 所以图里看到的形状就是游戏里会长出来的形状。

用法：
  python tools/scan_unused_cats.py --sheet      # 只出图
  python tools/scan_unused_cats.py --list       # 只列明细
"""

import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)

PACK_ROOT = 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3'
CLOTHES = os.path.join(PACK_ROOT, 'clothes')
BODY = os.path.join(PACK_ROOT, 'body')
SHOTS = os.path.join(PROJ, 'screenshots')

BODY_CLIP = 130
BG = (26, 24, 30, 255)
PANEL = (40, 37, 45, 255)
TITLE_C = (255, 214, 130)
TEXT_C = (226, 220, 230)
DIM_C = (150, 145, 158)
GRID_C = (62, 58, 70)

STATE_CONV = ['-acc-underarm', '-underarm', '-basket', '-cover', '-acc', '_acc',
              '-open', '-big', '-clip']


def font(sz):
    for c in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf',
              'C:/Windows/Fonts/arial.ttf']:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, sz)
            except Exception:
                pass
    return ImageFont.load_default()


def stem_of(fn):
    """去掉「姿态 / 收纳」后缀，得到基名。"""
    s = fn[:-4] if fn.lower().endswith('.png') else fn
    for c in STATE_CONV:
        if s.endswith(c):
            return s[:-len(c)]
    return s


def load_body_crop(path):
    """读一张图并裁成「全身像列里的内容」，返回 (image, 原始 bbox) 或 None。"""
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    col = im.crop((0, 0, min(BODY_CLIP, w), h))
    bb = col.getbbox()
    if bb is None:
        return None
    return col.crop(bb), bb


def fit(im, box_w, box_h, scale):
    """等比缩放到 (box_w, box_h) 里，尽量放大 scale 倍但不超出。"""
    if im is None:
        return None
    # 先按 scale 放大，若超出就压回去
    w, h = im.size
    k = scale
    if w * k > box_w or h * k > box_h:
        k = min(box_w / float(w), box_h / float(h))
    nw = max(1, int(round(w * k)))
    nh = max(1, int(round(h * k)))
    return im.resize((nw, nh), Image.NEAREST)


class Sheet:
    def __init__(self, title, cell, cols, scale, pad=10, header=52, sub=26):
        self.title = title
        self.cell = cell
        self.cols = cols
        self.scale = scale
        self.pad = pad
        self.header = header
        self.sub = sub
        self.items = []          # (label, image|None, note)

    def add(self, label, im, note=''):
        self.items.append((label, im, note))

    def render(self, out_path, section_breaks=None):
        """section_breaks: 需要另起一段的下标集合（会空一行 + 画小标题由 items 里的 note 承担）"""
        cols = self.cols
        cw, ch = self.cell
        rows = (len(self.items) + cols - 1) // cols
        W = self.pad * 2 + cols * (cw + self.pad)
        H = self.header + self.pad + rows * (ch + self.pad + self.sub)
        canvas = Image.new('RGBA', (W, H), BG)
        dr = ImageDraw.Draw(canvas)
        dr.text((self.pad + 4, 14), self.title, fill=TITLE_C, font=font(22))

        for i, (label, im, note) in enumerate(self.items):
            r, c = divmod(i, cols)
            x = self.pad + c * (cw + self.pad)
            y = self.header + self.pad + r * (ch + self.pad + self.sub)
            dr.rectangle([x, y, x + cw, y + ch], fill=PANEL, outline=GRID_C)
            if im is not None:
                f = fit(im, cw - 8, ch - 8, self.scale)
                if f is not None:
                    canvas.alpha_composite(
                        f, (x + (cw - f.size[0]) // 2, y + (ch - f.size[1]) // 2))
            else:
                dr.text((x + 10, y + ch // 2 - 8), '（无内容）',
                        fill=DIM_C, font=font(13))
            dr.text((x + 4, y + ch + 4), label, fill=TEXT_C, font=font(13))
            if note:
                dr.text((x + 4, y + ch + 20), note, fill=DIM_C, font=font(11))

        canvas.convert('RGB').save(out_path)
        print('  saved %s (%d×%d)' % (out_path, W, H))


def sheet_masks_genitals():
    sh = Sheet('① masks（6 张可用）+ genitals（7 个独立图案）',
               cell=(150, 150), cols=7, scale=3.0)
    M = os.path.join(CLOTHES, 'masks')
    CN = {'formfitting-breasts': '贴合·胸', 'formfitting-curvy': '贴合·丰腴',
          'formfitting-slender': '贴合·纤细', 'soft-clip': '柔软·裁切',
          'soft-lower-clip': '柔软·下裁切', 'soft-shadow': '柔软·阴影'}
    for fn in sorted(os.listdir(M)):
        if not fn.endswith('.png'):
            continue
        r = load_body_crop(os.path.join(M, fn))
        s = stem_of(fn)
        sh.add(CN.get(s, s), None if r is None else r[0],
               '' if r else '全透明占位')
    G = os.path.join(CLOTHES, 'genitals')
    GCN = {'chastitybelt': '贞操带', 'chastitybeltfetish': '贞操带·恋物',
           'chastitycage': '贞操笼', 'chastitycagefetish': '贞操笼·恋物(同图)',
           'flatchastitycage': '平坦贞操笼', 'goldchastitybelt': '金贞操带',
           'smallchastitycage': '小贞操笼', 'strapon': '穿戴式假阳具'}
    for style in sorted(os.listdir(G)):
        d = os.path.join(G, style)
        if not os.path.isdir(d):
            continue
        r = load_body_crop(os.path.join(d, 'full.png'))
        note = '四态仅此一件有差异' if style == 'chastitybeltfetish' else '四态同图'
        sh.add(GCN.get(style, style), None if r is None else r[0], note)
    sh.render(os.path.join(SHOTS, '_scan_masks_genitals.png'))


def sheet_belly():
    # 上排：body/pregnant-belly 的 24 阶（这是小腹本体）
    sh = Sheet('② belly 怀孕小腹系统 ｜ 上排 body/pregnant-belly 24 阶 · 下排 clothes/belly 的遮罩与阴影',
               cell=(96, 130), cols=12, scale=2.0)
    PB = os.path.join(BODY, 'pregnant-belly')
    for i in range(1, 25):
        p = os.path.join(PB, '%d.png' % i)
        r = load_body_crop(p)
        sh.add('%d 阶' % i, None if r is None else r[0])
    B = os.path.join(CLOTHES, 'belly')
    order = ([('belly-mask.png', '小腹遮罩·基准')]
             + [('mask-%d.png' % i, '遮罩 %d' % i) for i in range(15, 25)]
             + [('mask-min-%d.png' % i, '最简遮罩 %d' % i) for i in range(15, 25)]
             + [('mask-clip-%d.png' % i, '裁切遮罩 %d' % i) for i in range(15, 25)]
             + [('shadow-%d.png' % i, '阴影 %d' % i) for i in list(range(8, 25))]
             + [('belly-mask-upper-shadow.png', '上阴影'),
                ('belly-mask-upper-shadow-2.png', '上阴影 2'),
                ('belly-mask-lower-shadow.png', '下阴影'),
                ('belly-mask-lower-shadow-2.png', '下阴影 2'),
                ('belly-mask-lower-shadow-3.png', '下阴影 3'),
                ('mask-shirt-breasts.png', '衬衫遮罩·胸'),
                ('mask-shirt-clip.png', '衬衫裁切'),
                ('mask-shirt-clip-big.png', '衬衫裁切·大')])
    for fn, label in order:
        r = load_body_crop(os.path.join(B, fn))
        sh.add(label, None if r is None else r[0])
    sh.render(os.path.join(SHOTS, '_scan_belly.png'))


def collect_props(subs):
    """返回 [(子类, 基名, 路径, 变体数), ...]，按基名归并、只留一张代表。"""
    out = []
    for sub in subs:
        base = os.path.join(CLOTHES, 'props', sub)
        if not os.path.isdir(base):
            continue
        groups = {}
        for root, dirs, files in os.walk(base):
            dirs.sort()
            for fn in sorted(files):
                if not fn.lower().endswith('.png'):
                    continue
                st = stem_of(fn)
                groups.setdefault(st, []).append(os.path.join(root, fn))
        for st in sorted(groups):
            paths = groups[st]
            # 代表优先取「裸名」full / 基名本身
            pick = None
            for p in paths:
                if os.path.basename(p)[:-4] == st:
                    pick = p
                    break
            if pick is None:
                pick = paths[0]
            out.append((sub, st, pick, len(paths)))
    return out


def sheet_props(subs, title, out_name, cell=(78, 78), cols=14, scale=2.2):
    sh = Sheet(title, cell=cell, cols=cols, scale=scale)
    rows = collect_props(subs)
    for sub, st, pick, nvar in rows:
        r = load_body_crop(pick)
        note = '%s%s' % (sub, '' if nvar == 1 else ' ×%d' % nvar)
        sh.add(st, None if r is None else r[0], note)
    sh.render(os.path.join(SHOTS, out_name))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sheet', action='store_true')
    args = ap.parse_args()

    os.makedirs(SHOTS, exist_ok=True)
    print('生成清点对照图：')
    sheet_masks_genitals()
    sheet_belly()
    sheet_props(['general'], '③ props/general（219 张 → 归并后）',
                '_scan_props_general.png')
    sheet_props(['antique', 'book', 'child toy', 'drink'],
                '④ props：antique / book / child toy / drink', '_scan_props_a.png')
    sheet_props(['food', 'furniture', 'ingredient', 'tending', 'sex toy', 'npc'],
                '⑤ props：food / furniture / ingredient / tending / sex toy / npc',
                '_scan_props_b.png')
    print('完成。')


if __name__ == '__main__':
    main()
