# AU 图包 · 配饰候选清单

> 第四十六轮清点，供你挑选。**编号与对照图一一对应**：
> `screenshots/_pick_acc_hands.png` / `_pick_acc_legs.png` /
> `_pick_acc_waist.png` / `_pick_acc_neck.png`。
> 复现：`python tools/list_accessories.py`。

## 先说清楚：AU 没有「配饰」目录

「配饰」是各部位往里凑出来的。项目现有三件就是这么借的：

| 游戏里的 id | 源 | 借用部位 |
|---|---|---|
| `acc_locket` 银质心形吊坠 | `neck/lovelocket` | 锁骨 |
| `acc_belt` 束腰皮带 | `lower/chainbelt skirt` 的 `acc` 层 | 腰 |
| ~~`acc_anklet` 金脚链~~ | `legs/goldanklets` | 脚踝 |
| ~~`acc_shackle` 金色手铐~~ | `hands/goldshackles` | 双腕 |

（后两件这一轮按你的口径删掉了，列在这里只是说明「配饰能借哪些部位」。）

## 怎么读「档」这一列

| 档 | 含义 | 能不能用 |
|---|---|---|
| **A** | 新几何 512×256 + 灰度蒙版（sat ≤ 0.05） | 推荐 |
| **B** | 新几何 512×256，但是彩色 | 能用，但需试色（`tint()` 会先转灰度再乘色，不会漏色） |
| × | DoL 旧几何（256×128 / 256×256） | **不能用** —— 位置会整个错位 |

> 标 **◇** 的其实是**衣物部件**（手套 / 束腰外衣）而不是挂件 ——
> 它们出现在这里是因为「手套」那一栏已经下架，如果你想恢复手套槽，
> 直接从这几件里挑更合适。
>
> 标 **← 已用于** 的说明那个源已经被占用了（再挑会重复）。

## 手 / 腕 —— 14 项（A 11 / B 3）

| # | 档 | 图包款式名 | 中文名 | 备注 |
|---|---|---|---|---|
| 1 | A | `armwarmers` | 暖手筒（前臂套） | 主图 `left-idle.png` |
| 2 | A | `belted` | 搭扣腕带 | 主图 `left-idle-belts.png` |
| 3 | A | `cow` | 牛纹手环 | 主图 `left-idle.png` |
| 4 | A | `fingerlessgloves` | 半指手套 ◇ | 主图 `left-idle.png` |
| 5 | B | `gold` | 金手镯 | 主图 `left-idle.png` |
| 6 | B | `goldshackles` | 金色手铐（已删） | （第四十六轮已删）金色手铐 |
| 7 | A | `lacewarmers` | 蕾丝护腕 | 主图 `left-idle.png` |
| 8 | A | `longleathergloves` | 长皮手套 ◇ | 主图 `left-idle.png` |
| 9 | A | `mittens` | 连指手套 ◇ | 主图 `left-idle.png` |
| 10 | A | `nunlewd` | 修女腕饰 | 主图 `left-idle.png` |
| 11 | A | `pompoms` | 绒球腕饰 | 主图 `left-idle.png` |
| 12 | A | `succubus` | 魅魔腕饰 | 主图 `left-idle.png` |
| 13 | B | `workgloves` | 劳保手套 ◇ | 主图 `left-idle.png` |
| 14 | A | `wristcuffs` | 金属腕铐 | 主图 `left-idle.png` |

## 腿 / 踝（已排除袜子） —— 8 项（A 5 / B 3）

| # | 档 | 图包款式名 | 中文名 | 备注 |
|---|---|---|---|---|
| 1 | A | `belted` | 搭扣腿环 | 主图 `full-long.png` |
| 2 | B | `christmas` | 圣诞腿饰（高 45px，比袜子矮 —— 像腿套） |  |
| 3 | A | `cow` | 牛纹腿饰 |  |
| 4 | B | `goldanklets` | 金脚链（已删） | （第四十六轮已删）金脚链 |
| 5 | B | `goldshackles` | 金色手铐（同名款） |  |
| 6 | A | `leather` | 皮质腿环 |  |
| 7 | A | `mensgarters` | 男式吊袜带 |  |
| 8 | A | `nunlewd` | 修女腿饰 |  |

