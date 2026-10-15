# -*- coding: utf-8 -*-
"""
把 AUfemale 图包的美术资源按 dol_map.py 的映射烘焙进本项目。

做四件事：
  1. 基础层（身体 / 脸 / 头发）→ <out>/base/<name>.png
  2. 每件衣物 → <out>/clothes/<our_id>.png
       · 取精灵图里的**正面全身那一帧**
       · 染色：结果 = 颜色 × 蒙版灰度（复刻 DoL 的 Renderer.composeOverCutout）
       · 按需搬运 / 缩放（耳饰 / 穿环 / 刺青这些槽位 DoL 里没有，只能挪用头部小件，
         再把它的不透明中心挪到耳朵 / 眉骨 / 唇边）
       · 统一裁到固定取景框（所有图层用同一个框，否则换装时小人会跳）
  3. 每件衣物的卡片图标 → <out>/icons/<our_id>.png（30×30，照 DoL 的物品图标尺寸）
  4. 图层表 → data/doll_au.json（Godot 侧照着它按 z 序叠）

★★ 第三十七轮：用户口径「现在和之后只使用 au 源的服装」——
   **只剩 AU 一套图包**。原来还支持 `--pack dol`（DoL 官方原版，256×128 精灵图），
   那条链路连同 assets/dol 与 data/doll.json 一起停掉了，PACKS 里只留 au。

  au（AUfemale）   512×256 画布 —— 按 **128 px 一列**分成 4 列，两两一组：
                    · 第 0 列 x0..127   = 正面全身像（人物约 40×145 px，站在 x85..125、y45..190）
                    · 第 1 列 x128..255 = 胸像 / 脸部特写（头 x165..230，被 y=128 拦腰截断）
                    · 第 2/3 列 x256..511 = 上面两列的**逐像素复制**
                 ★ 本脚本**只用全身像那一列**，胸像一律不要 —— 分界线见 crop_clip。
                 ★ 图包里混着一批「仍是 DoL 原尺寸 256×128」的旧图层，
                   由 old_geom 那一支负责把它们抬到新几何（见 normalize_geom）。

用法：
  python tools/dol_prepare.py                       # 烘 AUfemale
  python tools/dol_prepare.py --root <图包目录> --out <产物目录>
"""
import argparse
import io
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dol_map as M

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ICON = 30            # DoL 的物品图标尺寸（30×30）
ICON_SCALE = 2       # ★ 落盘时放大 2 倍：Godot 的 Button.icon_max_width 只缩不放，
                     #   30×30 的图标直接塞进按钮里就还是 30×30，太小；
                     #   放大到 60×60 正好等于 DoL 卡片里那枚 60×60 的图标。
                     #   用 NEAREST 放大，保住像素画的硬边。

# ---------------- 图包几何表 ----------------
#  grid       精灵图的单帧尺寸；None = 整张就是一层，不做网格切分
#  canvas     transform() 里「搬运 / 缩放」的落点画布（= 图包自己的坐标系）
#  align_scale / align_origin
#             dol_map 里的 align 坐标是**按 DoL 的头心 (58,30) 写的**。
#             换包时按 (x-58)*s+ox、(y-30)*s+oy 换算，scale 也一并乘 s。
#  old_geom   包内「仍是 DoL 原尺寸」的图层（AU 里混着一批），按同一套变换抬到新几何
#  crop_pad   取景框在基础层并集之外留的边（左, 上, 右, 下）
#  crop_clip  取景框的硬边界 —— AU 靠它把右侧的胸像挡在外面
PACKS = {
    'au': {
        'root': 'E:/DOWNLOAD/AUfemale.imgpack_v0.9.3',
        'out': 'assets/dol_au',
        'json': 'data/doll_au.json',
        'grid': None,
        'canvas': (512, 256),
        # 实测 body/base-head 在全身像列里是 x90..122、y14..47 → 头心 (106, 30.5)；
        # 头宽 33 px，DoL 是 22 px（x47..69）→ 1.5 倍
        'align_scale': 1.5,
        'align_origin': (106.0, 30.5),
        'old_geom': (256, 128),
        # 上 16 让发髻 / 帽檐不被切；右留 9 但硬夹在 130 —— 全身像列的内容最远到 x129，
        # 胸像列的内容最近从 x130 起（全量扫过 clothes/hair/body 三层得出的接缝）
        'crop_pad': (22, 16, 9, 16),
        'crop_clip': (0, 0, 130, 256),
        'clip_view': (0, 0, 130, 256),
    },
}

