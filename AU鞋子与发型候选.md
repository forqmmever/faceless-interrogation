# AU 图包 · 鞋子与发型候选清单

> 第四十五轮清点，供你挑选。**编号与对照图一一对应**：
> `screenshots/_pick_feet.png` / `_pick_hair_sides.png` / `_pick_hair_fringe.png` / `_pick_hair_back.png`。
> 复现：`python tools/make_pick_sheets.py`（出图）+ `tools/dump_pick_list.py`（出清单）。

## 怎么读「档」这一列

AU 图包里**混着一批 DoL 的旧款**（名字与新款相同），所以每个款式都要验两件事：

| 档 | 含义 | 能不能用 |
|---|---|---|
| **A** | AU 新几何 512×256 + **灰度蒙版**（sat ≤ 0.05） | 推荐。灰度蒙版是图包作者专为「乘色」画的，明暗关系正确 |
| **B** | AU 新几何 512×256，但是**彩色** | 能用，但需试色 |
| × | DoL **旧几何**（256×128 / 256×256） | **不能用** —— 几何不对，贴上去位置整个错位 |

> ★ **B 档为什么能用**：`dol_prepare.tint()` 是**先把源像素转成灰度、再乘目标色**：
>
> ```python
> lum = (r*299 + g*587 + b*114) / 1000.0 / 255.0
> out = (target_r * lum, target_g * lum, target_b * lum, alpha)
> ```
>
> 所以彩色源**不会漏色**（最终饱和度只由目标色决定），只是明暗关系来自原彩色的亮度分布，
> 可能不如蒙版理想 —— 实烘一次看效果即可。
> 项目现有的 `shoes_school_navy` 用的就是 B 档源图（`schoolshoes`）。

> ★ 一个实例：**`wavy braid` 是 512×256 新几何、但仍是 DoL 红（sat=0.66）** ——
> 所以它落在发型的 B 档。项目早先的注释也点名过这个漏网款。

## 现在游戏里已经用的（供对比，别重复选）

**鞋子 4 件**（`OutfitData` 的 `shoes` 槽）：

| 游戏里的 id | 中文名 | 源款式 | 清单编号 | 档 |
|---|---|---|---|---|
| `shoes_boots` | 及踝皮靴 | `bootheels` | 7 | A |
| `shoes_heels` | 细跟高跟鞋 | `courtheels` | 14 | A |
| `shoes_school_navy` | 藏青校服皮鞋 | `schoolshoes` | 38 | **B** |
| `shoes_school_green` | 棕色校服皮鞋 | `loafers` | 28 | A |

> `shoes_boots` 的映射里还有一条 `highheelankleboots` 的 `alt`，
> 但 AU 图包里**没有这个目录** —— 所以实际是回落到 `bootheels` 烘出来的。

**发型 4 款**（`hair` 槽。每款 = `sides` + `fringe` + 可选 `back`）：

| 游戏里的 id | 中文名 | sides | fringe | back |
|---|---|---|---|---|
| `hair_short` | 利落短发 | `neat` / short | `default` | —— |
| `hair_braid` | 侧编辫 | `braid right` / shoulder | `curtain` | —— |
| `hair_long` | 垂肩长发 | `all down` / chest | `parted` | `all down` / thighs |
| `hair_up` | 高盘发髻 | `messy bun` / navel | `parted` | —— |

> 同一个 `sides` 换长度档就是另一款（`short` → `shoulder` → `chest` → `navel` → `thighs` → `feet`，共 6 档）。
> `fringe` 与 `back` 可以自由换 —— 光换 `fringe`，同一款侧面就能变成完全不同的观感。

## 一、鞋子 —— 50 款（A 38 / B 12）

