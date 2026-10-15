# -*- coding: utf-8 -*-
"""清点 AU 图包里可用的**鞋子**与**发型**款式，供挑选。

筛选依据（沿用项目已有约定，见 memory 的「AU 只认新几何」）：
  · 几何必须是 **512×256** —— AU 是照着 DoL 的目录结构重画的，
    但它**同时留着 DoL 的旧款**（名字一样、仍是 256×128 旧几何）；
  · 饱和度必须是 **0.00** —— 新几何的图层是**灰度蒙版**（靠 tint 上色），
    而 DoL 旧款是**彩色**（红色）。两个条件缺一不可。

量 bbox 前先裁到**全身像列**（x < 130），因为右边那列是胸像、游戏里不画。

用法：
  python tools/list_feet_hair.py            # 汇总
  python tools/list_feet_hair.py --long     # 含每个长度档的明细
"""

import argparse
import io
import os
import sys

from PIL import Image

PACK = 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3'
BODY_CLIP = 130
AU_CANVAS = (512, 256)

# 发型长度档（从短到长）—— 目录里就是这些文件名
LENGTHS = ['short', 'shoulder', 'chest', 'navel', 'thighs', 'feet']


def probe(path):
    """量一张图：几何 / 饱和度 / 全身列 bbox。"""
    if not os.path.exists(path):
        return None
    try:
        im = Image.open(path).convert('RGBA')
    except Exception:
        return None
    w, h = im.size
    col = im.crop((0, 0, min(BODY_CLIP, w), h))
    bb = col.getbbox()
    if bb is None:
        return {'size': (w, h), 'empty': True, 'sat': None, 'bb': None}
    sub = col.crop(bb)
    # 平均饱和度（只看不透明像素）
    px = list(sub.getdata())
    tot = 0
    s = 0.0
    for r, g, b, a in px:
        if a > 32:
            mx, mn = max(r, g, b), min(r, g, b)
            s += 0.0 if mx == 0 else (mx - mn) / float(mx)
            tot += 1
    return {
        'size': (w, h),
        'empty': False,
        'sat': (s / tot) if tot else 0.0,
        'bb': bb,
        'px': tot,
    }


def verdict(rec):
    if rec is None:
        return '缺'
    if rec['empty']:
        return '全透明'
    if rec['size'] != AU_CANVAS:
        return 'DoL 旧几何 %d×%d' % rec['size']
    if rec['sat'] is not None and rec['sat'] > 0.05:
        return '彩色（非蒙版）sat=%.2f' % rec['sat']
    return 'OK'


# ---------------------------------------------------------------- 鞋子
def list_feet(verbose):
    base = os.path.join(PACK, 'clothes', 'feet')
    styles = sorted(d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d)))
    rows = []
    for st in styles:
        d = os.path.join(base, st)
        pngs = sorted(f for f in os.listdir(d) if f.lower().endswith('.png'))
        # 主体取 full.png；没有就取第一个非 mask 的
        main = None
        if 'full.png' in pngs:
            main = 'full.png'
        else:
            for f in pngs:
                if not f.startswith('mask'):
                    main = f
                    break
        rec = probe(os.path.join(d, main)) if main else None
        variants = [f for f in pngs if f.startswith('full') and f != 'full.png']
        rows.append((st, main, variants, rec, len(pngs)))

    ok = [r for r in rows if verdict(r[3]) == 'OK']
    print('=' * 78)
    print('【鞋子】%s  —— 共 %d 个目录，其中 %d 个可用' % (
        os.path.join('clothes', 'feet'), len(rows), len(ok)))
    print('=' * 78)
    print('%-26s %-10s %-9s %s' % ('款式目录', '可用?', '全身列 bbox', '备注'))
    for st, main, variants, rec, n in rows:
        v = verdict(rec)
        bb = '——' if (rec is None or rec['empty']) else '%d,%d-%d,%d' % rec['bb']
        note = []
        if main != 'full.png':
            note.append('主图=%s' % main)
        if variants:
            note.append('%d 个变体: %s' % (len(variants),
                ', '.join(x[:-4] for x in variants[:4]) + ('…' if len(variants) > 4 else '')))
        if n > 1 and not variants:
            note.append('%d 个文件' % n)
        print('%-26s %-10s %-9s %s' % (st, v, bb, ' ｜ '.join(note)))
    print()
    return ok


# ---------------------------------------------------------------- 发型
def hair_parts():
    return {
        'sides': os.path.join(PACK, 'hair', 'sides'),
        'fringe': os.path.join(PACK, 'hair', 'fringe'),
        'back': os.path.join(PACK, 'hair', 'back'),
    }


def list_hair(verbose):
    parts = hair_parts()
    print('=' * 78)
    print('【发型】每个发型 = sides（侧面，主体）+ fringe（刘海）+ back（脑后）的**组合**')
    print('=' * 78)

    for name in ['sides', 'fringe', 'back']:
        base = parts[name]
        if not os.path.isdir(base):
            print('!! 缺目录 %s' % base)
            continue
        styles = sorted(d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d)))
        ok_styles = []
        dead = []
        for st in styles:
            d = os.path.join(base, st)
            avail = []
            for L in LENGTHS:
                p = os.path.join(d, L + '.png')
                r = probe(p)
                if r is not None and not r['empty'] and r['size'] == AU_CANVAS \
                        and (r['sat'] is None or r['sat'] <= 0.05):
                    avail.append(L)
            if avail:
                ok_styles.append((st, avail))
            else:
                # 全部不满足 → 看看为什么
                why = '没有长度文件'
                for L in LENGTHS:
                    r = probe(os.path.join(d, L + '.png'))
                    if r is not None:
                        why = verdict(r)
                        break
                dead.append((st, why))
        print()
        print('--- %s --- 共 %d 款，可用 %d 款' % (name, len(styles), len(ok_styles)))
        for st, avail in ok_styles:
            print('   %-30s 长度档：%s' % (st, ' / '.join(avail)))
        if dead:
            print('   （不可用 %d 款：%s）' % (len(dead), '、'.join(
                '%s[%s]' % (x[0], x[1]) for x in dead[:8])))
        if verbose:
            print()
    return


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--long', action='store_true')
    args = ap.parse_args()
    list_feet(args.long)
    print()
    list_hair(args.long)


if __name__ == '__main__':
    main()
