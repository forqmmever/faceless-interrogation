"""三方像素比对：判断「截图变了」是回归还是噪声。

用法（三个目录里放同名的 PNG）：

    python tools/cmp_shots.py <①提交版> <②HEAD重跑> <③本轮>

三列的含义：

    ①vs②  仓库里那套 vs 用 HEAD 代码重拍   → 非 0 说明**仓库那张是旧货**
    ②vs③  只用同一份数据、只换本轮改动     → **这一列才是本轮真正的改动**
    ①vs③  仓库 vs 本轮

★ 只看 ②vs③ 就下结论 —— 别把「仓库里的过期货」误判成本轮的改动。
★ 依赖 Pillow（项目默认 venv 里有）。
"""
import os
import sys

from PIL import Image, ImageChops


def diff(a, b):
    ia = Image.open(a).convert("RGB")
    ib = Image.open(b).convert("RGB")
    if ia.size != ib.size:
        return -1, ia.size
    d = ImageChops.difference(ia, ib)
    if d.getbbox() is None:
        return 0, ia.size
    # 逐像素计数；百分比的分母 = 整屏像素数
    n = sum(1 for px in d.getdata() if px != (0, 0, 0))
    return n, ia.size


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 1
    a, b, c = sys.argv[1:4]
    names = sorted(f for f in os.listdir(a) if f.endswith(".png"))
    print("%-34s %10s %10s %10s" % ("file", "①vs②", "②vs③", "①vs③"))
    changed = 0
    for n in names:
        p1, p2, p3 = (os.path.join(d, n) for d in (a, b, c))
        if not all(os.path.exists(p) for p in (p1, p2, p3)):
            print("%-34s  missing" % n)
            continue
        d12, size = diff(p1, p2)
        d23, _ = diff(p2, p3)
        d13, _ = diff(p1, p3)
        if not (d12 or d23 or d13):
            continue
        changed += 1
        total = size[0] * size[1]
        pct = (100.0 * d23 / total) if d23 > 0 else 0.0
        print("%-34s %10d %10d %10d   (②vs③ %.3f%%)" % (n, d12, d23, d13, pct))
    print("\n共 %d 张，其中 %d 张有差异" % (len(names), changed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
