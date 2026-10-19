# 参考手册（按需读，不常驻上下文）

> 从 `MEMORY.md` 拆出来的**查阅型**内容 —— 只在做图包 / 写脚本时读。
> `MEMORY.md` 只留「每轮都要用的规矩」。

## 一、AU 图包知识

### `bodywriting` 的位置集合有两套

**14 个图案**（flower / star / heart / paw print …）全套都有：`forehead` / `left·right-cheek` /
`left·right-shoulder` / `left·right-thigh` / `breasts-0..6` / `pubic`；**`text/` 那 32 个短词**只有
五个：`forehead` / `left·right-thigh` / `breasts` / `pubic`（`default` 例外，全套都有）。
两套**都没有 `neck`**（「颈侧刺青」只能借左肩）与**「小腿」**（小腿各只有 **8~11 px 宽**、鞋子从
y≈161 起盖住，**塞不下可辨认的图案**）。
★ **`paw print` 每个位置都是同一个 5×5 图案** —— 「用哪个位置当 `src`」不影响结果，**只有 `align`
决定落点**。源图尺寸差异极大（5×5 / 10×10 / `heart` 大腿档 14×78 竖长条）—— 挑图案**必须逐个量
bbox**，不能照抄别人的 `scale`。
★ 那些 png 都是 **512×256 整画布、左右两列各画一份** —— 探图脚本要自己过滤 `x<130`。

### 纹身 `align` 的反算公式

```
实际落点 = 1.5 × align − (43, 15)      # align = (视口中心 + (43, 15)) / 1.5
```

（`transform()` 里 `tx = (align.x − 58)×1.5 + 106`，取景框裁掉 62 → 视口 = 源图 − (62,0)。）
★ bodywriting 的 `scale` 要**除以 1.5** —— 它本来就是 AU 几何，再乘一遍 `align_scale` 会放大 1.5 倍。

### 挑款式时「长度档 / 部位」要实测，不能按名字推

同一系列不同款跨度**差几倍**（`pigtails` 的 `short` 109px ≈ `neat/short` 39px 的三倍；
`princess wave` **所有档都是 197px**）。**规矩**：选档前先量 `bbox`（尤其**最低点 y**）。
参照系：现有款最低点都在 84 以内、**小人鞋底 y=189**。
★ 目录语义容易猜错：`clothes/lower/` 是**下装** —— 找腰带 / 配饰要去 `hands/` `legs/` `neck/` 翻；
`clothes/legs/` 里既有袜子（归 `stockings` 槽）又有腿环；**AU 没有 `accessory` 目录**。

## 二、GDScript 踩坑

- **不支持单行 `if … else` 语句** —— `if x == null: a else: b` 直接 Parse Error。只支持
  `x if cond else y` 这种**表达式**；语句必须拆成多行。
- **`arr or []` 非法**（`or` 只吃 bool，表现为「打印到一半进程就没了」）；**没有 `repr()`**。
- **删跨行的 `print` 要连后半截一起删**，只匹配第一行会留下孤行 → Parse Error 且行号指偏。
- **只读常量数组要整体 duplicate** —— 光 duplicate 元素不够，`_backgrounds[i] = bg` 照样报
  `Invalid assignment on read-only value`。
- **`sort_custom` 是「不稳定排序」** —— 需要「相同键保持原顺序」时必须**带上原下标当第二键**。
- **`Cannot infer the type of "x" variable`** —— `for x in [10, 16]` 的循环变量是 Variant，
  要写成 `for xv in [10, 16]: var x := int(xv)`。
- **别把函数名当变量** —— `true_appearance` 是函数（`true_appearance.get(...)` 报
  `Cannot find property "get" on base "Callable"`），变量叫 `true_app`。

## 三、脚本与工具

- **带反斜杠的 Python 脚本一律写成文件再跑，别用 heredoc** —— Bash heredoc 会把 `\\` 吞成 `\`。
- **两个 Python 环境**：烘焙用 `Python39`（PIL 10.1.0）；量图 / 探针用
  `.workbuddy-ai/binaries/python/envs/default`（PIL 12.3.0）。别搞混。
- ★ **Windows 版 Python 不认 Git Bash 的 `/tmp`**（解析成 `<当前盘>:\tmp`）—— 先 `cygpath -w /tmp`。
- ★ **`godot` 不在 PATH** —— 一律用完整路径
  `"D:/WorkBuddy/godot/Godot_v4.3-stable_win64_console.exe"`。
- **编辑大文件后要回读一眼** —— 出现过「替换时把换行一起吃掉、两行合成一行」。

### ★★ 改 CRLF 文件：多行 old/new 必须先归一化行尾（第 54 轮定稿）

`tools/story_editor.html` / `phone_editor.html` / `flow_overview.py` 都是 **CRLF**。
用 `open(P,'rb').read().decode('utf-8')` 读进来时换行是 `\r\n`，
而 Python 字符串字面量里写的是 `\n` → **多行匹配必然失败**（`substring not found`）。
更阴的是：**匹配上了但 new 里写 `\n`，就会写出「混合行尾」**（第 52 轮踩过一次）。

**固定下来这个 helper，以后照抄：**

```python
s = open(P, 'rb').read().decode('utf-8')
NL = '\r\n' if '\r\n' in s else '\n'      # 先探测文件自己的行尾

def N(t):
    """把任意行尾归一化成文件自己的行尾 —— 不做这步就会匹配不上或写出混合行尾"""
    return t.replace('\r\n', '\n').replace('\n', NL)

def cut(a, b, new, label):
    """把 [a 起点, b 终点] 这一段整体换成 new —— 比一整段长串的精确匹配稳得多"""
    global s
    A, B = N(a), N(b)
    i = s.index(A); j = s.index(B, i) + len(B)
    s = s[:i] + N(new) + s[j:]

# 写回后立刻验一遍
b = s.encode('utf-8'); open(P, 'wb').write(b)
crlf = b.count(b'\r\n'); lone = b.count(b'\n') - crlf
print('CRLF=%d 单独LF=%d %s' % (crlf, lone, '✓' if lone == 0 else '★ 混合行尾！'))
```

★ **定位技巧**：先用 `s.count(短锚点) == 1` 验证唯一，再用 `cut(起始锚点, 结束锚点, ...)`
做区间替换 —— 比「一整段长字符串精确匹配」对空白 / 换行差异的容忍度高得多。
第 54 轮就是靠这个才把 7 处改动一次做对。

### ★ 编辑器脚本里的两个坑（第 53 轮）

1. **`editor_smoke.js` 第 74~94 行那段是「模板字符串里的 JS」**（反引号包围的
   `const mainJs = \`...\``）。**在那段区域里写注释时不能用反引号** ——
   我写了个 `` `renderQuestions` ``，直接把模板字符串提前终止 →
   `SyntaxError: Unexpected identifier`。
   ★ 要引用函数名就直接写 `renderQuestions`，别加反引号。
2. **往冒烟的对象字面量里加导出前，先确认那个函数真的还存在**。
   删掉 HTML 里的函数（比如 `renderQuestions`）却忘了同步冒烟里的导出列表，
   报的是 `ReferenceError: xxx is not defined`（因为对象简写会去求值那个标识符），
   而不是「属性不存在」。

