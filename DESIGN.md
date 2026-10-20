# 千面人：设计与实现

数据格式、编辑器、美术管线、测试与已知限制。

> 玩法与规则见 [`README.md`](README.md)。English version: [`DESIGN.en.md`](DESIGN.en.md)

---

## 题目数据 schema

每套背景只有一份 `questions[]`，**每道题是一个自带全部属性的对象**。
判定不看「这道题属于哪一类」，**只看每个选项自己的 `tone`**。

| 字段 | 说明 |
|---|---|
| `id` | 题目 id（一套背景里唯一） |
| `level` | `-1` = 通用池，`0..N` = 固定给第 N+1 轮 |
| `speaker` | 谁在问。存量数据里写了照旧生效，没写就是审讯官问 |
| `text` | 题面 |
| `setup` | 可选：前置说明（盲区题用它交代「档案里没有这件事」） |
| `card` | 可选：来源档案卡。**挂了卡就按卡的归属判** |
| `fact` | 可选：挂到哪条事实上，参与「跨轮不许改口」的一致性检查 |
| `recall` | 可选：标了它就是跨轮复问用的那道 |
| `qte` | `{kind, delay}`：这道题出哪种 QTE、几秒后出现 |
| `options[]` | 候选回答 |

`options[]` 每一项：

| 字段 | 说明 |
|---|---|
| `text` | 选项文本（`tone: silence` 时可以留空，用出厂那句通用文案） |
| `echo` | 可选：选完之后接在下一题题面前的那段。留空 = 显示 `text`；填了 = 原样显示。按钮上的字不变 |
| `tone` | **语义标签**，判定只看它（七种，见下） |
| `suspicion` | 选了它怀疑值加多少。**留空 = 用全局默认**（这样性情机制才生效） |
| `value` | 只有 `version` 要填 —— 代表哪个版本，跨轮比对靠它 |
| `ending` | 可选：填 `leak` = 当场暴露收场。和 `tone` 分开 |
| `shake` | 可选：选了它震一下屏（填力度） |

七种 `tone`：

| tone | 含义 | 代价 |
|---|---|---|
| `correct` | 照实答（B 卡的档案，对得上就没事） | `rules.correct_delta`（**0**） |
| `leak` | 说漏嘴（只有 A 才知道的事） | `rules.leak_delta`（**100**，当场出局） |
| `version` | 事实题的某个版本 | 由一致性判定 |
| `bluff` | 撒谎 | 按审问官性情现算 |
| `evade` | 回避 | 按审问官性情现算 |
| `silence` | 沉默 | `rules.silence_delta`（**12**，与性情无关） |
| `made_up` | 硬编一个细节（盲区题） | `rules.blind_made_up_delta`（**48**） |

**自行编辑的背景**（`questions_source = "manual"`）不自动加说话人名牌，也不加「你：」前缀 ——
题面与回应都按原文显示。自动生成的背景保留名牌。

---

## 数据与文件

### 目录

```
project.godot             Godot 4 配置（7 个 Autoload）
run_game.bat              双击开始游戏
run_tests.bat             双击跑全部测试
open_story_editor.bat     双击打开编辑器（会起一个本地小服务）
data/
  story.json              全部数据：背景 / 题目 / 选项 / 数值 / 文案 / 结局
  doll_au.json            小人图层表（由 tools/dol_prepare.py 产出）
assets/dol_au/            小人素材（base / clothes / icons）
scenes/Main.tscn          主场景（UI 全部代码构建）
scripts/                  16 个 GDScript
shaders/photo_blur.gdshader  相册照片的糊 / 反光 / 冲淡 / 颗粒
tools/
  story_editor.html       可视化编辑器（单文件网页）
  story_server.py         本地服务，让编辑器直接读写 story.json（8765）
  build_story_editor.py   把 story.json 内嵌进编辑器的内置快照
  dol_map.py              156 件衣物 → AU 图包的映射表
  dol_prepare.py          取帧 / 染色 / 裁框，烘进 assets/dol_au/
  DumpStory.tscn/.gd      把内置常量导出成 story.json（★ 会覆盖真实数据，慎用）
  editor_smoke.js         编辑器冒烟测试
tests/
  WardrobeTest.tscn/.gd   换装 + 数据层单元测试
  TestRunner.tscn/.gd     端到端测试
  Screenshot.tscn/.gd     真实渲染截图脚本
screenshots/              各阶段渲染截图 + 流程总览图
CHANGELOG.md              逐轮变更记录
```