DOL_HEAD = (58.0, 30.0)      # align 坐标的参考点（DoL 头心），不要改

P = PACKS['au']
OUT = os.path.join(HERE, PACKS['au']['out'])

_IMG_CACHE = {}
_CONTENT_CACHE = {}
CLIPPED = []


def has_content(path):
    """这张 png 里有没有不透明像素。

    ★ 图包里混着一些**全透明的占位文件**（AU 的 `winterjacket/3.png` 就是），
      不筛掉的话会选中一张空图，烘出来那件衣服整个消失。
    """
    if path not in _CONTENT_CACHE:
        try:
            _CONTENT_CACHE[path] = Image.open(path).convert('RGBA').getbbox() is not None
        except Exception:
            _CONTENT_CACHE[path] = False
    return _CONTENT_CACHE[path]


# ---------------- 路径解析 ----------------
def resolve(spec):
    """spec = ("clothes","upper","blouse") 这样的路径元组；支持一次给多个候选。

    ★ 第二个图包（AU）裁掉了不少款式，所以 dol_map 里可以写成
      `"src": [("clothes","upper","classic blouse"), ("clothes","upper","sweater")]`
      —— 按顺序试，用第一个能找到的。只给一个元组时行为和以前完全一样。

    给目录时的挑选顺序（挑到全透明的就跳过、继续往下）：
      0. 先滤掉 `-acc` / `_acc` 变体 —— 那是「附加装饰」那一层，不是主体
         （手套目录里 `left-idle-acc.png` 只有几颗星星）
      1. full.png
      2. full*（AU 里不少件只有 full-alt / full_gray / full-long）
      3. 带 idle 的（我们的小人永远用站立手臂，cover / hold 是别的姿势）
      4. 数字名（1.png / 2.png …）
      5. 其余按名字排第一个
    """
    if isinstance(spec, (list, tuple)) and spec and isinstance(spec[0], (list, tuple)):
        for cand in spec:
            p = resolve(cand)
            if p:
                return p
        return None
    p = os.path.join(P['root'], *spec)
    if os.path.isfile(p + '.png'):
        return p + '.png' if has_content(p + '.png') else None
    if os.path.isfile(p):
        return p if has_content(p) else None
    if os.path.isdir(p):
        files = [f for f in sorted(os.listdir(p)) if f.endswith('.png')]
        files = [f for f in files if has_content(os.path.join(p, f))]
        if not files:
            return None
        plain = [f for f in files if '-acc' not in f and '_acc' not in f]
        files = plain if plain else files
        if 'full.png' in files:
            return os.path.join(p, 'full.png')
        fulls = [f for f in files if f.startswith('full')]
        if fulls:
            return os.path.join(p, fulls[0])
        idles = [f for f in files if 'idle' in f]
        if idles:
            return os.path.join(p, idles[0])
        num = sorted((f for f in files if f[:-4].isdigit()), key=lambda x: int(x[:-4]))
        if num:
            return os.path.join(p, num[0])
        return os.path.join(p, files[0])
    return None