| # | 档 | 图包款式名 | 中文名 / 备注 |
|---|---|---|---|
| 1 | A | `anklecuffs` | 脚踝环带 |
| 2 | A | `ballchain` | 球链凉鞋 |
| 3 | A | `balletshoes` | 芭蕾平底鞋 |
| 4 | A | `basketball` | 篮球鞋 |
| 5 | A | `belly` | 露趾凉鞋（图包名为 belly） |
| 6 | A | `belted` | 搭扣短靴 |
| 7 | A | `bootheels` | 粗跟短靴 |
| 8 | B | `bunny` | 兔耳拖鞋（7 个动物款）     主图 full-bunny.png ｜ 7 个配色变体 |
| 9 | A | `canvas loafers` | 帆布乐福鞋 |
| 10 | A | `chain boots` | 锁链长靴 |
| 11 | B | `christmasboots` | 圣诞毛边靴 |
| 12 | A | `combat` | 战斗靴 |
| 13 | B | `cordovanloafers` | 马臀皮乐福鞋 |
| 14 | A | `courtheels` | 细高高跟鞋 |
| 15 | B | `cowboy` | 牛仔靴 |
| 16 | A | `dresssandals` | 正装凉鞋 |
| 17 | A | `field` | 户外及膝靴 |
| 18 | A | `flippers` | 脚蹼 |
| 19 | A | `fur_boots` | 毛绒靴 |
| 20 | A | `geta` | 日式木屐 |
| 21 | A | `giftwrap` | 缎带缠足 |
| 22 | A | `hightops` | 高帮帆布鞋 |
| 23 | B | `horsebitloafers` | 马衔扣乐福鞋 |
| 24 | A | `iceskates` | 冰刀鞋 |
| 25 | A | `kittenheels` | 猫跟鞋 |
| 26 | A | `lacedupheels` | 系带过膝高跟靴 |
| 27 | A | `lightuptrainers` | 发光运动鞋 |
| 28 | A | `loafers` | 便鞋（乐福款） |
| 29 | A | `long` | 及膝长靴 |
| 30 | A | `maryjanes` | 玛丽珍鞋 |
| 31 | A | `paddock` | 马术短靴 |
| 32 | A | `platformheels` | 松糕高跟鞋 |
| 33 | A | `platformmaryjanes` | 松糕玛丽珍 |
| 34 | B | `reindeerslippers` | 驯鹿毛绒拖鞋 |
| 35 | A | `ribbonplatformheels` | 缎带松糕高跟 |
| 36 | B | `ropes` | 绳索缠足 |
| 37 | A | `sandals` | 凉鞋 |
| 38 | B | `schoolshoes` | 校服皮鞋 |
| 39 | A | `stripperheels` | 超高细跟 |
| 40 | A | `succubus` | 魅魔过膝靴 |
| 41 | A | `thighhigh_heels` | 过膝高跟长靴 |
| 42 | A | `trainers` | 运动鞋 |
| 43 | B | `tuxedoshoes` | 燕尾服皮鞋 |
| 44 | B | `vines` | 藤蔓缠绕             1 个配色变体 |
| 45 | A | `wedgesandals` | 坡跟凉鞋 |
| 46 | A | `wellies` | 威灵顿雨靴 |
| 47 | B | `wingtips` | 布洛克皮鞋 |
| 48 | A | `witch` | 尖头女巫靴 |
| 49 | B | `work` | 工装靴 |
| 50 | A | `zori` | 日式草履 |

> 图里是「叠在小人脚上、裁脚部放大」的效果。

## 二、发型 · 侧面（sides）—— 48 款（A 47 / B 1）**这是发型的主体**