### ★★ 编辑器现在直接读写 `data/story.json`（第 76 轮定稿）

用户口径：「编辑器现在直接编辑 data 中的 story.json，不要打开功能」。

链路：

```
open_story_editor.bat
  → python tools\build_story_editor.py         （刷内置快照，只读退路用）
  → start /min python tools\story_server.py --no-open
  → 浏览器开 http://127.0.0.1:8765/
```

服务（标准库，无依赖，只监听 127.0.0.1）：

| 路由 | 作用 |
|---|---|
| `GET /` | `tools/story_editor.html`（`no-store`） |
| `GET /api/story` | `data/story.json` 原文 |
| `POST /api/story` | 校验 → 备份 `data/story.json.bak` → 写 `.tmp` → `os.replace` |
| 其他 | 项目根下的静态文件（防目录穿越） |

页面启动三条路，**只有第一条能保存**：

1. `GET /api/story` 成功 → `canSave = true`（正常路径）
2. 静态服务能读到 `data/story.json` → 只读
3. 页面内置快照 → 只读

★ 第 41 轮那套 **File System Access + IndexedDB 记句柄**已整段删除
（`openFile` / `writableHandle` / `idbPut` / `idbGet` / `PICKER_ID` / `rememberedHandle`）。
**别改回去**：`showSaveFilePicker` 只能让用户手挑文件、指定不了路径，
`file://` 下连 `fetch` 都被拦 —— 那个方案天生做不到「就写这一个文件」。
★ 保存**不再有「下载一份」的回退**：只读模式下点保存只弹提示。
以前那条下载路会让人误以为存好了。

★ 结构守卫：`POST` 的 JSON 必须有非空 `backgrounds` 数组，否则 400 —— 防手滑写废整份数据。
★ 往返无损验证法：`curl` GET 到临时文件 → 原样 POST 回去 → `git diff data/story.json` 必须为空。

### 改两个编辑器快照（内嵌 seed）—— 不用重跑 `DumpStory`

`rules` / `ui` / `phone` 段是**逐键覆盖**语义，所以只改 `story.json` 里那几键时，
可以直接改 `tools/story_editor.html` / `phone_editor.html` 里的内嵌 seed（`<script id="seed">`），
**不用重跑 `DumpStory`**。

★ **先验「解析 → 紧凑重序列化」是否逐字节还原**，还原才敢用脚本改字段
（否则会把整份文件重排）。两个文件实测都是 `True`（106059 B，`separators=(",",":")` + `ensure_ascii=False`）：

```python
out = json.dumps(json.loads(raw), ensure_ascii=False, separators=(",", ":"))
same = (out == raw)
```

★ **两个坑（第 50 轮踩的）**：

1. **两处比较方式不同，不能共用同一对字符串。**
   `story.json` 的**原始行文本**里换行是**字面的 `\n`**（两个字符）→ 用子串 `in` 匹配；
   JSON **解析后的值**里是**真实换行** → 用全等 `==` 匹配。
   混用会**静默漏改**（第 50 轮漏了 `help.phone_marks` 那条，而 `phone_tip` / `tail` 却改成功了
   —— 表现得像「脚本只改了一部分」）。脚本里要维护两套：
   `RAW_PAIRS`（字面 `\n`，给行替换）与 `VAL_PAIRS`（真实换行，给 JSON 值）。
2. **脚本要幂等。** 第二次重跑时已改过的字段命中 **0 处**，若直接 `sys.exit(1)` 就 `ABORT`。
   改成「**新值已经在行里就跳过**」才能安全重跑。
3. ★★ **别用 `newline=""` 写这两个 HTML —— 会把整份文件的行尾从 CRLF 改成 LF。**
   第 50 轮踩的：`io.open(f, "w", encoding="utf-8", newline="")` 写出后，
   `tools/story_editor.html` / `phone_editor.html`（**3494 / 1261 行、全 CRLF**）
   整体变成 LF → `git diff --stat` 显示 **6988 / 2522 行变化**，
   真正的 4 行改动完全被淹没。（仓库里存的**就是 CRLF**：`core.autocrlf=false`、
   无 `.gitattributes`，所以行尾差异会实打实进 diff。）

   ```python
   # 正确的写法：写 bytes，保住原行尾
   raw = open(f, "rb").read()
   raw = raw.replace(old_bytes, new_bytes)     # 只在 seed 段内做字节级替换
   open(f, "wb").write(raw)

   # 已经写坏了就救回来（确认过当前无 \r 才敢这么干）
   b = open(f, "rb").read(); assert b"\r" not in b
   open(f, "wb").write(b.replace(b"\n", b"\r\n"))
   ```

   **判据**：改完两个 HTML 后 `git diff --stat` 应该只有**个位数行**；
   几百上千行就是行尾被动了。
   ★ `data/story.json` 本来就是 **LF**（7514 行），所以它用 `newline=""` 写反而没事 ——
   **动手前先量一下原文件的行尾**，别一刀切。

4. ★★★ **第 52 轮又踩了一次（同一个坑，换个文件）** ——
   `tools/flow_overview.py` 是 **CRLF**，我改了 4 行图注却让 `git diff --stat` 显示
   **306 行**变化。原因还是那句 `io.open(f,'w',encoding='utf-8',newline='')`。

   **根因**：`io.open(..., encoding='utf-8')` **读**的时候会把 `\r\n` 归一成 `\n`，
   再用 `newline=''`（不转换）**写**回去，`\n` 就是 `\n` —— **CRLF 文件被静默转成 LF**。

   **所以这不是「两个 HTML 的问题」，是「这整套「读文本 → 替换 → 写回」写法的问题」。**
   ★ 而这个写法在本项目里用得非常频繁（改 README / CHANGELOG / .gd / .js / 记忆文件都要用），
   它们**恰好都是 LF**，所以一直没暴露 —— 直到碰上 CRLF 的文件。

   **因此正确的做法是：每次做「读→改→写」之前，先花一行量原文件的行尾。**

   ```python
   # 动手前的第一件事
   b = open(f, 'rb').read()
   print(f, 'CRLF' if b.count(b'\r\n') else 'LF')
   ```

   三条可选路线，按可靠度排：

   | 做法 | 说明 |
   |---|---|
   | **① 全程 bytes**（最稳） | `raw = open(f,'rb').read()` → `raw.replace(old_bytes, new_bytes)` → `open(f,'wb').write(raw)`。**永远不改行尾**，但替换串要写成 bytes（中文要 `.encode('utf-8')`） |
   | ② 先探测再定 `newline` | `nl = '' if CRLF else '\n'`；写的时候 `newline=nl` |
   | ③ 写回后补一刀 | 确认当前无 `\r` 后 `b.replace(b'\n', b'\r\n')` —— 只在你已经忘了前两步时**救火**用 |

   **判据（每次改完都扫一眼）**：
   ```
   git diff --stat <改过的文件>
   ```
   行数 ≈ 你实际改的行数就对了；出现「文件行数 × 2」量级 = 行尾被动了。
   ★ 更省事的兜底：`git diff --stat` 里**任何一个文件的改动行数超过它的总行数的一半**，
   先怀疑行尾。

   **本项目已知是 CRLF 的文件**（截至第 52 轮）：`tools/story_editor.html`（3500 行）、
   `tools/phone_editor.html`（1261 行）、`tools/flow_overview.py`（153 行）。
   其余（README / CHANGELOG / scripts / tests / memory / story.json）都是 LF。