def first_frame(im, grid):
    """网格精灵图 → 取第一个有内容的帧。

    ★ 这里踩过坑：一开始直接裁 (0,0,128,128)，结果有些贴图整张是空的
      —— 精灵图不都是「横向 2 帧」：衣物多为 256×128（2 帧），
      但 bodywriting 是 512×256（4×2 共 8 帧）而且第 0 帧是空的。
    """
    if im.size == grid:
        return im
    cols, rows = max(1, im.width // grid[0]), max(1, im.height // grid[1])
    for r in range(rows):
        for c in range(cols):
            f = im.crop((c * grid[0], r * grid[1], (c + 1) * grid[0], (r + 1) * grid[1]))
            if f.getbbox():
                return f
    return Image.new('RGBA', grid, (0, 0, 0, 0))


def normalize_geom(im):
    """把一张原图抬到本图包的画布坐标系里。"""
    if P['grid']:
        return first_frame(im, P['grid'])
    old = P['old_geom']
    if old and im.size == old:
        # 仍是 DoL 原尺寸的图层（AU 里混着一批）：
        # 取第 0 帧 → 按头心对齐放大到新几何，落点用和 align 同一套换算
        f = first_frame(im, (128, 128))
        s = P['align_scale']
        f = f.resize((max(1, int(f.width * s)), max(1, int(f.height * s))), Image.NEAREST)
        ax, ay = P['align_origin']
        dx = int(round(ax - DOL_HEAD[0] * s))
        dy = int(round(ay - DOL_HEAD[1] * s))
        canvas = Image.new('RGBA', P['canvas'], (0, 0, 0, 0))
        canvas.paste(f, (dx, dy), f)
        return canvas
    return im


def layer_image(path):
    if path not in _IMG_CACHE:
        im = clip_to_body(normalize_geom(Image.open(path).convert('RGBA')))
        _IMG_CACHE[path] = im
    return _IMG_CACHE[path]


def clip_to_body(im):
    """把图层裁到「全身像」那一列，右边并排的胸像直接扔掉。

    ★ 必须在**任何 bbox 计算之前**裁。耳饰 / 穿环 / 刺青这些靠 align 搬运的图层
      挪用的是「头部小件」（goldhairpin / hairclip）—— 它们在 AU 里同时画在全身像
      和胸像两张脸上，整图 bbox 会横跨 x109..482（宽 373 px），中心自然落在两张像
      中间。拿这个中心去对齐，整块就被推到画布左边缘（踩过这个坑）。
    """
    cv = P.get('clip_view')
    if not cv:
        return im
    w, h = P['canvas']
    box = (max(0, cv[0]), max(0, cv[1]), min(w, cv[2]), min(h, cv[3]))
    if box == (0, 0, w, h):
        return im
    canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    canvas.paste(im.crop(box), (box[0], box[1]))
    return canvas


def bbox(im):
    return im.getbbox()


def tint(im, colour, gain=1.0):
    """复刻 DoL 的 composeOverCutout：结果 = 颜色 × 蒙版灰度，alpha 取蒙版 alpha

    gain 是给**灰度蒙版**用的亮度增益（默认 1.0 = 和 DoL 完全一样）：
    AU 的头发是纯灰度蒙版（实测饱和度 0.00）但整体偏暗（亮度 38..207），
    直接乘颜色会发乌，得先把灰度拉上来。
    """
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
            op[x, y] = (int(r * lum * 255), int(g * lum * 255), int(b * lum * 255), a)
    return out


def transform(im, scale, align):
    """按需缩放 / 搬运 —— DoL 没有耳饰与穿环槽位时靠它顶替。

    align 坐标是**按 DoL 的 128×128 帧**写的（头心 58,30），换图包时在这里换算。
    ★ 只有带 align 的图层才跟着 align_scale 走 —— 图包自己的贴图本来就是
      新几何，再乘一遍 1.5 会直接飞出取景框（这个坑踩过）。
    """
    if align:
        s = float(scale or 1.0) * float(P['align_scale'])
        if abs(s - 1.0) > 1e-6:
            im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.NEAREST)
        mode, tx, ty = align[0], align[1], align[2]
        tx = (tx - DOL_HEAD[0]) * P['align_scale'] + P['align_origin'][0]
        ty = (ty - DOL_HEAD[1]) * P['align_scale'] + P['align_origin'][1]
        bb = im.getbbox()
        if bb and mode == 'bbox_center':
            cx, cy = (bb[0] + bb[2]) / 2.0, (bb[1] + bb[3]) / 2.0
            dx, dy = int(round(tx - cx)), int(round(ty - cy))
            canvas = Image.new('RGBA', P['canvas'], (0, 0, 0, 0))
            canvas.paste(im, (dx, dy), im)
            return canvas
        return im
    s = float(scale or 1.0)
    if abs(s - 1.0) > 1e-6:
        im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.NEAREST)
    return im


def overlay(base, layer):
    if base is None:
        return layer.copy()
    return Image.alpha_composite(base, layer)


