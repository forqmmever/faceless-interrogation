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

## 四、判「两张图是不是同一张」要两个独立方法交叉验证

① 文件 **MD5** 一致 ⇒ 绝对同一张；② `ImageChops.difference(a,b).getbbox()` 为 `None` ⇒ 逐像素一致。
★ 别只看尺寸 / bbox —— 图包里大量「bbox 一样但内容不同」。★ 反过来也成立：`chastitycage` 与
`chastitycagefetish` 的 `full.png` 完全相同；`props/npc/` 47 张拼起来是完整 NPC 立绘，不是道具。
★ 看差异用字符画：`ImageChops.difference(a,b).resize((96,27), Image.BOX)` + `ramp = ' .:-=+*#%@'`。
整块 UI 不同 → 大片 `#@`；文字边缘 → 稀疏 `.::`。

## 五、测试与排查细则（`MEMORY.md` 三章的展开）

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
★ **探针要跑真实链路** —— 第 44 轮直接调 `RunData.start_new_run()` 得到
`revealed_slots = 0`（看起来像「原貌不可见」），真相是那个字段由**情报台（UI 层）**写入。
验游戏行为要用 `load("res://scenes/Main.tscn").instantiate()` 起真实场景。

### 其它两条

- **约束的作用域是「整局」时，测试也要走完整流程** —— 照片是「开局 3 张 + 每轮 +2 张」
  逐轮追加的，「整局各自最多一次」只跑开局那 3 张验不出来。
- **测试用完要清「跨局保留」的状态** —— `ProfileData.add_gain()`（接受度）跨局保留，
  用例里反复 `advance_level()` 会把它永久推高 → 后面「开局接受度」当场挂。
  **结尾必须显式还原**（`reset_all()` + 把注入的 `_*_presets` 清回 `{}`）。

### 截图「变了」不一定是回归 —— 三条判据（第 40 轮）

真凶常是跑过 `--import` 后**导入缓存刷新**、字体图集烘焙变了 → 文字边缘抗锯齿略有差异。
**三条同时成立 = 抗锯齿差异，别当回归**：

1. 同一份代码**连跑三次完全一致**（渲染本身是确定性的）
2. 差异是**稀疏点状** —— 降采样成字符画看得出是文字边缘，不是整块 UI
3. 该镜头的 `_plog` 状态输出**逐字相同**

★ 二分排查时**先做「代码全还原」这一步**，一次性排除所有代码嫌疑，比逐个文件试快得多。

## 六、架构细节（`MEMORY.md` 五章的展开）

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
