# -*- coding: utf-8 -*-
"""把候选清单写成 markdown 文档（编号与对照图一致）。

★ 踩过的坑：`dump_pick_list.py` 的输出在 Windows 上是 **CRLF** 换行，
  用 `\n\n\n` 分段会匹配不到（实际是 `\r\n\r\n\r\n`）→ 各段串行。
  这里先归一化换行再切。
"""

import io
import os
import re

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(PROJ, '.workbuddy-ai', 'tmp', 'pick.txt')

raw = io.open(SRC, encoding='utf-8').read()
src = raw.replace('\r\n', '\n').replace('\r', '\n')


def section(marker):
    """取「【marker】…」到下一个「【」之前（或文末）的内容。"""
    i = src.find('【' + marker + '】')
    if i < 0:
        return ''
    j = src.find('【', i + 1)
    if j < 0:
        j = len(src)
    return src[i:j].strip()


def to_rows(block):
    """把 ` 1. [A] name   中文` 解析成 (n, grade, en, cn)。"""
    out = []
    for line in block.split('\n'):
        m = re.match(r'^\s*(\d+)\.\s*\[([AB])\]\s+(\S.*?)(?:\s{2,}(.*))?$', line)
        if m:
            out.append((m.group(1), m.group(2), m.group(3).strip(),
                        (m.group(4) or '').strip()))
    return out


feet = to_rows(section('鞋子'))
sides = to_rows(section('发型 · sides'))
fringe = to_rows(section('发型 · fringe'))
back = to_rows(section('发型 · back'))

L = []
A = L.append
A('# AU 图包 · 鞋子与发型候选清单')
A('')
A('> 第四十五轮清点，供你挑选。**编号与对照图一一对应**：')
A('> `screenshots/_pick_feet.png` / `_pick_hair_sides.png` / `_pick_hair_fringe.png` / `_pick_hair_back.png`。')
A('> 复现：`python tools/make_pick_sheets.py`（出图）+ `tools/dump_pick_list.py`（出清单）。')
A('')
A('## 怎么读「档」这一列')
A('')
A('AU 图包里**混着一批 DoL 的旧款**（名字与新款相同），所以每个款式都要验两件事：')
A('')
A('| 档 | 含义 | 能不能用 |')
A('|---|---|---|')
A('| **A** | AU 新几何 512×256 + **灰度蒙版**（sat ≤ 0.05） | 推荐。灰度蒙版是图包作者专为「乘色」画的，明暗关系正确 |')
A('| **B** | AU 新几何 512×256，但是**彩色** | 能用，但需试色 |')
A('| × | DoL **旧几何**（256×128 / 256×256） | **不能用** —— 几何不对，贴上去位置整个错位 |')
A('')
A('> ★ **B 档为什么能用**：`dol_prepare.tint()` 是**先把源像素转成灰度、再乘目标色**：')
A('>')
A('> ```python')
A('> lum = (r*299 + g*587 + b*114) / 1000.0 / 255.0')
A('> out = (target_r * lum, target_g * lum, target_b * lum, alpha)')
A('> ```')
A('>')
A('> 所以彩色源**不会漏色**（最终饱和度只由目标色决定），只是明暗关系来自原彩色的亮度分布，')
A('> 可能不如蒙版理想 —— 实烘一次看效果即可。')
A('> 项目现有的 `shoes_school_navy` 用的就是 B 档源图（`schoolshoes`）。')
A('')
A('> ★ 一个实例：**`wavy braid` 是 512×256 新几何、但仍是 DoL 红（sat=0.66）** ——')
A('> 所以它落在发型的 B 档。项目早先的注释也点名过这个漏网款。')
A('')
A('## 现在游戏里已经用的（供对比，别重复选）')
A('')
A('**鞋子 4 件**（`OutfitData` 的 `shoes` 槽）：')
A('')
A('| 游戏里的 id | 中文名 | 源款式 | 清单编号 | 档 |')
A('|---|---|---|---|---|')
A('| `shoes_boots` | 及踝皮靴 | `bootheels` | 7 | A |')
A('| `shoes_heels` | 细跟高跟鞋 | `courtheels` | 14 | A |')
A('| `shoes_school_navy` | 藏青校服皮鞋 | `schoolshoes` | 38 | **B** |')
A('| `shoes_school_green` | 棕色校服皮鞋 | `loafers` | 28 | A |')
A('')
A('> `shoes_boots` 的映射里还有一条 `highheelankleboots` 的 `alt`，')
A('> 但 AU 图包里**没有这个目录** —— 所以实际是回落到 `bootheels` 烘出来的。')
A('')
A('**发型 4 款**（`hair` 槽。每款 = `sides` + `fringe` + 可选 `back`）：')
A('')
A('| 游戏里的 id | 中文名 | sides | fringe | back |')
A('|---|---|---|---|---|')
A('| `hair_short` | 利落短发 | `neat` / short | `default` | —— |')
A('| `hair_braid` | 侧编辫 | `braid right` / shoulder | `curtain` | —— |')
A('| `hair_long` | 垂肩长发 | `all down` / chest | `parted` | `all down` / thighs |')
A('| `hair_up` | 高盘发髻 | `messy bun` / navel | `parted` | —— |')
A('')
A('> 同一个 `sides` 换长度档就是另一款（`short` → `shoulder` → `chest` → `navel` → `thighs` → `feet`，共 6 档）。')
A('> `fringe` 与 `back` 可以自由换 —— 光换 `fringe`，同一款侧面就能变成完全不同的观感。')
A('')

