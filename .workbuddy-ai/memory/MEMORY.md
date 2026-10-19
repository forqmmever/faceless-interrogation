# 项目长期笔记（千面人 · 伪装与高压审讯）

> 只放**每轮都要用的规矩**。查阅型内容（图包 / GDScript 踩坑 / 脚本工具 / 图片比对 /
> 测试细则 / 架构细节 / 数值曲线）→ 同目录 `REFERENCE.md`；诊断与改动清单 → 按轮次分文件。

## 一、工作流

### 一轮的收尾动作

1. `CHANGELOG.md` 追加一节 → **git 提交一次**，提交信息 = 那节第一行。填「测试」那行**必须是真跑过的数字**。同一轮第二块工作写「第 N 轮（续）」。
2. `README.md` 写「为什么这么改 / 机制 / 数值表 / 踩坑」；被新改动作废的旧句**加 ★ 作废说明**。
3. `memory/` 写明细 —— 分文件，进版本库（`.workbuddy-ai/tmp/` **不进**）。

★ **memory 权威目录 = `D:\workbuddy\2026-10-11-09-19-59\.workbuddy-ai\memory\`（进版本库）**；
系统注入读的是 `C:\Users\...\WorkBuddy AI\2026-10-11-09-19-59\.workbuddy-ai\memory\MEMORY.md`
—— **改完必须同步这一份到 C:**（明细仍只在 D:）。C: 那份**超过约 17KB 会被截断**。

### 四套验证（只在动了 `scripts/` `data/` `tests/` `tools/*editor.html` 时跑）

```bash
godot --headless --path . res://tests/WardrobeTest.tscn   # 换装 + 数据层（~70 秒）
godot --headless --path . res://tests/TestRunner.tscn     # 端到端（~4~7 分钟）
node tools/editor_smoke.js                                 # 编辑器（含手机那 8 页）
godot --path . res://tests/Screenshot.tscn                 # 43 张截图 ★ 非 headless（~80 秒）
```

★ **只有一个编辑器** `tools/story_editor.html`。两套 Godot 测试**跑完都打印耗时前 8 段** —— 提速看那个。
★ 编辑器直接读写 `data/story.json`：`open_story_editor.bat` 起 `story_server.py`（8765）；`file://` = **只读**。
★ **改完 story.json 要跑 `python tools/build_story_editor.py` 重建快照**（冒烟读的就是那份）。
★ **`open_story_editor.bat` 必须纯 ASCII + CRLF**。★ `--check-only --script` **不加载 autoload**，报
  `Identifier not found` 不是语法错。
★ 用户 2026-10-15：「没动代码不用跑四套验证」—— 纯文档 / 清点 / 加工具**跳过**。
★ 长测试用 `run_in_background` + 重定向到 `.workbuddy-ai/tmp/*.log`；**跑时别改它读的资源**。

### 术语（用户 2026-10-15 定义）

**一局** = 一套背景 + 若干轮；**一轮** = 一次换装 + 问答（代码 `level_index`）。统一用「轮」。
★ 批量替换用「本关→本轮 / 每关→每轮 / 关卡→轮次」，**不动**「通关 / 过关 / 关键 / 相关 / 关闭」。
★ 别用 `line.split('#')[0]` 切注释 —— BBCode 的 `[color=#8a919c]` 会被当注释起点。

## 二、改数据的几条链路

### ★★ 逐轮类字段：只有背景页那一份（第 83 轮删掉了全局那页）

「🎬 背景 → ⑦ 本局覆写 · 几轮」写 `bg.levels[i]`，**游戏真正读的就是它**。
★ **标题写着「说明」不等于有说明字段** —— 排查「改不了」先数 `fields` 的键。
★ 选关面板要显示「这套背景的轮次名」，得用 `Main._levels_for_panel(bg_id)`：
`OutfitData.level_at()` 与 `RunData.levels()` 都取「当前这一局」，面板里还没开局。

### 改一句界面文案 → 同时找三处

① `ScenarioData.gd` 的 `DEFAULT_*`（兜底）；② `data/story.json`（**实际读的**，优先）；③ `tests/*.gd` 的**期望值**。
★ **改了占位符数量 = 改了接口**。六处同步：`_tf(...)` → `DEFAULT_*` → `story.json` → **占位符守卫断言**（两处）
→ 编辑器字段表 → `ui` 段的 `ph:true`。★ `phone.*` 另有两处登记：`PHONE_SEGS` / `PH_EXPECT`。
★ 数据里的**空串**会静默盖掉 `DEFAULT_*` 的整句（第 71 轮「掏手机越界一片空白」）。

### ★ story.json 的合并规则

`_item_desc` / `_backgrounds` / `_traits` / `_clue_frame` / `_clue_sources` / `_photo_notes` = **整段替换**；`_rules` / `_ui` / `_phone` = **逐键覆盖**。
★ **`DumpStory` 不能无条件重跑**：`backgrounds[].questions[]` 里的题目**只存在于 story.json**。
★★ **改 `rules` 的数值光改常量没用** —— `TestRunner` 用 `ScenarioData.rule_f(...)` 比常量（8 项守卫）。
★★ **不要用 `json.loads → 改 → json.dumps` 整体重写 `data/story.json`**（第 78 轮踩）：一次重写退回旧版。
要删/改几个键就用**逐行文本操作**，写完断言「背景数没变 + 字节数没暴跌」再 `git diff --stat`。

### ★ 派生数据不会自己跟上来

`OutfitData.gd` 是**唯一权威**，其余全是派生快照。改它的**槽位 / 标签 / 物品**时：

- `data/doll_au.json` 的图层 `z` → **重烘** `python tools/dol_prepare.py`
- `data/story.json` 的 `catalog` → 重导；`tools/story_editor.html` 的 `TRUE_POOL` → **手改**（JS 常量区）
- `screenshots/_flow_overview.png` → **重跑** `python tools/flow_overview.py`（**最容易漏**，不在四套验证里）

★ 改完权威表问一句「**哪些地方抄了它**」——出厂数据一改，**冒烟的「出厂状态」断言要跟着改**。

### 加新物品的固定顺序

`改代码 → 烘图 → godot --headless --path . --import → 导出 story.json → 重建快照 → 跑测试`
漏 `--import` → WardrobeTest 报「每件物品都有卡片图标」挂；漏重建快照 → 冒烟报 catalog 件数旧值。
删物品靠烘焙脚本 `prune_stale()` 自动清产物。

### ★★ 加「会被随机抽到 / 会被测试遍历」的内容型数据 → 先想草稿标志（第 53 轮）

先问：**① 半成品会不会被抽到？② 测试会不会遍历它？** 两个「会」→ 需要 `enabled`（草稿）标志
（`b.get("enabled", true) != false`，缺省 = 启用）。过滤只放在**产生新选择**的地方；
**按 id 取对象的地方不过滤**（存档里可能有后来被停用的背景）。

### ★★ 「自行编辑」模式（`questions_source = manual`）

编辑器把用不到的字段**整节收起来**（数据一条不动）：`MANUAL_HIDDEN_META` / `MANUAL_HIDDEN_COMPANION`、
③ 档案卡与 ④ 事实两节、题目 `recall`、选项 `tone` / `value`。★ **`interrogator`（称呼）不在此列**。
运行时三处：① `_is_unified_question()` 判据放宽成「有 `tone` 或 `text`」（否则掉进旧「档案题」路，
**完全不读你写的选项**）；② `is_blind` 加 `and not questions_are_manual()`；③ 未知 / 空 `tone` 取 `correct_delta`。
★★ **代价只认选项上的 `suspicion`**（第 77 轮）——「说漏嘴」也不例外。**每个选项都必须写它**（有守卫）。

### ★★ 盘问左栏四块（第 78 / 81 轮定稿 · 第 82 轮改布局）

`echo_label`（回应，淡蓝 #9ECCFA、字号 15）→ `dialogue_label`（题面，15 / 白）→
`feedback_label`（反馈区，12 / 灰，只放判定解释）→ 掏出手机 + 选项。
没写回应 / 第一题 → `echo_label.visible = false`。

- 回应**不能换题就清空**：`_load_question` 每次重新贴 `last_choice_text`；开新轮清空。
- 取法 `_choice_echo()`：写了 `echo` 原样；没写 → manual 留空、auto 加「你：」。
- 判定解释（口径不符 / 矛盾 / 带偏 / 盲区）用 `_append_feedback()` 写进反馈区。
  模板反馈句已删（`ui.feedback` 24 → 11 条）。**盲区题的「选对 / 选错 + 备忘录」必须留**。

★★ **这三块必须放在「有界滚动区」里**（第 82 轮）：`Control(clip_contents)` +
`ScrollContainer(横向 DISABLED / 纵向 AUTO)`。Label 换行后高度按行数长，
`PanelContainer` 会把它当最小高度 → 撑高父容器 → 整块溢出 720 的屏。
★ 普通 `Control.get_minimum_size()` 只认 `custom_minimum_size`，这是「不传给父容器」的关键。
★ 选项区用 `SHRINK_END`，别和文字区都 `EXPAND_FILL`。
★ `_set_dialogue(txt)` 写题面并显示；`_set_dialogue_visible(false)` 收起 ——
**点完选项就收起题面**，收场台词必须走 `_set_dialogue` 才会重新显示。
★★ **换题不要调 `_show_choice_echo()`** —— 它顺手清空反馈区，判定解释会只剩 1.8 秒。

### ★★ QTE 与强制穿着的默认语义（第 80 轮起 · 第 83 轮修正）

- **没写 `qte` 的题 = `none`**（`OutfitData.question_qte_plan()`：题目自带 > 按题号表 > none）。
  `QTE_NONE` 连**随机递话**一起关（`_intf_suppressed`）。
- **强制穿着 `fixed` 第 1 轮也生效**；`li <= 0` 只挡 `random`。
- ★★ **第 83 轮撤掉了「有规则就自动升级成 fixed」**：那条让 `{"mode":"none","rules":[...]}`
  的脏数据**真的强制了玩家**。现在 `mode` 说 none 就是没有要求，矛盾配置由编辑器**报错**。
- ⚠ `scene_1` 第 1 轮强制短袖校服 → 反差只到 **105 < 125**，120 种子里 6 个第 1 轮无解。
  **是用户配的内容、不是脏数据**，只报告不擅改。

### ★★ 缺陷（defects）只有背景一层（第 83 轮续 2 定稿）

- **全局 defects 层已彻底删掉**（编辑器那页、`story.json` 顶层段、`defects_override()`）。
  ★ 判据：**没有编辑入口的数据不许留**（会变成「改不了却偷偷生效」的隐形脏数据）。
- 只有两级：本套写过 `defects`（哪怕 `[]`）→ 用它，空就是没有；没写 → `DEFAULT_DEFECTS`。
  门面 `bg_has_defects(id)`。★ `levels` / `forced_rules` / `qte_plan` 的全局段**还在**。

### ★ 选关面板与通关按钮（第 86 轮）

- `_levels_for_panel()` 只返回轮次名（`Array[String]`）。**别再把 `derived_profile` 拼上去** ——
  背景没写时兜上来的是全局表默认值（「一个不起眼的路人」），玩家看着就是脏数据。
- 一局通关后 `_pending_action = "home"`（回标题）；`"new_run"` 只留给测试 / 截图脚本显式设。

### ★★ 反差公式（第 85 轮定稿）

```
单槽位 = |你穿的 exposure − 原貌那件| × contrast_per_exposure(5)
       + (暴露值相同 且 不是原貌那件) ? 「换了件」分 : 0
```
「换了件」分：基础 2 / **发型 12** / 妆容 10（三键都在 `DEFAULT_RULES` 与编辑器「⑥ 反差」）。
★ 两个条件缺一不可：暴露值不同时前半截已在给分（否则重复算）；穿回原貌仍须 0。
★ `base_id == ""`（原貌该栏没穿）**不加分** —— 没有「原貌那件」可比。
★ 发型 7 件全暴露 0 / 眼镜 3 / 妆 6 里 5 件 / 鞋 3 件全是 0 —— 这几栏以前怎么换都白换。

★★ **`contrast_req` 是每套背景自己的**（`bg.levels[i]`），同一个 125 不可能适配三套：
三套能到的上限实测 **126 / 193 / 162**（第 1 轮）。改它要按「随机搭配约 1/4 能过」定。
★★ **接受度不是瓶颈**（第 85 轮实测）：scene_1 第 1 轮 10 → 16 时 DP 最优恒为 126，
最优解只用 24/30 暴露 —— 卡住的是**结构**（强制件把某格锁死），不是额度。别先动它。

★★ **`story.json` 逐行替换：先打印区间结束行看一眼**，写盘后断言「**所有**同级段条数没变」——
第 83 轮用括号深度算结束行时 `forced_rules` 的 `{...}` 提前闭合，把 `defects` 整段吞了。
★ 第 83 轮删掉了左侧「流程」四页：这四项**只在背景页 ⑦ 里配**。
★ **机制类测试别依赖「当前数据配没配」**：自备一份出厂数据跑完还原。

### ★★ 结局文案「不写就不显示」（第 81 轮定稿）

- **三层兜底全拆**：`_fill_endings(false)` 不填模板、`endings_of()` 原样返回、
  `end_t` 没有 `dflt` 参数（没写就是 `""`）。只有「根本没有 story.json」那条演示路径填 `DEFAULT_ENDINGS`。
- ★ `_fill_endings(false)` 必须给「从文件读但没写 endings」的背景补一个**空字典**，
  否则 `endings_of()` 会判成内置常量、又退回模板。
- 界面：标题 / 正文 / 提示空 → `visible = false` 整块收起；**按钮空 → 只显示箭头（➔ / ↺）**。
- 调用点一律 `_et(key)` / `_etf(key, args)`，**不要再写兜底长句**。

## 三、测试怎么写（细则见 `REFERENCE.md` 五章）

- ★★ **校验面板只放「问题」** —— 出厂数据必须 **0 错误且 0 提醒**。**看到一大片提醒先怀疑规则本身**。
- ★★ **跑完看三样**：`Failures: 0`、**有没有 `SCRIPT ERROR`**、**断言总数有没有莫名减少**。
  **运行时报错不会让测试失败，只会让那一行静默消失**。取数组用 `_arr_of(d, key)`（`x or []` 恒返回 bool）。
- **防「空转通过」**：循环一次都不进 = 什么都没测。**加「样本里确实查到 N 条」的断言**。
- ★ **写断言的四个老坑**：① 只对部分对象生效的规则配**对照断言**；② 写完**故意改回错的**验证能抓到；
  ③「非空」断言看不见「少做一步」→ 判**数值范围**；④ 「单调」断言前**先写下取样点数值**。
  ★ 验「文本不重复」去掉「A. 」前缀再比（前缀把重名盖住，第 77 轮踩过）。
- ★★ **别让断言依赖「上一个测试留下的局」**（随机种子 → 假失败）。★ 断言「涨 N 点」前先**钉死基数**。
- ★ **纯函数测不出「时间线上的 bug」** → 状态随轮次变的要**走完整流程的探针**（`Main.tscn`）。
- ★★ **背景不止一种形态时，测试要自己挑背景**：`scene_*` 是 `manual`。依赖某类数据的**钉在 `_canonical_bg()`**。
- **用完清跨局状态**：`ProfileData.reset_all()` + 注入的 `_*_presets` 清回 `{}`。
- ★ **改全局数值 / 删文案键时** `tests/` 与 `editor_smoke.js` 里写死的计数会成片挂 —— 改用常量或 `>=`。
- ★★ **删代码前 grep 它定义的局部变量**（第 83 轮删全局校验带走 `knownTags` → 冒烟 `ReferenceError`）；
  ★ 删局部变量要搜**整个函数体**（续 2 漏了 `declared`，整个 autoload 起不来）。
- ★ **断言文案会跟着代码文案一起变**（「比上一关」→「比上一轮」）。

### ★★ 截图「变了」怎么判（细则见 `REFERENCE.md`）

1. **先 `git stash` 退回 HEAD 重拍**（三方对照）。`③新 vs ②HEAD = 0` 而 `①提交 vs ② ≠ 0` → **仓库那张是旧货**。
2. **「时对时错」先查这一屏状态钉没钉死**，再查异步定时器（`set_process(false)` **停不住 `await create_timer()`**）。
3. **判噪声**：① 同代码连跑三次一致 ② 差异稀疏点状 ③ `_plog` 逐字相同 → 抗锯齿差异。
   ★ 相册 / 带 shake / QTE 判负**每次跑都不同** → 与旧版差异量级 ≈ 同代码两次跑量级 → `git checkout --`。
4. ★ **报「真变」要给机制上的量** + 差异百分比 + bbox。

## 四、数值曲线的规矩（展开见 `REFERENCE.md` 七章）

★ **一局 2 轮**；**反差要求 125 / 150**；**暴露上限 = 10 + 接受度 × 2**（第 1 轮 10 → 30，第 2 轮 19 → 48）。
★ **怀疑度**：起点 20、过关线 100、`leak_delta = 100`。改过关线按「预算 = 线 − 起点」等比重标增量。
★ **接受度 vs 衣服**：165 件、`acceptance_req` 最大 **15**。第 1 轮 10 → 160/165；第 2 轮 19 → 全开。
★ 标定用 `WardrobeModel.auto_complete_outfit()`（`_dp_optimum` 会高估）；探针要覆盖测试种子池。
★ **反差 = 全槽位求和**，单件 `|你穿的 − 原貌那件| × 5`；改口径要同时**拉开原貌池** + **重标 `contrast_req`**。
★ **下装 / 成装是命门**：`FORCED_NEVER_SLOTS := ["bottom","dress"]`、不抽「与原貌完全相同」那件；
「抽原貌」必须在「抽强制装备」**之前**（各用独立随机流）。★ 报余量用**最差值**。

## 五、架构约定（细节见 `REFERENCE.md` 六章）

- **★ 只用 AU 图包（第 37 轮）**：产物只有 `assets/dol_au/` + `data/doll_au.json`。取景框 **68×203**。
- **★ 成装（`dress`）= 两层源图叠加**：只取一层只有上半身。加新成装先查 `upper/` 与 `lower/`。
- **两条槽位名单语义相反**：`DISABLED_SLOTS` = 下架；`MANUAL_SLOTS` = 只能手动装备。`active_slots()` / `auto_slots()` **别混用**。
- **多件槽位（`MULTI_SLOTS := {"tattoo": 2}`）**：`equipped` 里**单件 = `String`，多件 = `Array`** → **一律走访问器**。★ 测试里自己读写 `equipped[slot]` 最容易踩。
- **运行时覆写用 `static var`**：**「原地改容器」而非换新容器**；由 `_load_story()` 读完反调 `apply_*()`；落盘**只写「与内置值不同」的条目**。
- **★★ 多个调用点顺序不一致 → 改「写」的时机，不改调用点（第 71 轮）**：累加 + `call_deferred` 本帧末统一追加。
- **★ 一个文本变量服务多个选项时别整句替换**（第 77 轮）：只给「⚠ 前缀」。

### 五条硬规矩（展开见 `REFERENCE.md`）

① 「N / M」的分子分母必须同一个集合。② 改「初始化顺序」前先 grep 谁依赖它。③ 结构约束优于概率约束。
④ 稳定随机用确定性哈希，不能用 `RandomNumberGenerator`。⑤ DP 去重的键用归一化字段。
