extends Node

# ============================================================
#  渲染原型并抓取各阶段截图（多轮制 + 手机 + 前后矛盾 + 审问者的情报）
#  运行（不加 --headless，会短暂弹窗）:
#    godot --fixed-fps 60 --path <project> res://tests/Screenshot.tscn
#
#  用固定种子开局，保证每次抓出来的图完全一致。共 36 张。
#
#  抓图顺序上有两个陷阱（都踩过）：
#    1. 👁 原貌对照必须放在换装**之后**抓，否则拍到的是原封不动的原貌。
#    2. 不能直接 await RenderingServer.frame_post_draw —— 该信号在某些
#       情况下不再触发，脚本会永远卡死。改用「信号 + 帧计数兜底」。
# ============================================================

const SHOT_SEED := 20261011

var main: Node
var wardrobe: Control
var intel: IntelDesk
var phone: PhoneDesk
var interro: Control
var gd: Node
var out_dir := "res://screenshots"

var _drawn := false
var _logf: FileAccess

# 进度同时打到 stdout 和 screenshots/_progress.log。
# 为什么要落盘：stdout 重定向到文件时是块缓冲的，脚本一旦卡死，
# 最后几行永远刷不出来，根本看不出卡在哪一步（踩过）。
func _plog(msg: String) -> void:
	print(msg)
	if _logf == null:
		_logf = FileAccess.open("res://screenshots/_progress.log", FileAccess.WRITE)
	if _logf != null:
		_logf.store_line(msg)
		_logf.flush()

# 把卡片墙滚到某个槽位的分区标题那里 —— 拍「内衣内裤的曝光门控」那两张要用：
# bra / panties 的分区在卡片墙中段，不滚过去根本拍不到。
# 用**运行时矩形**算偏移（不写死像素），布局改了也不会失准。
func _scroll_to_slot(wall: ScrollContainer, slot: String) -> void:
	var lab: Label = wardrobe.slot_labels.get(slot)
	if lab == null:
		_plog("     [滚屏] 找不到「%s」的分区标题，保持原位" % slot)
		return
	# 注意：设完 scroll_vertical 之后**布局要等一帧才更新**，
	# 所以这里只能报「算出来的目标值」；真正的落点由调用方在 _wait() 之后复核。
	var dy := lab.get_global_rect().position.y - wall.get_global_rect().position.y
	wall.scroll_vertical = maxi(0, int(wall.scroll_vertical + dy) - 64)
	_plog("     [滚屏] 滚到「%s」分区：偏移 %.0f → scroll_vertical=%d"
		% [slot, dy, wall.scroll_vertical])

# 复核：滚完之后，这个槽位的分区标题落在视口内第几像素（应该是个小值）
func _slot_viewport_y(wall: ScrollContainer, slot: String) -> float:
	var lab: Label = wardrobe.slot_labels.get(slot)
	if lab == null:
		return -1.0
	return lab.get_global_rect().position.y - wall.get_global_rect().position.y

func _ready() -> void:
	# 截图必须可复现：账号级的「跨局保留」会改变接受度，进而改变强制装备池
	# 和能穿什么。先关掉自动存档并清零，免得本机残留的 profile.json 让画面漂移。
	ProfileData.autosave_enabled = false
	ProfileData.reset_all()
	# 局内存档同理 —— 否则开始界面那张图的「继续游戏」亮不亮，会随本机玩过什么而变
	RunSave.autosave_enabled = false
	RunSave.clear()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame

	wardrobe = main.get_node("Wardrobe")
	interro = main.get_node("Interrogation")
	intel = wardrobe.intel
	phone = intel.phone
	gd = get_node("/root/GameData")
	await _run()
	get_tree().quit(0)

func _on_frame_drawn() -> void:
	_drawn = true

# 等「这一帧已经画完」再截图；帧计数兜底，避免永久卡死
func _shot(name: String) -> void:
	_plog("  [shot] begin " + name)
	_drawn = false
	var guard := 0
	while not _drawn and guard < 240:
		await get_tree().process_frame
		guard += 1
	if not _drawn:
		_plog("  !! frame_post_draw 超时，跳过 " + name)
		return
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	_plog("  [shot] saved %s  err=%d" % [path, img.save_png(path)])

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

# ---------------- 测试辅助（与 TestRunner 同款） ----------------
func _reveal_first(n: int) -> void:
	var i := 0
	for clue in DossierData.appearance_clues():
		if i >= n:
			break
		intel._reveal(str(clue["id"]))
		i += 1

func _reveal_all() -> void:
	for clue in DossierData.appearance_clues():
		intel._reveal(str(clue["id"]))

func _assign_all() -> void:
	for card in DossierData.cards():
		intel._assign(card["id"], "kept" if card["owner"] == "B" else "sealed")