A('## 一、鞋子 —— %d 款（A %d / B %d）' % (
    len(feet), sum(1 for r in feet if r[1] == 'A'),
    sum(1 for r in feet if r[1] == 'B')))
A('')
A('| # | 档 | 图包款式名 | 中文名 / 备注 |')
A('|---|---|---|---|')
for n, g, en, cn in feet:
    A('| %s | %s | `%s` | %s |' % (n, g, en, cn))
A('')
A('> 图里是「叠在小人脚上、裁脚部放大」的效果。')
A('')
A('## 二、发型 · 侧面（sides）—— %d 款（A %d / B %d）**这是发型的主体**' % (
    len(sides), sum(1 for r in sides if r[1] == 'A'),
    sum(1 for r in sides if r[1] == 'B')))
A('')
A('| # | 档 | 图包款式名 | 中文名 | 图里用的长度档 |')
A('|---|---|---|---|---|')
for n, g, en, cn in sides:
    # sides 的 cn 末尾带了长度档（如「非洲蓬蓬头          feet」）
    parts = cn.rsplit(None, 1)
    if len(parts) == 2 and parts[1] in ('short', 'shoulder', 'chest',
                                        'navel', 'thighs', 'feet'):
        A('| %s | %s | `%s` | %s | %s |' % (n, g, en, parts[0], parts[1]))
    else:
        A('| %s | %s | `%s` | %s | —— |' % (n, g, en, cn))
A('')
A('> 图里是**叠在头骨上、上好发色**的效果 —— 灰度蒙版必须上色才看得出形状。')
A('> 每款都取了它**最长的可用长度档**（看得最清楚）；文字里标的是用的哪一档。')
A('')
A('## 三、发型 · 刘海（fringe）—— %d 款（A %d / B %d）' % (
    len(fringe), sum(1 for r in fringe if r[1] == 'A'),
    sum(1 for r in fringe if r[1] == 'B')))
A('')
A('| # | 档 | 图包款式名 | 中文名 |')
A('|---|---|---|---|')
for n, g, en, cn in fringe:
    parts = cn.rsplit(None, 1)
    if len(parts) == 2 and parts[1] in ('short', 'shoulder', 'chest',
                                        'navel', 'thighs', 'feet'):
        cn = parts[0]
    A('| %s | %s | `%s` | %s |' % (n, g, en, cn))
