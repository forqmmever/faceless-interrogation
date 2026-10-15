# -*- coding: utf-8 -*-
"""导出「鞋子 / 发型」候选清单（编号与对照图一致），供挑选。

输出到 stdout，格式便于贴进文档。
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from make_pick_sheets import (PACK, LENGTHS, load_any, grade,   # noqa: E402
                              pick_main_png, BODY_CLIP, AU_CANVAS)

# 中文名建议（按图包里的英文款名意译；★ 标的是「已在游戏里用过」）
FEET_CN = {
    'anklecuffs': '脚踝环带', 'ballchain': '球链凉鞋', 'balletshoes': '芭蕾平底鞋',
    'basketball': '篮球鞋', 'belly': '露趾凉鞋（图包名为 belly）', 'belted': '搭扣短靴',
    'bootheels': '粗跟短靴', 'canvas loafers': '帆布乐福鞋', 'chain boots': '锁链长靴',
    'christmasboots': '圣诞毛边靴', 'combat': '战斗靴', 'cordovanloafers': '马臀皮乐福鞋',
    'courtheels': '细高高跟鞋', 'cowboy': '牛仔靴', 'dresssandals': '正装凉鞋',
    'field': '户外及膝靴', 'flippers': '脚蹼', 'fur_boots': '毛绒靴',
    'geta': '日式木屐', 'giftwrap': '缎带缠足', 'hightops': '高帮帆布鞋',
    'horsebitloafers': '马衔扣乐福鞋', 'iceskates': '冰刀鞋', 'kittenheels': '猫跟鞋',
    'lacedupheels': '系带过膝高跟靴', 'lightuptrainers': '发光运动鞋',
    'loafers': '便鞋（乐福款）', 'long': '及膝长靴', 'maryjanes': '玛丽珍鞋',
    'paddock': '马术短靴', 'platformheels': '松糕高跟鞋',
    'platformmaryjanes': '松糕玛丽珍', 'reindeerslippers': '驯鹿毛绒拖鞋',
    'ribbonplatformheels': '缎带松糕高跟', 'ropes': '绳索缠足', 'sandals': '凉鞋',
    'schoolshoes': '校服皮鞋', 'stripperheels': '超高细跟',
    'succubus': '魅魔过膝靴', 'thighhigh_heels': '过膝高跟长靴',
    'trainers': '运动鞋', 'tuxedoshoes': '燕尾服皮鞋', 'vines': '藤蔓缠绕',
    'wedgesandals': '坡跟凉鞋', 'wellies': '威灵顿雨靴', 'wingtips': '布洛克皮鞋',
    'witch': '尖头女巫靴', 'work': '工装靴', 'zori': '日式草履',
    'bunny': '兔耳拖鞋（7 个动物款）',
}

HAIR_CN = {
    'afro pouf': '非洲蓬蓬头', 'afro puffs': '双丸子蓬发', 'all down': '全部披散',
    'bedhead': '睡乱翘发', 'braid left': '左编辫', 'braid right': '右编辫',
    'bubble tails': '泡泡双马尾', 'crescent tails': '月牙双马尾', 'curl': '卷发',
    'curly pigtails': '卷双马尾', 'curly side up': '侧盘卷发', 'default': '默认短发',
    'defined curl': '分束卷发', 'drill ringlets': '钻头卷', 'flat ponytail': '贴头马尾',
    'french bob': '法式波波头', 'fro': '爆炸头', 'half up twintail': '半扎双马尾',
    'half-up': '半扎发', 'heart braid': '心形编发', 'jellyfish ponytail': '水母马尾',
    'jellyfish twintails': '水母双马尾', 'layered bob': '层次波波头',
    'loop braid': '环形编发', 'loose': '松散披发', 'low tails': '低位双马尾',
    'messy': '蓬乱发', 'messy bun': '蓬松丸子头', 'messy ponytail': '蓬乱马尾',
    'neat': '利落短发', 'pigtails': '双马尾', 'ponytail': '马尾',
    'princess wave': '公主大波浪', 'ruffled': '蓬起短发', 'sailor buns': '水手双丸子',
    'short': '极短发', 'sidecut': '两侧剃短', 'sidetail left': '左侧马尾',
    'sidetail right': '右侧马尾', 'sleek': '服帖直发', 'space buns': '太空双丸子',
    'straight bob': '直发波波头', 'swept left': '左偏分', 'thick pigtails': '厚双马尾',
    'thick sidetail': '厚侧马尾', 'thick twintails': '厚双马尾辫', 'twintails': '双马尾辫',
    'wavy braid': '波浪编发',
    # fringe
    'aerial': '轻薄空气刘海', 'back': '后梳（露额）', 'blunt locks': '齐刘海',
    'bowl': '锅盖头刘海', 'buzzcut': '剃头', 'curtain': '中分帘式',
    'emo': '斜长遮眼', 'emo left': '左斜遮眼', 'emo right': '右斜遮眼',
    'flat': '贴额刘海', 'framed': '脸侧框发', 'front braids': '前额编发',
    'hime': '姬发式', 'loose antenna': '散乱呆毛', 'messy curls': '蓬乱卷刘海',
    'overgrown': '长长了没修', 'parted': '分缝刘海', 'sectioned': '分区短发',
    'short air vents': '短气孔刘海', 'side-pinned': '侧别发夹',
    'sideswept braid': '侧扫编发', 'split': '对半分开', 'straight': '直刘海',
    'swept back': '向后梳', 'swept left': '左扫刘海', 'thin flaps': '细碎薄片',
    'tied back': '向后扎起', 'trident': '三叉刘海',
    'centred': '中分刘海', 'straight tails': '直发束尾',
}


def dump_feet():
    d = os.path.join(PACK, 'clothes', 'feet')
    rows = []
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
                pick = (f, g)
                break
        if pick is None:
            continue
        nvar = len([f for f in pngs if f.startswith('full') and f != 'full.png'])
        rows.append((st, pick[1], pick[0], nvar))
    print('【鞋子】共 %d 款（A %d / B %d）' % (
        len(rows), sum(1 for r in rows if r[1] == 'A'),
        sum(1 for r in rows if r[1] == 'B')))
    print()
    for i, (st, g, fname, nvar) in enumerate(rows):
        extra = []
        if fname != 'full.png':
            extra.append('主图 %s' % fname)
        if nvar:
            extra.append('%d 个配色变体' % nvar)
        print('%2d. [%s] %-22s %-16s %s' % (
            i + 1, g, st, FEET_CN.get(st, ''), ' ｜ '.join(extra)))
    print()


def dump_hair():
    for part in ['sides', 'fringe', 'back']:
        d = os.path.join(PACK, 'hair', part)
        rows = []
        for st in sorted(os.listdir(d)):
            p = os.path.join(d, st)
            if not os.path.isdir(p):
                continue
            best = None
            for L in reversed(LENGTHS):
                r = load_any(os.path.join(p, L + '.png'))
                if r is None:
                    continue
                g = grade(r[0], r[1])
                if g is None:
                    continue
                best = (L, g)
                break
            if best is None:
                continue
            rows.append((st, best[1], best[0]))
        print('【发型 · %s】共 %d 款（A %d / B %d）' % (
            part, len(rows), sum(1 for r in rows if r[1] == 'A'),
            sum(1 for r in rows if r[1] == 'B')))
        print()
        for i, (st, g, L) in enumerate(rows):
            print('%2d. [%s] %-24s %-14s %s' % (
                i + 1, g, st, HAIR_CN.get(st, ''), L))
        print()


if __name__ == '__main__':
    dump_feet()
    dump_hair()
