# -*- coding: utf-8 -*-
"""清点 AU 图包里还没接入的四类：masks / genitals / props / belly。

量每张 png 的：
  size      画布尺寸（AU 好图层应是 512×256；混进来的旧几何是 256×128）
  bbox      非透明像素的包围盒
  body      包围盒是否落在「全身像列」（x < 130）—— 只有落在这一列的才用得上，
            右边那列是胸像，游戏里根本不画
  alpha     是否全透明（占位图）

用法：
  python tools/scan_unused_cats.py            # 汇总
  python tools/scan_unused_cats.py --list     # 逐张列明细
"""

import argparse
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image

PACK_ROOT = 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3'
CLOTHES = os.path.join(PACK_ROOT, 'clothes')
CATS = ['masks', 'genitals', 'props', 'belly']

BODY_CLIP = 130          # 全身像列右边界（与 dol_prepare 的 crop_clip 一致）
AU_CANVAS = (512, 256)
OLD_GEOM = (256, 128)


def measure(path):
    """量一张图：尺寸 / 非透明 bbox / 是否有内容。"""
    try:
        im = Image.open(path).convert('RGBA')
    except Exception as e:
        return {'err': str(e)}
    w, h = im.size
    bbox = im.getbbox()
    if bbox is None:
        return {'size': (w, h), 'bbox': None, 'body': None, 'empty': True}
    x0, y0, x1, y1 = bbox
    # 全身像列里有没有不透明像素
    left = im.crop((0, 0, min(BODY_CLIP, w), h)).getbbox()
    return {
        'size': (w, h),
        'bbox': bbox,
        'body': left,
        'empty': False,
        'au_geom': (w, h) == AU_CANVAS,
        'old_geom': (w, h) == OLD_GEOM,
    }


def geometry_label(r):
    if r.get('err'):
        return '读取失败'
    if r.get('empty'):
        return '全透明占位'
    if r.get('au_geom'):
        return 'AU 新几何'
    if r.get('old_geom'):
        return 'DoL 旧几何'
    return '%d×%d 其它' % r['size']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', action='store_true', help='逐张列明细')
    args = ap.parse_args()

    grand = Counter()
    for cat in CATS:
        base = os.path.join(CLOTHES, cat)
        if not os.path.isdir(base):
            print('!! 目录不存在:', base)
            continue

        # 收集 (子目录, 文件名, 完整路径)
        rows = []
        for root, dirs, files in os.walk(base):
            dirs.sort()
            for fn in sorted(files):
                if not fn.lower().endswith('.png'):
                    continue
                full = os.path.join(root, fn)
                sub = os.path.relpath(root, base)
                sub = '' if sub == '.' else sub
                rows.append((sub, fn, full))

        print('=' * 70)
        print('【%s】共 %d 张 png' % (cat, len(rows)))
        print('=' * 70)

        by_sub = defaultdict(lambda: {'n': 0, 'geoms': Counter(),
                                      'usable': 0, 'empty': 0})
        for sub, fn, full in rows:
            r = measure(full)
            g = geometry_label(r)
            e = by_sub[sub]
            e['n'] += 1
            e['geoms'][g] += 1
            if r.get('empty'):
                e['empty'] += 1
            elif r.get('body') is not None:
                e['usable'] += 1
            grand[g] += 1

        for sub in sorted(by_sub):
            e = by_sub[sub]
            name = sub if sub else '(根目录)'
            gs = '  '.join('%s×%d' % (k, v) for k, v in sorted(e['geoms'].items()))
            print('  %-22s %4d 张 ｜ 全身像列可用 %3d ｜ 空 %2d ｜ %s' % (
                name, e['n'], e['usable'], e['empty'], gs))
            if args.list:
                for sub2, fn, full in rows:
                    if sub2 != sub:
                        continue
                    r = measure(full)
                    bb = '——' if r.get('bbox') is None else '%d,%d-%d,%d' % r['bbox']
                    print('      %-34s %-12s bbox %s' % (fn, geometry_label(r), bb))
        print()

    print('=' * 70)
    print('四类合计 %d 张 ｜ 几何分布：' % sum(grand.values()))
    for k, v in sorted(grand.items(), key=lambda kv: -kv[1]):
        print('  %-14s %d' % (k, v))


if __name__ == '__main__':
    main()