A('')
A('> 刘海决定「正面看到的那一撮」。')
A('')
A('## 四、发型 · 脑后（back）—— %d 款（A %d / B %d）只有长发款才有这一层' % (
    len(back), sum(1 for r in back if r[1] == 'A'),
    sum(1 for r in back if r[1] == 'B')))
A('')
A('| # | 档 | 图包款式名 | 中文名 |')
A('|---|---|---|---|')
for n, g, en, cn in back:
    parts = cn.rsplit(None, 1)
    if len(parts) == 2 and parts[1] in ('short', 'shoulder', 'chest',
                                        'navel', 'thighs', 'feet'):
        cn = parts[0]
    A('| %s | %s | `%s` | %s |' % (n, g, en, cn))
A('')
A('> `back` 只有 `thighs` / `feet` 两个长度档 —— 短的够不着、也不需要。')
A('')
A('## 五、不可用的款式（DoL 旧几何 —— 硬伤）')
A('')
A('这些款在 AU 图包里还留着，但**几何是 DoL 的**（256×128 或 256×256），')
A('贴到 AU 的小人身上会整个错位。都是名字与新款相同的「旧同名款」。')
A('')
A('**鞋子**：**无** —— 50 款全部是新几何。')
A('')
A('**发型 · sides（17 款）**：')
A('')
A('```')
A('crude            dreads             fluffy half up twintail')
A('fluffy ponytail  left fishtail      princess twintails')
A('ribbon tail      right fishtail     scorpion tails')
A('shaved           short spiky        straight')
A('thick ponytail   thick princess twintail')
A('twin braids      twin double braids twin fishtails')
A('```')
A('')
A('**发型 · fringe（22 款 + 1 个 B 档）**：')
A('')
A('```')
A('crude            dread bun          dreadlocks')
A('drill ringlets   fluffy wave        goopy')
A('middlepart       milkmaid           mohawk')
A('old_hime         opened curtain     princess wave')
A('quiff            ringlet curl       ringlets')
A('sidecut          straight curl      thorn and curl')
A('torn and curl    voluminous smoke   wavy sickle')
A('wide flaps       wispy')
A('```')
A('')
A('> 另有 `centred` 是**新几何但彩色**（sat 偏高）→ 它其实在 B 档，能用。')
A('')
A('**发型 · back（7 款）**：')
A('')
A('```')
A('afro pouf   dreads      fluffy half up twintail')
A('half-up     space buns  thick ponytail')
A('voluminous smoke')
A('```')
A('')
A('## 六、挑完之后怎么加进游戏')
A('')
A('1. `tools/dol_map.py` → `ITEMS` 那块加映射（`src` 指到款式目录）；')
A('2. 若是发型，加进 `HAIR_STYLES`（点名 `style` / `length` / `fringe` / `back`）；')
A('3. `scripts/OutfitData.gd` 的 `ITEMS_BASE` 加物品（`slot` / 数值 / `tags`）；')
A('4. 跑 `python tools/dol_prepare.py` 烘图 → `godot --import` 登记资源；')
A('5. 跑 `run_tests.bat` + 重拍截图。')
A('')
A('> 具体数值（暴露值 / 接受度门槛 / 反差）要你定；')
A('> 也可以按现有同槽位的档次给一版建议，你调。')
A('')

out = os.path.join(PROJ, 'AU鞋子与发型候选.md')
io.open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(L))

# 自检：表格行数必须与图一致
import subprocess
print('已写出 %s（%d 行）' % (out, len(L)))
print('自检（表格行数 vs 图里的款数）：')
for name, rows, img in [('鞋子', feet, '_pick_feet.png'),
                        ('sides', sides, '_pick_hair_sides.png'),
                        ('fringe', fringe, '_pick_hair_fringe.png'),
                        ('back', back, '_pick_hair_back.png')]:
    print('   %-8s 文档 %2d 行 ｜ 图 %s' % (name, len(rows), img))
