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

### 四套验证（只在动了 `scripts/` `data/` `tests/` `tools/*_editor.html` 时跑）

```bash
godot --headless --path . res://tests/WardrobeTest.tscn   # 换装 + 数据层（~70 秒）
godot --headless --path . res://tests/TestRunner.tscn     # 端到端（~4~7 分钟）
node tools/editor_smoke.js                                 # 编辑器（含手机那 8 页）
godot --path . res://tests/Screenshot.tscn                 # 43 张截图 ★ 非 headless（~80 秒）
```

★ **只有一个编辑器** `tools/story_editor.html`（`phone_editor.*` 第 55 轮已删）。
★ 两套 Godot 测试**跑完都打印「耗时合计」+「最耗时的前 8 段」** —— 提速**先看那个**。
★ **第 76 轮起编辑器直接读写 `data/story.json`**：`open_story_editor.bat` 起 `story_server.py`（8765）；
`file://` 打开 = **只读**。★ **改完 story.json 要跑 `python tools/build_story_editor.py` 重建内置快照**。
★ **`open_story_editor.bat` 必须纯 ASCII + CRLF**（cmd 按 OEM 代码页读，UTF-8 中文会变乱码）。
★ **`--check-only --script` 不加载 autoload** —— 每个脚本都会报 `Identifier not found`，那不是语法错。
★ 用户 2026-10-15：「没动代码不用跑四套验证」—— 纯文档 / 清点 / 加工具**跳过**。
★ 长测试用 `run_in_background` + 重定向到 `.workbuddy-ai/tmp/*.log`；**跑的时候别改它读得到的资源**。

### 术语（用户 2026-10-15 定义）

**一局** = 含一套背景 + 若干轮的那一整盘；**一轮** = 一次换装 + 问答环节（代码 `level_index`）。统一用「轮」。
★ 替换用**精确模式 + SKIP 词表**：「本关→本轮 / 每关→每轮 / 第 N 关→第 N 轮 / 关卡→轮次」，
**不动**「关口 / 关隘 / 通关 / 进关 / 过关 / 关心 / 关键 / 相关 / 关闭」。
★ 脚本里别用 `line.split('#')[0]` 切注释 —— BBCode 的 `[color=#8a919c]` 会被当注释起点。

## 二、改数据的几条链路

### ★★ 逐轮类字段：第 83 轮起只剩背景页那一份（第 72 轮曾有两份）

「🎬 背景 → ⑦ 本局覆写 · 几轮」写 `bg.levels[i]`，**游戏真正读的就是它**。
★ **标题写着「说明」不等于有说明字段** —— 排查「改不了」先数 `fields` 的键。
★ 原来「🪜 关卡与轮数」页是另写的一份 `fields`（写 `story.levels`，只是默认值），第 83 轮已删。

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
要删/改几个键就用**逐行文本操作**，写完立刻断言「背景数没变 + 字节数没暴跌」再 `git diff --stat`。
### ★ 派生数据不会自己跟上来

`OutfitData.gd` 是**唯一权威**，其余全是派生快照。改它的**槽位 / 标签 / 物品**时：

- `data/doll_au.json` 的图层 `z` → **重烘** `python tools/dol_prepare.py`
- `data/story.json` 的 `catalog` → 重导；`tools/story_editor.html` 的 `TRUE_POOL` → **手改**（JS 常量区，**不在内嵌快照标记之间**）
- `screenshots/_flow_overview.png` → **重跑** `python tools/flow_overview.py`（不在四套验证里，**最容易漏**；图注表**写死了题数与手机次数**）。用 `.../envs/default/Scripts/python.exe`。

★ 改完权威表问一句「**哪些地方抄了它**」——出厂数据一改，**编辑器冒烟的「出厂状态」断言要跟着改**。

### 加新物品的固定顺序

`改代码 → 烘图 → godot --headless --path . --import → 导出 story.json → 重建快照 → 跑测试`
漏 `--import` → WardrobeTest 报「每件物品都有卡片图标」挂；漏重建快照 → 冒烟报 catalog 件数旧值。
删物品靠烘焙脚本 `prune_stale()` 自动清产物。

### ★★ 加「会被随机抽到 / 会被测试遍历」的内容型数据 → 先想草稿标志（第 53 轮）