# 凑一套能过当前关的伪装（先把缺陷补上，再按效率堆反差）
func _viable_build(m: WardrobeModel) -> void:
	m._equip_defaults()

	# ★ 第二十七轮：成装与上装 / 下装互斥（EXCLUSIVE_GROUPS），而这里的贪心是
	#   「逐槽位试探」、没有 DP 的互斥剪枝。为了避免它凑出「成装 + 长裤」这种
	#   事后被 `_apply_exclusive` 拆掉的搭配，干脆把成装锁成「不穿」——
	#   求解只在「上衣 + 下装」这条路里走（截图要拍的也正是这个常规搭配）。
	m.equipped["dress"] = "dress_none"

	# ★ 本关强制装备先穿上，而且**之后不许再动这几个槽位**。
	#   不穿的话 evaluate() 直接判「当场识破」，截图拍出来的就是失败画面。
	for it in m.forced_items_info():
		m.equip(it)

	var guard := 0
	while not m.exposed_defects().is_empty() and guard < 40:
		guard += 1
		var cur_left := m.exposed_defects().size()
		var best_slot := ""
		var best_id := ""
		var best_left := cur_left
		var best_exp := 9999
		for slot in OutfitData.SLOT_ORDER:
			if m.is_forced_slot(slot):
				continue
			# ★ 第二十七轮：成装与上装 / 下装互斥，这一版贪心没有互斥剪枝 ——
			#   把成装整栏跳过去，只在「上衣 + 下装」里求解（见函数开头的说明）。
			if slot == "dress":
				continue
			# ★ 第三十六轮：纹身变成「多件槽位」（一个槽位可同时装 2 件），
			#   而这一版贪心是「一个槽位一件」的模型 —— 它会把整条 Array 顶成单件。
			#   纹身只加暴露值、不贡献反差，对「凑达标」没有帮助，索性整栏跳过。
			if OutfitData.is_multi_slot(slot):
				continue
			# ★ 第三十九轮：妙妙工具是「只能手动装备」的一栏 ——
			#   它不改暴露值、不遮缺陷、不算反差，推导搭配时整栏跳过。
			if OutfitData.is_manual_slot(slot):
				continue
			var cur := m.item_at(slot)
			for it in OutfitData.get_items_for_slot(slot):
				if str(it["id"]) == str(cur.get("id", "")):
					continue
				if not m.can_equip(it):
					continue
				# ★ 暴露值增量必须问模型 —— 受门控的内衣内裤靠它（换上衣会连带开关门控）
				if m.exposure_after(slot, str(it["id"])) > m.exposure_cap():
					continue
				var old: String = m.equipped[slot]
				m.equipped[slot] = it["id"]
				var left := m.exposed_defects().size()
				m.equipped[slot] = old
				if left < best_left or (left == best_left and int(it["exposure"]) < best_exp):
					best_left = left
					best_exp = int(it["exposure"])
					best_slot = slot
					best_id = str(it["id"])
		if best_slot == "":
			break
		m.equipped[best_slot] = best_id

	var improved := true
	var guard2 := 0
	while improved and guard2 < 120:
		guard2 += 1
		improved = false
		var best_slot := ""
		var best_id := ""
		var best_score := 0.0
		var best_gain := 0
		# ★ 基准值提到循环外 —— 每个候选都重算一遍总和会把这一步拖慢一个量级
		var base_c: int = m.total_contrast()
		var base_e: int = m.total_exposure()
		for slot in OutfitData.SLOT_ORDER:
			if m.is_forced_slot(slot):
				continue
			# ★ 第二十七轮：成装与上装 / 下装互斥，这一版贪心没有互斥剪枝 ——
			#   把成装整栏跳过去，只在「上衣 + 下装」里求解（见函数开头的说明）。
			if slot == "dress":
				continue
			# ★ 第三十六轮：纹身变成「多件槽位」（一个槽位可同时装 2 件），
			#   而这一版贪心是「一个槽位一件」的模型 —— 它会把整条 Array 顶成单件。
			#   纹身只加暴露值、不贡献反差，对「凑达标」没有帮助，索性整栏跳过。
			if OutfitData.is_multi_slot(slot):
				continue
			# ★ 第三十九轮：妙妙工具是「只能手动装备」的一栏 ——
			#   它不改暴露值、不遮缺陷、不算反差，推导搭配时整栏跳过。
			if OutfitData.is_manual_slot(slot):
				continue
			var cur := m.item_at(slot)
			var cur_id := str(cur.get("id", ""))
			for it in OutfitData.get_items_for_slot(slot):
				if str(it["id"]) == cur_id:
					continue
				if not m.can_equip(it):
					continue
				var new_id := str(it["id"])
				var gain: int = m.contrast_delta(slot, new_id)
				if gain <= 0:
					continue
				var d_e: int = m.exposure_delta(slot, new_id)
				if base_e + d_e > m.exposure_cap():
					continue
				var old: String = m.equipped[slot]
				m.equipped[slot] = it["id"]
				var still_ok := m.exposed_defects().is_empty()
				m.equipped[slot] = old
				if not still_ok:
					continue
				var score := float(gain) / float(maxi(1, d_e))
				if score > best_score or (is_equal_approx(score, best_score) and gain > best_gain):
					best_score = score
					best_gain = gain
					best_slot = slot
					best_id = new_id
		if best_slot != "":
			m.equipped[best_slot] = best_id
			improved = true

func _prepare_and_enter() -> void:
	_reveal_all()
	_assign_all()
	var m: WardrobeModel = wardrobe.model
	_viable_build(m)
	wardrobe._refresh()
	wardrobe._on_continue()

func _pass_current_level() -> void:
	interro.set_process(false)
	interro._running = true
	interro._ended = false
	interro.is_qte_active = false
	interro.interference_active = false
	interro.qte_container.hide()
	interro.intf_container.hide()
	gd.suspicion_level = 30.0
	interro._finish_interrogation()
	interro._on_result_pressed()

# ---------------- 盘问侧小工具 ----------------
func _card_questions() -> Array:
	var out := []
	for q in interro.level_questions():
		if _q_kind(q as Dictionary) == "card":
			out.append(q)
	return out

# from 用来跳过第 1 题 —— 第 1 题固定不出 QTE（见 Interrogation.needs_expression_for），
# 要验 QTE 的用例必须从第 2 题起找。
func _find_question_index(owner: String, from: int = 0) -> int:
	var qs: Array = interro.level_questions()
	for i in range(maxi(0, from), qs.size()):
		var q: Dictionary = qs[i]
		if _q_kind(q) != "card":
			continue
		if DossierData.owner_of(str(q.get("card", ""))) == owner:
			return i
	return -1

func _find_fact_question_index(n: int = 0) -> int:
	var qs: Array = interro.level_questions()
	var seen := 0
	for i in qs.size():
		if _q_kind(qs[i] as Dictionary) != "fact":
			continue
		if seen == n:
			return i
		seen += 1
	return -1

# 一关只抽 2 道档案题，未必含 A 类 —— 在当前局 4 关里找，还找不到就换种子。
# 只认「不在第 1 题上」的那道 —— 第 1 题的 QTE 额度固定为 0。
func _find_level_with_card_owner(owner: String) -> int:
	for attempt in 80:
		for li in RunData.level_count():
			var qs: Array = RunData.questions_for_level(li, Interrogation.QUESTIONS_PER_LEVEL)
			for i in range(1, qs.size()):
				var qd: Dictionary = qs[i]
				if _q_kind(qd) != "card":
					continue
				if DossierData.owner_of(str(qd.get("card", ""))) == owner:
					return li
		RunData.start_new_run(31337 + attempt)
	return -1

