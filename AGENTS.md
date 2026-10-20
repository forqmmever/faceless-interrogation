# 千面人 · 伪装与高压审讯

Godot 4.3 单机文字 AVG + 换装。一局 = 2 轮（一次换装 + 一次盘问）。
本文件是**入口**，不是规约本身 —— 规则只有一份，在 `.workbuddy-ai/memory/MEMORY.md`。

## 开工前必读（按顺序，别跳过）

1. `.workbuddy-ai/memory/MEMORY.md` —— 每轮都要用的规矩（工作流 / 数据链路 / 测试写法 / 数值曲线 /
   架构约定 / 已知未处理的事）。**每个会话先读这份，它是唯一的「当前状态」。**
2. 要细节时再读 `.workbuddy-ai/memory/REFERENCE.md`，或对应轮次明细 `.workbuddy-ai/memory/YYYY-MM-DD-第N轮-*.md`。

动代码前没读第 1 条，就不要动代码。

★ **`交接.md` 已删除**（2026-10-20，第 95 轮）。它曾排在必读第一位、自称「当前状态」，
但停在 57 轮、验证数字全错、约束条目还在讲已删的键 —— 详见 `REFERENCE.md` 十三章。
**别再造同类文档**：当前状态只写进 `MEMORY.md`（每轮必读、每轮必改），历史看 `CHANGELOG.md`。

## 永不可违反（用户口径，压缩版）

- **只用 AU 图包**。DoL 链路已从代码拆掉，`assets/dol/` 与 `data/doll.json` 已删，**不要写回**。路径走 `DolDoll.root()` / `data_path()`，不写死。
- **不新增 emoji**：UI 文案、注释、README、提交信息、对话回复都算。已有的不必删。
- **只有一个编辑器**：`tools/story_editor.html`（手机那 8 页在左侧「手机」组）。不要拆回去。
- **术语是「一局 / 一轮」**，不用「关」。**一局 2 轮**。
- **`OutfitData.gd` 是服装唯一权威**，其余（`doll_au.json` 图层 z、`story.json` 的 `catalog`、编辑器 `TRUE_POOL`、流程图）全是派生快照，改权威表后要按固定顺序重烘。
- **`interrogator`（审讯官称呼）不能删** —— 准备室顶栏、手机备忘录第二条、短信联系人三处都在读它。
- **`DumpStory` 不能无条件重跑** —— 第 29 轮迁移的题目只存在于 `story.json`，重跑会全部冲掉。

## memory 只有一份

`.workbuddy-ai/memory/`（本仓库，进版本库）。`C:\Users\qiongmuming\WorkBuddy AI\...` 那份已冻结，
不再写入、不再同步、不要读。自动加载由本文件承担。

## 一轮的收尾

`CHANGELOG.md` 追加一节 → git 提交一次（提交信息 = 该节第一行，测试数字必须真跑过）→
`README.md` 写「为什么这么改」→ memory 写本轮明细。

验证（`WardrobeTest` / `TestRunner` / `editor_smoke.js` / `Screenshot`）**只在动了
`scripts/` `data/` `tests/` `tools/*_editor.html` 时跑**；纯文档 / 清点 / 出图跳过。
跑完看三样：`Failures: 0`、有没有 `SCRIPT ERROR`、断言总数有没有莫名减少。