## 四、判「两张图是不是同一张」要两个独立方法交叉验证

① 文件 **MD5** 一致 ⇒ 绝对同一张；② `ImageChops.difference(a,b).getbbox()` 为 `None` ⇒ 逐像素一致。
★ 别只看尺寸 / bbox —— 图包里大量「bbox 一样但内容不同」。★ 反过来也成立：`chastitycage` 与
`chastitycagefetish` 的 `full.png` 完全相同；`props/npc/` 47 张拼起来是完整 NPC 立绘，不是道具。
★ 看差异用字符画：`ImageChops.difference(a,b).resize((96,27), Image.BOX)` + `ramp = ' .:-=+*#%@'`。
整块 UI 不同 → 大片 `#@`；文字边缘 → 稀疏 `.::`。

## 五、测试与排查细则（`MEMORY.md` 三章的展开）

### ★★ 越界不会让测试失败，只会让那一行静默消失（第 53 轮）

`WardrobeTest` 里这两行从第 52 轮起一直「没跑过」：

```gdscript
_check("第 4 轮解锁全部 4 条", int(seen[3]) == OutfitData.MAX_LEVELS)
```

第 52 轮把一局压成 2 轮之后 `seen` 只有 2 个元素 —— 访问 `seen[3]` 越界，
Godot 报 `SCRIPT ERROR: Out of bounds get index '3'` 并**跳过这一行**，
`_check` 根本没执行。而测试摘要照旧是 `Failures: 0`。

**所以跑完测试要同时看三样：**

| 看什么 | 为什么 |
|---|---|
| `Failures: 0` | 断言本身过不过 |
| **有没有 `SCRIPT ERROR`** | 运行时报错会让断言**静默消失** |
| **断言总数有没有莫名减少** | 唯一能发现「少跑了」的指标 |

★ 改「一局几轮 / 槽位数」这类常量后，**grep 所有带下标的断言**
（`seen[3]` / `LEVELS[3]` / `rows[3]` / `lv2[2]`）—— 夹具里的下标同样危险
（见「夹具里的下标访问」那节）。

### 空转通过

读一个**已废弃**的数据段时循环一次都不进 → 计数器全 0、断言全绿但什么都没测。
**加一条「样本里确实查到了 N 条」的断言防这个。** 第 49 轮给「局部最优」配了
「样本里出现过 DP 账卡满上限的轮次」—— 实测 480 轮里 **24 轮**，守卫通过。

### 对照断言

给「只对**部分**对象生效」的规则配**反向**断言，否则「对所有对象都生效」的写歪实现也能通过：

- 验「眼镜 / 发型 / 鞋子各自最多一次」→ 同时断言「**主体（上衣）不受这条限制**」。
- 验「成装必须覆盖上下两截」→ 配「**对照：短款上衣确实短**（露脐款底边 < 90）」
  —— 「短」不是一刀切禁止的。

### 假护栏：写完断言要验证它真能抓到 bug

标准动作：**把代码故意改回错的 → 确认断言挂 → 恢复 → 重跑**。
第 49 轮实测：把 `dress_nurse` 改回单层 → 输出
`没覆盖上下两截的成装: ["dress_nurse（y48-74，需 y72-104 以上）"]` + `[FAIL]` → 恢复。
**不做这一步就无法排除「新断言其实永远通过」。**

### 「存在性 / 非空」断言看不见「少做了一步」

第 49 轮的成装 bug（只烘 `upper` 一层）活了 **12 轮**、580 条断言一条都没响 ——
旧断言查的是「文件存在」「图层有可见内容」，少叠一层**两者都满足**。
**唯一能看出来的是几何形状**（像素实际延伸到哪儿），所以断言要判**数值范围**，
阈值用**实测**定：当轮量出「上衣底边 76~112 / 下装 y83..124 / 修好后成装 106~188 /
错的 74~87」→ 取 **104** 把两类干净分开，**空档 19px**。

### 「单调 / 递增」类断言：先把取样点数值写下来

第 33 轮踩的：想验「暴露值越高 → 概率越大」，取 `min+5 / 中点 / min+15` ——
第三个点（25）其实**比中点（35）还低**，于是 `0.10 < 0.50 < 0.30` 当场挂。
**名字叫 low/mid/high 不代表数值真的递增。**

### 纯函数测试测不出「时间线上的 bug」

第 40 轮两个 bug 都不是单元测试发现的：

- **「假防御」**：`for s in group` 遍历的是**嵌套**数组，`str(s)` 得 `'["dress"]'`，
  `dict.get()` 永远查不到 → 整段是死代码，注释却写着「这是纯防御」。
- **「粘关」**：未配覆写的关沿用了上一关的原貌。★ 单元测试当时**是绿的** ——
  它只测 `_apply_preset()` 这个纯函数，没测 `start_new_run → advance_level → advance_level`。

**规矩**：涉及「状态随时间 / 轮次推进而变」的功能，除了纯函数测试，
**必须再写一个走完整流程的探针**（哪怕临时、用完就删）。
判据：**测试里如果没出现两次以上的状态推进，它就测不到时间线。**
★ **探针要跑真实链路** —— 第 44 轮直接调 `RunData.start_new_run()` 看到某个字段是 0
（看起来像「功能没生效」），真相是它由 **UI 层**写入。验游戏行为要用
`load("res://scenes/Main.tscn").instantiate()` 起真实场景。

### 其它两条

- **约束的作用域是「整局」时，测试也要走完整流程** —— 照片是「开局 3 张 + 每轮 +2 张」
  逐轮追加的，「整局各自最多一次」只跑开局那 3 张验不出来。
- **测试用完要清「跨局保留」的状态** —— `ProfileData.add_gain()`（接受度）跨局保留，
  用例里反复 `advance_level()` 会把它永久推高 → 后面「开局接受度」当场挂。
  **结尾必须显式还原**（`reset_all()` + 把注入的 `_*_presets` 清回 `{}`）。

### ★★ 夹具里的「下标访问」会因常量改动而越界，且越界会跳过「还原现场」（第 52 轮）

`_test_true_presets` 的清洗夹具 `by_level` 还是 4 项，而一局已经改成 2 轮：

```gdscript
and (lv2[1] as Dictionary).is_empty()
and (lv2[2] as Dictionary).is_empty()   # ← 越界！lv2 只有 2 项
and (lv2[3] as Dictionary).is_empty()
```

越界 → **函数当场中断** → 末尾那句「把全局预设还回来」**没执行** →
`ScenarioData._true_presets` 被夹具永久污染 → 后面**一整片**断言假红
（15 条失败里的大半都源于此，但它们看起来像「曲线标定错了」）。

**教训：**