func _goto_level_with_card_owner(owner: String) -> int:
	var li := _find_level_with_card_owner(owner)
	if li < 0:
		return -1
	if li != RunData.level_index:
		RunData.level_index = li
		gd.level_index = li
		wardrobe.start_level()
		_prepare_and_enter()
	interro.set_process(false)
	# 只返回第 2 题之后的那道 —— 第 1 题的 QTE 额度固定是 0，验 QTE 用它必挂
	return _find_question_index(owner, 1)

func _option_index_of_value(val: String) -> int:
	for i in interro.current_options.size():
		if str((interro.current_options[i] as Dictionary).get("value", "")) == val:
			return i
	return -1

# 同行者提问：找它的下标 / 找某个 value 的选项 / 找那个错的版本
# 从新 schema 反推「这道题原本属于哪一类」。
# ★ 第二十九轮：题目不再有 `kind`（用户口径：「不再给问题分类」）——
#   截图脚本要挑「某类题」来拍，所以在这里按数据形状现推。
func _q_kind(q: Dictionary) -> String:
	if str(q.get("kind", "")) != "":
		return str(q.get("kind", ""))          # 旧格式（内置常量兜底）
	if str(q.get("speaker", "")) == "companion":
		return "companion"
	if str(q.get("fact", "")) != "":
		return "fact"
	if str(q.get("card", "")) != "":
		return "card"
	return "blind"

func _find_companion_question_index() -> int:
	var qs: Array = interro.level_questions()
	for i in qs.size():
		if _q_kind(qs[i] as Dictionary) == "companion":
			return i
	return -1

func _companion_option_index(val: String) -> int:
	for i in interro.current_options.size():
		var o: Dictionary = interro.current_options[i]
		if str(o.get("kind", "")) != "companion":
			continue
		if str(o.get("value", "")) == val:
			return i
	return -1

func _companion_wrong_value(q: Dictionary) -> String:
	var fid := str(q.get("fact", ""))
	var canonical := DossierData.canonical_value(fid)
	for o in q.get("options", []):
		var v := str((o as Dictionary).get("value", ""))
		if v != "" and v != canonical:
			return v
	return ""

# 盲区题（「完全没给信息的题」）：找它的下标
func _find_blind_question_index() -> int:
	var qs: Array = interro.level_questions()
	for i in qs.size():
		if _q_kind(qs[i] as Dictionary) == "blind":
			return i
	return -1

func _option_index_of_value_not(val: String) -> int:
	for i in interro.current_options.size():
		var o: Dictionary = interro.current_options[i]
		if str(o.get("kind", "")) != "fact":
			continue
		if str(o.get("value", "")) != val:
			return i
	return -1

