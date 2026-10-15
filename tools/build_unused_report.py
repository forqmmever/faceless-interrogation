# -*- coding: utf-8 -*-
"""第三十八轮：生成「AU 未接入分类清点」文档。

用法：
  python tools/build_unused_report.py
输出：
  未接入分类清点.md（项目根）
"""

import io
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from scan_unused_sheet import (CLOTHES, BODY, PACK_ROOT, collect_props,
                              load_body_crop, stem_of)          # noqa: E402
from PIL import Image                                            # noqa: E402

OUT = os.path.join(PROJ, '未接入分类清点.md')

MASK_CN = {
    'formfitting-breasts': '贴合式 · 胸线',
    'formfitting-curvy': '贴合式 · 丰腴体型',
    'formfitting-slender': '贴合式 · 纤细体型',
    'formfitting-left-move': '贴合式 · 左手移开（占位）',
    'formfitting-right-move': '贴合式 · 右手移开（占位）',
    'soft-clip': '柔软式 · 裁切',
    'soft-lower-clip': '柔软式 · 下摆裁切',
    'soft-shadow': '柔软式 · 阴影',
    'soft-left-move': '柔软式 · 左手移开（占位）',
    'soft-right-move': '柔软式 · 右手移开（占位）',
}
GEN_CN = {
    'chastitybelt': '贞操带',
    'chastitybeltfetish': '贞操带（恋物版）',
    'chastitycage': '贞操笼',
    'chastitycagefetish': '贞操笼（恋物版）',
    'flatchastitycage': '平坦贞操笼',
    'goldchastitybelt': '金贞操带',
    'smallchastitycage': '小号贞操笼',
    'strapon': '穿戴式假阳具',
}
PROP_CN = {
    'general': '杂物（最大一类）',
    'antique': '古董 / 财宝',
    'book': '书报',
    'child toy': '儿童玩具',
    'drink': '饮品',
    'food': '食物',
    'furniture': '家具 / 床上用品',
    'ingredient': '食材',
    'tending': '采集物 / 花木',
    'sex toy': '情趣用品',
    'npc': 'NPC 立绘（不是道具）',
}


def measure(path):
    r = load_body_crop(path)
    if r is None:
        return None
    return r[1]


