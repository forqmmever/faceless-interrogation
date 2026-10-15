# 项目长期笔记（千面人 · 伪装与高压审讯）

## 工作流约定

### 变更记录（第三十轮定下）

1. **每一轮结束**，在 `CHANGELOG.md` 追加一节，然后 **git 提交一次**。
   - 提交信息 = 那一节的第一行，例如 `第29轮：阶段二题目不再分类，改成可逐题编辑的清单`
   - CHANGELOG 里填「测试」那一行时，**必须是真的跑过**的数字
2. 三个记录位置的分工（别搞混）：
   | 位置 | 内容 | 粒度 |
   |---|---|---|
   | `CHANGELOG.md` | 每轮改了什么 | 一句话级别 |
   | `README.md` | 为什么这么改 / 机制说明 / 数值表 / 踩坑 | 主题级，按轮次章节组织 |
   | `.workbuddy-ai/memory/` | 诊断过程 / 具体改动 / 临时数据 | 明细级 |
3. **新记忆写项目盘的 `memory/`**，按轮次命名分文件（如 `2026-10-14-第N轮-xxx.md`）。
   > 历史遗留：早期记录分散在两个目录（项目盘的单文件日志 + 用户盘的分文件），
   > 暂不合并；新记录统一写项目盘。详见 CHANGELOG「详细记录在哪」一节。
4. `.workbuddy-ai/memory/` **进版本库**（`.workbuddy-ai/tmp/` 不进）。

### 一轮做完必须跑的验证

```bash
godot --headless --path . res://tests/WardrobeTest.tscn      # 换装 + 数据层
godot --headless --path . res://tests/TestRunner.tscn        # 端到端
node tools/editor_smoke.js                                    # 文本编辑器
node tools/phone_editor_smoke.js                              # 手机编辑器
godot --path . res://tests/Screenshot.tscn                    # 42 张截图（★ 非 headless）
```

## 技术约定

### 改 `data/story.json` 的两条铁律

1. **不能用 `DumpStory.tscn` 重跑来「顺便更新」** —— 从 GDScript 常量导出的只有
   `rules` / `ui` / `levels` / `forced_rules` / `qte_plan` / `defects` / `catalog` /
   `backgrounds` / `traits` / `item_desc` 等；但 `backgrounds[].questions[]` 里
   第二十九轮迁移出来的题目**只存在于 story.json**，常量里没有备份。
   重跑一次就把题目全冲掉。**要用脚本精确改字段**。
2. 改完必须**重建编辑器快照**：`python tools/build_story_editor.py`（以及 `build_phone_editor.py`），
   否则编辑器里的内置快照与 story.json 脱节，冒烟测试会挂。

### 文本与逻辑的分界

- **文本**（短信 / 对话 / 题目 / 选项 / 结局 / 界面文案 / 数值规则 / 关卡）→ `data/story.json`，编辑器改
- **逻辑**（判定 / 求解 / 渲染）→ `scripts/*.gd`
- 改数值或关卡**要重标**：README 里记录着每轮的实测「可达反差下限」，改完数值曲线要对得上

### 测试与判定的写法

- **不要按「题目的类别」写断言** —— 第二十九轮起题目不再分类，一律从数据形状推
  （`_q_kind()` 这类助手）；`kind` 字段只在旧格式兜底路径里存在。
- **不要假设「第 N 题是什么」** —— 题序 = 题目清单顺序，玩家可在题库页拖。
  用「按类型现找」的助手，不要 `_load_question(1)` 写死。
- **断言要防「空转通过」** —— 读一个已废弃的数据段时循环一次都不进，
  计数器全 0，断言全绿但什么都没测。加一条「样本里确实查到了 N 条」的断言防这个。

### 写「单调 / 递增」类断言时，先把取样点的数值写下来核对

第三十三轮踩的：想验「暴露值越高 → 触发概率越大」，取了三 个点
`min+5 / 中点 / min+15` —— 第三个点（25）其实**比中点（35）还低**，
于是断言写成 `0.10 < 0.50 < 0.30`，当场挂掉。

> 规矩：写 `a < b < c` 这类断言前，**先在纸上算出三个取样点的实际值**。
> 名字叫 low/mid/high 不代表数值真的递增 —— 尤其是从「最小值 + 偏移」推出来的点。

### 派生数据不会自己跟上来（三处都是「改了源表还得手动同步」）

改 `OutfitData.gd` 的**槽位或标签**时，除了改那一行，还必须记得：