1. 改「一局几轮 / 槽位数」这类常量时，**逐个 grep 夹具里的下标**
   （`lv2[2]` / `LEVELS[3]` / `level_select_rows[3]` 这类）。
2. **看到「一大批断言同时红」先怀疑「共享状态被污染」，别先怀疑产品逻辑。**
   定位手法：在可疑断言前**插一行 `print` 把共享状态打出来** ——
   本轮打印 `ScenarioData._true_presets` 一眼就看到了夹具值。
3. GDScript 没有 `finally`，所以夹具的「还回」只能靠**不在中间 return / 越界**来保证。
   带下标的断言本身就是风险点。

### ★★ 减少测试耗时：先量，再找「白跑」的那部分（第 52 轮，147 → 30 秒）

1. **先量。** 给 `_ready()` 加**常驻**的分段计时（`Callable` 数组 + `call()` 跑），
   跑完打印「耗时合计」+「最耗时的前 8 段」。数据会立刻告诉你该动哪。
   ★ `TestRunner` 里有 `await` 协程，**不能用动态 `call()` 包**（会把执行顺序弄乱）
   —— 改成「在两段测试之间打点」。
2. **找出白跑的部分（关键）。** 本轮最大的一段是 `强制装备可解性`（占 80%）：
   它对每一轮都跑一次 DP，但打印出来的统计是 **`71 / 240 轮带强制装备`** ——
   **70% 的 DP 在验一件根本不存在的东西**（没有强制装备的轮次不该验「强制装备会不会死局」，
   那是重复验「普通可解性」，已被别的段落覆盖）。
   **跳过它们 = 零覆盖损失地砍掉 70% 的 DP。**
3. **种子数尽量别减。** 第 2 步拿到大部分收益后，`FORCED_SEEDS` 仍是 120、
   `PROBE_SEEDS` 仍是 40 —— 中途试过减到 60（再省 4 秒）又**还回去了**，
   不值得用一半覆盖换 4 秒。
4. 统计口径（如 `levels_with_forced`）**照旧在跳过之前算** —— 它们是
   「规则确实按轮生效」的证据，省不得。

实测：`WardrobeTest` 147 → **30~40 秒**（一键达标 与 强制装备可解性 两段是大头）。

### 截图「变了」不一定是回归 —— 三条判据（第 40 轮）

真凶常是跑过 `--import` 后**导入缓存刷新**、字体图集烘焙变了 → 文字边缘抗锯齿略有差异。
**三条同时成立 = 抗锯齿差异，别当回归**：

1. 同一份代码**连跑三次完全一致**（渲染本身是确定性的）
2. 差异是**稀疏点状** —— 降采样成字符画看得出是文字边缘，不是整块 UI
3. 该镜头的 `_plog` 状态输出**逐字相同**

★ 二分排查时**先做「代码全还原」这一步**，一次性排除所有代码嫌疑，比逐个文件试快得多。

### ★★ 还有一类「每次跑都不一样」的镜头（第 50 轮补）

上面那三条判据是针对「`--import` 后字体图集重烘」的（差异**稀疏点状**）。
但**有一批镜头本身就带渲染非确定性**，跑几次就有几种结果 —— 它们的差异**不是**稀疏点状：

| 镜头类型 | 例子 | 为什么 |
|---|---|---|
| **SubViewport 实时渲染 + 噪点 / 模糊 shader** | `06_phone_album` / `07_phone_album_cleared` | 照片是 `SubViewport` 里渲的，噪点与模糊每次采样的随机相位不同 → **整块照片区**都变 |
| **带抖动（`shake`）或动画进度条** | `19_expression_qte` / `20_leak_exposed` / `25_run_failed` | 抖动让整个界面**位移**若干像素 → 大面积稀疏差异；进度条停在的帧也不同 |

**判据（第 50 轮实测出来的）**：

> **「与旧版的差异量级」≈「同一份代码连跑两次的差异量级」⇒ 非确定性渲染，不是回归。**

实测（差异像素数，`-` 分隔为 `>0 / >8 / >40`）：

| 对比 | `06_phone_album` | `07_phone_album_cleared` |
|---|---|---|
| 旧版 vs 本轮 | 22000 / 14223 / 1895 | 15528 / 2614 / 0 |
| **同代码两次跑** | **21998 / 14261 / 1856** | **15542 / 2759 / 0** |

两组数字几乎完全一样 → 差异**全部**来自渲染噪声。逐像素比对（判据①「连跑三次一致」）
在这类镜头上**必然失败**（三次三个样），所以**它单独不能证伪**，必须配上这条量级对比。

★ **处理办法：把这几个文件 `git checkout --` 还原成上一版，别提交噪声。**
否则每次重拍都会在 git 里留下几个永远「未提交」的脏文件，
真正因代码 / 文案变化的截图反而被淹没。
（第 50 轮 43 张重拍后，真正该提交的只有 3 张：`00e_help_phone`、`09_phone_interrogator_sms`、
`_flow_overview` —— 其余 5 张全是噪声。）

### ★★ 第三类：**全局常量变了** → 全部截图都该提交（第 52 轮补）

改「一局几轮」「槽位数」这类全局常量时，**几乎所有**含进度文字的镜头都会变
（选关面板 4 行 → 2 行、顶栏「第 1 / 2 轮」、通关覆盖层「2/2 轮」）。
第 52 轮就是 43 张**全部**提交。

★ 这里踩到一个判据上的坑：**16×16 实心变化块判据对「少数字符变化」不敏感**。
`4/4 关` → `2/2 轮` 只改了几十个像素，实心块数 = **0**，会被误判成「文字抗锯齿噪声」。
（那个判据是为「整栏消失 / 卡片增减」这类**成片**变化设计的。）

**所以第三类要用「两个量比量级」，不是数实心块：**

| 判据 | 判读 |
|---|---|
| `差异(新图 vs HEAD)` ÷ `差异(同代码两次跑)` | **> 3 倍** → 真实变化；**≈ 1 倍** → 噪声量级 |

第 52 轮实测：43 张里 35 张 > 3 倍（真变化）、8 张 ≈ 1 倍（4 张是 SubViewport / 抖动，
4 张差异只有 46~135 像素、无法断定）。**但既然全局常量变了，43 张全部提交** ——
新图就是「当前代码的真实渲染」，那才是正确状态。

★ 三种情况的判据汇总：

| 情况 | 怎么判 |
|---|---|
| 只跑了 `--import`（字体图集重烘） | 三条判据（连跑三次一致 + 稀疏点状 + `_plog` 逐字相同） |
| SubViewport / 抖动镜头 | 差异量级 ≈ 同代码两次跑 → 噪声，`git checkout --` 还原 |
| **全局常量变了** | 差异量级 > 3 倍同代码两次跑 → 真变化；**全部提交** |

## 六、架构细节（`MEMORY.md` 五章的展开）

### ★★ 新增「会被随机抽到 / 会被测试遍历」的内容型数据 → 先想草稿标志（第 53 轮）

第 53 轮要做「编辑器新增背景」时发现的：一套背景「能上场」的硬门槛不少
（12 张档案卡 / 每轮 1 道盲区题 / 每轮 1 条事实+1 条揭示它的短信 / 干扰台词 ≥4），
**而开局是随机抽背景的** —— 抽到空背景直接崩，测试也会一片红。