def main():
    L = []
    A = L.append

    A('# AU 图包未接入分类 · 清点')
    A('')
    A('> 第三十八轮产出。范围是用户点名的四类：**`masks` / `genitals` / `props` / `belly`**。')
    A('> 图包根目录：`%s`' % PACK_ROOT)
    A('>')
    A('> 生成方式：`python tools/scan_unused_cats.py`（明细）与')
    A('> `python tools/scan_unused_sheet.py`（对照图，落在 `screenshots/_scan_*.png`）。')
    A('')

    # ---------- 总览 ----------
    A('## 总览')
    A('')
    A('| 分类 | png 张数 | 归并后 | 全身像列可用 | 性质 |')
    A('|---|---|---|---|---|')
    A('| `masks` | 10 | 6 | 6 | **服装贴合遮罩**（不是衣服） |')
    A('| `genitals` | 32 | 7 | 32 | 下半身饰品 / 束缚具 → 可做槽位 |')
    A('| `props` | 691 | 609 | 690 | **手持道具**（含一整张 NPC 立绘） |')
    A('| `belly` | 63 | 63 | 56 | **怀孕小腹分层系统**（不是衣服） |')
    A('| **合计** | **796** | **685** | **784** | |')
    A('')
    A('四类里只有 **`genitals`** 是「本来就该做成槽位」的东西；')
    A('另外三类要么是**渲染辅助层**（`masks` / `belly`），要么是**别的东西**（`props` 是手持物，')
    A('游戏里没有「手持」这个概念）。这一点在第 5 节展开。')
    A('')

    # ---------- masks ----------
    A('## 1. `masks` —— 服装贴合遮罩（6 张可用 / 10 张）')
    A('')
    A('**这不是衣服，是「怎么把衣服裁到身体轮廓上」的辅助图层。**')
    A('AU 画身体时按体型分了三种基础体型（slender / classic / curvy），')
    A('衣服要贴着这种轮廓走，就得有一层遮罩告诉渲染器「这里该被身体挡住」。')
    A('')
    A('| 文件 | 含义 | 画布 | 全身列内容 bbox |')
    A('|---|---|---|---|')
    M = os.path.join(CLOTHES, 'masks')
    for fn in sorted(os.listdir(M)):
        if not fn.endswith('.png'):
            continue
        # ★ 这里要用**完整文件名**查表，不能走 stem_of() ——
        #   `soft-clip` 会被剥成 `soft`、`soft-lower-clip` 会变成 `soft-lower`，都对不上。
        key = fn[:-4]
        im = Image.open(os.path.join(M, fn)).convert('RGBA')
        bb = measure(os.path.join(M, fn))
        A('| `%s` | %s | %d×%d | %s |' % (
            fn, MASK_CN.get(key, key), im.size[0], im.size[1],
            '全透明（占位）' if bb is None else '`%d,%d-%d,%d`' % bb))
    A('')
    A('**结论**：这 6 张是**运行时合成**才会用到的东西 —— 只有当「衣服覆盖身体」这件事')
    A('需要按体型变化时才需要。本项目的小人是**单一体型**（`base-classic`），')
    A('衣服贴图在烘焙期已经裁好了，所以这类**不需要接入**。')
    A('')

    # ---------- genitals ----------
    A('## 2. `genitals` —— 下半身饰品 / 束缚具（8 个目录 / **7 个独立图案**）')
    A('')
    A('这**才是**真正可以做成槽位的一类：都是穿在下半身、看得见、能参与暴露 / 反差的东西。')
    A('')
    A('每个目录都有四种**磨损态**：`full` / `torn` / `tattered` / `frayed`。')
    A('★ **实测只有 1 个目录的四态真的不同**（其余 7 个的四张文件 MD5 完全一致）：')
    A('')
    A('| 目录 | 中文 | 四态是否不同 | 全身列内容 bbox |')
    A('|---|---|---|---|')
    G = os.path.join(CLOTHES, 'genitals')
    styles = sorted(d for d in os.listdir(G) if os.path.isdir(os.path.join(G, d)))
    for style in styles:
        d = os.path.join(G, style)
        hs = set()
        for s in ('full', 'torn', 'tattered', 'frayed'):
            p = os.path.join(d, s + '.png')
            if os.path.exists(p):
                import hashlib
                hs.add(hashlib.md5(open(p, 'rb').read()).hexdigest())
        bb = measure(os.path.join(d, 'full.png'))
        A('| `%s` | %s | %s | %s |' % (
            style, GEN_CN.get(style, style),
            '**不同**（4 态可用）' if len(hs) > 1 else '相同（只有 1 态）',
            '全透明' if bb is None else '`%d,%d-%d,%d`' % bb))
    A('')
    A('**去重结论**：`chastitycage` 与 `chastitycagefetish` 的 `full.png` **内容完全相同**')
    A('（MD5 都是 `fc0a9b98…`），实际只有 **7 个独立图案**：')
    A('')
    A('1. `chastitybelt` —— 贞操带')
    A('2. `chastitybeltfetish` —— 贞操带（恋物版，**唯一有四态磨损**）')
    A('3. `chastitycage` / `chastitycagefetish` —— 贞操笼（两个目录同图）')
    A('4. `flatchastitycage` —— 平坦贞操笼')
    A('5. `goldchastitybelt` —— 金贞操带')
    A('6. `smallchastitycage` —— 小号贞操笼')
    A('7. `strapon` —— 穿戴式假阳具')
    A('')
    A('位置上全部落在画布 `x 91..118`、`y 81..104` —— 正是裆部高度，与 `panties` 同一层。')
    A('')

    # ---------- props ----------
    A('## 3. `props` —— 手持道具（691 张 / 609 个基名）')
    A('')
    A('**这是四类里最大的一类，但它不是衣服。** 这是「角色手上拿着 / 身上衬着」的东西。')
    A('本项目没有「手持」这套机制（换装只有槽位，没有「拿着什么」），')
    A('所以接入方式要单独设计 —— 见第 5 节。')
    A('')
    A('### 命名约定')
    A('')
    A('| 后缀 | 含义 | 张数 |')
    A('|---|---|---|')
    A('| （无） | 基准图 | 596 |')
    A('| `-basket` | 装了东西的篮子（`apple` → `apple-basket`） | 41 |')
    A('| `-acc` | 附属小件（单独拆出来的一层，`resolve()` 会滤掉） | 23 |')
    A('| `-underarm` | 夹在腋下的姿态 | 17 |')
    A('| `-cover` | 盖住的形态 | 8 |')
    A('| `-open` | 打开状态 | 5 |')
    A('| `-big` | 放大版 | 1 |')
    A('')
    A('### 各子类')
    A('')
    A('| 子类 | 文件数 | 基名数 | 是什么 |')
    A('|---|---|---|---|')
    for sub in ['general', 'antique', 'book', 'child toy', 'drink',
                'food', 'furniture', 'ingredient', 'tending', 'sex toy', 'npc']:
        rows = collect_props([sub])
        d = os.path.join(CLOTHES, 'props', sub)
        nf = sum(len(fs) for _, _, fs in os.walk(d))
        A('| `%s` | %d | %d | %s |' % (sub, nf, len(rows), PROP_CN.get(sub, sub)))
    A('')
    A('### 内容重复')
    A('')
    A('按 MD5 逐张比对：**26 组、56 个文件是内容完全相同的重复**，独立图案 **661 / 691**。')
    A('例如 `box-creature` / `box-creature-underarm` / `box-porn` / `box-porn-underarm`')
    A('这 4 张是**同一张图**（盒子外观一样，只有里面装的东西不同）。')
    A('')

    # 完整清单
    A('### 完整清单（按基名归并，`×N` = 有 N 个姿态 / 收纳变体）')
    A('')
    for sub in ['general', 'antique', 'book', 'child toy', 'drink',
                'food', 'furniture', 'ingredient', 'tending', 'sex toy', 'npc']:
        rows = collect_props([sub])
        A('#### `%s` —— %s（%d 个基名）' % (sub, PROP_CN.get(sub, sub), len(rows)))
        A('')
        A('```')
        line = []
        for _, st, _, n in rows:
            line.append(st + ('' if n == 1 else '×%d' % n))
        # 每行约 92 字符换行
        buf = ''
        for tok in line:
            sep = '、' if buf else ''
            if len(buf) + len(sep) + len(tok) > 92:
                A(buf)
                buf = tok
            else:
                buf += sep + tok
        if buf:
            A(buf)
        A('```')
        A('')

    # ---------- belly ----------
    A('## 4. `belly` —— 怀孕小腹分层系统（63 张）')
    A('')
    A('**这不是衣服，是一整套「肚子鼓起来之后衣服怎么跟着变形」的分层。**')
    A('它由两部分配合：')
    A('')
    A('### 4.1 小腹本体：`body/pregnant-belly/1.png` ~ `24.png`')
    A('')
    A('24 个孕肚阶数，直接画在身体上。这一组**与 `clothes/belly` 是配套的** ——')
    A('`clothes/belly` 里所有文件名带数字的图层，那个数字就是对应 `body/pregnant-belly` 的哪一阶。')
    A('')
    A('### 4.2 分层遮罩：`clothes/belly/`（63 张）')
    A('')
    A('| 文件族 | 张数 | 阶数范围 | 作用 |')
    A('|---|---|---|---|')
    A('| `mask-N.png` | 10 | 15~24 | 按阶数把小腹**露出来**的遮罩（衣服在这块被挖掉） |')
    A('| `mask-min-N.png` | 10 | 15~24 | 同上，「最小化」版本 |')
    A('| `mask-clip-N.png` | 10 | 15~24 | 同上，裁切版 |')
    A('| `shadow-N.png` | 17 | 8~24 | 小腹的**阴影**（让鼓起有立体感） |')
    A('| `mask-shirt-*.png` | 10 | —— | 衬衫专用的遮罩（含 `-clip` / `-clip-big` / `-breasts`） |')
    A('| `belly-mask*.png` | 6 | —— | 基准小腹遮罩 + 上 / 下缘阴影（各带 `-2` / `-3` 变体） |')
    A('')
    A('★ 注意**只有 15 阶起才有遮罩**，8 阶起才有阴影 —— 说明前 14 阶肚子还不够大，')
    A('不需要把衣服挖开。这个分界是图包作者定下的，不是我们猜的。')
    A('')
    A('**7 张全透明占位**：`mask-shirt-left.png` / `mask-shirt-left2.png` /')
    A('`mask-shirt-left2-big.png` / `mask-shirt-left_big.png` / `mask-shirt-right.png` /')
    A('`mask-shirt-right2.png` / `mask-shirt-right3.png`。')
    A('')
    A('**结论**：本项目**没有怀孕机制**，这套整块不需要接入。')
    A('真要接的话，成本不在贴图而在**「每件衣服都要额外烘一套 24 阶的挖洞版本」**，')
    A('等于把现有 155 件 × 24 阶重烘一遍。')
    A('')

    # ---------- 结论 ----------
    A('## 5. 结论：这四类各自适合怎么处理')
    A('')
    A('| 分类 | 建不建议接入 | 理由 |')
    A('|---|---|---|')
    A('| `masks` | **不建议** | 是「按体型裁衣」的辅助层。本项目小人是单一体型、衣服在烘焙期已裁好，接进来没有东西可用。 |')
    A('| `genitals` | **建议**（唯一的候选） | 7 个独立图案，都是穿在下半身、看得见的东西，与现有 `panties` 同层同高；做成一栏是「多一件少一件」的问题，不是机制问题。 |')
    A('| `props` | **不建议** | 除非先设计「手持」机制。609 个基名确实是好东西，但它们是「手里拿的东西」——换装界面没有这一栏，硬塞进槽位语义上不成立；而且绝大多数是食物 / 收藏品 / 杂物，与「伪装成 A」这个核心玩法无关。 |')
    A('| `belly` | **不建议** | 是怀孕系统。要接得先有怀孕机制，而且要把 155 件衣服按 24 阶重烘一遍。 |')
    A('')
    A('**一句话**：四类里真正「补进去就多一批衣服」的只有 `genitals`（7 件）；')
    A('`masks` / `belly` 是渲染机制，`props` 是另一个系统的东西。')
    A('')
    A('## 6. 对照图')
    A('')
    A('| 文件 | 内容 |')
    A('|---|---|')
    A('| `screenshots/_scan_masks_genitals.png` | masks 6 张 + genitals 8 个目录 |')
    A('| `screenshots/_scan_belly.png` | 上排 body/pregnant-belly 24 阶、下排 clothes/belly 各层 |')
    A('| `screenshots/_scan_props_general.png` | props/general（219 张 → 归并后） |')
    A('| `screenshots/_scan_props_a.png` | antique / book / child toy / drink |')
    A('| `screenshots/_scan_props_b.png` | food / furniture / ingredient / tending / sex toy / npc |')
    A('')

    with io.open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(L))
    print('已写出 %s（%d 行 / %d 字符）' % (OUT, len(L), len('\n'.join(L))))


if __name__ == '__main__':
    main()