## 腰（只挑腰带类） —— 2 项（A 2 / B 0）

| # | 档 | 图包款式名 | 中文名 | 备注 |
|---|---|---|---|---|
| 1 | A | `belted` | 束腰皮带 ← acc_belt 实际用的源 |  |
| 2 | A | `chain tunic` | 锁链束腰外衣 ◇（算衣服不算挂件） |  |

## 颈 / 锁骨（与「颈饰」槽共用目录） —— 42 项（A 32 / B 10）

| # | 档 | 图包款式名 | 中文名 | 备注 |
|---|---|---|---|---|
| 1 | A | `Whitney's Collar` | Whitney's 项圈 |  |
| 2 | A | `Whitney's collar with leash` | Whitney's 带牵引绳项圈 |  |
| 3 | A | `boa` | 羽毛围脖 |  |
| 4 | A | `bolotie` | 波洛领带 |  |
| 5 | A | `bowtie` | 领结 |  |
| 6 | A | `bunnycollar` | 兔女郎项圈 |  |
| 7 | B | `cat` | 猫项圈 |  |
| 8 | B | `chaingold` | 金色锁链项圈（已用） | neck_chain 金色锁链项圈 |
| 9 | A | `chainiron` | 铁锁链项圈 |  |
| 10 | A | `clothchoker` | 布质颈圈 |  |
| 11 | A | `collar` | 立领（已用） | neck_collar 硬挺立领 |
| 12 | B | `collarfamiliar` | 使魔项圈 |  |
| 13 | A | `collarfetish` | 恋物项圈 |  |
| 14 | A | `collarleash` | 带牵引绳项圈 |  |
| 15 | A | `collarleashfetish` | 恋物牵引项圈 |  |
| 16 | A | `cow` | 牛铃项圈 |  |
| 17 | B | `darkpendant` | 暗色吊坠 |  |
| 18 | A | `feathernecklace` | 羽毛项链 |  |
| 19 | B | `freeuse` | 刻字颈圈（已用） | neck_freeuse 刻字颈圈 |
| 20 | B | `freeuseleash` | 刻字牵引颈圈 |  |
| 21 | B | `goldchoker` | 金色颈圈 |  |
| 22 | A | `heartchoker` | 心形颈圈 |  |
| 23 | B | `holypendant` | 圣徽吊坠 |  |
| 24 | A | `holystole` | 圣带 |  |
| 25 | A | `holystolelong` | 长圣带 |  |
| 26 | B | `ivorynecklace` | 象牙项链 |  |
| 27 | B | `jasperpendant` | 碧玉吊坠 |  |
| 28 | A | `lacechoker` | 蕾丝颈圈（已用） | neck_lace 蕾丝颈圈 |
| 29 | A | `lacechokerold` | 旧蕾丝颈圈 |  |
| 30 | A | `lovelocket` | 心形吊坠（已用） | acc_locket 银质心形吊坠 |
| 31 | A | `ribbontie` | 缎带领带 |  |
| 32 | A | `ribbontielarge` | 大缎带领带 |  |
| 33 | A | `ringedcollar` | 金属环扣项圈（已用） | neck_ringed 金属环扣项圈 |
| 34 | A | `scarf` | 围巾 |  |
| 35 | A | `serafuku ribbon` | 水手服领巾 |  |
| 36 | A | `shorttie` | 短领带 |  |
| 37 | A | `spiked` | 尖刺项圈（已用） | neck_spiked 尖刺项圈 |
| 38 | A | `spikedleash` | 尖刺牵引项圈 |  |
| 39 | A | `stonependant` | 石质吊坠 |  |
| 40 | A | `suspenders` | 背带 |  |
| 41 | A | `tie` | 领带 |  |
| 42 | A | `whistle` | 口哨 |  |

## 挑完之后怎么加进游戏

1. `tools/dol_map.py` → `ITEMS` 加映射（`src` 指到源目录，可带 `tint`）；
2. `scripts/OutfitData.gd` 的 `ITEMS_BASE` 加物品（`slot: "accessory"` + 数值）；
3. 跑 `python tools/dol_prepare.py` 烘图 → `godot --import` 登记资源；
4. 跑四套测试 + 重拍截图。

> 数值（暴露值 / 接受度门槛 / 反差）要你定，或我按现有档次给建议。