先问：**① 半成品会不会被抽到？② 测试会不会遍历它？** 两个「会」→ 需要 `enabled`（草稿）标志
（`b.get("enabled", true) != false`，缺省 = 启用）。过滤只放在**产生新选择**的地方；
**按 id 取对象的地方不过滤**（存档里可能有后来被停用的背景）。

### ★★ 「自行编辑」模式（`questions_source = manual`）

编辑器把用不到的字段**整节/整栏收起来**（数据一条不动）：`MANUAL_HIDDEN_META`、`MANUAL_HIDDEN_COMPANION`、
③ 档案卡与 ④ 事实两整节、题目 `recall`、选项 `tone` / `value`。★ **`interrogator`（称呼）不在此列**。

运行时三处一起改：① `_is_unified_question()` 判据放宽成「有 `tone` 或 `text`」（否则掉进旧「档案题」那条路，
**完全不读你写的选项**）；② `is_blind` 加 `and not RunData.questions_are_manual()`；③ 未知 / 空 `tone`
的 `delta` 取 `correct_delta`。
★★ **代价只认选项上的 `suspicion`**（第 77 轮）——「说漏嘴」也不例外（两条 leak 分支原来无条件 `+leak_delta`）。
**这类背景的每个选项都必须写 `suspicion`**（TestRunner 有守卫）。

### ★★ 盘问界面四块（第 78 轮改位置、第 81 轮定稿）

`echo` → **题面之上**（`echo_label`，淡蓝 #9ECCFA、字号 15）→ 题面 → 反馈区（只放判定解释）→ 手机 + 选项。
- 回应**不能换题就清空**：`_load_question` 每次重新贴 `last_choice_text`；开新轮清空。
- 取法 `_choice_echo()`：写了 `echo` 原样；没写 → manual 留空、auto 加「你：」。
- 判定解释（口径不符 / 矛盾 / 带偏 / 盲区）用 `_append_feedback()` 写进反馈区。
- 模板反馈句已删（`ui.feedback` 24 → 11 条）。**盲区题的「选对 / 选错 + 备忘录」必须留**。

### ★★ QTE 与强制穿着的默认语义（第 80 轮起 · 第 83 轮修正）

- **没写 `qte` 的题 = `none`**。优先级在 `OutfitData.question_qte_plan()`：
  **题目自带 > 按题号的 `qte_plan` 表 > none**；未知类型退成 none。
  `QTE_NONE` 连**随机递话**一起关（`_intf_suppressed`）。
- **强制穿着的 `fixed` 第 1 轮也生效**；`li <= 0` 只挡 `random`。
- ★★ **第 83 轮撤掉了「有规则就自动升级成 fixed」**（第 80 轮加的）：那条让
  `{"mode":"none","rules":[...]}` 的脏数据**真的强制了玩家**（「我选的是没有要求，怎么被强制了」）。
  现在 `mode` 说 none 就是没有要求，配置矛盾由编辑器**报错**。
- ⚠ `scene_1` 第 1 轮强制短袖校服 → 上下装锁死、反差只到 **105 < 125**，
  120 种子里 6 个第 1 轮无解。**是用户配的内容、不是脏数据**，只报告不擅改。

### ★★ 背景的 `levels` / `forced_rules` / `qte_plan` / `defects` 覆写语义

**`defects`：空 = 这套没有缺陷**（第 83 轮续定的）。三级回落：
本套写过（哪怕 `[]`）→ 用本套；没写过 → 全局；都没有 → `DEFAULT_DEFECTS`。
门面：`ScenarioData.defects_declared()` / `bg_has_defects(id)`。
★ 以前「空就一路回落到出厂 2 项」，用户写 `[]` 也会被补上 —— 编辑器空、游戏里却有。
★ `levels` / `forced_rules` / `qte_plan` 仍是「空 = 回落全局」，只 `defects` 特殊。

★★ **改 `story.json` 的逐行替换：先把区间结束行打印出来人眼看**，写盘后断言
「**所有**同级段的条数没变」，不只断言被改的那一段 —— 第 83 轮我用括号深度算结束行，
`forced_rules` 里的 `{...}` 提前闭合导致区间越过 `qte_plan`、把 `defects` 整段吞了。

★ 第 83 轮删掉了左侧「流程（各套背景共用）」四页：这四项**只在背景页 ⑦ 里配**。
★ **机制类测试不要依赖「当前数据配没配」**：缺陷遮挡那一节现在自带一份出厂缺陷表跑完还原。

