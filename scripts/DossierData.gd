extends Node

# ============================================================
#  情报数据 —— 按「当前这一局」查询的门面
#
#  设定：审讯官是认识「A」的旧识。他手上攒着一批关于 A 的档案碎片 ——
#  通缉令、目击者口供、旧账单、线人报告…… 你通过内线拿到了副本。
#
#  于是「准备」变成了两件事同时进行：
#    · 身份情报 —— 搞清楚他掌握了哪些只有 A 才知道的事  → 决定盘问时什么不能说
#    · 外貌情报 —— 搞清楚他记忆里 A 长什么样            → 决定该改哪些部位
#
#  多轮制之后，这两类情报都**不再写死**：
#    · 身份情报 / 问题 / 干扰台词  →  随本局抽到的背景变化（ScenarioData）
#    · 外貌情报                    →  随本局随机出的原貌现场拼出来（RunData）
#
#  所以本文件只剩「查询门面」，没有任何内容常量。
#  内容在 ScenarioData，本局状态在 RunData。
# ============================================================

# ---------------- 身份情报 ----------------
func cards() -> Array:
	return RunData.background().get("cards", [])

func card_count() -> int:
	return cards().size()

func get_card(id: String) -> Dictionary:
	for c in cards():
		if str(c["id"]) == id:
			return c
	return {}

func owner_of(card_id: String) -> String:
	return str(get_card(card_id).get("owner", ""))

func b_cards() -> Array:
	var out := []
	for c in cards():
		if str(c["owner"]) == "B":
			out.append(c)
	return out

func a_cards() -> Array:
	var out := []
	for c in cards():
		if str(c["owner"]) == "A":
			out.append(c)
	return out

# ---------------- 盘问 ----------------
func question_pool() -> Array:
	return RunData.background().get("questions", [])

# 当前关的题目（档案题 + 盲区题 + 同一个事实问两次）
func questions_for_level(li: int, count: int) -> Array:
	return RunData.questions_for_level(li, count)

# 盲区题（「完全没给信息的题」）：档案里没有、短信里也没提
func blind_questions() -> Array:
	return ScenarioData.blind_questions_of(RunData.background())

func blind_question_for_level(li: int) -> Dictionary:
	return ScenarioData.blind_question_for_level(RunData.background(), li)

func interference_lines() -> Array:
	return RunData.background().get("interference_lines", [])

# ---------------- 手机：短信 ----------------
# 短信是**逐关解锁**的 —— 第 i 关解锁 level == i 的那一条。
# 所以这里返回的是「当前关已经能看到的那几条」。
func sms_threads() -> Array:
	return RunData.sms_threads()

# 当前关已解锁的条数
func sms_count() -> int:
	return RunData.sms_threads().size()

# 本局一共几条（含还没解锁的）
func sms_total() -> int:
	return RunData.sms_total()

# 还没解锁的条数（第三十一轮起界面上不再显示，留着是个正经查询）
func sms_locked_count() -> int:
	return maxi(0, sms_total() - sms_count())

func get_sms(id: String) -> Dictionary:
	return ScenarioData.get_sms(RunData.background(), id)

# ---------------- 手机：与 C 的短信 ----------------
# 与剧情短信同构、同样逐关解锁，区别只有一条：**它不揭示任何官方口径**。
# C 知道你是 A —— 他发消息不是帮你，是让你记着他一直都在旁边。
func companion_sms_threads() -> Array:
	return RunData.companion_sms_threads()

func companion_sms_count() -> int:
	return RunData.companion_sms_threads().size()

func companion_sms_total() -> int:
	return RunData.companion_sms_total()

func companion_sms_locked_count() -> int:
	return maxi(0, companion_sms_total() - companion_sms_count())

func get_companion_sms(id: String) -> Dictionary:
	return ScenarioData.get_companion_sms(RunData.background(), id)

# ---------------- 手机：与审问官的短信 ----------------
# ★ 第五十五轮：和另外两组完全同构 —— 每套背景一份、逐轮解锁、没有 reveals。
#   （原来是「掏手机越界收到的事件短信」，第 50 轮删了触发，第 55 轮连特殊渲染一起删。）
func interrogator_sms_threads() -> Array:
	return RunData.interrogator_sms_threads()

func interrogator_sms_total() -> int:
	return ScenarioData.interrogator_sms_of(RunData.background()).size()

func get_interrogator_sms(sms_id: String) -> Dictionary:
	return ScenarioData.get_interrogator_sms(RunData.background(), sms_id)