# ---------------- 抓图流程 ----------------
func _run() -> void:
	# ---------- 开始界面 ----------
	_plog("--- 0: 开始界面 —— 开始游戏 / 继续游戏 / 退出游戏 ---")
	_plog("     Main._ready() 已经切到开始界面（wardrobe / interrogation 都藏着）")
	_plog("     此刻没有进行中的一局 → 「继续游戏」是灰的、点不动")
	main._show_title()
	await _wait(16)
	await _shot("00_title_screen")

	# ---------- 选关面板 ----------
	# 第二十一轮：点「开始游戏」不再直接开局，而是先出这一层。
	# 四行关卡都在、名字都在；锁着的那三行只是按钮灰掉、右侧写「尚未开放」。
	_plog("--- 0a: 选关面板 —— 点「开始游戏」后先出这一层 ---")
	_plog("     四关入口都在，目前只开放第一关；其余三关锁定但没删除")
	_plog("     开放表：OutfitData.OPEN_LEVELS = %s" % str(OutfitData.OPEN_LEVELS))
	main._on_title_start()
	await _wait(16)
	await _shot("00a_level_select")
	main._on_level_select_back()

	# 顺手把「有存档时继续游戏可点」的样子也拍下来 —— 先开一局（顺手写下存档），
	# 再切回开始界面。注意只开一局：多开一次会让标题栏的「第 N 局」跟着漂。
	_plog("--- 0b: 开始界面 · 有存档时 —— 「继续游戏」亮起，摘要写明停在哪一关 ---")
	RunSave.autosave_enabled = true
	main._start_new_run(SHOT_SEED)
	main._show_title()
	_plog("     存档摘要：%s" % RunSave.summary())
	await _wait(16)
	await _shot("00b_title_continue")
	RunSave.autosave_enabled = false
	RunSave.clear()

	# 回到准备室 —— 注意 _show_title() 把换装界面藏了，_hide_title() 只管开始界面，
	# 所以这里必须显式 show() 一次，否则 01~12 拍出来的全是空屏（踩过）。
	main._hide_title()
	wardrobe.show()
	wardrobe._refresh()
	await _wait(20)

	# ---------- 开场介绍浮窗 / 玩法说明 ----------
	_plog("--- 0c: 开场介绍浮窗 —— 开局自动弹出，讲清「这是哪儿 / 你是谁 / 谁在旁边」---")
	main._show_intro()
	_plog("     正文取自 story.json 的 intro（可用编辑器改）")
	await _wait(16)
	await _shot("00c_intro_popup")

	_plog("--- 0d: 阶段一 · 玩法说明（手机未开）—— 方框 + 编号 + 短箭头，讲四处 ---")
	main._close_intro()
	main._show_stage_help()
	_plog("     共 %d 处标注（卡片墙 / 数值量表 / 换装预览 / 手机）"
		% main._wardrobe_marks().size())
	await _wait(16)
	await _shot("00d_help_wardrobe")
	main.help_overlay.close()
	await _wait(4)

	_plog("--- 0e: 阶段一 · 玩法说明（手机已开）—— 逐个讲手机里四个界面 ---")
	wardrobe.intel.open_phone()
	await _wait(12)
	main._show_stage_help()
	_plog("     共 %d 处标注（消息 / 相册 / 备忘录 / 备注）" % main._phone_marks().size())
	await _wait(16)
	await _shot("00e_help_phone")
	main.help_overlay.close()
	wardrobe.intel.close_phone()
	await _wait(6)

	_plog("--- 1: 准备室 · 开局（随机背景 + 随机原貌；%d 个槽位各一组衣物卡片）---"
		% OutfitData.active_slots().size())
	_plog("     背景=%s 种子=%d" % [RunData.background_name(), RunData.seed_value])
	var cast0 := RunData.cast()
	_plog("     卡司：A 真身=%s（%s·%s）→ B 马甲=%s　｜　审讯官=%s（%s）　｜　C 同行人=%s（%s·%s）" % [
		cast0["true_role"], cast0["true_name"], cast0["interrogator_gender"], cast0["cover_role"],
		cast0["interrogator"], cast0["trait"],
		cast0["companion"], cast0["companion_gender"], cast0["companion_relation"]])
	var forced0 := RunData.forced_items_info()
	if forced0.is_empty():
		_plog("     本关强制装备：无")
	else:
		var fn := []
		for it in forced0:
			fn.append("%s（暴露 %d）" % [str(it.get("name", "")), int(it.get("exposure", 0))])
		_plog("     本关强制装备（必须穿上，否则当场识破）：%s" % "、".join(fn))
	_plog("     接受度 %d（起始 %d + 跨局保留 %d）" % [
		RunData.acceptance, OutfitData.START_ACCEPTANCE, ProfileData.bonus()])
	_plog("     本关短信 %d 条 / 全局共 %d 条（逐关解锁）" % [
		DossierData.sms_count(), DossierData.sms_total()])
	await _shot("01_briefing_start")

	# ---------- 准备室 · 滚到底 ----------
	#  这张专门用来证明「外袍暂时下架」：卡片墙最后一段分区是「鞋履」，没有「外袍」。
	#  （槽位表本身还留着 robe，只是 active_slots() 把它滤掉了 —— 见 OutfitData.DISABLED_SLOTS）
	_plog("--- 1b: 准备室 · 滚到底 —— 最后一段分区是「鞋履」，没有「外袍」（本轮下架）---")
	var wall: ScrollContainer = wardrobe.item_cols.get_parent()
	wall.scroll_vertical = int(wall.get_v_scroll_bar().max_value)
	await _wait(14)
	await _shot("01b_briefing_bottom")
	wall.scroll_vertical = 0
	await _wait(10)

	# ---------- 内衣内裤的曝光门控（第二十二轮）----------
	#  用户口径：「内裤内衣的反差值和暴露值只有在**能够显示在人物身上**时才会计算，
	#            如透明外衣能计算、直接外穿能计算、镂空开档能计算」
	#  同一身内衣，只换一件外衣：左边（藏起来）两行点阵压暗、总和不算它；
	#  右边（透出来）一切恢复正常。这两张就是把这条规则拍给人看。
	_plog("--- 1c: 门控 · 藏起来 —— 高领衬衫 + 蕾丝内衣：内衣的两行点阵压暗、不计入总和 ---")
	_plog("     悬停会多写一行「外衣盖得严实 —— 这一件不计入暴露值」")
	var gm: WardrobeModel = wardrobe.model
	gm.equipped["top"] = "top_highneck"
	gm.equipped["bottom"] = "bottom_longskirt"
	gm.equipped["bra"] = "bra_lace"
	gm.equipped["panties"] = "panties_lace"
	# ★ 第二十六轮：`dress` 也是 bra / panties 的开门人。本局随机原貌若是一条连衣裙，
	#   它就会独立于 top / bottom 把内衣盖住 —— 1d「透出来」那张就拍不出效果。
	#   这一组要证明的是「换上衣能开关门控」，所以把 dress 显式压成「不穿」。
	gm.equipped["dress"] = "dress_none"
	wardrobe._refresh()
	_scroll_to_slot(wall, "bra")
	await _wait(14)
	_plog("     此刻「上内衣」分区标题在视口内 y=%.0f（应是个小值 → 卡片确实在画面里）"
		% _slot_viewport_y(wall, "bra"))
	_plog("     此刻 暴露值=%d（内衣那 4 + 5 点都没算）｜ 反差值=%d"
		% [gm.total_exposure(), gm.total_contrast()])
	await _shot("01c_gate_hidden")

	_plog("--- 1d: 门控 · 透出来 —— 只把上衣换成半透蕾丝：内衣立刻计入 ---")
	_plog("     三条路都算：①透明外衣 ②镂空开档 ③直接外穿（「（不穿上衣）」）")
	gm.equipped["top"] = "top_lace"
	wardrobe._refresh()
	await _wait(14)
	_plog("     此刻 暴露值=%d（多了上衣 6 + 内衣 4）｜ 反差值=%d"
		% [gm.total_exposure(), gm.total_contrast()])
	await _shot("01d_gate_shown")
	wardrobe.start_level()
	await _wait(10)

	# ---------- 纹身：同时 2 件 + 逐件门控（第三十六轮）----------
	#  用户口径：「可装备的纹身上限设为 2，将纹身暴露度设置为 2」+
	#           「纹身与内衣内裤处理方法相同，不漏出来时，不计算暴露值反差度」。
	#  这一张一次拍出两件事：
	#    ① 纹身槽能**同时装 2 件** —— 两张卡片同时是「已装备」；
	#    ② 门控是**逐件**的 —— 同一屏里一件露着（点阵正常）、一件被盖住（点阵压暗）。
	_plog("--- 1g: 纹身 · 同时 2 件 + 逐件门控 —— 上装「（不穿）」露出胸口刻字、长裙盖住大腿刻字 ---")
	gm.equipped["dress"] = "dress_none"
	gm.equipped["top"] = "top_none"              # 胸口刻字露出来
	gm.equipped["bottom"] = "bottom_longskirt"   # 大腿刻字被盖住
	gm.equipped["tattoo"] = ["tattoo_slave", "tattoo_bitch"]
	wardrobe._refresh()
	_scroll_to_slot(wall, "tattoo")
	await _wait(14)
	_plog("     胸口「slave」%s ｜ 大腿「bitch」%s ｜ 纹身槽合计 %d 点（满 2 件 = 4 点）"
		% ["计入" if gm.item_counts("tattoo", "tattoo_slave") else "不计入",
		   "计入" if gm.item_counts("tattoo", "tattoo_bitch") else "不计入",
		   gm.effective_stat("tattoo", "exposure")])
	_plog("     两张卡片都是「已装备」；再点已装备的那张 = 脱下来，装满 2 件再点第三张 = 顶掉最早那件")
	await _shot("01g_tattoo_multi")
	wardrobe.start_level()
	wall.scroll_vertical = 0
	await _wait(10)

	# ---------- 强制穿着：固定一件 + 几件选一件（第二十三轮，编辑器可写）----------
	#  这张专门给「自由组合」留证据：一条「必须穿黑色蕾丝内裤」+ 一条
	#  「超短皮裙 / 开衩短裙 里任选一件」。规则是编辑器里写死的，
	#  这里只是把它套到模型上，看准备室认不认（橙色卡片 + 锁槽位 + 判定栏逐条写差在哪）。
	_plog("--- 1e: 强制穿着 · 固定一件 + 几件选一件（编辑器里写死的规则表）---")
	_plog("     规则① 必须穿：黑色蕾丝内裤   规则② 任选一件：超短皮裙 / 开衩短裙")
	var fm: WardrobeModel = wardrobe.model
	fm.reset_for_level(30, 0, RunData.true_appearance(),
		["panties_lace"], [
			{"pick": "all", "items": ["panties_lace"]},
			{"pick": "any", "items": ["bottom_mini", "bottom_cut"]},
		])
	wardrobe._refresh()
	_scroll_to_slot(wall, "bottom")
	await _wait(14)
	_plog("     此刻还差：%s" % str(fm.missing_forced_text()))
	await _shot("01e_forced_fixed")

	fm.equipped["panties"] = "panties_lace"
	fm.equipped["bottom"] = "bottom_cut"
	wardrobe._refresh()
	await _wait(12)
	_plog("     穿上「固定那件 + 任选一件里的一件」之后：%s"
		% ("✅ 满足" if fm.forced_satisfied() else "🚨 还不满足"))
	await _shot("01f_forced_satisfied")
	wardrobe.start_level()
	wall.scroll_vertical = 0
	await _wait(10)

	# ---------- 手机浮层 ----------
	#  右栏的情报台删掉了：整块地方留给换装，手机改成点左下角按钮才弹出的浮层。
	#  注意这里**不单独拍一张「浮层」**：浮层是整屏压暗、手机居中，背景与下面的
	#  消息列表那张逐字节相同（踩过的坑），拍两张等于拍一张。
	_plog("--- 2: 手机浮层 —— 点左下角的「📱 手机」弹出，整屏压暗、点遮罩 / 「✕ 收起」关掉 ---")
	_plog("     性情=%s（%s）—— 它写在备忘录第一条，不再单独占一栏" % [
		RunData.interrogator_trait_name(),
		str(RunData.interrogator_trait().get("tag", ""))])
	intel.open_phone()
	phone._switch_app("messages")
	await _wait(14)

	# ---------- 手机 ----------
	_plog("--- 3: 手机 · 备忘录（第一条：审问者是个什么人；往后还有本局的人、这一关）---")
	phone._switch_app("memo")
	await _wait(14)
	await _shot("03_phone_memo")

	_plog("--- 4: 手机 · 消息列表（浮层里；不再有分组标题 —— 审问官 / C / 朋友按顺序排下来）---")
	phone._switch_app("messages")
	await _wait(14)
	await _shot("04_phone_messages")

	_plog("--- 5: 手机 · 一段对话 —— 读完才知道「B 该怎么说」---")
	var t0: Dictionary = DossierData.sms_threads()[0]
	phone._open_thread(str(t0["id"]))
	await _wait(14)
	await _shot("05_phone_thread")

	# 把短信全部读完（学到全部官方口径）
	for t in DossierData.sms_threads():
		phone._open_thread(str(t["id"]))
		await _wait(2)
	phone._back_to_list()

	_plog("--- 5b: 手机 · 与 C 的短信 —— 他不给口径，只提醒你他一直都在旁边 ---")
	phone._switch_app("messages")
	_plog("     消息 App 的三个界面：与审问官 %d 条 ｜ 与同行的人 %d / %d 条 ｜ 与朋友 %d / %d 条" % [
		DossierData.interrogator_sms_list().size(),
		DossierData.companion_sms_count(), DossierData.companion_sms_total(),
		DossierData.sms_count(), DossierData.sms_total()])
	var ct: Dictionary = DossierData.companion_sms_threads()[0]
	_plog("     本关解锁的那条：%s（%s）—— 读完学到 0 条官方口径（设计如此，他不是信息源）" % [
		str(ct.get("contact", "")), str(ct.get("id", ""))])
	phone._open_thread(str(ct["id"]))
	await _wait(14)
	await _shot("05b_phone_companion_sms")
	phone._back_to_list()

	_plog("--- 6: 手机 · 相册 —— 糊、有反光、有噪点 ---")
	phone._switch_app("photos")
	await _wait(16)
	await _shot("06_phone_album")

	_plog("--- 7: 手机 · 擦掉反光后 —— 看清了那处原貌 ---")
	for i in DossierData.photo_count():
		for _k in int(DossierData.get_photo(i).get("max_wipes", 0)):
			phone._wipe(i)
	await _wait(18)
	await _shot("07_phone_album_cleared")

	_plog("--- 8: 手机 · 备注 —— 按轮次回放的问答记录（第一轮空着，第二轮起显示上一轮）---")
	# 第一轮：整页空着，拍一张留证
	gd.answer_log = []
	RunData.level_index = 0
	gd.level_index = 0
	phone._switch_app("notes")
	await _wait(14)
	await _shot("08a_phone_notes_round1")
	# 造「上一轮」的记录 → 第二轮的样子
	gd.answer_log = [
		{"level": 0, "q": "你说你从寒霜港来 —— 具体在城里哪一片？",
			"answer": "A. 寒霜港东侧旧城区，码头往上数第三条巷子"},
		{"level": 0, "q": "你这一车货，都运的什么？",
			"answer": "B. 布匹和铁器，都是不值钱的东西"},
		{"level": 0, "q": "（他盯着你的手）这双手，做过粗活吗？",
			"answer": "A. 幼年在香料工坊帮工，被蒸汽烫的"},
	]
	RunData.level_index = 1
	gd.level_index = 1
	phone.rebuild()
	_plog("     第二轮应有 3 条上一轮的问答记录")
	await _wait(14)
	await _shot("08_phone_notes")
	gd.answer_log = []
	RunData.level_index = 0
	gd.level_index = 0

	_plog("--- 9: 手机 · 盘问里掏了 4 次 → 收到审问者本人的短信（红框那条）---")
	# 这一幕平时由盘问里的「掏出手机」触发（见 Interrogation._phone_pull_event）。
	# 这里直接塞两条进去，把手机那一页拍下来。
	gd.interrogator_sms = [ScenarioData.interrogator_sms_at(0), ScenarioData.interrogator_sms_at(1)]
	phone._switch_app("messages")
	phone._open_thread(PhoneDesk.INTR_THREAD)
	await _wait(16)
	await _shot("09_phone_interrogator_sms")
	phone._back_to_list()

	# ---------- 换装 ----------
	_plog("--- 10: 只拼到 6 处外貌情报时按 👁 —— 只能看见残缺的「A」---")
	intel.close_phone()          # 收起手机，换装界面整块露出来
	#  earrings 已下架（第二十五轮），这里换成 tattoo，凑满 6 处「全是还在架上的」情报。
	var keep_slots := ["hair", "headgear", "glasses", "tattoo", "makeup", "piercing"]
	var partial := []
	for slot in OutfitData.SLOT_ORDER:
		if keep_slots.has(slot):
			partial.append(slot)
	gd.revealed_slots = partial
	wardrobe.peek_btn.button_pressed = true
	await _wait(16)
	await _shot("10_peek_partial")
	wardrobe.peek_btn.button_pressed = false
	await _wait(8)

	_plog("--- 11: 情报整理完 + 换装完成（强制装备已穿齐、反差达标、缺陷全遮、不超上限）---")
	_reveal_all()
	_assign_all()
	var m: WardrobeModel = wardrobe.model
	_viable_build(m)
	wardrobe._refresh()
	_plog("     强制装备 %s ｜ 判定：%s" % [
		"已穿齐" if m.forced_satisfied() else "还差 " + str(m.missing_forced().size()) + " 件",
		str(m.evaluate()["verdict"])])
	await _wait(18)
	await _shot("11_briefing_done")

	_plog("--- 11b: 测试按钮「🧪 一键达标」—— 先打回原貌（什么都不满足），再一键补齐 ---")
	m._equip_defaults()                       # 退回「开局即 A 的原貌」= 反差 0、强制件没穿
	wardrobe._refresh()
	await _wait(10)
	_plog("     按之前：%s" % str(m.evaluate()["reasons"]))
	wardrobe._on_auto_complete()
	await _wait(18)
	_plog("     按之后：%s ｜ 反差 %d / %d ｜ 暴露 %d / %d ｜ 强制件 %s" % [
		str(m.evaluate()["verdict"]),
		m.total_contrast(), m.contrast_requirement(),
		m.total_exposure(), m.exposure_cap(),
		"已穿齐" if m.forced_satisfied() else "还差 " + str(m.missing_forced().size()) + " 件"])
	_plog("     仍与原貌一致的槽位：%s（求解器已尽力，剩下的换了反而更亏）" % str(m.matching_slots()))
	await _shot("11b_auto_complete")

	_plog("--- 12: 暴露值超上限 —— 刻度条指针越过橙色刻线、读数变红（判定栏已撤，看量表）---")
	# 演示「超出暴露值上限」要把接受度临时压到 0 —— 但**必须还原**。
	# 忘了还原的话，下面的 _viable_build() 会在「上限 10 + 缺陷要遮 + 反差要 20」
	# 这组不可能同时满足的约束里空转，整个脚本卡死（这一坑踩过一次）。
	var acc_keep: int = m.acceptance
	m.acceptance = 0
	m._equip_defaults()
	# 先把强制装备穿上（绕过 can_equip()：接受度压到 0 了，正常路径穿不上），
	# 再**只在非强制槽位**上挑最暴露、且**不会把缺陷露出来**的那件，把暴露值顶到上限之上。
	# 这样左侧量表的暴露值指针就明确越过橙色刻线、读数变红 —— 一眼看出超限。
	for slot in OutfitData.SLOT_ORDER:
		var fit: Dictionary = m.forced_for_slot(slot)
		if not fit.is_empty():
			m.equipped[slot] = str(fit["id"])
	for slot in ["top", "bottom", "bra", "panties", "stockings", "neckwear", "gloves"]:
		if m.is_forced_slot(slot):
			continue
		var best: Dictionary = {}
		for it in OutfitData.get_items_for_slot(slot):
			# ★ 第三十六轮：`equipped` 的值可能是 Array（多件槽位），这里用 Variant 接住 ——
			#   上面那串槽位眼下都是单件，但别再埋一颗同类的雷。
			var old: Variant = m.equipped[slot]
			m.equipped[slot] = str(it["id"])
			var keeps_covered: bool = m.exposed_defects().is_empty()
			m.equipped[slot] = old
			if not keeps_covered:
				continue
			if best.is_empty() or int(it["exposure"]) > int(best["exposure"]):
				best = it
		if not best.is_empty():
			m.equipped[slot] = str(best["id"])
	wardrobe._refresh()
	await _wait(16)
	_plog("     暴露值 %d / 上限 %d ｜ 他记下的问题：%s" % [
		m.total_exposure(), m.exposure_cap(), str(m.evaluate()["reasons"])])
	await _shot("12_overcap")
	m.acceptance = acc_keep

	# ---------- 盘问 ----------
	_plog("--- 13: 盘问开局（本关 8 题 = 档案 ×4 + 说法 ×3 + 同行者提问 ×1）---")
	_plog("      [s13] viable_build 开始")
	_viable_build(m)
	_plog("      [s13] viable_build 完成")
	wardrobe._refresh()
	_plog("      [s13] refresh 完成")
	await _wait(10)
	_plog("      [s13] wait10 完成")
	# 这一张要拍「没翻开过备忘录」的样子 —— 上面为了拍手机翻过备忘录，
	# 不重置的话顶栏会直接写出性情与对策，17 那张「读过之后」的对比就不成立了。
	gd.interrogator_intel_read = false
	wardrobe._on_continue()
	_plog("      [s13] on_continue 完成")
	await _wait(26)
	_plog("      [s13] wait26 完成")
	interro.set_process(false)
	_plog("      [s13] set_process(false) 完成")
	await _shot("13_interrogation")

	_plog("--- 13b: 阶段二 · 玩法说明 —— 怀疑度 / 题面 / 反馈 / 选项 / 掏手机 / 两种提示条 ---")
	main._show_stage_help()
	_plog("     共 %d 处标注" % main._interrogation_marks().size())
	await _wait(16)
	await _shot("13b_help_interrogation")
	main.help_overlay.close()
	await _wait(4)

	_plog("--- 14: 盘问中掏出手机 —— 左边答题、右边查档，选完答案自动收回 ---")
	interro._open_phone()
	await _wait(16)
	await _shot("14_phone_in_interrogation")
	interro._close_phone()
	await _wait(6)

	_plog("--- 15: 说法题 —— 你选的版本会被他记下来 ---")
	var f0 := _find_fact_question_index(0)
	interro._load_question(f0)
	await _wait(14)
	await _shot("15_fact_question")
	var fid := str((interro.level_questions()[f0] as Dictionary).get("fact", ""))
	var canonical := DossierData.canonical_value(fid)
	interro._select_option(_option_index_of_value(canonical))
	interro.is_qte_active = false
	interro.qte_container.hide()
	await _wait(6)

	_plog("--- 16: 同行者提问 —— 他刚听见你的说法，就抛了个错的版本来试你 ---")
	var ci := _find_companion_question_index()
	if ci >= 0:
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
		interro.qte_container.hide()
		interro._load_question(ci)
		await _wait(14)
		await _shot("16_companion_question")
		# 选「顺着他说」的那个 → 前后矛盾
		var wrong := _companion_wrong_value(interro.level_questions()[ci])
		var wi := _companion_option_index(wrong)
		interro._select_option(maxi(0, wi))
		interro.is_qte_active = false
		interro.qte_container.hide()
		await _wait(8)
	else:
		_plog("     !! 本关没有同行者提问，跳过")

	# ---------- 盲区题：「完全没给信息的题」 ----------
	#  他问一件档案里没有、短信里也没提的事。题面不指向任何卡，
	#  所以手里真的一点底都没有 —— 选项数量可变（写了「硬答」就 3 个，
	#  留空就只有「撒谎 / 回避」2 个），正解只能从手机备忘录第一条（他的性情）推出来。
	_plog("--- 16b: 盲区题 —— 档案里没有、短信里也没提，只能照备忘录第一条答 ---")
	var bi := _find_blind_question_index()
	if bi >= 0:
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
		interro.qte_container.hide()
		interro._load_question(bi)
		await _wait(14)
		var bq: Dictionary = interro.level_questions()[bi]
		# ★ 第二十九轮：「有没有硬答」现在看选项里有没有 tone = made_up
		var has_made_up := false
		for o in (bq.get("options", []) as Array):
			if str((o as Dictionary).get("tone", "")) == "made_up":
				has_made_up = true
		_plog("     这一题摆了 %d 个选项（题面%s「硬答」）｜ 序号 %d ｜ %s" % [
			interro.current_options.size(),
			"给了" if has_made_up else "没给",
			bi,
			"要压表情" if interro.qte_needed else "不用压表情"])
		await _shot("16b_blind_question")
		# 答完一张：反馈里无论对错都会把备忘录第一条摆出来
		interro._select_option(interro.current_options.size() - 1)
		interro.is_qte_active = false
		interro.qte_needed = false
		interro.qte_container.hide()
		await _wait(8)
		await _shot("16c_blind_feedback")
	else:
		_plog("     !! 本关没有盲区题，跳过")

	# ---------- 审问者的情报怎么用在 B 类题上 ----------
	#  第 13 张的顶栏写着「性情未知」、选项上什么都没有；
	#  这一张把情报读进去，同一个审讯官立刻有了名字和脾性，
	#  而「撒谎」那一项被标成红色 ⚠ —— 这就是「情报读了才有用」。
	_plog("--- 17: B 类题 · 读过审问者情报后，危险的「撒谎」项亮起 ⚠ ---")
	# 强制换成「多疑」：本局抽到的那一种未必是危险性情，
	# 而这张图要说明的正是「同一道题，换成多疑的人来问，撒谎就成了死路」。
	var tid_keep := RunData.interrogator_trait_id
	RunData.interrogator_trait_id = "suspicious"
	gd.interrogator_intel_read = true
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro._load_question(0)          # 第 1 题一定是档案题
	await _wait(14)
	await _shot("17_bluff_warning")
	RunData.interrogator_trait_id = tid_keep
	gd.interrogator_intel_read = false

	_plog("--- 18: 同行者递话 QTE —— 暴露值越高，他来得越勤（窗口 2.6 秒）---")
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro._load_question(0)
	interro.interference_count = 0        # 锁定「单键」那一支
	interro._start_interference()
	await _wait(14)
	await _shot("18_companion_interference")
	interro._end_interference(true)
	await _wait(6)

	_plog("--- 18b: 组合干扰 QTE —— 每 3 次里出 1 次，得依次敲 J → K → L ---")
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro.interference_count = 2        # 下一次是第 3 次 → 组合
	interro._start_interference()
	interro.press_combo_key(KEY_J)        # 敲对第一个键，进度走到 1/3
	await _wait(14)
	await _shot("18b_combo_interference")
	interro._end_interference(true)
	await _wait(6)

	_plog("--- 19: 表情控制 QTE（贴在屏幕最下方；延迟 2.5 秒才出现，答完即结束）---")
	_plog("     规则：第 1 题固定不出；其余**只看暴露值**（≥ %d 每题必出，"
		% Interrogation.EXPOSURE_QTE_FULL
		+ "≤ %d 一次不出）" % Interrogation.EXPOSURE_QTE_MIN)
	# ⚠ 拍这张之前必须先把**挂起的切题**等完：
	#   前面每次答题都会排一个「1.8 秒后进下一题」，那个计时器在拍图这一刻到期，
	#   就会顺手把 QTE 面板收掉 —— 拍出来是「面板已收起」的空图（踩过）。
	await _wait(160)
	interro.set_process(false)
	var a_idx: int = _find_question_index("A", 1)
	if a_idx < 0:
		a_idx = _goto_level_with_card_owner("A")
		interro.set_process(false)
	if a_idx >= 0:
		interro._ended = false
		interro._running = true
		interro.interference_active = false
		interro.interference_timer = 999.0
		interro._load_question(a_idx)
		# 不等延迟，直接弹出来 —— 状态完全由这里定，不受引擎帧影响
		interro._start_expression_qte()
		interro.qte_progress = 86.0          # 已经顶过通过线（那道竖线在 60）
		interro.qte_bar.value = interro.qte_progress
		_plog("     题目序号 %d ｜ 面板可见 = %s ｜ 进度 = %.0f（通过线 %.0f）" % [
			a_idx, str(interro.qte_container.visible),
			interro.qte_progress, Interrogation.EXPR_QTE_PASS])
		await _shot("19_expression_qte")
		_plog("     面板实际位置 = %s（屏幕高 720 ｜ 底边距屏底 16）"
			% str(interro.qte_strip.get_global_rect()))
		# 答题 → 本题的 QTE 立刻收掉（单阶段，不再续下一轮）
		interro._select_option(1)      # A 类题撒谎 → 触发表情 QTE（正面回应 = 说漏嘴）
		_plog("     答完题 → QTE 已结束 = %s" % str(not interro.is_qte_active))
	else:
		_plog("     !! 本局没有 A 类题，跳过")

	_plog("--- 20: 说漏嘴 —— 把 A 的情报写进了 B 的档案 ---")
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	if a_idx >= 0:
		var a_card := str(interro.level_questions()[a_idx]["card"])
		gd.dossier_kept.append(a_card)
		interro._load_question(a_idx)
		await _wait(10)
		interro._select_option(0)
		await _wait(16)
		await _shot("20_leak_exposed")
		gd.dossier_kept.erase(a_card)

	_plog("--- 21: 一眼认出 —— 阶段一不判定，门一开他才开口：「怎么是你，XX。」---")
	main._start_new_run(SHOT_SEED)
	await _wait(14)
	# 故意穿回 A 的原貌（只把强制装备穿上），反差值必然不足 → 判定为「没通过」
	var m2: WardrobeModel = wardrobe.model
	m2.reset_for_level(RunData.acceptance, RunData.level_index, RunData.true_appearance(),
		RunData.forced_item_ids())
	# 强制装备先穿上 —— 否则判定理由里会多出一条「强制装备没穿」，抢了「反差值不足」的戏
	for slot in OutfitData.SLOT_ORDER:
		var fit2: Dictionary = m2.forced_for_slot(slot)
		if not fit2.is_empty():
			m2.equipped[slot] = str(fit2["id"])
	for slot in OutfitData.SLOT_ORDER:
		if m2.is_forced_slot(slot):
			continue
		m2.equipped[slot] = RunData.true_item(slot)
	wardrobe._refresh()
	_plog("     准备室里的判定：%s（A 真身名 = %s）" % [
		str(m2.evaluate()["verdict"]), RunData.true_name()])
	await _wait(14)
	wardrobe._on_continue()
	await _wait(26)
	interro.set_process(false)
	_plog("     _end_reason = %s ｜ 对白开头：%s" % [
		interro._end_reason, interro.dialogue_label.text.substr(0, 40)])
	await _shot("21_recognized_on_sight")

	_plog("--- 22: 前后矛盾 —— 同一件事，两套说法 ---")
	main._start_new_run(SHOT_SEED)
	await _wait(14)
	_prepare_and_enter()
	await _wait(12)
	interro.set_process(false)
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	var rf := _find_fact_question_index(1)
	if rf < 0:
		rf = _find_fact_question_index(0)
	var rfid := str((interro.level_questions()[rf] as Dictionary).get("fact", ""))
	gd.stated_facts[rfid] = DossierData.canonical_value(rfid)
	gd.contradictions = Interrogation.CONTRADICTION_LIMIT - 1
	interro._load_question(rf)
	await _wait(12)
	interro._select_option(_option_index_of_value_not(DossierData.canonical_value(rfid)))
	await _wait(16)
	await _shot("22_contradiction")
	gd.contradictions = 0
	gd.stated_facts.clear()

	_plog("--- 23: 结果覆盖层 · 本关通过 → 进入下一关 ---")
	main._start_new_run(SHOT_SEED)
	await _wait(14)
	_prepare_and_enter()
	await _wait(14)
	interro.set_process(false)
	_pass_current_level()
	await _wait(18)
	await _shot("23_level_cleared")
	_plog("     现在：第 %d 关 ｜ 接受度 %d" % [RunData.level_number(), RunData.acceptance])

	_plog("--- 24: 结果覆盖层 · 整局通关 ---")
	main._on_overlay_pressed()
	await _wait(12)
	for lvl in range(1, OutfitData.MAX_LEVELS):
		_prepare_and_enter()
		await _wait(10)
		interro.set_process(false)
		_pass_current_level()
		await _wait(10)
		if lvl < OutfitData.MAX_LEVELS - 1:
			main._on_overlay_pressed()
			await _wait(10)
	await _wait(18)
	await _shot("24_run_cleared")

	_plog("--- 25: 结果覆盖层 · 失败 → 回到本轮开始（同一局 · 同一关）---")
	_plog("     第二十一轮：失败只作废这一轮 —— 背景 / 原貌 / 情报 / 接受度全都不变")
	main._on_overlay_pressed()
	await _wait(12)
	_prepare_and_enter()
	await _wait(12)
	interro.set_process(false)
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	var a2 := _find_question_index("A")
	if a2 < 0:
		a2 = _goto_level_with_card_owner("A")
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
	if a2 >= 0:
		gd.dossier_kept.append(str(interro.level_questions()[a2]["card"]))
		interro._load_question(a2)
		interro._select_option(0)
		await _wait(12)
		interro._on_result_pressed()
		await _wait(18)
	await _shot("25_run_failed")

	_plog("--- done ---")
