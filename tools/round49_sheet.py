# -*- coding: utf-8 -*-
"""第四十九轮：成装「只烘上半身」bug 的**修复前后对照图**。

为什么单独出一张图：
    这个 bug 从第三十七轮活到第四十九轮（用户报「护士服和服显示上半身」），
    期间 580 条断言一条都没响 —— 因为它不是「文件缺失」也不是「内容全透明」，
    而是**少叠了一层源图**，只有把像素实际延伸到哪儿画出来才看得见。

左边 = 修复前（只叠 `upper/<款>`）；右边 = 修复后（`upper` + `lower` 两层）。
两边的底图、染色、取景框完全一致，唯一的差别就是有没有叠下半截。

用法：
    python tools/round49_sheet.py
输出：
    screenshots/_round49_dress_fix.png
"""

import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from PIL import Image                                               # noqa: E402
import dol_prepare as dp                                            # noqa: E402

SHOTS = os.path.join(ROOT, "screenshots")

# 成装 -> (upper 源目录名, lower 源目录名, 染色, 中文名)
#   染色必须与 dol_map.py 里那条映射一致，否则颜色对不上。
ITEMS = [
    ("dress_nurse",     "pinknurse",     "WHITE",     "粉色护士服"),
    ("dress_kimono",    "kimonomini",    "NAVY_DARK", "短款和服"),
    ("dress_cheongsam", "cheongsamshort", "QIPAO",    "开衩短旗袍"),
    ("dress_maid",      "maid",          "DARKGREY",  "黑白女仆装"),
    ("dress_transparent", "transparentnurse", "SKIN_SILK", "透明纱睡袍"),
    ("dress_leather",   "leatherdress",  "LEATHER",   "皮质紧身裙"),
    ("dress_swan",      "swandress",     "WINE",      "高开衩天鹅绒长裙"),
]

# 染色常量从 dol_map 里取 —— 保证两边一致，不手抄
import dol_map as dm                                                # noqa: E402

# 取景框：dol_prepare 里的 crop 是 (62, 0, 130, 203)，纯平移、无缩放
CROP = (62, 0, 130, 203)
W = CROP[2] - CROP[0]
H = CROP[3] - CROP[1]

SCALE = 3
PAD = 6
BG = (246, 246, 249, 255)


def load_win(path):
    """读源图 → 裁到取景框（得到视口坐标系）。"""
    im = Image.open(path).convert("RGBA")
    return im.crop(CROP)


def layer(name, sub, tint_name):
    p = os.path.join(dp.P["root"], "clothes", sub, name, "full.png")
    if not os.path.exists(p):
        return None
    im = load_win(p)
    if tint_name and tint_name != "None":
        im = dp.tint(im, getattr(dm, tint_name))
    return im


def compose(under, overlays):
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for im in under + overlays:
        if im is not None:
            c.alpha_composite(im)
    return c


def main():
    # 底图：身体 + 头 + 眼睛 + 短发（与 round48_sheet 同一套，保证可比）
    base = []
    for n in ["head.png", "body.png", "brow.png", "eyelids.png", "sclera.png",
              "iris.png", "lashes.png", "mouth.png",
              "hair_short_fringe.png", "hair_short_sides.png"]:
        p = os.path.join(ROOT, "assets", "dol_au", "base", n)
        if os.path.exists(p):
            base.append(Image.open(p).convert("RGBA"))

    cells = []
    for _id, sub, tint_name, cn in ITEMS:
        up = layer(sub, "upper", tint_name)
        lo = layer(sub, "lower", tint_name)
        if up is None:
            print("!! 缺 upper:", sub)
            continue
        # 左 = 修复前（只有 upper）；右 = 修复后（upper + lower）
        cells.append((cn + "\n修复前", compose(base, [up])))
        cells.append((cn + "\n修复后", compose(base, [up, lo])))

    ROWS = len(ITEMS)
    COLS = 2
    cw, ch = W * SCALE, H * SCALE
    sheet = Image.new("RGBA", (COLS * cw + (COLS + 1) * PAD,
                               ROWS * ch + (ROWS + 1) * PAD), BG)
    for i, (label, c) in enumerate(cells):
        r, col = divmod(i, COLS)
        sheet.alpha_composite(c.resize((cw, ch), Image.NEAREST),
                              (PAD + col * (cw + PAD), PAD + r * (ch + PAD)))

    os.makedirs(SHOTS, exist_ok=True)
    out = os.path.join(SHOTS, "_round49_dress_fix.png")
    sheet.convert("RGB").save(out)
    print("ok ->", out, sheet.size)
    print("%d 行 × 2 列（左=修复前 / 右=修复后）" % ROWS)
    for i, (_id, _sub, _t, cn) in enumerate(ITEMS):
        print("   第 %d 行 %s" % (i + 1, cn))


if __name__ == "__main__":
    main()