### `data/story.json` 的顶层结构

| 键 | 内容 | 合并语义 |
|---|---|---|
| `rules` | 全部数值（题数、怀疑度、QTE、干扰、掏手机…） | 逐键覆盖 |
| `ui` | 界面文案 | 逐键覆盖 |
| `phone` | 手机文案（外壳 / 消息页 / 备忘录 / 相册 / 备注） | 逐键覆盖 |
| `levels` | 两轮的接受度 / 反差要求 | 整段替换 |
| `forced_rules` | 强制穿着 | 整段替换 |
| `qte_plan` | 按题号的 QTE 类型与延迟 | 整段替换 |
| `item_overrides` | 物品数值覆写 | 逐键覆盖 |
| `true_presets` | 原貌池（逐轮递进） | 整段替换 |
| `catalog` | 只读目录（供编辑器挑东西，游戏本身不读） | 整段替换 |
| `backgrounds` | 背景列表（卡 / 事实 / 题目 / 短信 / 轮次 / 强制穿着 / QTE / 缺陷） | 整段替换 |
| `traits` | 审讯官性情表 | 整段替换 |
| `endings` | 结局文案 | 逐键覆盖 |

**整段替换**的意思是：写了就盖掉整段，空字典被忽略。**逐键覆盖**只盖你写的那几个键。

缺文件时回落到 GDScript 里的 `DEFAULT_*` 常量，游戏照跑。

### 服装数据

`scripts/OutfitData.gd` 是**唯一权威**：槽位定义、156 件物品的数值、标签、原貌池。
其余全是派生快照：

| 派生 | 什么时候要重做 |
|---|---|
| `data/doll_au.json` 的图层 z | 改槽位 / 物品后重跑 `tools/dol_prepare.py` |
| `story.json` 的 `catalog` | 同上，重新导出 |
| `tools/story_editor.html` 的 `TRUE_POOL` | **手改**（JS 常量区） |
| `screenshots/_flow_overview.png` | 重跑 `tools/flow_overview.py` |

### 下架槽位

`OutfitData.gd` 里有两条名单，语义相反，别混用：

| 名单 | 含义 |
|---|---|
| `DISABLED_SLOTS` | 下架：物品与贴图都在，但不出现在换装界面 |
| `MANUAL_SLOTS` | 只能手动装备，不参与随机抽取 |

当前下架的 7 个槽位（外袍 / 耳饰 / 手套 / 头饰 / 穿环 / 配饰 / 妙妙工具）只是从
`DISABLED_SLOTS` 里删掉那一项就能恢复 —— 贴图与 `doll_au.json` 的图层都还在。

---

## 文本编辑器

`open_story_editor.bat` 会起一个本地小服务（8765），编辑器**直接读写** `data/story.json`。
用 `file://` 打开只能读内置快照，改不了文件。

左侧导航：

| 组 | 能改什么 |
|---|---|
| **基础** | 数值规则（题数 / 怀疑度 / 反差 / QTE / 干扰…）、界面文案、结局文案 |
| **背景** | 每套背景的卡 / 事实 / 题库 / 短信 / 轮次 / 强制穿着 / QTE 计划 / 缺陷 |
| **题库** | 每道题的题面、选项、`tone`、代价、QTE，拖动能调顺序 |
| **手机** | 外壳、消息页文案、备忘录格式、相册文案、备注文案 |
| **服装** | 物品数值、原貌池 |
| **校验** | 全量检查，**只放问题不放说明** |

**「自行编辑」模式**（`questions_source = "manual"`）：用不到的字段整节收起来（数据不动）。
判定改为只看怀疑值，不建档案卡与事实，不判盲区题。