# ---------------- 取景框 ----------------
def compute_crop():
    """所有图层共用的取景框：拿基础层的并集 bbox，四边按图包留边，再硬夹一下"""
    box = None
    for L in M.BASE_LAYERS:
        p = resolve(L['src'])
        if not p:
            continue
        bb = layer_image(p).getbbox()
        if not bb:
            continue
        box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]),
                                      max(box[2], bb[2]), max(box[3], bb[3]))
    if box is None:
        box = (40, 14, 88, 98)
    pl, pt, pr, pb = P['crop_pad']
    cx0, cy0, cx1, cy1 = P['crop_clip']
    x0 = max(cx0, box[0] - pl)
    y0 = max(cy0, box[1] - pt)
    x1 = min(cx1, box[2] + pr)
    y1 = min(cy1, box[3] + pb)
    return (x0, y0, x1, y1)


def note_clip(name, im, crop):
    """记下被取景框切掉的图层 —— 切多了就是 crop_pad / crop_clip 没调好。

    传进来的 im 已经在 layer_image() 里裁到全身像那一列了，所以这里的 bbox
    天然不含胸像，不会再刷一堆假警报。
    """
    bb = im.getbbox()
    if not bb:
        return
    over = max(crop[0] - bb[0], crop[1] - bb[1], bb[2] - crop[2], bb[3] - crop[3], 0)
    if over > 0:
        CLIPPED.append((over, name, bb))


# ---------------- 主流程 ----------------
def item_slots():
    """从 scripts/OutfitData.gd 抓「物品 id → 槽位」。**这是唯一的权威来源**。

    ★ 为什么要抓：dol_map.SLOT_Z 是按**槽位**编号的（top 95 / bra 70 / bottom 90 /
      panties 67 …），而映射表里只有物品 id。以前这里写成 `M.SLOT_Z.get(our_id)`，
      拿 id 去查槽位表永远查不到 → 每一件衣物的图层 z 都退化成兜底的 100.0，
      于是 DolDoll.plan() 的排序完全失效（全是同一个 z），画出来的层序退化成
      equipped 的插入顺序 —— 内裤（SLOT_ORDER 里排在下装后面）就跑到下装**上面**去了。
      修好之后每件衣物带上自己槽位的 z，排序才真的按 ZIndices 生效。
    """
    import re
    path = os.path.join(HERE, 'scripts', 'OutfitData.gd')
    pat = re.compile(r'"id"\s*:\s*"([^"]+)"[^\n]*?"slot"\s*:\s*"([^"]+)"')
    out = {}
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = pat.search(line)
            if m:
                out[m.group(1)] = m.group(2)
    return out