1. **重烘图包**：`data/doll*.json` 里每件物品的图层 `z` 是从 `OutfitData.gd` 的槽位推出来的
   （`dol_prepare.item_slots()`）。第 32 轮把两件丁字裤从 `panties` 挪到 `bottom` 但没重烘，
   于是预览里它们一直画在下装**下面**，谁也没发现 —— 直到第三十四轮重烘才修好。
2. **重建 `story.json` 的 `catalog`**：那是 `DumpStory` 导出的只读快照，
   而 DumpStory **不能随便跑**（会用内置常量覆盖 JSON，冲掉只在 JSON 里的题库）。
   所以它只会越漂越远 —— 第 32 轮的槽位、第 28 轮的标签都漂了。
   正确做法是**用脚本按 `OutfitData.gd` 重建 `catalog.items`**，别去跑 DumpStory。
3. **`tools/story_editor.html` 里另有一份手写的 `TRUE_POOL` 常量** ——
   它在 JS 常量区、**不在内嵌快照的两个标记之间**，所以 `build_story_editor.py`
   重建快照时不会碰它，必须手改（否则编辑器的「原貌候选池」和游戏对不上）。

> 一句话：**`OutfitData.gd` 是唯一权威，其余全是派生快照。**
> 改完权威表顺手问一句「哪些地方抄了它」。

### 新增物品后必须先让 Godot 登记资源

烘完 `assets/dol*/` 的新 png 之后要跑一次
`godot --headless --path . --import`。
不然 `ResourceLoader.exists()` 对新 png 返回 false，
WardrobeTest 的「全部物品均有卡片图标」会挂 —— 而烘焙产物其实是好的，
只是没被 Godot 写进 `.godot/imported/`。这个坑第三十四轮踩过一次。

### 只使用 AU 图包（第三十七轮定下的硬约定）

用户口径：「现在和之后只使用 au 源的服装」。这不是「挑衣服时优先 AU」，
而是**DoL 那条链路已经从代码里拆掉了**：

- 唯一图包 = `au`。`tools/dol_prepare.py` 的 `PACKS` 只有 `au` 一项、`--pack` 默认 `au`；
  `tools/dol_map.py` 用 `AU_OVERRIDE`（不再有 `PACK_OVERRIDE` / `PACK_HAIR` / `hue_shift()`）；
  `scripts/DolDoll.gd` 只有三个常量 `PACK` / `ROOT` / `DATA_PATH`。
- **产物只有一份**：`assets/dol_au/` + `data/doll_au.json`。
  `assets/dol/` 与 `data/doll.json` 已删除，**不要再把它们写回代码或文档**。
- 取景框只有 AU 那一套（68×203，画布 512×256）；`ScenarioData.PHOTO_FOCUS` 是唯一一张表
  （以前按 `DolDoll.pack()` 分两张）。
- 引用路径一律走 `DolDoll.root()` / `DolDoll.data_path()`，**不要写死 `assets/dol_au`**
  —— 写死会绕过「换图包」这层抽象，测试也会变成假通过。

### DP 选项剪枝的两条铁律（第三十七轮）

「一键达标」的门控组（top/bra/bottom/dress/panties）算的是**笛卡尔积**。
补到 155 件后原积到 62 万，DP 从 0.2 秒涨到 7~8 秒 —— 靠 `_dedupe_equivalent()` 两级剪枝压到 27。

1. **① 去重的键必须用「归一化后」的字段**，不能用 `tags` / `gate` 的原文：
   要用 `_defect_mask_of(it)` 和 `data.outer_slots_of_item(it)`。
   用原文的后果：`tags` 顺序不同、或 `gate` 显式写 vs 回落 的等价件漏过 ①，
   进 ② 又因为语义确实相同而**互相判定为被支配、双双被删**，
   整个槽位候选清空 → 该组无解 → 「一键达标」静默返回「什么都没改」。
   （第三十七轮实测踩过，WardrobeTest 7 条断言才抓到。）
2. **② 帕累托剪枝里四项全同时只能让一方赢**（按序号），绝不互删。
   另外必须在**同一「行为签名」组内**比（`outer_slots_of_item` + `see` + `is_bare`），
   否则会剪掉「自己数值差一点但能把别的槽位露出来」的必需件。

验证手段：`tools/PerfProbe.tscn` 这种一次性探针很好用 —— 直接量「每个槽位去重前后候选数」
与 `auto_complete_outfit()` 的平均耗时。写完记得删。

### 稳定随机 vs 运行时随机