**校验面板只放「问题」**：出厂数据必须 **0 错误 0 提醒**。
带占位符的字段空着会标红（`"" % 参数` 会直接报错）；不带占位符的字段空着**不算问题**，
会回落到出厂文案。

改完 `story.json` 要重建编辑器的内置快照（`build_story_editor.py`），冒烟测试读的是那份。

---

## 美术资产

小人**不是自己画的**，是现成的分层图包逐件映射过来的。只用 **AUfemale** 这一套
（社区重画，人物更高、有完整双腿）。

### 分层画布

所有图层裁到**同一个取景框 68×203**，换装时小人才不会跳。
染色烘在构建期、不放在运行时（染色是逐像素乘法，颜色又是固定的）。

### 管线

```
tools/dol_map.py（映射表）
      ↓
tools/dol_prepare.py（取帧 / 染色 / 裁框）
      ↓
assets/dol_au/*.png  +  data/doll_au.json
      ↓
godot --headless --path . --import      ← 漏了这步 Godot 看不见新图
```

### 挑贴图的规则

图包里的文件名不总是 `full.png`，按这个顺序挑（挑到全透明的就跳过）：

1. 先滤掉 `-acc` / `_acc` 变体（那是「附加装饰」那层，不是主体）
2. `full.png`
3. `full*`（不少件只有 `full-alt` / `full_gray` / `full-long`）
4. 带 `idle` 的（小人永远用站立手臂）
5. 数字名（`1.png` / `2.png` …）
6. 其余按名字排第一个

### 头发

头发（侧面 / 刘海 / 脑后三块）是**纯灰度蒙版**，换色必须走 `tint()`：
结果 = 发色 × 蒙版灰度，外加 `gain` 抬亮度。

**只能点名 AU 重画的新几何款**，不能写成「候选列表」—— 图包里同时留着旧款
（同名、256×128、还是红色），候选列表会先撞上旧款。
硬条件是**几何 512×256** 且**饱和度 0.00**，两个条件缺一不可。

### 成装

`dress` 是**两层源图叠加**（`upper/<款>` + `lower/<款>`，upper 在前）。
只取一层就只有上半身。加新成装第一件事：查这两层是否都在。

---

## 测试

四套，`run_tests.bat` 一次跑完。

| 套件 | 覆盖 | 怎么跑 |
|---|---|---|
| `WardrobeTest` | 换装 + 数据层单元测试 | `godot --headless --path . res://tests/WardrobeTest.tscn` |
| `TestRunner` | 端到端（整局流程） | `godot --headless --path . res://tests/TestRunner.tscn` |
| `editor_smoke.js` | 编辑器（含手机那 8 页） | `node tools/editor_smoke.js` |
| `Screenshot` | 真实渲染截图 | `godot --path . res://tests/Screenshot.tscn`（**非 headless**） |

前两套跑完都会打印「耗时合计」与「最耗时的前 8 段」，想调优直接看那个。

**断言条数每轮都会变，本文件不写具体数字** —— 跑一遍看，或看 `CHANGELOG.md`
末尾那张「测试规模的变化」表。

**跑完看三样**：

1. `Failures: 0`
2. 有没有 `SCRIPT ERROR` —— 报错不会让测试失败，只会让那一行断言静默消失
3. **断言总数有没有莫名减少**

---

## 截图

`screenshots/` 由 `tests/Screenshot.tscn` 生成，非 headless 真实渲染。
文件名按流程编号（`00_title_screen` → `22_contradiction`），另有 `_` 开头的工具产出图
（流程图、挑选对照图）。

---

## 已知限制

- **自行编辑（manual）仍受「每轮 6 道题」约束**。想「一局只问 2 道」得改数值规则，或把题按轮分配。
- **`relation` / `desc` / `speaker` 已从编辑器下线，运行时仍在读**。现在只能直接改 `story.json`。
- **手机外观预览没有**。想看效果只能跑游戏或看截图。
- **`index.html` 是早期 HTML5 原型**，规则与数值早和 Godot 版不同步，未删未清。
- **`border_post` 还留着 12 条 `cards`**（两套启用的背景都是自行编辑、`cards` 为空）。
  要不要在导出时清掉未定 —— 保留的理由是切回自动生成还能用。