def main():
    for sub in ['base', 'clothes', 'icons']:
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    crop = compute_crop()
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]

    # 物品 → 槽位 → 图层 z（拿不到就退回兜底 100.0，但会在末尾报出来）
    slots = item_slots()

    def z_of(our_id):
        return M.SLOT_Z.get(slots.get(our_id, ''), 100.0)

    layers = []          # data/doll*.json 的 base 段
    report = []

    # ---- 1. 基础层 ----
    for L in M.BASE_LAYERS:
        p = resolve(L['src'])
        if not p:
            report.append('XX base %s %s' % (L['name'], L['src']))
            continue
        im = layer_image(p)
        if L.get('tint'):
            im = tint(im, L['tint'])
        note_clip('base/' + L['name'], im, crop)
        save(im.crop(crop), 'base', L['name'])
        layers.append({'name': L['name'], 'file': 'base/%s.png' % L['name'], 'z': L['z']})

    # ---- 2. 头发（四件，各含 sides / fringe / back 三块）----
    # ★ 发型表只有 AU 一套（dol_map.HAIR_STYLES）：AU 自己重画的那批头发是
    #   **灰度蒙版**，走 tint 乘发色；不再有「DoL 彩色原图 + hue_shift」那条路。
    hair_table = M.HAIR_STYLES
    hair_files = {}
    for key, h in hair_table.items():
        pieces = []
        for sub, skey, z in [('back', 'back', 10.0), ('sides', 'style', 60.0), ('fringe', 'fringe', 132.0)]:
            st = h.get(skey)
            if not st:
                continue
            length = h.get('back_len') if sub == 'back' else h['length']
            # st 可以是「一个名字」也可以是「一串候选名字」，按顺序试
            names = st if isinstance(st, (list, tuple)) else [st]
            p = resolve([('hair', sub, n, length or h['length']) for n in names])
            if not p:
                report.append('XX hair %s %s/%s' % (key, sub, st))
                continue
            im = layer_image(p)
            if h.get('tint'):
                # 灰度蒙版：结果 = 发色 × 蒙版灰度
                im = tint(im, h['tint'], h.get('gain', 1.0))
            name = '%s_%s' % (key, sub)
            note_clip('base/' + name, im, crop)
            save(im.crop(crop), 'base', name)
            pieces.append({'name': name, 'file': 'base/%s.png' % name, 'z': z})
        hair_files[key] = pieces
        report.append('OK hair %s -> %s' % (key, len(pieces)))

    # ---- 3. 衣物 ----
    items = {}
    for our_id, layerspec in M.ITEMS.items():
        if our_id in hair_table:
            items[our_id] = {'layers': hair_files.get(our_id, []), 'z': M.SLOT_Z['hair'],
                             'icon': 'icons/%s.png' % our_id}
            # 发型的图标：把侧面 + 刘海叠起来当一枚「发型缩略」
            # （脑后的那块与侧面基本重合，叠进去只会加深，所以不要）
            acc = None
            for piece in hair_files.get(our_id, []):
                if str(piece['name']).endswith('_back'):
                    continue
                acc = overlay(acc, load_asset('base', str(piece['name'])))
            if acc is None:
                make_none_icon(our_id)
            else:
                make_icon(acc, our_id)
            report.append('OK %s icon' % our_id)
            continue
        acc = None
        used = 0
        # 「借用头部小件」那一小撮的参数（见 dol_map.AU_OVERRIDE）
        ov = M.AU_OVERRIDE.get(our_id, {})
        for base_spec in layerspec:
            spec = dict(base_spec)
            spec.update(ov)
            p = resolve(spec['src'])
            if not p and spec.get('alt'):
                # 这个图包没有那件款式 → 用 alt 里那套（整条覆盖，不是合并）
                spec = spec['alt']
                p = resolve(spec['src'])
            if not p:
                report.append('XX %s %s' % (our_id, spec['src']))
                continue
            used += 1
            im = layer_image(p)
            if spec.get('tint'):
                im = tint(im, spec['tint'])
            im = transform(im, spec.get('scale', 1.0), spec.get('align'))
            acc = overlay(acc, im)
        if acc is None:
            items[our_id] = {'layers': [], 'z': z_of(our_id), 'icon': None}
            continue
        note_clip('clothes/' + our_id, acc, crop)
        save(acc.crop(crop), 'clothes', our_id)
        z = z_of(our_id)
        items[our_id] = {'layers': [{'name': our_id, 'file': 'clothes/%s.png' % our_id, 'z': z}],
                         'icon': 'icons/%s.png' % our_id}
        # ---- 4. 物品图标：裁到这件衣服自身的不透明范围，缩进 30×30 ----
        make_icon(acc, our_id)
        report.append('OK %s -> %s' % (our_id, used))

    # ---- 「不戴 / 素颜」这些空件没有贴图，画一个小灰杠当图标 ----
    for our_id, _ in M.ITEMS.items():
        if items.get(our_id, {}).get('icon'):
            continue
        make_none_icon(our_id)
        if not items.get(our_id, {}).get('layers'):
            items.setdefault(our_id, {'layers': [], 'z': z_of(our_id), 'icon': None})
        items[our_id]['icon'] = 'icons/%s.png' % our_id

    data = {
        'pack': P.get('name', 'au'),
        'frame': list(P['canvas']),
        'crop': list(crop),
        'size': [cw, ch],
        'base': layers,
        'slot_z': M.SLOT_Z,
        'items': items,
    }
    # ★ 先清掉这一轮已经不存在的物品留下的旧产物，再落盘
    gone = prune_stale()

    with io.open(os.path.join(HERE, P['json']), 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True))

    print('图包 %s  ← %s' % (P.get('name', 'au'), P['root']))
    print('产物 %s ｜ %s' % (P['out'], P['json']))
    print('取景框 %s  →  %d×%d' % (str(crop), cw, ch))
    print('基础层 %d ｜ 衣物 %d' % (len(layers), len([k for k in M.ITEMS])))
    bad = [r for r in report if r.startswith('XX')]
    print('完成 %d 项，缺失 %d 项' % (len(report), len(bad)))
    if gone:
        print('清掉 %d 个已下架物品的旧产物（贴图 / 图标 / .import）' % len(gone))
    for r in bad:
        print('   ', r)
    if CLIPPED:
        CLIPPED.sort(reverse=True)
        print('★ 被取景框切到的图层 %d 个（按切掉像素数排）:' % len(CLIPPED))
        for over, name, bb in CLIPPED[:12]:
            print('    切 %2d px  %-24s bbox=%s' % (over, name, str(bb)))
    else:
        print('没有被取景框切到的图层')

    # ★ 兜底自检：拿不到槽位的物品会退化成 z=100.0（层序就乱了）。
    #   正常应该是空的 —— 一旦有名字冒出来，说明 OutfitData.gd 里那件没写 slot。
    noz = [k for k in M.ITEMS if not M.SLOT_Z.get(slots.get(k, ''))]
    if noz:
        print('★ 这些物品查不到槽位、图层 z 退化成 100.0（层序会乱）: %s' % noz)