| # | 档 | 图包款式名 | 中文名 | 图里用的长度档 |
|---|---|---|---|---|
| 1 | A | `afro pouf` | 非洲蓬蓬头 | feet |
| 2 | A | `afro puffs` | 双丸子蓬发 | feet |
| 3 | A | `all down` | 全部披散 | feet |
| 4 | A | `bedhead` | 睡乱翘发 | feet |
| 5 | A | `braid left` | 左编辫 | feet |
| 6 | A | `braid right` | 右编辫 | feet |
| 7 | A | `bubble tails` | 泡泡双马尾 | feet |
| 8 | A | `crescent tails` | 月牙双马尾 | feet |
| 9 | A | `curl` | 卷发 | feet |
| 10 | A | `curly pigtails` | 卷双马尾 | feet |
| 11 | A | `curly side up` | 侧盘卷发 | feet |
| 12 | A | `default` | 默认短发 | feet |
| 13 | A | `defined curl` | 分束卷发 | feet |
| 14 | A | `drill ringlets` | 钻头卷 | feet |
| 15 | A | `flat ponytail` | 贴头马尾 | feet |
| 16 | A | `french bob` | 法式波波头 | feet |
| 17 | A | `fro` | 爆炸头 | feet |
| 18 | A | `half up twintail` | 半扎双马尾 | feet |
| 19 | A | `half-up` | 半扎发 | feet |
| 20 | A | `heart braid` | 心形编发 | feet |
| 21 | A | `jellyfish ponytail` | 水母马尾 | feet |
| 22 | A | `jellyfish twintails` | 水母双马尾 | feet |
| 23 | A | `layered bob` | 层次波波头 | feet |
| 24 | A | `loop braid` | 环形编发 | feet |
| 25 | A | `loose` | 松散披发 | feet |
| 26 | A | `low tails` | 低位双马尾 | feet |
| 27 | A | `messy` | 蓬乱发 | feet |
| 28 | A | `messy bun` | 蓬松丸子头 | feet |
| 29 | A | `messy ponytail` | 蓬乱马尾 | feet |
| 30 | A | `neat` | 利落短发 | feet |
| 31 | A | `pigtails` | 双马尾 | feet |
| 32 | A | `ponytail` | 马尾 | feet |
| 33 | A | `princess wave` | 公主大波浪 | feet |
| 34 | A | `ruffled` | 蓬起短发 | feet |
| 35 | A | `sailor buns` | 水手双丸子 | feet |
| 36 | A | `short` | 极短发 | feet |
| 37 | A | `sidecut` | 两侧剃短 | feet |
| 38 | A | `sidetail left` | 左侧马尾 | feet |
| 39 | A | `sidetail right` | 右侧马尾 | feet |
| 40 | A | `sleek` | 服帖直发 | feet |
| 41 | A | `space buns` | 太空双丸子 | feet |
| 42 | A | `straight bob` | 直发波波头 | feet |
| 43 | A | `swept left` | 左扫刘海 | feet |
| 44 | A | `thick pigtails` | 厚双马尾 | feet |
| 45 | A | `thick sidetail` | 厚侧马尾 | feet |
| 46 | A | `thick twintails` | 厚双马尾辫 | feet |
| 47 | A | `twintails` | 双马尾辫 | feet |
| 48 | B | `wavy braid` | 波浪编发 | feet |

> 图里是**叠在头骨上、上好发色**的效果 —— 灰度蒙版必须上色才看得出形状。
> 每款都取了它**最长的可用长度档**（看得最清楚）；文字里标的是用的哪一档。

## 三、发型 · 刘海（fringe）—— 37 款（A 36 / B 1）

| # | 档 | 图包款式名 | 中文名 |
|---|---|---|---|
| 1 | A | `aerial` | 轻薄空气刘海 |
| 2 | A | `back` | 后梳（露额） |
| 3 | A | `bedhead` | 睡乱翘发 |
| 4 | A | `blunt locks` | 齐刘海 |
| 5 | A | `bowl` | 锅盖头刘海 |
| 6 | A | `buzzcut` | 剃头 |
| 7 | B | `centred` | 中分刘海 |
| 8 | A | `curtain` | 中分帘式 |
| 9 | A | `default` | 默认短发 |
| 10 | A | `emo` | 斜长遮眼 |
| 11 | A | `emo left` | 左斜遮眼 |
| 12 | A | `emo right` | 右斜遮眼 |
| 13 | A | `flat` | 贴额刘海 |
| 14 | A | `framed` | 脸侧框发 |
| 15 | A | `fro` | 爆炸头 |
| 16 | A | `front braids` | 前额编发 |
| 17 | A | `hime` | 姬发式 |
| 18 | A | `loose` | 松散披发 |
| 19 | A | `loose antenna` | 散乱呆毛 |
| 20 | A | `messy` | 蓬乱发 |
| 21 | A | `messy curls` | 蓬乱卷刘海 |
| 22 | A | `overgrown` | 长长了没修 |
| 23 | A | `parted` | 分缝刘海 |
| 24 | A | `ruffled` | 蓬起短发 |
| 25 | A | `sectioned` | 分区短发 |
| 26 | A | `short air vents` | 短气孔刘海 |
| 27 | A | `side-pinned` | 侧别发夹 |
| 28 | A | `sideswept braid` | 侧扫编发 |
| 29 | A | `sleek` | 服帖直发 |
| 30 | A | `split` | 对半分开 |
| 31 | A | `straight` | 直刘海 |
| 32 | A | `straight tails` | 直发束尾 |
| 33 | A | `swept back` | 向后梳 |
| 34 | A | `swept left` | 左扫刘海 |
| 35 | A | `thin flaps` | 细碎薄片 |
| 36 | A | `tied back` | 向后扎起 |
| 37 | A | `trident` | 三叉刘海 |