「同一道题要不要出 QTE」这种事，**必须用确定性哈希**（`hash("seed|关号|题号|标签")`），
不能用 `RandomNumberGenerator`。因为同一道题会被**反复装载**
（来回切题、重来本轮、测试里多次 `_load_question`）——
每次现摇会变成「同一题一会儿出一会儿不出」，玩家莫名其妙、测试也没法断言。

### 带反斜杠的 Python 脚本一律写成文件再跑（别用 heredoc）

Bash 的 heredoc 会把 `\\` 吞成 `\`。所以 `python - <<'PY' ... re.compile(r'[^"\\]') ... PY`
传进去的正则**已经被改坏**（`[^"\]` → `unterminated character set`）。
前几轮那些「看起来能用」的 heredoc 脚本其实也在被吞，只是刚好没炸。

> 规矩：脚本里只要出现正则、转义、Windows 路径反斜杠，就用 Write 工具写成
> `.workbuddy-ai/tmp/xxx.py` 再 `python xxx.py`。

### AU `bodywriting` 的位置集合有两套

- **14 个图案**（flower / star / heart …）有全套：`forehead` / `left·right-cheek` /
  `left·right-shoulder` / `left·right-thigh` / `breasts-0..6` / `pubic`。
- **`text/` 那 32 个短词**只有 **五个**：`forehead` / `left·right-thigh` / `breasts` /
  `pubic` —— **没有 cheek / shoulder**（`default` 例外，它全套都有，还带 `-arrow` / `-heart` 变体）。
- 两套**都没有 `neck`**，所以「颈侧刺青」只能借左肩（第二十六轮起的已知取舍）。
- 源图尺寸差异极大：`paw print` 5×5、`flower` 10×10、`heart`/`cross`/`flame` 那种
  大腿档是 14×78 的**竖长条** —— 挑图案时**必须逐个量 bbox**，不能照抄别人的 `scale`。
- ★ 第三十六轮起 `text/` 的四件刻字（bitch / free-use / slave / cum-rag）走的是**整字**路子：
  位置沿用图包自己的落点，`align` 由该部位字形 bbox 中心反算，只做小幅缩放（0.72 ~ 1.6）。
- ★ 那些 png 都是 **512×256 整画布**，左右两列各画一份 —— 探图脚本要自己过滤 x<130，
  否则会看到「一张图里好几个词」的假象（`clip_to_body()` 只负责烘焙时裁掉右列）。

### 多件槽位：`equipped` 的值有两种形态（第三十六轮起）

- `OutfitData.MULTI_SLOTS := {"tattoo": 2}` —— 只有纹身是多件槽位，其余槽位一件。
- `WardrobeModel.equipped` 的值：**单件槽位 = `String`，多件槽位 = `Array`**。
- **一律走访问器** `ids_at` / `id_at` / `has_id` / `set_ids` / `solid_ids` / `_ids_of`，
  不要再写 `str(equipped.get(slot, ""))` —— 多件槽位上那会得到 `["a", "b"]` 这种字符串。
- 多件槽位的「空件」必须标 `"bare": true`（`tattoo_none` 第三十六轮才补上），
  否则 `_settle_multi()` 会把它当成一件真货占名额。
- 门控也分了级：`OutfitData.outer_slots_of_item(item)` **先看这一件自己的 `gate`**，
  没有才退回槽位级的 `UNDER_GATE`。纹身按件写 gate（部位不同、遮盖不同），内衣内裤继续走槽位表。
- `_delta()` 的连带项扫 `OutfitData.gate_dependents(slot)`（静态缓存），
  并且**只在可见性真的翻转时**才重算那一槽位的贡献 —— 无条件重算会把 WardrobeTest 拖慢 3 倍。
- DP（一键达标）里多件槽位**故意不并进** `top/bra/dress/bottom/panties` 那一大块，
  自成一个单元素组、暴露值按保守口径计入（并进去选项数会从两万五涨到上百万）。

### GDScript 的坑（踩过的）

- **`arr or []` 非法** —— `or` 只吃 bool，会直接报错（表现为「打印到一半进程就没了」）
- **没有 `repr()`** —— 那是 Python 的
- **删跨行的 `print` 要连后半截一起删** —— 只匹配第一行会留下孤行 → Parse Error 且行号指偏
- **只读常量数组要整体 duplicate** —— 光 duplicate 元素不够，
  `_backgrounds[i] = bg` 这一步照样报 `Invalid assignment on read-only value`
