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

### 稳定随机 vs 运行时随机

「同一道题要不要出 QTE」这种事，**必须用确定性哈希**（`hash("seed|关号|题号|标签")`），
不能用 `RandomNumberGenerator`。因为同一道题会被**反复装载**
（来回切题、重来本轮、测试里多次 `_load_question`）——
每次现摇会变成「同一题一会儿出一会儿不出」，玩家莫名其妙、测试也没法断言。

### GDScript 的坑（踩过的）

- **`arr or []` 非法** —— `or` 只吃 bool，会直接报错（表现为「打印到一半进程就没了」）
- **没有 `repr()`** —— 那是 Python 的
- **删跨行的 `print` 要连后半截一起删** —— 只匹配第一行会留下孤行 → Parse Error 且行号指偏
- **只读常量数组要整体 duplicate** —— 光 duplicate 元素不够，
  `_backgrounds[i] = bg` 这一步照样报 `Invalid assignment on read-only value`
