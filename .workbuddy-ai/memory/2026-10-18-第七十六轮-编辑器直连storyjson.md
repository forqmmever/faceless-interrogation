# 第七十六轮：编辑器直接编辑 data/story.json

> 用户口径：「编辑器现在直接编辑 data 中的 story.json，不要打开功能」。

## 一、做了什么

| 文件 | 改动 |
|---|---|
| `tools/story_server.py` | **新增**。标准库本地服务，`GET/POST /api/story`，127.0.0.1:8765 |
| `tools/story_editor.html` | 删「📂 打开」「另存为…」+ `input[type=file]` + 第 41 轮那套句柄/IndexedDB；保存改成 POST |
| `open_story_editor.bat` | 刷快照 → 起服务 → 开 `http://127.0.0.1:8765/`；没 python 时退回 `file://` 只读 |
| `tools/editor_smoke.js` | 探针加 `canSave` / `save` / `API_STORY`；新增第 16 节 6 条断言 |
| `.gitignore` | 加 `data/story.json.bak` / `.tmp` |

## 二、为什么必须加一个服务

浏览器给不了两样东西，缺一样都做不到「直接编辑那个文件」：

| 想要 | 实际 |
|---|---|
| `fetch("data/story.json")` | `file://` 下**被拦**（跨源），只能读页面内置快照 |
| 写回 `data/story.json` | `showSaveFilePicker` 只能让**用户手挑**文件，**不能指定路径** |

所以服务只干两件事：把文件原文吐出来、把 POST 上来的正文写回去。

- 写入**原子**：`.tmp` → `os.replace`。
- 旧版备份 `data/story.json.bak`（每次保存覆盖它）。
- 结构守卫：没有非空 `backgrounds` 数组 → 400。
- 只监听 `127.0.0.1`，不对外。

## 三、页面启动的三条路

| 顺序 | 条件 | `canSave` | 顶栏文案 |
|---|---|---|---|
| ① | `GET /api/story` 成功 | **true** | `data/story.json · 已同步 · 直连本地服务` |
| ② | 静态服务能读到 `data/story.json` | false | `…（只读）· 只读（没连上本地服务）` |
| ③ | 页面内置快照 | false | `内置快照（只读）· 只读（没连上本地服务）` |

`save()` 第一件事就是判 `canSave` —— 只读模式只弹提示，**不发请求、不下载**。
以前那条「浏览器不给就地写权限 → 下载一份」的回退删掉了：它会让人误以为存好了。

## 四、删掉的代码（第 41 轮那套）

`openFile` / `fileinput` 监听 / `writableHandle` / `idbOpen` / `idbPut` / `idbGet` /
`IDB_NAME` / `IDB_STORE` / `PICKER_ID` / `rememberedHandle` / `fileHandle` / `Ctrl+O`。
整块 5435 字符换成 3 个小函数（`getSeed` / `tryFetch` / `save`）。

★ **别改回 File System Access**：它天生做不到「就写这一个文件」。

## 五、验证

1. `curl` 真链路：`GET /api/story` 212918 字节 → `POST` 原样写回 →
   `git diff data/story.json` **为空**（往返无损）。
2. 结构守卫：`{"rules":{}}` → `400 {"ok": false, "error": "缺少 backgrounds 数组 —— 拒收…"}`。
3. `node tools/editor_smoke.js` → **367 / 12**（新增 6 条全过；失败仍是那 12 条用户数据）。
4. 页面顶栏实测：`curl http://127.0.0.1:8799/` 打出来只剩
   「💾 保存到 data/story.json / 📋 回退常量 / ↶ ↷」。
5. Godot 两套本轮没动（`data/story.json` 字节未变）→ 633 / 944 沿用。

## 六、踩坑

1. **`getSeed` 被我连带删掉了**。它原来和第 41 轮那套代码挨在一起，整块替换时漏了 →
   冒烟报 `ReferenceError: getSeed is not defined`。换整块代码后**先 grep 每个被删函数的所有调用点**。
2. **`tools/story_editor.html` 是 CRLF**。用 Python 改它必须
   `io.open(..., encoding="utf-8")`（自动归一成 `\n`）→ 改完 `newline="\r\n"` 写回；
   直接 `newline=""` 会让 `\n` 标记匹配不上。
3. **bash 里 `cd A && cmd &` 的 `&` 作用于整条 `&&` 链** —— 后半段 curl 跑在原来的 cwd，
   `-o 相对路径` 就写到别处去了。起后台服务改用工具的 `run_in_background`。
4. 端口被占时服务会直接退出并打印原因 —— 换个 `--port` 即可。

## 七、顺手抓到的真 bug：过关线其实还是 60

刷新内置快照之后才看见：`data/story.json` 里 `pass_suspicion` = **60**、`correct_delta` = **−6**。
第 75 轮只改了 `DEFAULT_RULES` / `Interrogation` 常量 / 文档，**json 那两键没跟上**。
`rules` 是**逐键覆盖** → 游戏实际跑的一直是旧过关线（其余 6 项增量倒是对了）。

**为什么测试没抓到**：`TestRunner` 验的是 `Interrogation.PASS_SUSPICION` 这个常量，
不是「运行时读到的值」。常量对、数据错，照样全绿。

修法：

- `story.json` → `pass_suspicion: 100` / `correct_delta: 0`
- `Interrogation` 新增 `const CORRECT_DELTA := 0.0`（原来三个调用点各写 `-6.0` 兜底，
  和 `DEFAULT_RULES` 的 0 早就对不上）
- `TestRunner` 新增一节「story.json 与常量必须一致」，用 `ScenarioData.rule_f(...)` 比 8 个关键项
- 「B 类题正面回应降低怀疑度」→「不涨怀疑值」（归零后「降」不成立）

★ 教训：**改数值的三处同步，第三处是「运行时读到的那份」**。
`DEFAULT_RULES` 是兜底，`const` 是调用点兜底，**都不等于游戏实际用的值**。

## 八、本轮最终数字

| 套件 | 数字 |
|---|---|
| `WardrobeTest` | 633 / 34（全是用户数据） |
| `TestRunner` | **952 / 0**（新增 8 条 rules 守卫） |
| `editor_smoke.js` | 367 / 12（全是用户数据） |
| 截图 | 43 张重拍，只有 3 张变化且全是噪声（相册 2 张 + 局号 1 行），已还原 |