# ---------------- 强制装备（每轮随机 0~2 件高暴露衣物）----------------
func forced_items() -> Array:
	return RunData.forced_item_ids()

func forced_items_info() -> Array:
	return RunData.forced_items_info()

func has_forced_items() -> bool:
	return RunData.has_forced_items()

# ---------------- 本局固定主人公（A 真身 / B 马甲 / C 同行人 / 审讯官）----------------
func cast() -> Dictionary:
	return RunData.cast()

# ---------------- 手机：相册 ----------------
func photos() -> Array:
	return RunData.photos

func photo_count() -> int:
	return RunData.photos.size()

func get_photo(index: int) -> Dictionary:
	return RunData.photo_at(index)

# ---------------- 事实（前后矛盾的判定基础）----------------
func facts() -> Array:
	return RunData.facts()

func fact_for_level(li: int) -> Dictionary:
	return RunData.fact_for_level(li)

func get_fact(fact_id: String) -> Dictionary:
	return ScenarioData.get_fact(RunData.background(), fact_id)

func fact_value_label(fact_id: String, value_id: String) -> String:
	return ScenarioData.fact_value_label(RunData.background(), fact_id, value_id)

func canonical_value(fact_id: String) -> String:
	return ScenarioData.canonical_value(RunData.background(), fact_id)

# 「这条事实说的是哪件事」—— 给玩家看的短名字（矛盾文案里要指名道姓）。
# 优先用事实自己的 name，没有就从第一条问法里截一段。
func fact_prompt_name(fact_id: String) -> String:
	var f := get_fact(fact_id)
	if f.is_empty():
		return fact_id
	var n := str(f.get("name", ""))
	if n != "":
		return n
	var prompts: Array = f.get("prompts", [])
	if prompts.is_empty():
		return fact_id
	var s := str(prompts[0])
	# 去掉「（他忽然换了个问法）」这类括号旁白与问号，留一小句
	var cut := s.find("）")
	if cut >= 0 and cut < 8:
		s = s.substr(cut + 1)
	s = s.strip_edges()
	return s if s.length() <= 18 else s.substr(0, 18) + "…"

# ---------------- 同行者提问 ----------------
func companion_questions() -> Array:
	return RunData.companion_questions()

func companion_question_at(n: int) -> Dictionary:
	return RunData.companion_question_at(n)

# ---------------- 开场介绍（浮动窗口用）----------------
# ★ 第六十轮：每一轮可以写自己的说明（背景的 `levels[i].intro`）。
#   本轮写了就用本轮的；没写才回落到这套背景的总说明 `intro`。
#   这样第二轮的浮窗既会再弹一次，内容也和第一轮不一样。
func intro_text() -> String:
	var own := str(RunData.current_level().get("intro", ""))
	if own.strip_edges() != "":
		return own
	return ScenarioData.intro_of(RunData.background())

func venue_text() -> String:
	return ScenarioData.venue_of(RunData.background())

# ---------------- 结局文案（★ 每套背景一份）----------------
#  用户口径：「游戏结束的说明文字」每个背景一套 —— 所以在 backgrounds[].endings
#  里，由编辑器按背景分别改。这里只是「取当前这一局那一份」的门面。
func endings() -> Dictionary:
	return ScenarioData.endings_of(RunData.background())

# 取一条结局文案。key 见 ScenarioData.DEFAULT_ENDINGS。
# ★ 第八十一轮：**没写就是空串**（界面上不显示），不再有「调用点兜底」这回事 ——
#   用户口径「结局文案中所有的部分不写默认不使用」。
func end_t(key: String) -> String:
	var v: Variant = endings().get(key, null)
	if typeof(v) == TYPE_STRING:
		return str(v)
	return ""

# ---------------- 界面文案 / 数值（转发到 ScenarioData）----------------
func ui(path: String, fallback: String = "") -> String:
	return ScenarioData.ui_t(path, fallback)

func ui_arr(path: String, fallback: Array = []) -> Array:
	return ScenarioData.ui_arr(path, fallback)

# ---------------- 审问者的情报（性情）----------------
# 盘问时「撒谎 / 回避」的代价由它决定；手机备忘录第一条也是靠它给玩家提前预警。
func interrogator_trait() -> Dictionary:
	return RunData.interrogator_trait()

func interrogator_trait_name() -> String:
	return RunData.interrogator_trait_name()