### ★★ 结局文案「不写就不显示」（第 81 轮定稿）

- **三层兜底全拆**：`_fill_endings(false)` 不填模板、`endings_of()` 原样返回、
  `end_t` 没有 `dflt` 参数（没写就是 `""`）。只有「根本没有 story.json」那条演示路径填 `DEFAULT_ENDINGS`。
- ★ `_fill_endings(false)` 必须给「从文件读但没写 endings」的背景补一个**空字典**，
  否则 `endings_of()` 会判成内置常量、又退回模板。
- 界面：标题 / 正文 / 提示空 → `visible = false` 整块收起；**按钮空 → 只显示箭头（➔ / ↺）**。
- 调用点一律 `_et(key)` / `_etf(key, args)`，**不要再写兜底长句**。
### ★★ 盘问左栏四块（第 81 轮定稿 · 第 82 轮改布局）

`echo_label`（回应，淡蓝 #9ECCFA、字号 15）→ `dialogue_label`（题面，15 / 白）→
`feedback_label`（反馈区，12 / 灰，只放判定解释）→ 掏出手机 + 选项。
没写回应 / 第一题 → `echo_label.visible = false`。

★★ **这三块必须放在「有界滚动区」里**（第 82 轮）：`Control(clip_contents)` +
`ScrollContainer(横向 DISABLED / 纵向 AUTO)`。理由：Label 换行后高度按行数长，
`PanelContainer` 会把它当最小高度 → 撑高父容器 → 整块溢出 720 的屏（第 3 套背景就是这么坏的）。
★ 普通 `Control` 的 `get_minimum_size()` 只认 `custom_minimum_size`，这是「不传给父容器」的关键。
★ 选项区用 `SHRINK_END`，别和文字区都 `EXPAND_FILL`（会各分一半，文字区只剩两百像素）。
★ `_set_dialogue(txt)` 写题面并显示；`_set_dialogue_visible(false)` 收起 ——
**点完选项就收起题面**，收场台词必须走 `_set_dialogue` 才会重新显示。
★★ **换题不要调 `_show_choice_echo()`** —— 它顺手清空反馈区，判定解释会只剩 1.8 秒。

## 三、测试怎么写（细则见 `REFERENCE.md` 五章）

- ★★ **编辑器校验面板只放「问题」，不放「说明」** —— 出厂数据必须 **0 错误且 0 提醒**。**看到一大片提醒时先怀疑规则本身**（第 54 轮 57 条里 27 条是校验器算错）。
- ★★ **跑完测试看三样**：`Failures: 0`、**有没有 `SCRIPT ERROR`**、**断言总数有没有莫名减少**。**运行时报错不会让测试失败，只会让那一行静默消失**。
  ★ `(d.get("options", []) or [])` —— **GDScript 的 `or` 永远返回 bool**，缺字段时 `for x in true` 当场报错、整节断言静默消失。取数组用 `_arr_of(d, key)`。
- **防「空转通过」**：循环一次都不进 → 断言全绿但什么都没测。**加「样本里确实查到 N 条」的断言**。
- ★ **写断言的四个老坑**：① 只对部分对象生效的规则要配**对照断言**；② 写完要**故意改回错的**验证它真能抓到 bug；③「存在性 / 非空」断言看不见「少做了一步」→ 要判**数值范围**；④ 写「单调」断言前**先把取样点数值写下来**。
  ★ 验「文本不重复」要去掉「A. 」前缀再比 —— **前缀把重名盖住了**（第 77 轮改坏代码仍然 PASS）。
- ★★ **别让断言依赖「上一个测试留下的局」**：继承来的局是**随机种子** → 假失败。★ 断言「涨了 N 点」之前先**钉死基数**。
- ★ **纯函数测试测不出「时间线上的 bug」** → 涉及「状态随轮次推进而变」的功能**必须再写一个走完整流程的探针**（`Main.tscn` 起场景）。
- ★★ **背景不止一种形态时，测试要自己挑背景**：`scene_*` 是 `manual`（没有档案卡）。依赖某一类数据的测试**钉在 `_canonical_bg()`**。
- **测试用完清跨局保留状态**：`ProfileData.reset_all()` + 注入的 `_*_presets` 清回 `{}`。
- ★ **改全局数值 / 删文案键时 `tests/` 和 `editor_smoke.js` 里写死的计数会成片挂** —— 改成引用常量或 `>=` 阈值。
- ★★ **删一段代码前 grep 它定义的局部变量**：第 83 轮删「全局缺陷校验」时带走了
  `const knownTags`，而**背景级**缺陷校验一直在用 → 冒烟当场 `ReferenceError`。