解法是加一个 **`enabled`（草稿 / 启用）** 标志：

| 草稿（`enabled: false`） | 已启用（**缺省**，或 `true`） |
|---|---|
| 不被抽到（抽局的池子过滤掉它） | 会被抽到 |
| 不进测试的内容校验 | 逐项校验 |
| 校验面板只给**一条**提醒 | 有问题逐条报 |
| 编辑器照常显示、照常编辑 | 同左 |

**判断式：`b.get("enabled", true) != false`** —— 缺省 = 启用，
所以出厂数据一个字段都不用补（向后兼容）。

**以后再加这类数据（背景 / 题目 / 原貌预设 / 缺陷…）先问两句：
① 半成品会不会被抽到？② 测试会不会遍历它？两个都是「会」→ 草稿机制是前提，不是装饰。**

★ **过滤只放在「产生新选择」的地方**（抽局、列按钮、校验），
**不要放在「按 id 取已有对象」的地方** —— `ScenarioData.get_background(id)` 故意
不过滤草稿，因为存档里可能记着一套后来被停用的背景，玩家点「继续游戏」时
仍要能取到它、把这一局走完。

### ★ 官方随机流：要「覆盖结果」不要「跳过抽取」

`RunData.start_new_run(seed, level, bg_id)` 支持指定背景时，
**无论指不指定都先消耗一次 `_rng.randi()`**（结果被覆盖掉）：

```gdscript
	var rolled := str(ids[_rng.randi() % ids.size()])
	background_id = bg_id if (bg_id != "" and ids.has(bg_id)) else rolled
```

原貌 / 情报 / 性情 / 强制装备全从同一个 `_rng` 出，所以「跳过抽取」会让后续随机
**整体错位** → 同一个种子换个参数就变出另一个人，**可复现性一起没了**
（截图 / 测试都靠固定种子）。

**「抽一次再丢弃」= 随机流恒定。**
★ 这类不变式一定要落成断言（TestRunner：「指定背景不改变后续随机流」），
否则下次有人顺手把 `randi()` 挪进 `else` 分支就没人发现。

### ★ 只使用 AU 图包（第 37 轮起的硬约定）

不是「优先 AU」，而是 **DoL 那条链路已从代码里拆掉**：唯一图包 = `au`
（`dol_prepare.PACKS` 只有 `au`；`dol_map` 用 `AU_OVERRIDE`，不再有 `PACK_OVERRIDE` /
`PACK_HAIR` / `hue_shift()`；`DolDoll.gd` 只有 `PACK`/`ROOT`/`DATA_PATH`）。
**产物只有一份**：`assets/dol_au/` + `data/doll_au.json`；`assets/dol/` 与 `data/doll.json`
已删，**不要再写回代码或文档**。取景框只有 AU 一套（**68×203**，画布 512×256，
`crop = (62,0,130,203)` 纯平移无缩放）。引用路径一律走 `DolDoll.root()` / `data_path()`，
**不要写死 `assets/dol_au`** —— 写死会绕过「换图包」这层抽象，测试也变成假通过。

### ★ 成装（`dress` 槽）= 两层源图叠加

AU 把每件成装拆成**两个文件**，**只取一层就会只有上半身**（第 49 轮修的 bug）：

```python
"dress_nurse": [{"src": ("clothes", "upper", "pinknurse"), "tint": WHITE},
                {"src": ("clothes", "lower", "pinknurse"), "tint": WHITE}],
```

两层的 y 范围**精密衔接**（74→74 / 82→82 / 85→85 / 87→85），这是「一整套被拆开存」的铁证；
叠放顺序 `upper` 在前、`lower` 在后 → 后画的盖上 → 「裙子压住上衣下摆」。
例外：`dress_slip`（babydoll）AU 里没有 `lower/` 对应目录，单层就完整。
**加新成装时第一件事**：查 `upper/<款>` 和 `lower/<款>` 是否都存在。

### 两条「槽位级名单」语义相反，别搞混（第 39 轮）

```gdscript
OutfitData.DISABLED_SLOTS   # 下架：玩家看不到
OutfitData.MANUAL_SLOTS     # 只能手动装备：看得到、点得到，但系统从不代劳
```

| 表 | 界面可见 | 能手动穿 | 原貌 | 情报 | 相册 | 强制池 | 一键达标 | 数值统计 |
|---|---|---|---|---|---|---|---|---|
| `DISABLED_SLOTS` | 否 | 否 | 不抽 | 不问 | 不拍 | 不进 | 不动 | 不算 |
| `MANUAL_SLOTS` | **是** | **是** | 不抽 | 不问 | 不拍 | 不进 | **不动** | **不算** |

- `active_slots()` = `SLOT_ORDER - DISABLED_SLOTS` —— **界面口径**
- `auto_slots()` = `active_slots() - MANUAL_SLOTS` —— **自动流程 / 数值口径**
  （原貌 / 情报 / 相册 / 强制池 / 一键达标 / 一致数统计）
- `slot_enabled()` / `is_manual_slot()` —— 单项判断

★ 新加槽位先问：会出现在换装界面吗（→ `active_slots()`）？该被系统自动抽 / 算吗（→ 不在 `MANUAL_SLOTS`）？
★ 一次不一致就直接出假数字：`peek_hint` 曾印出「13 / 14 处仍一致」。
**凡是「N / M」的显示，分子分母必须同一个集合。**

### 多件槽位：`equipped` 的值有两种形态

- `OutfitData.MULTI_SLOTS := {"tattoo": 2}` —— 只有纹身是多件槽位。
- `WardrobeModel.equipped`：**单件槽位 = `String`，多件槽位 = `Array`**。
- **一律走访问器** `ids_at` / `id_at` / `has_id` / `set_ids` / `solid_ids` / `_ids_of` ——
  别写 `str(equipped.get(slot,""))`（多件槽位上会得到 `["a","b"]` 字符串）。
- 多件槽位的「空件」必须标 `"bare": true`，否则 `_settle_multi()` 把它当真货占名额。
- 门控分级：`outer_slots_of_item(item)` **先看这一件自己的 `gate`**，没有才退回槽位级 `UNDER_GATE`。
- `_delta()` 的连带项只在**可见性真的翻转时**才重算 —— 无条件重算会把测试拖慢 3 倍。

### 运行时覆写：`static var` 是唯一解

要让「一份 JSON 在运行期改掉代码里的常量表」：

- `const` 改不了（编译期只读）；普通 `var` 又不行（`static func` 够不着实例成员）
  → **`static var` 是唯一解**，而且原有的 `OutfitData.ITEMS` 写法一行都不用改。
  ★ 连带的缓存（`_by_slot` / `_by_id` / `_stat_max`）**也要一起改 `static var`**。
- **必须「原地改容器」而不是「换新容器」** —— 全项目几十处**直接读** `X.ITEMS`，
  换表的话那些引用点还拿旧表。
