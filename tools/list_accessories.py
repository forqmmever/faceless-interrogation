# -*- coding: utf-8 -*-
"""清点 AU 图包里**可以当配饰**的款式（身上佩戴的小件），供挑选。

★ 为什么不像鞋/发型那样只扫一个目录：AU **没有 `accessory` 这个目录** ——
  「配饰」是各部位往里凑出来的。项目现有三件就是这么借的：
    · `acc_locket`  ← `neck/lovelocket`（锁骨）
    · `acc_belt`    ← `lower/chainbelt skirt` 的 `acc` 层（腰）
    · 已删的 `acc_anklet` / `acc_shackle` ← `legs/goldanklets` / `hands/goldshackles`
  所以这里按**部位**扫四个地方（`lower/` 只挑腰带类 —— 那个目录本身是下装，
  183 项里绝大多数是裤子裙子，不是配饰）：
    手 / 腕 → `hands/` 全部
    腿 / 踝 → `legs/` 里**排除袜子**之后的
    腰     → `lower/` 里名字含 belt / chain / garter / harness / strap 的
    颈 / 锁骨 → `neck/` 全部（与「颈饰」槽共用目录，已占用的会标出来）

★ 判定沿用第四十五轮的三档口径：
    A = 新几何 512×256 + 灰度蒙版（sat ≤ 0.05）
    B = 新几何 512×256，但是彩色（`tint()` 先转灰度再乘色，能用但需试色）
    × = DoL 旧几何（256×128 / 256×256）→ 不能用

输出（screenshots/）：
  _pick_acc_hands.png / _pick_acc_legs.png / _pick_acc_waist.png / _pick_acc_neck.png

用法：
  python tools/list_accessories.py
"""

import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from make_pick_sheets import (PACK, load_any, grade, pick_main_png,   # noqa: E402
                              Sheet, SHOTS)

# 已经被占用的源 —— 标出来免得重复挑
USED = {
    ('neck', 'collar'): 'neck_collar 硬挺立领',
    ('neck', 'woolscarf'): 'neck_scarf 暗红羊毛围巾',
    ('neck', 'gothic choker'): 'neck_choker 黑色皮革颈圈',
    ('neck', 'spiked'): 'neck_spiked 尖刺项圈',
    ('neck', 'ringedcollar'): 'neck_ringed 金属环扣项圈',
    ('neck', 'lacechoker'): 'neck_lace 蕾丝颈圈',
    ('neck', 'chaingold'): 'neck_chain 金色锁链项圈',
    ('neck', 'freeuse'): 'neck_freeuse 刻字颈圈',
    ('neck', 'lovelocket'): 'acc_locket 银质心形吊坠',
    ('lower', 'chainbelt skirt'): 'acc_belt 束腰皮带',
    ('legs', 'chain leggings'): 'stockings_chainnet 金属环网眼腿套',
    ('legs', 'goldanklets'): '（第四十六轮已删）金脚链',
    ('hands', 'goldshackles'): '（第四十六轮已删）金色手铐',
}

# legs/ 里属于「袜子」的 —— 那是 stockings 槽的地盘
SOCK_KW = ['sock', 'stocking', 'thighhigh', 'tights', 'kneehigh', 'gym',
           'tabi', 'legwarmer', 'leggings']
# lower/ 里算「腰带 / 束具」的（其余是裤子裙子）
BELT_KW = ['belt', 'chain', 'garter', 'harness', 'strap', 'corset']