> 刘海决定「正面看到的那一撮」。

## 四、发型 · 脑后（back）—— 13 款（A 13 / B 0）只有长发款才有这一层

| # | 档 | 图包款式名 | 中文名 |
|---|---|---|---|
| 1 | A | `all down` | 全部披散 |
| 2 | A | `bedhead` | 睡乱翘发 |
| 3 | A | `curl` | 卷发 |
| 4 | A | `default` | 默认短发 |
| 5 | A | `defined curl` | 分束卷发 |
| 6 | A | `half up twintail` | 半扎双马尾 |
| 7 | A | `loose` | 松散披发 |
| 8 | A | `messy ponytail` | 蓬乱马尾 |
| 9 | A | `neat` | 利落短发 |
| 10 | A | `princess wave` | 公主大波浪 |
| 11 | A | `ruffled` | 蓬起短发 |
| 12 | A | `sleek` | 服帖直发 |
| 13 | A | `straight` | 直刘海 |

> `back` 只有 `thighs` / `feet` 两个长度档 —— 短的够不着、也不需要。

## 五、不可用的款式（DoL 旧几何 —— 硬伤）

这些款在 AU 图包里还留着，但**几何是 DoL 的**（256×128 或 256×256），
贴到 AU 的小人身上会整个错位。都是名字与新款相同的「旧同名款」。

**鞋子**：**无** —— 50 款全部是新几何。

**发型 · sides（17 款）**：

```
crude            dreads             fluffy half up twintail
fluffy ponytail  left fishtail      princess twintails
ribbon tail      right fishtail     scorpion tails
shaved           short spiky        straight
thick ponytail   thick princess twintail
twin braids      twin double braids twin fishtails
```

**发型 · fringe（22 款 + 1 个 B 档）**：

```
crude            dread bun          dreadlocks
drill ringlets   fluffy wave        goopy
middlepart       milkmaid           mohawk
old_hime         opened curtain     princess wave
quiff            ringlet curl       ringlets
sidecut          straight curl      thorn and curl
torn and curl    voluminous smoke   wavy sickle
wide flaps       wispy
```

> 另有 `centred` 是**新几何但彩色**（sat 偏高）→ 它其实在 B 档，能用。

**发型 · back（7 款）**：

```
afro pouf   dreads      fluffy half up twintail
half-up     space buns  thick ponytail
voluminous smoke
```

## 六、挑完之后怎么加进游戏

1. `tools/dol_map.py` → `ITEMS` 那块加映射（`src` 指到款式目录）；
2. 若是发型，加进 `HAIR_STYLES`（点名 `style` / `length` / `fringe` / `back`）；
3. `scripts/OutfitData.gd` 的 `ITEMS_BASE` 加物品（`slot` / 数值 / `tags`）；
4. 跑 `python tools/dol_prepare.py` 烘图 → `godot --import` 登记资源；
5. 跑 `run_tests.bat` + 重拍截图。

> 具体数值（暴露值 / 接受度门槛 / 反差）要你定；
> 也可以按现有同槽位的档次给一版建议，你调。