- **autoload 顺序决定谁读得到谁**：`OutfitData` 在 `ScenarioData` 之前 ready，
  数据却在后者手里 → 覆写要由 `ScenarioData._load_story()` 读完文件后**反调** `OutfitData.apply_*()`。
  兜底函数里**绝不能**在「数据源还没就绪」时标记完成，否则空覆写会被当成最终结果、永远丢失。

★ 覆写类数据落盘：**只写「与内置值不同」的条目** —— 改回内置值就删掉那个字段。
好处：文件干净（默认 `{}`）、语义明确（**文件里有 = 改过**）、校验能直接报「这条多余」。

### 五条硬规矩的展开

- **改「初始化顺序」前先 grep 谁依赖那个顺序** —— `start_new_run()` 里 `level_index`
  原本在 `_roll_true_appearance()` **之后**才赋值。第 40 轮让原貌依赖 `level_index` 后，
  这个顺序就成了 bug（「从选关面板直接进第 N 轮」会取到上一局残留的轮次号）。
- **稳定随机 vs 运行时随机** —— 「同一道题要不要出 QTE」这类**必须用确定性哈希**
  （`hash("seed|轮号|题号|标签")`），不能用 `RandomNumberGenerator`：同一道题会被**反复装载**
  （来回切题 / 重来本轮 / 测试），每次现摇会变成「同一题一会儿出一会儿不出」。
- **结构约束优于概率约束** —— 相册要求「上半身不能出现鞋子、下半身不能出现头发 / 眼镜」。
  做法不是「取完候选再筛一遍」，而是**按组取候选**（上半身只从 `PHOTO_UPPER` 取）
  —— 越界在**结构上不可能发生**。**能做成结构约束的，就别做成概率约束。**
- **DP 去重的键要用「归一化后」字段**（`_defect_mask_of` / `outer_slots_of_item`），
  不能用 `tags` / `gate` 原文 —— 否则等价件互相判定被支配、双双被删 → 该组无解 →
  「一键达标」静默返回「什么都没改」。帕累托剪枝四项全同时**只能让一方赢**（按序号），绝不互删。

### ★★ 盘问左栏四块（第 78 / 81 轮定稿 · 第 82 轮改布局）

从上到下：

| 控件 | 内容 | 样式 |
|---|---|---|
| `echo_label` | 上一句**回应**（玩家刚选的那句的复述） | 淡蓝 `#9ECCFA`、字号 15 |
| `dialogue_label` | 题面 | 字号 15 / 白 |
| `feedback_label` | 反馈区 —— **只放判定解释**，不放模板句 | 字号 12 / 灰 |
| （手机按钮 + 选项） | | |

没写回应 / 第一题 → `echo_label.visible = false`。

- 回应**不能换题就清空**：`_load_question` 每次重新贴 `last_choice_text`；开新轮才清空。
- 取法 `_choice_echo()`：写了 `echo` 原样用；没写 → manual 留空、auto 加「你：」。
- 判定解释（口径不符 / 矛盾 / 带偏 / 盲区）用 `_append_feedback()` 写进反馈区。
  模板反馈句已删（`ui.feedback` 24 → 11 条）。**盲区题的「选对 / 选错 + 备忘录」必须留**。
- ★ `_set_dialogue(txt)` 显示题面 / `_set_dialogue_visible(false)` 收起 —— **点完选项就收起题面**；
  收场台词必须走 `_set_dialogue` 才会重新显示。
- ★★ **换题不要调 `_show_choice_echo()`** —— 它顺手清空反馈区，判定解释会只剩 1.8 秒。

**★ 这三块必须放在「有界滚动区」里**（第 82 轮）：`Control(clip_contents)` +
`ScrollContainer(横向 DISABLED / 纵向 AUTO)`。Label 换行后高度按行数长，
`PanelContainer` 会把它当最小高度 → 撑高父容器 → 整块溢出 720 的屏。

- ★ 普通 `Control.get_minimum_size()` **只认 `custom_minimum_size`** —— 这是「高度不传给父容器」的关键。
- ★ 选项区用 `SHRINK_END`，别和文字区都 `EXPAND_FILL`。

## 七、数值曲线的展开（`MEMORY.md` 四章）

### 反差 = 全槽位求和

`WardrobeModel.CONTRAST_EXCLUDED_SLOTS := []`（**空 = 不排除任何槽位**）——
所有「看得见」（过门控）的槽位都计反差，含纹身。单件口径 `|你穿的暴露度 − 原貌那件| × 5`。

★ **改口径必须同时做两件事**：
① **拉开原貌池** —— 原貌暴露值几乎全 0 时 `Σ|你 − 原貌|` 退化成 `Σ你穿的` = 暴露值 × 5
（**共线**），反差只是暴露值的别名；
② **重标 `contrast_req`**。

出厂 `true_presets.by_level` 带逐轮递进；两轮要求**手写 125 / 150**；
`rules` 出厂 `base` 125 / `step` 15。实测余量 **+80 / +5**。

★★ **150 是实测定的，别凭感觉改**：2 轮的可达区间是 **205~210** 与 **155~215**（中位 215）——
第 2 轮**写不了 160**（最不利那个原貌最多到 155，写 160 = 有种子无解）。

★ **报「余量」要用最差值、不能用中位** —— 第 2 轮中位余量有 +65，只有最不利的原貌紧到 +5，
而本作的难度本来就是「由原貌决定」的。

### 下装 / 成装是整条曲线的命门

**变露**或**被锁死** → 可达上限**断崖式下跌**
（第 49 轮实测：下装进强制池 → 下限 215 → **130** 死局；强制装备 = 原貌那一件 → 235 → **125**）。

机制：拉满反差要把下装脱到 `bottom_none`(9) 才能让**内裤一起计分**
（下装不够露时内裤整格不计数，白丢 9 档 = 45 点）；原貌下装本来就露时「脱到最露」的差反而是 0
→ 只能改穿保守下装 → 内裤被盖住 → **一次丢 45 点**。

落地：出厂递进里下装**始终 `bottom_longskirt`**；`FORCED_NEVER_SLOTS := ["bottom","dress"]`；
`_roll_forced_items()` **不抽「与原貌完全相同」的那一件**。

★ 换序注意：`advance_level()` / `resume_run()` 里「抽原貌」必须在「抽强制装备」**之前**
（强制池按本轮原貌过滤）；两者各用独立随机流（`_level_rng` / `_forced_rng`）。

### 标定必须用真实求解器，不能用测试里那份 DP

`WardrobeTest._dp_optimum`（无缺陷约束）会**高估** —— 第 49 轮实测差 10~55 点。
曲线标定与余量必须用 `WardrobeModel.auto_complete_outfit()`。

★ **原貌越露曲线越宽松**（不是越紧）：原貌全高暴露最差余量 **+36**；
全在谷底（中间档）**−64（会卡关）**。

★ 探针要覆盖**测试用的那个种子池**（第 52 轮教训：换一串种子就漏掉了更差的局面）。

### DP 的暴露账是「保守上界」