func interrogator_name() -> String:
	return RunData.interrogator()

func interrogator_gender() -> String:
	return RunData.interrogator_gender()

func trait_delta(kind: String) -> float:
	return ScenarioData.trait_delta(interrogator_trait(), kind)

# ---------------- 手机备忘录（第九十轮：改成每轮自己写的一段文字）----------------
#  ★★ 用户口径：「备忘录改成每条都是有正文，第一条可以额外设置绑定盲题的部分
#    也可以不选，也自动填写到正文，最后效果是点进备忘录的每一套会是一段文字」。
#
#  数据在 `bg.levels[i]`：
#    "memo": [ {"body": "第一段"}, {"body": "第二段"} ]
#    "memo_hint": true      ← 勾上 = 第一段正文后面自动接一行「该怎么答：…」
#
#  ★ 原来那两条自动内容（性情 / 这一局的人）**整块下线** —— 想写人物信息就用
#    `memo_fill()` 的占位符自己写，见下面 MEMO_PH_KEYS。
#  ★ 缺省（两轮都没配）→ 空数组 + 不绑盲题 = 备忘录这一页是空的（不报错）。

# 本轮自己写的正文（已做占位符替换，空段已剔掉）
func level_memo_bodies() -> Array:
	var out := []
	var lv: Dictionary = RunData.current_level()
	var raw: Variant = lv.get("memo", null)
	if typeof(raw) != TYPE_ARRAY:
		return out
	for it in (raw as Array):
		var t := ""
		if typeof(it) == TYPE_DICTIONARY:
			t = str((it as Dictionary).get("body", ""))
		elif typeof(it) == TYPE_STRING:
			# 兼容「直接写一串字符串」的写法（编辑器存的是对象，但手改 JSON 更省事）
			t = str(it)
		t = memo_fill(t)
		if t.strip_edges() != "":
			out.append(t)
	return out

# 第一条要不要自动接「该怎么答」
func level_memo_hint() -> bool:
	var lv: Dictionary = RunData.current_level()
	return bool(lv.get("memo_hint", false))

# 占位符对照表 —— 编辑器里的提示与这里必须一致
const MEMO_PH_KEYS := ["{真身}", "{我性别}", "{真身份}", "{马甲}",
	"{审问者}", "{审问者性别}", "{性情}", "{同行者}", "{同行者关系}", "{同行者性别}"]

# 把正文里的 {真身} / {审问者} 这类占位符换成这一局的实际值。
# ★ 顺序无关：每个 key 都带右花括号，{审问者} 不会吃掉 {审问者性别}。
func memo_fill(text: String) -> String:
	if text == "":
		return ""
	var c: Dictionary = cast()
	var out := text
	out = out.replace("{真身}", str(c.get("true_name", "")))
	out = out.replace("{我性别}", str(c.get("player_gender", "")))
	out = out.replace("{真身份}", str(c.get("true_role", "")))
	out = out.replace("{马甲}", str(c.get("cover_role", "")))
	out = out.replace("{审问者性别}", str(c.get("interrogator_gender", "")))
	out = out.replace("{审问者}", str(c.get("interrogator", "")))
	out = out.replace("{性情}", str(c.get("trait", "")))
	out = out.replace("{同行者关系}", str(c.get("companion_relation", "")))
	out = out.replace("{同行者性别}", str(c.get("companion_gender", "")))
	out = out.replace("{同行者}", str(c.get("companion", "")))
	return out

# 「该怎么答」那一行（只有绑定了盲题提示才用）
func interrogator_hint() -> String:
	return ScenarioData.trait_hint(interrogator_trait())

# ★ 第九十轮：备忘录不再自动显示「性格 / 喜好 / 忌讳」这三行，但**访问器留着** ——
#   盘问反馈（Interrogation 说漏嘴那句）还在用 `interrogator_hate()`，
#   测试也拿它当「这一局的性情确实被读到了」的探针。
func interrogator_memo() -> String:
	return ScenarioData.trait_memo(interrogator_trait())

func interrogator_like() -> String:
	return ScenarioData.trait_like(interrogator_trait())

func interrogator_hate() -> String:
	return ScenarioData.trait_hate(interrogator_trait())

func trait_note(kind: String) -> String:
	return ScenarioData.trait_note(interrogator_trait(), kind)

func trait_is_dangerous(kind: String) -> bool:
	return ScenarioData.trait_is_dangerous(interrogator_trait(), kind)