def save(im, sub, name):
    im.save(os.path.join(OUT, sub, name + '.png'))


def prune_stale():
    """删掉**不在 M.ITEMS 里**的旧产物（贴图 / 图标 / 它们的 .import）。

    ★ 为什么需要：烘焙只写不删。第二十六轮把「连衣裙 / 晚礼服」从
      top_* + bottom_* 四件合并成 dress_* 两件之后，旧的那四张 png 还躺在
      assets/dol_au/clothes 与 icons 里 —— 游戏不会去读它们（图层表里没有），
      但 `godot --import` 会把它们一起登记，测试里「图标数 == 物品数」这类
      断言就会多出几个幽灵。所以每次烘完顺手清一遍。
    """
    keep = set(M.ITEMS.keys())
    gone = []
    for sub in ('clothes', 'icons'):
        d = os.path.join(OUT, sub)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith('.png'):
                continue
            if fn[:-4] in keep:
                continue
            for victim in (fn, fn + '.import'):
                p = os.path.join(d, victim)
                if os.path.isfile(p):
                    os.remove(p)
                    gone.append('%s/%s' % (sub, victim))
    return gone


def load_asset(sub, name):
    return Image.open(os.path.join(OUT, sub, name + '.png')).convert('RGBA')


def make_icon(layer, our_id):
    """物品图标：裁到自身不透明范围，等比缩进 30×30 居中（照 DoL 的 30×30 图标尺寸）"""
    bb = layer.getbbox()
    if not bb:
        return
    cut = layer.crop(bb)
    w, h = cut.size
    s = min((ICON - 2) / float(w), (ICON - 2) / float(h))
    nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
    cut = cut.resize((nw, nh), Image.NEAREST)
    canvas = Image.new('RGBA', (ICON, ICON), (0, 0, 0, 0))
    canvas.paste(cut, ((ICON - nw) // 2, (ICON - nh) // 2), cut)
    canvas = canvas.resize((ICON * ICON_SCALE, ICON * ICON_SCALE), Image.NEAREST)
    canvas.save(os.path.join(OUT, 'icons', our_id + '.png'))


def make_none_icon(our_id):
    """空件（不戴 / 素颜 / 不穿）：一条小灰杠 —— 和 DoL 里「没有这一层」的意思一致"""
    canvas = Image.new('RGBA', (ICON, ICON), (0, 0, 0, 0))
    px = canvas.load()
    for x in range(8, 22):
        px[x, 15] = (120, 126, 134, 255)
        px[x, 16] = (120, 126, 134, 255)
    canvas = canvas.resize((ICON * ICON_SCALE, ICON * ICON_SCALE), Image.NEAREST)
    canvas.save(os.path.join(OUT, 'icons', our_id + '.png'))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--pack', default='au', choices=sorted(PACKS.keys()))
    ap.add_argument('--root', default=None, help='覆盖图包目录')
    ap.add_argument('--out', default=None, help='覆盖产物目录（相对项目根）')
    ap.add_argument('--json', default=None, help='覆盖图层表路径（相对项目根）')
    args = ap.parse_args()

    P = dict(PACKS[args.pack])
    P['name'] = args.pack
    if args.root:
        P['root'] = args.root
    if args.out:
        P['out'] = args.out
    if args.json:
        P['json'] = args.json
    globals()['P'] = P
    globals()['OUT'] = os.path.join(HERE, P['out'])
    main()