# 中文名按 (目录, 款) 给 —— 同名款在不同部位是**两件不同的东西**，不能共用。
CN = {
    # ---- 手 / 腕 ----
    ('hands', 'armwarmers'): '暖手筒（前臂套）',
    ('hands', 'belted'): '搭扣腕带',
    ('hands', 'cow'): '牛纹手环',
    ('hands', 'fingerlessgloves'): '半指手套 ◇',
    ('hands', 'gold'): '金手镯',
    ('hands', 'lacewarmers'): '蕾丝护腕',
    ('hands', 'longleathergloves'): '长皮手套 ◇',
    ('hands', 'mittens'): '连指手套 ◇',
    ('hands', 'nunlewd'): '修女腕饰',
    ('hands', 'pompoms'): '绒球腕饰',
    ('hands', 'succubus'): '魅魔腕饰',
    ('hands', 'workgloves'): '劳保手套 ◇',
    ('hands', 'wristcuffs'): '金属腕铐',
    ('hands', 'goldshackles'): '金色手铐（已删）',
    # ---- 腿 / 踝 ----
    ('legs', 'belted'): '搭扣腿环',
    ('legs', 'leather'): '皮质腿环',
    ('legs', 'cow'): '牛纹腿饰',
    ('legs', 'nunlewd'): '修女腿饰',
    ('legs', 'mensgarters'): '男式吊袜带',
    ('legs', 'christmas'): '圣诞腿饰（高 45px，比袜子矮 —— 像腿套）',
    ('legs', 'sheerleggings'): '透肉连裤袜（袜类，已用于 stockings_sheerskin）',
    ('legs', 'goldanklets'): '金脚链（已删）',
    ('legs', 'goldshackles'): '金色手铐（同名款）',
    ('legs', 'chain leggings'): '金属环腿套（已用）',
    # ---- 腰 ----
    # ★ 注意：dol_map 里 acc_belt 的 src 写的是 `lower/chainbelt skirt`，
    #   但 AU 图包里**没有这个目录** → 它走的是 alt 分支 `lower/belted`。
    #   所以 acc_belt 实际用的源是下面这个 `belted`。
    ('lower', 'belted'): '束腰皮带 ← acc_belt 实际用的源',
    ('lower', 'chain tunic'): '锁链束腰外衣 ◇（算衣服不算挂件）',
    # ---- 颈 / 锁骨 ----
    ('neck', "Whitney's Collar"): "Whitney's 项圈",
    ('neck', "Whitney's collar with leash"): "Whitney's 带牵引绳项圈",
    ('neck', 'boa'): '羽毛围脖',
    ('neck', 'bolotie'): '波洛领带',
    ('neck', 'bowtie'): '领结',
    ('neck', 'bunnycollar'): '兔女郎项圈',
    ('neck', 'cat'): '猫项圈',
    ('neck', 'chaingold'): '金色锁链项圈（已用）',
    ('neck', 'chainiron'): '铁锁链项圈',
    ('neck', 'clothchoker'): '布质颈圈',
    ('neck', 'collar'): '立领（已用）',
    ('neck', 'collarfamiliar'): '使魔项圈',
    ('neck', 'collarfetish'): '恋物项圈',
    ('neck', 'collarleash'): '带牵引绳项圈',
    ('neck', 'collarleashfetish'): '恋物牵引项圈',
    ('neck', 'cow'): '牛铃项圈',
    ('neck', 'darkpendant'): '暗色吊坠',
    ('neck', 'feathernecklace'): '羽毛项链',
    ('neck', 'freeuse'): '刻字颈圈（已用）',
    ('neck', 'freeuseleash'): '刻字牵引颈圈',
    ('neck', 'goldchoker'): '金色颈圈',
    ('neck', 'heartchoker'): '心形颈圈',
    ('neck', 'holypendant'): '圣徽吊坠',
    ('neck', 'holystole'): '圣带',
    ('neck', 'holystolelong'): '长圣带',
    ('neck', 'ivorynecklace'): '象牙项链',
    ('neck', 'jasperpendant'): '碧玉吊坠',
    ('neck', 'lacechoker'): '蕾丝颈圈（已用）',
    ('neck', 'lacechokerold'): '旧蕾丝颈圈',
    ('neck', 'lovelocket'): '心形吊坠（已用）',
    ('neck', 'ribbontie'): '缎带领带',
    ('neck', 'ribbontielarge'): '大缎带领带',
    ('neck', 'ringedcollar'): '金属环扣项圈（已用）',
    ('neck', 'scarf'): '围巾',
    ('neck', 'serafuku ribbon'): '水手服领巾',
    ('neck', 'shorttie'): '短领带',
    ('neck', 'spiked'): '尖刺项圈（已用）',
    ('neck', 'spikedleash'): '尖刺牵引项圈',
    ('neck', 'stonependant'): '石质吊坠',
    ('neck', 'suspenders'): '背带',
    ('neck', 'tie'): '领带',
    ('neck', 'whistle'): '口哨',
}

GROUPS = [
    ('hands', '手 / 腕', (0, 78, 68, 132), '_pick_acc_hands.png', None),
    ('legs', '腿 / 踝（已排除袜子）', (0, 145, 68, 200), '_pick_acc_legs.png', SOCK_KW),
    ('lower', '腰（只挑腰带类）', (0, 100, 68, 145), '_pick_acc_waist.png', BELT_KW),
    ('neck', '颈 / 锁骨（与「颈饰」槽共用目录）', (6, 36, 68, 76), '_pick_acc_neck.png', None),
]


def keep(sub, st, kw):
    """关键词过滤：给了 kw 就是「只保留含关键词的」，否则全要。"""
    if not kw:
        return True
    if sub == 'legs':
        return not any(k in st.lower() for k in kw)      # 排除袜子
    return any(k in st.lower() for k in kw)              # 只留腰带类


def collect(sub, kw):
    base = os.path.join(PACK, 'clothes', sub)
    out = []
    for st in sorted(os.listdir(base)):
        p = os.path.join(base, st)
        if not os.path.isdir(p) or not keep(sub, st, kw):
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
        out.append((st, pick[1] if pick else None,
                    pick[2] if pick else None, pick[0] if pick else ''))
    return out