多件槽位（纹身）的可见性取决于**别的槽位**，DP 却把它单独分了一组
（并进门控组选项数会从 **3.8k 涨到 420 万**）→ 只能按「全都当作露着」计。
这本账 **≥ 真实账**，解绝不超上限（安全），代价是偶尔剩一点真实余量没用上。
引用点 = `WardrobeModel.conservative_exposure()`。

★ **「局部最优」类断言要按同一本账判**（按真实账判，480 轮里 4 轮「假失败」）。

★ **多件槽位的「一件不穿」必须按空件计分**（第 49 轮修的 bug）：只补 id、不进计分循环
→ DP 认为「不穿」恒 0 分，实测少拿 10~20 点反差。

★ 判据：**「解不是局部最优」时先怀疑账的口径，再怀疑求解器**。

### 改轮数要动的全部位置

见 `2026-10-16-第五十二轮-两轮制与减测试耗时.md` 第二节（那张表比这里全）。

## 八、界面细节（`MEMORY.md` 二章「相册废片预算 / 选关面板 / 启动声明」的展开）

### 相册：废片预算与发型（第 88 轮）

用户口径：「第一轮中相册中的照片，无法恢复的不能超过两个，之后新增的无法恢复的不超过一个，
出现上半身时，发型要显示并且与原貌保持一致」。

- **「无法恢复」= 擦到底也认不出**：`start_clarity + max_wipes × PHOTO_WIPE_STEP(0.25) < PHOTO_CLEAR_AT(0.70)`。
  出厂取值下天然废片率 ≈ **1/3**（擦 1 次 78% 落空 / 擦 2 次 22% / 擦 3 次恒成）—— 这条限制真的会咬到。
- **预算按「批」重置**：`_photo_dead_budget` 在 `_append_photos()` 开头赋值 ——
  `photos` 本来是空的（开局那批）→ `PHOTO_DEAD_START(2)`，否则 → `PHOTO_DEAD_PER_LEVEL(1)`。
  ★ 判据用「相册空不空」而不是「第几轮」，所以不用给函数加参数。
- **兜底只改擦亮次数，不重抽照片**（`_photo_wipes_to_clear()`）：重抽会白吃一个点缀名额并多走随机数。
  最坏 `0.10 + 3 × 0.25 = 0.85 ≥ 0.70`，一定有解；另有守卫断言防止以后调小步长让兜底静默失效。
- **发型退出「整局最多一次」名单**：`PHOTO_ONE_OF` 三样 → `["glasses","shoes"]`，上半身照片
  （`PHOTO_UPPER = ["glasses","hair","top"]`）**一律**带发型、取原貌那件。
  ★ 副作用：上半身不再走「一件都没选中 → 补一件」的兜底 → 少消耗一次 `randi()` →
  **同种子的随机流整体偏移**（截图里盘问那几张的题目顺序会换，不是画面坏了）。

### 选关面板与通关按钮（第 86 / 87 轮）

- `_levels_for_panel()` 只返回轮次名（`Array[String]`）。**别把 `derived_profile` 拼上去** ——
  背景没写时兜上来的是全局表默认值（「一个不起眼的路人」），玩家看着就是脏数据。
- 一局通关后 `_pending_action = "home"`（回标题）；`"new_run"` 只留给测试 / 截图脚本显式设。

### 启动声明（第 87 轮）

`splash_layer` 盖在标题**之上** 3 秒，文案 `ui.common.splash_text`。
测试与截图调 `_skip_splash()`，别真等 3 秒（否则两套测试各多 3 秒、截图那段也会被拖）。

## 九、手机备忘录（第 90 轮）的展开

### 数据

```json
"levels": [
  { "name": "第一轮 · …",
    "memo": [ { "body": "第一段（可含 {占位符}）" }, { "body": "第二段" } ],
    "memo_hint": true }
]
```

- **每轮一份完整清单**，不是累积：第 2 轮要保留第 1 轮的内容，作者得自己再写一遍。
- `memo` 允许直接写字符串（`["一段话"]`）—— `level_memo_bodies()` 两种都认，手改 JSON 更省事。
- `memo_hint` 缺省 `false`：只有勾了才在末尾接一行 `该怎么答：<trait_hint>`。

### 占位符（`DossierData.MEMO_PH_KEYS`，10 个）

`{真身}` `{我性别}` `{真身份}` `{马甲}` `{审问者}` `{审问者性别}` `{性情}`
`{同行者}` `{同行者关系}` `{同行者性别}`

★ 替换是 `String.replace("{键}", 值)` 逐个做，**键带右花括号** → `{审问者}` 不会吃掉
`{审问者性别}`，替换顺序无关。★ 编辑器里的对照表（`MEMO_PH_KEYS`，JS 常量）与这一份**必须一致**；
冒烟里有断言守「10 项且都是 `{xx}` 形式」。

### 渲染（`PhoneDesk._build_memo()`）

```
标题 → 顶部提示 → 一张卡片（`_card()`）里一个 Label
Label.text = "\n\n".join(paras)   # 段间空一行
Label.autowrap_mode = WORD_SMART / font_size = 11
```

- `paras` = `level_memo_bodies()`（已 `memo_fill` + 剔空串）；`memo_hint` 为真时 append 那一行。
- `paras.is_empty()` → **直接 return，连卡片都不建**（不留空白框）。
- `screen_box` 在 `ScrollContainer` 里（滚动条宽度压到 0），写多少段都能滚，不会撑破手机。

### 三条容易踩的坑

1. **`RunData.current_level()` 是临时副本**：`levels()` 每次 `duplicate` 重建。
   测试里注入 `memo` 必须改 `OutfitData.level_at(i)` 返回的那份（`LEVELS` 里的同一对象）。
2. **别把 `memo` 当成「累积」写**：它与 `sms` / `notes` 都不一样 —— notes 是回放、sms 是解锁累加，
   memo 是**每轮重写一遍**。
3. **`blind_tail` 的抬头**：第 90 轮起是 `【他的脾性】%s · 忌讳：%s`，
   `Interrogation._answer_blind()` 里 `_ut()` 的默认值与 `story.json` 的 `ui.feedback.blind_tail`
   必须同句 —— 只改一处就会出现「测试里对、游戏里旧」。

### 编辑器

- `memoFields()` 返回两条：`memo`（objlist，字段 `body` area 4 行）+ `memo_hint`（bool）。
- **`levelsFields()` 与背景页 ⑦ 都用 `...memoFields()`** —— 第六十轮 `intro` 只加进一份、
  第七十二轮才发现背景页里改不了的教训，这次直接共用。
- 校验：`memo` 非数组 / 某段既非 `{body}` 也非字符串 → **错误**；
  勾了 `memo_hint` 却一段正文都没有 → **提醒**（「备忘录里只会剩那一行」）。
- 出厂 `scene_1` / `scene_2` × 2 轮 = 4 段，都带占位符、都勾了 `memo_hint`；
  草稿背景（`border_post` / `bg_new_1`）不配 → 那一轮备忘录就是空的，合法。

## 十、结局文案与安全格式化（第 91 轮）

### 取文案的三层

```
DossierData.end_t(key)                 ← 门面，读本局背景
  → ScenarioData.end_t(bg, key)
      → endings_of(bg)
          = ending_template().duplicate()      # ① 模板打底（「玩玩的关系」那套的数据）
            + bg.endings 里**非空白**的键       # ② 自己的逐键覆盖
      → 取不到 → ""                           # ③ 界面不显示
```

