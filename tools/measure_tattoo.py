"""量新烘的两枚爪印落在身体/头部轮廓上的比例。

判据（沿用既有约定）：至少 85% 的墨点落在皮肤上算合格；
颈侧 65% / 颊 76% / 大腿 81% 是第二十六轮那次翻车的下限。

只读。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLOTHES = os.path.join(ROOT, "assets", "dol_au", "clothes")
BASE = os.path.join(ROOT, "assets", "dol_au", "base")

body = Image.open(os.path.join(BASE, "body.png")).convert("RGBA")
head = Image.open(os.path.join(BASE, "head.png")).convert("RGBA")
W, H = body.size
bp, hp = body.load(), head.load()

skin = set()
for y in range(H):
    for x in range(W):
        if bp[x, y][3] > 0 or hp[x, y][3] > 0:
            skin.add((x, y))

for name in ["tattoo_paw.png", "tattoo_paw_chest.png", "tattoo_paw_face.png",
             "tattoo_cheek.png", "tattoo_neck.png", "tattoo_slave.png"]:
    im = Image.open(os.path.join(CLOTHES, name)).convert("RGBA")
    px = im.load()
    pts = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 8]
    if not pts:
        print(f"{name:24s} 空")
        continue
    on = sum(1 for p in pts if p in skin)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bb = im.getbbox()
    print(f"{name:24s} n={len(pts):4d}  落在皮肤 {on:4d}/{len(pts)} = {100.0*on/len(pts):5.1f}%"
          f"   bbox={bb}   x {min(xs)}-{max(xs)}  y {min(ys)}-{max(ys)}")