def main():
    r = load_any(os.path.join(PACK, 'body', 'base-classic.png'))
    base = r[0] if r else None
    L = []
    A = L.append
    A('# AU 图包 · 配饰候选清单')
    A('')
    A('> 第四十六轮清点，供你挑选。**编号与对照图一一对应**：')
    A('> `screenshots/_pick_acc_hands.png` / `_pick_acc_legs.png` /')
    A('> `_pick_acc_waist.png` / `_pick_acc_neck.png`。')
    A('> 复现：`python tools/list_accessories.py`。')
    A('')
    A('## 先说清楚：AU 没有「配饰」目录')
    A('')
    A('「配饰」是各部位往里凑出来的。项目现有三件就是这么借的：')
    A('')
    A('| 游戏里的 id | 源 | 借用部位 |')
    A('|---|---|---|')
    A('| `acc_locket` 银质心形吊坠 | `neck/lovelocket` | 锁骨 |')
    A('| `acc_belt` 束腰皮带 | `lower/chainbelt skirt` 的 `acc` 层 | 腰 |')
    A('| ~~`acc_anklet` 金脚链~~ | `legs/goldanklets` | 脚踝 |')
    A('| ~~`acc_shackle` 金色手铐~~ | `hands/goldshackles` | 双腕 |')
    A('')
    A('（后两件这一轮按你的口径删掉了，列在这里只是说明「配饰能借哪些部位」。）')
    A('')
    A('## 怎么读「档」这一列')
    A('')
    A('| 档 | 含义 | 能不能用 |')
    A('|---|---|---|')
    A('| **A** | 新几何 512×256 + 灰度蒙版（sat ≤ 0.05） | 推荐 |')
    A('| **B** | 新几何 512×256，但是彩色 | 能用，但需试色（`tint()` 会先转灰度再乘色，不会漏色） |')
    A('| × | DoL 旧几何（256×128 / 256×256） | **不能用** —— 位置会整个错位 |')
    A('')
    A('> 标 **◇** 的其实是**衣物部件**（手套 / 束腰外衣）而不是挂件 ——')
    A('> 它们出现在这里是因为「手套」那一栏已经下架，如果你想恢复手套槽，')
    A('> 直接从这几件里挑更合适。')
    A('>')
    A('> 标 **← 已用于** 的说明那个源已经被占用了（再挑会重复）。')
    A('')

    for sub, label, focus, out_name, kw in GROUPS:
        rows = collect(sub, kw)
        usable = [x for x in rows if x[1] is not None]
        dead = [x[0] for x in rows if x[1] is None]
        sh = Sheet('AU 配饰候选 · %s' % label,
                   cell=(120, 96), cols=8, focus=focus, base_img=base)
        for st, im, g, extra in rows:
            if im is None:
                continue
            sh.add(st, im, g, USED.get((sub, st), ''))
        sh.render(os.path.join(SHOTS, out_name))

        A('## %s —— %d 项（A %d / B %d）' % (
            label, len(usable),
            sum(1 for x in usable if x[2] == 'A'),
            sum(1 for x in usable if x[2] == 'B')))
        A('')
        A('| # | 档 | 图包款式名 | 中文名 | 备注 |')
        A('|---|---|---|---|---|')
        n = 0
        for st, im, g, extra in rows:
            if im is None:
                continue
            n += 1
            note = USED.get((sub, st), '')
            if not note and extra != 'full.png' and extra:
                note = '主图 `%s`' % extra
            A('| %d | %s | `%s` | %s | %s |' % (
                n, g, st, CN.get((sub, st), ''), note))
        A('')
        if dead:
            A('> 不可用 %d 项（DoL 旧几何）：%s' % (len(dead), '、'.join(dead)))
            A('')

    A('## 挑完之后怎么加进游戏')
    A('')
    A('1. `tools/dol_map.py` → `ITEMS` 加映射（`src` 指到源目录，可带 `tint`）；')
    A('2. `scripts/OutfitData.gd` 的 `ITEMS_BASE` 加物品（`slot: "accessory"` + 数值）；')
    A('3. 跑 `python tools/dol_prepare.py` 烘图 → `godot --import` 登记资源；')
    A('4. 跑四套测试 + 重拍截图。')
    A('')
    A('> 数值（暴露值 / 接受度门槛 / 反差）要你定，或我按现有档次给建议。')
    A('')

    out = os.path.join(os.path.dirname(HERE), 'AU配饰候选.md')
    io.open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(L))
    print()
    print('已写出 %s（%d 行）' % (out, len(L)))
    for sub, label, focus, out_name, kw in GROUPS:
        rows = collect(sub, kw)
        print('  %-40s 可用 %d 项' % (label[:40], sum(1 for x in rows if x[1])))


if __name__ == '__main__':
    main()
