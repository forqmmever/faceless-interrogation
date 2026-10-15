"""把这一轮新增的 8 件（6 配饰 + 2 纹身）渲染成一张对照图。

每格 = 身体 + 头部 + 眼睛 + 短发 + 那一件，放大 3 倍。
只读；输出 screenshots/_round48_new.png。
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "assets", "dol_au", "base")
CL = os.path.join(ROOT, "assets", "dol_au", "clothes")
SHOTS = os.path.join(ROOT, "screenshots")

SCALE = 3
UNDER = ["head.png", "body.png", "brow.png", "eyelids.png", "sclera.png",
         "iris.png", "lashes.png", "mouth.png",
         "hair_short_fringe.png", "hair_short_sides.png"]
# 短裤 + 素色上衣当底，免得纹身/腿环被看错位置
DRESS = ["top_plain.png", "bottom_knee.png"]

ITEMS = [
    ("tattoo_paw_chest", "胸口爪印"),
    ("tattoo_paw_face", "脸颊爪印"),
    # ★ 第四十九轮删了两条腿环（用户口径），这里同步撤掉
    ("acc_choker_bunny", "兔女郎项圈"),
    ("acc_choker_whitney", "Whitney 的项圈"),
    ("acc_choker_leash", "带牵引绳项圈"),
    ("acc_choker_whitney_leash", "Whitney 的牵引项圈"),
]

REF = Image.open(os.path.join(BASE, "body.png")).convert("RGBA")
W, H = REF.size

cells = []
for iid, label in ITEMS:
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for n in UNDER + DRESS:
        p = os.path.join(BASE, n)
        if not os.path.exists(p):
            p = os.path.join(CL, n)
        if os.path.exists(p):
            c.alpha_composite(Image.open(p).convert("RGBA"))
    p = os.path.join(CL, iid + ".png")
    if not os.path.exists(p):
        print("缺", p)
        continue
    c.alpha_composite(Image.open(p).convert("RGBA"))
    cells.append((label, c))

cw, ch = W * SCALE, H * SCALE
COLS = 4
ROWS = (len(cells) + COLS - 1) // COLS
PAD = 6
sheet = Image.new("RGBA", (COLS * cw + (COLS + 1) * PAD,
                           ROWS * ch + (ROWS + 1) * PAD), (246, 246, 249, 255))
for i, (label, c) in enumerate(cells):
    r, col = divmod(i, COLS)
    x = PAD + col * (cw + PAD)
    y = PAD + r * (ch + PAD)
    sheet.alpha_composite(c.resize((cw, ch), Image.NEAREST), (x, y))

os.makedirs(SHOTS, exist_ok=True)
out = os.path.join(SHOTS, "_round48_new.png")
sheet.convert("RGB").save(out)
print("ok ->", out, sheet.size)
print("顺序（左→右，上→下）：")
for i, (label, _) in enumerate(cells):
    print("   %d %s" % (i + 1, label))