- ★ **断言文案会跟着代码文案一起变**：把校验从全局搬到背景级时改了措辞
  （「比上一关」→「比上一轮」、「mode 必须是」→「mode 只能是」），两条断言立刻变红。

### ★★ 截图「变了」怎么判（最容易误判，细则见 `REFERENCE.md`）

1. **先 `git stash` 退回 HEAD 重跑**（三方对照：①提交版 ②HEAD 重拍 ③新代码重拍）。`③ vs ② = 0` 而 `① vs ② ≠ 0` → **仓库里那张是旧货**。
2. **「时对时错」先查这一屏状态有没有钉死**，再查异步定时器。★ `set_process(false)` **停不住 `await create_timer()`**。
3. **判噪声**：① 同代码连跑三次一致 ② 差异稀疏点状 ③ `_plog` 逐字相同 → 三条同时成立 = 抗锯齿差异。
   ★ 相册 / 带 shake / QTE 判负**每次跑都不同** → 判据 =「与旧版差异量级 ≈ 同代码两次跑量级」→ 还原别提交。
4. ★ **报「真变」要给机制上的量** + 差异百分比 + bbox。

## 四、数值曲线的规矩（展开见 `REFERENCE.md` 七章）

★ **一局 2 轮**；**反差要求 125 / 150**；**暴露上限 = 10 + 接受度 × 2**（第 1 轮 10 → 30，第 2 轮 19 → 48）。
★ **怀疑度**：起点 20、过关线 100、`leak_delta = 100`。改过关线按「预算 = 线 − 起点」等比重标增量。
★ **接受度 vs 衣服**：全库 165 件、`acceptance_req` 最大 **15**。第 1 轮 10 → 160/165；**第 2 轮 19 → 165/165**。
★ 标定用 `WardrobeModel.auto_complete_outfit()`（`_dp_optimum` 会高估）；探针要覆盖测试用的种子池。
★ **反差 = 全槽位求和**，单件 `|你穿的 − 原貌那件| × 5`；改口径必须同时**拉开原貌池** + **重标 `contrast_req`**。
★ **下装 / 成装是命门**：`FORCED_NEVER_SLOTS := ["bottom","dress"]`、不抽「与原貌完全相同」那件；
「抽原貌」必须在「抽强制装备」**之前**（各用独立随机流）。
★ 报余量用**最差值**。★ DP 的暴露账是**保守上界**。

## 五、架构约定（细节见 `REFERENCE.md` 六章）

- **★ 只用 AU 图包（第 37 轮）**：产物只有 `assets/dol_au/` + `data/doll_au.json`。取景框 **68×203**，路径走 `DolDoll.root()`。
- **★ 成装（`dress`）= 两层源图叠加**：**只取一层就只有上半身**。加新成装先查 `upper/` 与 `lower/` 都在不在。
- **两条槽位名单语义相反**：`DISABLED_SLOTS` = 下架；`MANUAL_SLOTS` = 只能手动装备。`active_slots()` / `auto_slots()` **别混用**。
- **多件槽位（`MULTI_SLOTS := {"tattoo": 2}`）**：`equipped` 里**单件 = `String`，多件 = `Array`** → **一律走访问器**。★ 测试里自己读写 `equipped[slot]` 最容易踩。
- **运行时覆写用 `static var`**：**「原地改容器」而非换新容器**；由 `_load_story()` 读完反调 `apply_*()`；落盘**只写「与内置值不同」的条目**。
- **★★ 多个调用点顺序不一致 → 改「写」的时机，不改调用点（第 71 轮）**：累加 + `call_deferred` 本帧末统一追加。
- **★ 一个文本变量服务多个选项时，别整句替换**（第 77 轮）：只该给「⚠ 前缀」，文本用各自的。

### 五条硬规矩（展开见 `REFERENCE.md`）

① 「N / M」的分子分母必须同一个集合。② 改「初始化顺序」前先 grep 谁依赖它。③ 结构约束优于概率约束。
④ 稳定随机用确定性哈希，不能用 `RandomNumberGenerator`。⑤ DP 去重的键用归一化字段。
