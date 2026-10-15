# -*- coding: utf-8 -*-
"""生成「挑鞋子 / 挑发型」对照图 —— 把 AU 图包里的款式逐个渲染成能看的图。

★ 三档分类（第四十五轮查明）：
  A 档 · 可用（推荐）—— **AU 新几何 512×256 + 灰度蒙版**（sat ≤ 0.05）
    灰度蒙版是图包作者专为「乘色」画的，明暗关系正确，效果最可控。
  B 档 · 可用（需试色）—— **AU 新几何 512×256，但是彩色**
    ★ 关键：`tint()` 是**先把源像素转成灰度、再乘目标色**（见 dol_prepare.tint），
      所以彩色源**技术上完全能用**，残留色不会漏进来（饱和度只由目标色决定）。
      只是明暗关系来自原彩色的亮度分布，可能不理想 —— 需要实烘一次看效果。
      项目现有的 `shoes_school_navy` 就是这么用的（源图 schoolshoes 是彩色）。
  × 不可用 —— **DoL 旧几何**（256×128 / 256×256）
    这是**硬伤**：几何不对，贴上去位置会整个错位。AU 图包里混着一批 DoL 旧款
    （名字与新款相同），必须排除。

输出（screenshots/）：
  _pick_feet.png          鞋子（含 A/B 档标注）
  _pick_hair_sides.png    发型 · 侧面（主体）
  _pick_hair_fringe.png   发型 · 刘海
  _pick_hair_back.png     发型 · 脑后

用法：
  python tools/make_pick_sheets.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
SHOTS = os.path.join(PROJ, 'screenshots')

PACK = 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3'
BODY_CLIP = 130
AU_CANVAS = (512, 256)
LENGTHS = ['short', 'shoulder', 'chest', 'navel', 'thighs', 'feet']

HAIR_TINT = (0.42, 0.30, 0.21)
HAIR_GAIN = 1.25

BG = (26, 24, 30, 255)
PANEL = (40, 37, 45, 255)
PANEL_B = (44, 40, 34, 255)          # B 档（需试色）底色偏暖，一眼能区分
TITLE_C = (255, 214, 130)
TEXT_C = (226, 220, 230)
DIM_C = (150, 145, 158)
WARN_C = (232, 176, 96)
GRID_C = (62, 58, 70)


def font(sz):
    for c in ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf',
              'C:/Windows/Fonts/arial.ttf']:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, sz)
            except Exception:
                pass
    return ImageFont.load_default()


def pick_main_png(pngs):
    """按项目 `resolve()` 的同一顺序挑主体图 —— 保证「清单里看到的」= 「游戏里会用的」。

    顺序（照 dol_prepare.resolve）：
      0. 先滤掉 `-acc` / `_acc` 变体（那是「附加装饰」那一层，不是主体）
      1. full.png
      2. full*（AU 里不少件只有 full-alt / full_gray）
      3. 带 idle 的
      4. 数字名
      5. 其余按名字排第一个
    """
    cand = [f for f in pngs if not f.startswith('mask')]
    body = [f for f in cand if not (f[:-4].endswith('-acc') or f[:-4].endswith('_acc'))]
    order = []
    for f in body:
        if f == 'full.png':
            order.append((0, f))
        elif f.startswith('full'):
            order.append((1, f))
        elif 'idle' in f:
            order.append((2, f))
        elif f[:-4].isdigit():
            order.append((3, f))
        else:
            order.append((4, f))
    order.sort()
    return [f for _, f in order]


def load_any(path):
    """读图并裁到全身像列。返回 (图, 原始尺寸) 或 None。"""
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert('RGBA')
    return im.crop((0, 0, min(BODY_CLIP, im.size[0]), im.size[1])), im.size


def grade(im, size):
    """判档：'A' / 'B' / None（None = 不可用）。"""
    if im is None or size != AU_CANVAS:
        return None
    bbox = im.getbbox()
    if bbox is None:
        return None
    sub = im.crop(bbox)
    tot = 0
    s = 0.0
    for r, g, b, a in sub.getdata():
        if a > 32:
            mx, mn = max(r, g, b), min(r, g, b)
            s += 0.0 if mx == 0 else (mx - mn) / float(mx)
            tot += 1
    if not tot:
        return None
    return 'A' if (s / tot) <= 0.05 else 'B'


def tint(im, colour, gain=1.0):
    """与 dol_prepare.tint 一致：先转灰度、再乘目标色。"""
    r, g, b = colour
    px = im.load()
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    op = out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            cr, cg, cb, a = px[x, y]
            if a == 0:
                continue
            lum = (cr * 299 + cg * 587 + cb * 114) / 1000.0 / 255.0
            if gain != 1.0:
                lum = min(1.0, lum * gain)
            op[x, y] = (int(r * lum * 255), int(g * lum * 255),
                        int(b * lum * 255), a)
    return out


class Sheet:
    def __init__(self, title, cell, cols, focus, base_img, tint_layers=False,
                 pad=8, header=68, sub=30):
        self.title = title
        self.cell = cell
        self.cols = cols
        self.focus = focus
        self.base = base_img
        self.tint_layers = tint_layers
        self.pad = pad
        self.header = header
        self.sub = sub
        self.items = []          # (label, layer, grade, note)

    def add(self, label, layer, g, note=''):
        self.items.append((label, layer, g, note))

    def _render_one(self, layer):
        canvas = Image.new('RGBA', (BODY_CLIP, AU_CANVAS[1]), (0, 0, 0, 0))
        if self.base is not None:
            canvas.alpha_composite(self.base)
        if layer is not None:
            lay = tint(layer, HAIR_TINT, HAIR_GAIN) if self.tint_layers else layer
            canvas.alpha_composite(lay)
        crop = canvas.crop(self.focus)
        cw, ch = self.cell
        k = min(cw / float(crop.size[0]), ch / float(crop.size[1])) * 1.0
        nw = max(1, int(round(crop.size[0] * k)))
        nh = max(1, int(round(crop.size[1] * k)))
        return crop.resize((nw, nh), Image.NEAREST)

    def render(self, out_path):
        cols = self.cols
        cw, ch = self.cell
        rows = (len(self.items) + cols - 1) // cols
        W = self.pad * 2 + cols * (cw + self.pad)
        H = self.header + self.pad + rows * (ch + self.pad + self.sub)
        canvas = Image.new('RGBA', (W, H), BG)
        dr = ImageDraw.Draw(canvas)
        dr.text((self.pad + 4, 12), self.title, fill=TITLE_C, font=font(21))
        dr.text((self.pad + 4, 40),
                "A = 灰度蒙版（推荐）　B = 彩色（tint 会先转灰度，能用但需试色）"
                "　编号与清单对应", fill=DIM_C, font=font(12))

        for i, (label, layer, g, note) in enumerate(self.items):
            r, c = divmod(i, cols)
            x = self.pad + c * (cw + self.pad)
            y = self.header + self.pad + r * (ch + self.pad + self.sub)
            dr.rectangle([x, y, x + cw, y + ch],
                         fill=(PANEL_B if g == 'B' else PANEL), outline=GRID_C)
            im = self._render_one(layer)
            canvas.alpha_composite(im, (x + (cw - im.size[0]) // 2,
                                        y + (ch - im.size[1]) // 2))
            col = WARN_C if g == 'B' else TEXT_C
            dr.text((x + 3, y + ch + 3), "%d.[%s] %s" % (i + 1, g, label),
                    fill=col, font=font(12))
            if note:
                dr.text((x + 3, y + ch + 18), note, fill=DIM_C, font=font(10))

        canvas.convert('RGB').save(out_path)
        na = sum(1 for it in self.items if it[2] == 'A')
        nb = sum(1 for it in self.items if it[2] == 'B')
        print('  saved %s (%d×%d) ｜ %d 款（A %d / B %d）' % (
            out_path, W, H, len(self.items), na, nb))


def feet_sheet():
    main = load_any(os.path.join(PACK, 'body', 'base-classic.png'))
    base = main[0] if main else None
    # 鞋在小人脚部；裁一条包含双脚的横条，放大
    sh = Sheet('AU 可用鞋子（逐个叠在小人脚上）', cell=(146, 86), cols=8,
               focus=(58, 152, 134, 198), base_img=base)
    d = os.path.join(PACK, 'clothes', 'feet')
    skipped = []
    for st in sorted(os.listdir(d)):
        p = os.path.join(d, st)
        if not os.path.isdir(p):
            continue
        pngs = sorted(f for f in os.listdir(p) if f.lower().endswith('.png'))
        pick = None
        for f in pick_main_png(pngs):
            r = load_any(os.path.join(p, f))
            if r is None:
                continue
            g = grade(r[0], r[1])
            if g is not None:
                pick = (f, r[0], g)
                break
        if pick is None:
            # 说明为什么不可用
            why = '没有可读的 png'
            for f in pngs:
                r = load_any(os.path.join(p, f))
                if r is not None:
                    why = '旧几何 %d×%d' % r[1]
                    break
            skipped.append('%s(%s)' % (st, why))
            continue
        fname, im, g = pick
        note = '' if fname == 'full.png' else ('主图 %s' % fname)
        sh.add(st, im, g, note)
    sh.render(os.path.join(SHOTS, '_pick_feet.png'))
    print('     不可用 %d 款（DoL 旧几何，硬伤）：%s' % (
        len(skipped), '、'.join(skipped)))


def hair_sheet(part, out_name, title, focus, base_kind, cols):
    r = load_any(os.path.join(PACK, 'body', base_kind))
    base = r[0] if r else None
    cell = (118, 118) if base_kind == 'base-head.png' else (98, 148)
    sh = Sheet(title, cell=cell, cols=cols, focus=focus, base_img=base,
               tint_layers=True)
    d = os.path.join(PACK, 'hair', part)
    skipped = []
    for st in sorted(os.listdir(d)):
        p = os.path.join(d, st)
        if not os.path.isdir(p):
            continue
        # 取「最长且可用」的长度档
        best = None
        for L in reversed(LENGTHS):
            r2 = load_any(os.path.join(p, L + '.png'))
            if r2 is None:
                continue
            g = grade(r2[0], r2[1])
            if g is None:
                continue
            best = (L, r2[0], g)
            break
        if best is None:
            skipped.append(st)
            continue
        L, im, g = best
        sh.add(st, im, g, L)
    sh.render(os.path.join(SHOTS, out_name))
    print('     不可用 %d 款：%s' % (len(skipped), '、'.join(skipped)))


def main():
    os.makedirs(SHOTS, exist_ok=True)
    print('生成挑选对照图：')
    feet_sheet()
    hair_sheet('sides', '_pick_hair_sides.png',
               'AU 可用发型 · 侧面（发型主体；小字是该款用的长度档）',
               (18, 4, 74, 66), 'base-head.png', 8)
    hair_sheet('fringe', '_pick_hair_fringe.png',
               'AU 可用发型 · 刘海（小字是长度档）',
               (18, 4, 74, 66), 'base-head.png', 8)
    hair_sheet('back', '_pick_hair_back.png',
               'AU 可用发型 · 脑后（只有长发款才有这一层）',
               (10, 40, 90, 170), 'base-classic.png', 7)
    print('完成。')


if __name__ == '__main__':
    main()