- `ENDING_TEMPLATE_BG_ID := "scene_1"`；`ending_template()` 遍历 `_backgrounds` 找它，
  找不到（数据被删/改名）→ 退回 `DEFAULT_ENDINGS`。
- 「未填写」三种都算：**缺键 / 空串 / 只有空白字符**（`strip_edges() != ""`）。
- 模板那套自己**不再合并自己**（`id` 命中就直接返回），省一次遍历、语义也更清楚。

### 为什么模板读数据而不是抄常量

抄一份进 `DEFAULT_ENDINGS` = 两个真相源：用户在编辑器里改「玩玩的关系」，另一份不动，
下一轮又会被问「为什么改了没生效」。读数据则天然只有一个来源，且**改一次全生效**。

`DEFAULT_ENDINGS` 只剩两个用途：`story.json` 完全缺失的演示路径、
「玩玩的关系」自己也找不到时的最后退路。

### 安全格式化（`ScenarioData.fmt_args`）

GDScript 4.3 裸 `%` 的真实行为（探针实测）：

| 表达式 | 控制台 | 返回 |
|---|---|---|
| `"无占位符" % ["甲","乙","丙"]` | `not all arguments converted` | `""` |
| `"只有 %s" % ["甲","乙","丙"]` | 同上 | `""` |
| `"%s 和 %s" % ["甲"]` | `not enough arguments` | `""` |
| `"" % ["甲"]` | `not all arguments converted` | `""` |

★ **返回的是空串，不是原串** —— 作者删掉 `%s` 就等于把那一屏清空，这是第 91 轮的根因。

```gdscript
func fmt_args(t: String, args: Array) -> String:
	if t == "": return ""
	var need := count_placeholders(t)      # 跳过 %% 转义
	if need <= 0: return t.replace("%%", "%")
	var use: Array = []
	for i in need:
		use.append(args[i] if i < args.size() else "")   # 少的补空串
	return str(t % use)
```

★ 只在**结局文案**这条路用（`Interrogation._etf` / `Main._etf`）。
`ui` 的 `_tf/_ut` 仍是裸 `%`，占位符个数由编辑器的 `f.ph` 校验守着。

### 编辑器口径（第 91 轮起）

- 结局文案**不校验占位符**：写不写 `%s` / `%d` 都不报错。
- 只校验数据形状：`endings` 不是对象 → 提醒（这一套整块用模板）；
  某条不是字符串 → 错误。
- 结局页顶部说明：**留空 = 用「玩玩的关系」那一条**；占位符写不写都行；想恢复就清空。
- ★ 副作用：**做不到「这一句不显示」**了 —— 模板里有字就一定有字。

## 十一、第 92 轮删掉的东西（防止被当成「丢了」再找回来）

「外貌情报 / 全局文本」整页 + 整套机制已按用户口径删除。**它们不存在了，不是坏了**：

| 删掉的 | 原来在哪 |
|---|---|
| `story.json` 顶层 `item_desc` / `clue_frame` / `clue_sources` / `photo_notes` | 数据文件 |
| `ScenarioData.ITEM_DESC` / `CLUE_FRAME` / `CLUE_SOURCES` / `PHOTO_NOTES` 四个属性与 `DEFAULT_*` 四个常量 | 代码 |
| `ScenarioData.desc_of()` / `frame_of()` / `sources_of()` / `clue_text()` | 查询函数 |
| `RunData.clues` / `_build_clues()` | 每局拼 18 条情报 |
| `DossierData.appearance_clues()` / `clue_count()` / `get_clue()` / `clue_for_slot()` | 门面 |
| `IntelDesk.revealed` / `_fill_revealed()` / `_reveal()` / `clues_done_count()` / `_on_phone_slot_revealed()` | 已还原槽位 |
| `GameData.revealed_slots` / `clues_total` | 状态 |
| `PhoneDesk.slot_revealed` 信号、照片卡片底部的 `note` Label | 相册 |
| `Wardrobe._slot_revealed()`；「原貌未知 ?」那一档与悬停提示 | 准备室 |
| 编辑器「📝 外貌情报 / 全局文本」页 + `renderStrMap()` + `SLOTS` / `SLOT_CN` / `POOL_IDS` | 编辑器 |

**为什么删**：那三段数据拼出的 18 条文案在界面上从来没显示过（只被测试调），
纯属「算了个没人看的结果」；`revealed_slots` 从第 39 轮起开局即全满，
所以「原貌未知」那档也从没出现过。**游戏行为零变化**（除了随机流前移）。

★ 现在 A 的原貌**一律可见**：`Wardrobe._refresh_preview()` 的 peek 分支直接铺整副原貌，
不再有「只铺已还原部位」的分支。

★ 想恢复「信息不全」这条体验，别照抄旧实现 —— 见 README「下一步」那条：
应该让**相册成为唯一的原貌来源**，而不是重新引入一套没人读的文案。

## 十二、相册张数与「额外上半身」（第 94 轮）

### 门面

```gdscript
const EXTRA_UPPER_BG := "scene_1"

func _photo_extra() -> int:              # 整局固定偏移：这套背景多几张
	return 1 if str(background().get("id", "")) == EXTRA_UPPER_BG else 0

func photos_expected_for_level(li: int) -> int:
	return ScenarioData.PHOTO_COUNT_START \
		+ ScenarioData.PHOTO_COUNT_PER_LEVEL * li + _photo_extra()
```

- `resume_run()` 补照片用 `need = photos_expected_for_level(level_index)`。
- 测试里凡是「期望几张」都调它 —— 各自套公式必漏（这就是它存在的理由）。
- 每套背景**各自一套**：scene_1 开局 4 张、一局 6 张；其余开局 3 张、一局 5 张。

### 生成

`_roll_photos()` → `_append_photos(START + extra, extra)`；
`_append_photos(n, force_upper_tail)` 让**批尾** `force_upper_tail` 张强制上半身；
`_make_photo(force_half)` 在 `force_half != ""` 时跳过 `_rng.randi()`。

### 三个约束（改动时别破坏）

1. **额外张必须并进开局同一批** —— 另调一次 `_append_photos()` 会让
   `photos.is_empty()` 为 false，废片预算从「开局 2」切成「每批 1」。
2. **强制分支不能消耗随机数** —— 否则同一颗种子的前 3 张会变，
   截图、相册单测、`PHOTO_SEEDS` 那批断言全部要重录。
3. **批尾而不是批首** —— 批首会让前几张全部错位；批尾只多一张，前面的逐张不变。

### 验证

- 换装测试新增 4 条：5 个种子「= 3+1 张」/ 多出来的是上半身 / 别的背景仍 3 张 /
  `["下","下","下","上"]`（证明强制只作用于末尾）。
- 废片预算那段的「开局批张数」也改成 `photos_expected_for_level(0)` —— 第 4 张计入预算。
- 截图 `SHOT_SEED = 20261011` 正好抽到 scene_1，相册 3 → 4 张可见。
