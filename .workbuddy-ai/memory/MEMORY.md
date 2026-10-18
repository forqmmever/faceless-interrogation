# 项目长期笔记（千面人 · 伪装与高压审讯）

> 只放**每轮都要用的规矩**。查阅型内容（图包知识 / GDScript 踩坑 / 脚本工具 / 图片比对 /
> 测试细则 / 架构细节 / 数值曲线）→ 同目录 `REFERENCE.md`；
> 诊断 / 改动清单 / 临时数据 → 按轮次分文件（`YYYY-MM-DD-第N轮-xxx.md`）。

## 一、工作流

### 一轮的收尾动作

1. `CHANGELOG.md` 追加一节 → **git 提交一次**，提交信息 = 那节第一行。填「测试」那行**必须是真跑过的数字**。同一轮第二块工作写「第 N 轮（续）」。
2. `README.md` 写「为什么这么改 / 机制 / 数值表 / 踩坑」；旧章节被新改动作废的句子**加 ★ 作废说明**，不改历史。
3. `memory/` 写明细 —— 分文件，进版本库（`.workbuddy-ai/tmp/` **不进**）。

★ **memory 权威目录 = `D:\workbuddy\2026-10-11-09-19-59\.workbuddy-ai\memory\`（进版本库）**；
系统注入读的是旧工作区 `C:\Users\...\WorkBuddy AI\2026-10-11-09-19-59\.workbuddy-ai\memory\MEMORY.md`
—— **`MEMORY.md` 改完必须同步一份到 C:**（只同步这一个文件，明细仍只在 D:）。C: 那份**超过约 17KB 会被截断**。

### 四套验证（只在动了 `scripts/` `data/` `tests/` `tools/*_editor.html` 时跑）

```bash
godot --headless --path . res://tests/WardrobeTest.tscn   # 换装 + 数据层（~70 秒）
godot --headless --path . res://tests/TestRunner.tscn     # 端到端（~4~7 分钟）
node tools/editor_smoke.js                                 # 编辑器（含手机那 8 页）
godot --path . res://tests/Screenshot.tscn                 # 43 张截图 ★ 非 headless（~80 秒）
```

★ **只有一个编辑器** `tools/story_editor.html`（`phone_editor.*` 第 55 轮已删）。
★ 两套 Godot 测试**跑完都打印「耗时合计」+「最耗时的前 8 段」** —— 提速**先看那个**。
★ **第 76 轮起编辑器直接读写 `data/story.json`**：`open_story_editor.bat` 起 `tools/story_server.py`
（`GET/POST /api/story`，127.0.0.1:8765）；`file://` 打开 = **只读**。**别改回 File System Access / 下载**。
★ **改完 `data/story.json` 要跑 `python tools/build_story_editor.py` 重建内置快照** ——
编辑器冒烟读的是 HTML 里那份快照，不同步就报旧数据的提醒（第 77 轮踩过）。
★ **`open_story_editor.bat` 必须纯 ASCII + CRLF**（第 77 轮续）：cmd 按 OEM 代码页读它，
存 UTF-8 的中文是乱码，再被「按 UTF-8 读」的编辑器（含本工具）存一次就变成一串 `?`。
用 Read/Edit 改它会按 UTF-8 重写 —— 改完**用 Python 转回 ascii + CRLF** 并验证 `all(b<128)`。
★ **Python 侧实测坑**：`sys.exit("一句话")` **写不进** `--log` 文件（那是解释器退出时打到 stderr 的，
文件没 flush）→ 用 `print` + `flush` 再 `exit`。
★ **Windows 的 `SO_REUSEADDR` 让两次 bind 都成功** —— 判断端口占用只能**主动 connect 一次**。
★ 用户 2026-10-15：「没动代码不用跑四套验证」—— 纯文档 / 清点 / 加工具**跳过**。
★ **后台跑长测试时不要同时改它读得到的资源**；长测试用 `run_in_background` + 重定向到 `.workbuddy-ai/tmp/*.log`（`| tail` 会吞输出）。
★ 本沙箱里 `start` 起的子进程会随命令结束被清掉 —— 验证「服务是否存活」必须和 `curl` 写**同一条命令**。

### 术语（用户 2026-10-15 定义）

**一局** = 含一套背景 + 若干轮的那一整盘；**一轮** = 一次换装 + 问答环节（代码 `level_index`）。统一用「轮」。
★ 替换用**精确模式 + SKIP 词表**：改「本关→本轮 / 每关→每轮 / 第 N 关→第 N 轮 / 关卡→轮次」，
**不动**「关口 / 关隘 / 通关 / 进关 / 过关 / 关心 / 关键 / 相关 / 关闭」；改完复查 diff。
★ 脚本里别用 `line.split('#')[0]` 切注释 —— BBCode 的 `[color=#8a919c]` 会被当注释起点。

## 二、改数据的几条链路

### ★★ 「逐轮」类字段有两份字段表，加字段必须加两处（第 72 轮）

`levelsFields()` 只给「🪜 关卡与轮数」页用（写 `story.levels`，**默认值**）；
「🎬 背景」页的「⑦ 本局覆写 · 几轮」是**另写的一份 `fields`**（写 `bg.levels[i]`，**游戏真正读的**）。
★ **标题写着「说明」不等于有说明字段** —— 排查「改不了」先数 `fields` 的键，别读标题。

### 改一句界面文案 → 同时找三处

① `ScenarioData.gd` 的 `DEFAULT_*`（兜底）；② `data/story.json`（**实际读的**，优先）；③ `tests/*.gd` 的**期望值**。
★ **改了占位符数量 = 改了接口**。六处同步：`_tf(...)` 参数 → `DEFAULT_*` → `story.json` →
**占位符守卫断言**（两处）→ 编辑器字段表 → `ui` 段的 `ph:true` 标记。
★ **`phone.*` 的文案字段分两处登记**：`PHONE_SEGS`（字段表）与 `PH_EXPECT`（占位符个数）。

### ★ 「为什么没显示」先查数据文件，别只读脚本

`story.json` 里的**空串**会静默盖掉 `DEFAULT_*` 的整句（第 71 轮「掏手机越界一片空白」）。

### ★ story.json：六段整段替换，三段逐键覆盖

`_item_desc` / `_backgrounds` / `_traits` / `_clue_frame` / `_clue_sources` / `_photo_notes` = **整段替换**（空字典被忽略）；`_rules` / `_ui` / `_phone` = **逐键覆盖**。
**同步办法**：备份 → 目标段置空写回 → 跑 `DumpStory` → 对比备份（**备份独有的键**应恰好是这轮删掉的那些）→ 重建快照。
★ **`DumpStory` 不能无条件重跑**：`backgrounds[].questions[]` 里第 29 轮迁移的题目**只存在于 story.json**。只改 `rules` / `levels` / `true_presets` 这类段**不用重导**。
★★ **改 `rules` 的数值光改常量没用** —— 第 75 轮漏了 `pass_suspicion`(60) / `correct_delta`(−6)，
整轮还在用旧过关线而测试全绿（验的是常量）。第 76 轮补了守卫：`TestRunner` 用 `ScenarioData.rule_f(...)` 比常量（8 项）。

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

先问两句：**① 半成品会不会被抽到？② 测试会不会遍历它？** 两个「会」→ 需要 `enabled`（草稿）标志。
判断式 `b.get("enabled", true) != false`（缺省 = 启用）。过滤只放在**产生新选择**的地方（抽局 / 列按钮 / 校验）；
**按 id 取对象的地方不过滤**（存档里可能有后来被停用的背景）。

### ★★ 「自行编辑」模式（`questions_source = manual`）

编辑器把用不到的字段**整节/整栏收起来**（数据一条不动）：`MANUAL_HIDDEN_META`、`MANUAL_HIDDEN_COMPANION`、
③ 档案卡与 ④ 事实两整节、题目 `recall`、选项 `tone` / `value`。
★ **`interrogator`（称呼）不在此列** —— 用户明确「审讯官的名字不删」。

运行时三处一起改：① `_is_unified_question()` 判据放宽成「有 `tone` 或 `text`」（否则掉进旧「档案题」那条路，
**完全不读你写的选项**）；② `is_blind` 加 `and not RunData.questions_are_manual()`（否则整局变盲区题）；
③ 未知 / 空 `tone` 分支的 `delta` 取 `correct_delta`（原来只改 `kind`，`delta` 还是 0）。
★★ **代价只认选项上的 `suspicion`**（第 77 轮用户口径）——「说漏嘴」也不例外：
`_select_option` 的 `ending == "leak"` / `kind == "leak"` 两条分支原来无条件 `+leak_delta`，
把选项写的数整个盖掉，已改成 `_add_suspicion(float(opt["delta"]))`。
**这类背景的每个选项都必须写 `suspicion`**（TestRunner 有守卫），编辑器也会给提醒。

## 三、测试怎么写（细则见 `REFERENCE.md` 五章）

- ★★ **编辑器校验面板只放「问题」，不放「说明」** —— 出厂数据必须 **0 错误且 0 提醒**（冒烟已断言守住）。**看到一大片提醒时先怀疑规则本身**（第 54 轮 57 条里 27 条是校验器算错）。
- ★★ **跑完测试看三样**：`Failures: 0`、**有没有 `SCRIPT ERROR`**、**断言总数有没有莫名减少**。**越界 / 运行时报错不会让测试失败，只会让那一行静默消失**。改「轮数 / 槽位数」这类常量后要 grep 所有带下标的断言。
  ★ 第 77 轮又踩一次：`(d.get("options", []) or [])` —— **GDScript 的 `or` 永远返回 bool**，缺字段时 `for x in true` 当场报错，整节断言静默消失而摘要照打「ALL PASSED」。取数组用 `_arr_of(d, key)`。
- **防「空转通过」**：循环一次都不进 → 断言全绿但什么都没测。**加「样本里确实查到 N 条」的断言**。
- ★ **写断言的四个老坑**：① 只对部分对象生效的规则要配**对照断言**；② 写完要**故意改回错的**验证它真能抓到 bug；③「存在性 / 非空」断言看不见「少做了一步」→ 要判**数值范围**，阈值用**实测**定；④ 写「单调 / 递增」断言前**先把取样点数值写下来**。
  ★ 第 77 轮再踩：验「按钮文本不重复」时比的是带「A. 」前缀的整串 —— **字母前缀把重名盖住了**，改坏代码断言照样 PASS。比之前先去掉前缀。
- ★★ **别让断言依赖「上一个测试留下的局」**：继承来的局是**随机种子** → 假失败，**同代码两次跑一挂一过**。要么自己开局，要么判据改成「相对量」。★ 凡断言「涨了 N 点」之前先**钉死基数**（第 75 轮继承到 100 上限，48 点被钳掉）。
- ★ **纯函数测试测不出「时间线上的 bug」** → 涉及「状态随轮次推进而变」的功能**必须再写一个走完整流程的探针**（`Main.tscn` 起场景）。判据：**测试里没出现两次以上状态推进，就测不到时间线**。
- ★★ **背景不止一种形态时，测试要自己挑背景**：`scene_*` 是 `manual`（没有档案卡 / 题目分类）。依赖某一类数据的测试**钉在 `_canonical_bg()`**；抽错不只是假红，`a_cards()[0]` 还会越界把后面几条**静默吞掉**。「最优值波动」这类断言要**逐背景分组**。
- **测试用完清跨局保留状态**：`ProfileData.reset_all()` + 注入的 `_*_presets` 清回 `{}`。
- ★ **改全局数值时 `tests/` 里写死旧数字的断言会成片挂** —— 改成引用常量或 `>=` 阈值。

### ★★ 截图「变了」怎么判（最容易误判，细则见 `REFERENCE.md`）

1. **先 `git stash` 退回 HEAD 重跑**（三方对照：①提交版 ②HEAD 重拍 ③新代码重拍）。`③ vs ② = 0` 而 `① vs ② ≠ 0` → **仓库里那张是旧货**。
2. **「时对时错」先查这一屏状态有没有钉死**，再查异步定时器。★ `set_process(false)` **停不住 `await create_timer()`**：先 `await _wait(120)` 让它过期，再 `_load_question()`。
3. **判噪声**：① 同代码连跑三次一致 ② 差异稀疏点状 ③ `_plog` 逐字相同 → 三条同时成立 = 抗锯齿差异。
   ★ 相册 SubViewport / 带 shake / QTE 判负**每次跑都不同** → 判据 = 「与旧版差异量级 ≈ 同代码两次跑量级」→ `git checkout --` **还原别提交**。
4. ★ **报「真变」要给机制上的量**，并附差异百分比与 bbox。

## 四、数值曲线的规矩（展开见 `REFERENCE.md` 七章）

★ **一局 2 轮**；**反差要求 125 / 150**；**暴露上限 = 10 + 接受度 × 2**（第 1 轮 10 → 30，第 2 轮 19 → 48）。
★ **怀疑度**：起点 20、过关线 100、`leak_delta = 100`。改过关线按「预算 = 线 − 起点」等比重标增量。
★ **接受度 vs 衣服**：全库 165 件、`acceptance_req` 最大 **15**（5 件：`top_none` / `bottom_none` / `dress_transparent` /
`dress_seethrough` / `panties_tieside`）。第 1 轮 10 → 160/165（有效槽位 132/137）；**第 2 轮 19 → 165/165，再加没用**。
★ 标定用 `WardrobeModel.auto_complete_outfit()`（测试里 `_dp_optimum` 会高估）；探针要覆盖测试用的种子池。
★ **反差 = 全槽位求和**（`CONTRAST_EXCLUDED_SLOTS := []`），单件 `|你穿的 − 原貌那件| × 5`；改口径必须同时**拉开原貌池** + **重标 `contrast_req`**。
★ **下装 / 成装是命门**（变露或被锁死 → 断崖下跌）：下装始终 `bottom_longskirt`、`FORCED_NEVER_SLOTS := ["bottom","dress"]`、
不抽「与原貌完全相同」那件；「抽原貌」必须在「抽强制装备」**之前**（各用独立随机流）。
★ **150 是实测定的**（第 2 轮写不了 160）；报余量用**最差值**不用中位。★ DP 的暴露账是**保守上界**，「局部最优」类断言按**同一本账**判。
★ 改轮数要动的全部位置见 `2026-10-16-第五十二轮-两轮制与减测试耗时.md` 第二节。

## 五、架构约定（细节见 `REFERENCE.md` 六章）

- **★ 只用 AU 图包（第 37 轮硬约定）**：DoL 链路**已从代码拆掉**，产物只有 `assets/dol_au/` + `data/doll_au.json`（**不要写回** `assets/dol/`）。取景框 **68×203**，路径走 `DolDoll.root()` / `data_path()`，**不要写死**。
- **★ 成装（`dress`）= 两层源图叠加**：**只取一层就只有上半身**。**加新成装第一件事**：查 `upper/<款>` 与 `lower/<款>` 都在不在。
- **两条槽位级名单语义相反**：`DISABLED_SLOTS` = 下架；`MANUAL_SLOTS` = 只能手动装备。`active_slots()`（界面口径）/ `auto_slots()`（自动流程 + 数值口径）**别混用**。
- **多件槽位（`MULTI_SLOTS := {"tattoo": 2}`）**：`equipped` 里**单件 = `String`，多件 = `Array`** → **一律走访问器**（`ids_at` / `set_ids` / `_ids_of`）；「空件」必须标 `"bare": true`。
  ★★ **测试里自己读写 `equipped[slot]` 最容易踩**（第 75 轮把 `Array` 写成字符串 → 纹身整栏从计算里消失）。用 `_slot_ids()` / `_restore_slot()` 这类帮手。
- **运行时覆写用 `static var`（唯一解）**：**「原地改容器」而非换新容器**；由 `ScenarioData._load_story()` 读完文件后**反调** `OutfitData.apply_*()`；落盘**只写「与内置值不同」的条目**。
- **★★ 多个调用点顺序不一致 → 改「写」的时机，不改调用点（第 71 轮）**：`_queue_delta_note()` 累加 + `call_deferred` 本帧末统一追加。判据：**同一动作 ≥3 个调用点且书写顺序不一致**。
- **★ 一个文本变量服务多个选项时，别整句替换**（第 77 轮）：`_trait_options()` 只该给「⚠ 前缀」，文本用每个选项自己的 —— 否则一道题里两个以上 bluff 会显示成同一句。

### 五条硬规矩（展开见 `REFERENCE.md`）

① 「N / M」的分子分母必须同一个集合。② 改「初始化顺序」前先 grep 谁依赖它。③ 结构约束优于概率约束。
④ 稳定随机用确定性哈希，不能用 `RandomNumberGenerator`。⑤ DP 去重的键用归一化字段，不能用 `tags` / `gate` 原文。
