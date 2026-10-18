extends Node

# ============================================================
#  端到端冒烟测试：多轮制完整流程
#
#  运行：
#    godot --headless --fixed-fps 60 --path <proj> \
#          res://tests/TestRunner.tscn --quit-after 1200
#
#  为了可复现，测试里把 Interrogation 的 _process 关掉，
#  所有计时器（表情 QTE / 同行者干扰）都手工步进。
#
#  覆盖的完整链路：
#    开局（随机背景 + 随机原貌）
#      → 情报台（外貌还原 / 身份归类）
#      → 换装（凑够反差、遮住缺陷、不超上限）
#      → 盘问（按关抽题 / 同行者干扰 / 表情 QTE）
#      → 通过 → 下一轮（背景与原貌不变、接受度提升）
#      → 第 4 关通过 → 整局通关
#      → 说漏嘴 → 本轮失败 → 回到本轮开始（换的只是这一轮的打扮）
# ============================================================

var main: Node
var wardrobe: Control
var intel: IntelDesk
var interro: Control
var gd: Node

var checks := 0
var failures := 0

# 只用它算版式做几何断言 —— 不挂进场景树，免得抢输入
var help_check_overlay: HelpOverlay

func _check(label: String, cond: bool) -> void:
	checks += 1
	if cond:
		print("  [PASS] ", label)
	else:
		failures += 1
		print("  [FAIL] ", label)

func _ready() -> void:
	print("=========================================")
	print(" Faceless - Multi-Run E2E Test")
	print("=========================================")

	# 存档层：关掉自动存盘 + 清零（同 WardrobeTest，见那边的注释）
	ProfileData.autosave_enabled = false
	ProfileData.reset_all()
	# 局内存档同理 —— 否则「继续游戏」的可用性会随这台机器上玩过什么而变
	RunSave.autosave_enabled = false
	RunSave.clear()

	help_check_overlay = HelpOverlay.new()

	var packed: PackedScene = load("res://scenes/Main.tscn")
	_check("Main.tscn loads", packed != null)
	if packed == null:
		_finish()
		return

	main = packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	gd = get_node_or_null("/root/GameData")
	_check("GameData autoload registered", gd != null)
	_check("RunData autoload registered", get_node_or_null("/root/RunData") != null)
	_check("ScenarioData autoload registered", get_node_or_null("/root/ScenarioData") != null)

	wardrobe = main.get_node_or_null("Wardrobe")
	interro = main.get_node_or_null("Interrogation")
	_check("Wardrobe node exists", wardrobe != null)
	_check("Interrogation node exists", interro != null)
	_check("主场景已无独立档案阶段节点", main.get_node_or_null("Dossier") == null)

	if wardrobe == null or interro == null or gd == null:
		_finish()
		return

	intel = wardrobe.intel
	_check("换装界面内嵌情报台", intel != null)
	if intel == null:
		_finish()
		return

	_t_prev = Time.get_ticks_msec()
	_test_boot()
	_test_clue_reveal()
	_test_identity_assign()
	_test_outfit()
	_test_enter_interrogation()
	_test_recognition_on_sight()
	_test_interference()
	_test_expression_qte()
	_test_qte_budget()
	_tick("① 开局~QTE预算（9 段）")
	await _test_qte_live_loop()
	_tick("QTE 实时循环（协程）")
	_test_shake()
	_tick("晃动")
	_test_fact_consistency()
	_tick("说法一致性")
	_test_cross_level_consistency()
	_tick("跨轮一致性")
	_test_companion_question()
	_tick("同行者提问")
	_test_phone()
	_tick("手机")
	_test_phone_in_interrogation()
	_tick("盘问里的手机")
	_test_interrogator_intel()
	_tick("审讯官情报")
	_test_blind_question()
	_tick("盲区题")
	_test_manual_question_options()
	_tick("自行编辑的题")
	await _test_option_button_layout()
	_tick("选项按钮布局（协程）")
	_test_option_echo()
	_tick("选项回应")
	_test_new_mechanics()
	_tick("新机制")
	_test_title_and_save()
	_tick("标题与存档")
	await _test_intro_and_help()
	_tick("开场与帮助（协程）")
	await _test_dol_style()
	_tick("纸娃娃风格（协程）")
	_test_suspicion_decay()
	_tick("怀疑度衰减")
	_test_story_config()
	_tick("剧情配置")
	_test_multi_level_flow()
	_tick("多轮流程")
	_test_leak_and_fail_restart()
	_tick("说漏嘴与失败重来")
	_test_retry_level_semantics()
	_tick("重试语义")
	_test_underwear_gate_ui()
	_tick("内衣门控界面")
	_test_editable_flow_data()
	_tick("可编辑流程数据")

	_finish()

# ------------------------------------------------------------
# 开局：一局已经开始，背景与原貌都是随机抽的
# ------------------------------------------------------------
func _test_boot() -> void:
	print("\n-- 开局：先出开始界面（开始 / 继续 / 退出）--")
	_check("开局先出开始界面", main.title_screen != null and main.title_screen.visible == true)
	_check("开始界面挡在换装前面", wardrobe.visible == false)
	_check("盘问也不该露头", interro.visible == false)
	_check("四个按钮都建出来了",
		main.title_start_btn != null and main.title_continue_btn != null
		and main.title_quit_btn != null and main.title_credits_btn != null)
	_check("「开始游戏」可点", main.title_start_btn.disabled == false)
	_check("没有存档时「继续游戏」点不动", main.title_continue_btn.disabled == true)
	_check("开始界面写着本局/账号进度", main.title_info.text.length() > 6)

	# ★ 第六十四轮：制作人名单
	_check("制作人名单层一开始是收起的",
		main.credits_layer != null and main.credits_layer.visible == false)
	main._show_credits()
	_check("点「制作人名单」→ 名单层出现", main.credits_layer.visible == true)
	_check("名单正文有美术素材 / 策划 / 文案 / 代码 / 测试",
		main.credits_body_label.text.contains("dol au美化包")
		and main.credits_body_label.text.contains("hey_unmu")
		and main.credits_body_label.text.contains("deepseek-V4-flash"))
	_check("名单正文有灵感来源",
		main.credits_body_label.text.contains("灵感来源")
		and main.credits_body_label.text.contains("Degrees of Lewdity"))
	main._hide_credits()
	_check("点「返回」→ 名单层收起", main.credits_layer.visible == false)

	# 点「开始游戏」→ 先出选关面板（第二十一轮）
	print("\n-- 开局：点「开始游戏」先出选关面板（两轮入口）--")
	main._on_title_start()
	_check("选关面板出现", main._is_level_select_open())
	# ★ 第五十二轮：一局 4 轮 → 2 轮，面板行数跟着变成 2
	_check("选关面板一共 2 行", main.level_select_rows.size() == OutfitData.MAX_LEVELS
		and main.level_select_rows.size() == 2)
	_check("第 1 轮那行点得动", main.level_select_rows[0]["btn"].disabled == false)
	# ★ 第五十九轮（用户口径）：「不再对第一关以外上锁」
	_check("第 2 轮那行也点得动（不再上锁）",
		main.level_select_rows[1]["btn"].disabled == false)
	_check("两行都写着「可以进入」",
		main.level_select_rows[0]["note"].text.contains("可以进入")
		and main.level_select_rows[1]["note"].text.contains("可以进入"))
	_check("两轮的名字都还在",
		main.level_select_rows[1]["btn"].text.contains(
			str(OutfitData.LEVELS[1].get("name", ""))))
	_check("选关时还没开局（准备室仍藏着）", wardrobe.visible == false)

	# ★★ 第五十三轮：选关面板新增「本局背景」一组按钮 ——
	#   默认「随机」，其余按 `ScenarioData.enabled_backgrounds()` **动态生成**
	#   （编辑器里新增一套背景并勾上「启用」，这里就自动多一颗，不用改代码）。
	print("\n-- 选关面板 · 本局背景（第五十三轮）--")
	_check("背景按钮组建出来了（冒烟/截图都靠它）", main.level_select_bg_btns.size() >= 2)
	_check("按钮数 = 已启用背景数 + 1（那一颗是「随机」）",
		main.level_select_bg_btns.size() == ScenarioData.enabled_backgrounds().size() + 1)
	_check("第 1 颗是「随机」（默认选中的就是它）",
		str(main.level_select_bg_btns[0]["id"]) == ""
		and main._pending_bg_id == "")
	_check("其余每颗对应一套已启用背景",
		main.level_select_bg_btns[1]["id"] == str((ScenarioData.enabled_backgrounds()[0] as Dictionary).get("id", "")))
	_check("草稿背景不出现在按钮组里（列了也点不出东西）",
		main.level_select_bg_btns.size() == ScenarioData.bg_count() + 1)

	# 挑一套背景 → 面板要记下来；再点「随机」要能记回空串
	#   ★ 显式标类型：`enabled_backgrounds()` 是 Array，元素是 Variant，
	#     用 `:=` 让编译器推断会因为「三元的两支类型不定」直接报 Parse Error。
	var enabled: Array = ScenarioData.enabled_backgrounds()
	var picked: Dictionary = enabled[1] if enabled.size() > 1 else enabled[0]
	var pick_id := str(picked.get("id", ""))
	main._on_bg_choice(pick_id)
	_check("点了某套背景 → 面板记下了它", main._pending_bg_id == pick_id)
	main._on_bg_choice("")
	_check("再点「随机」→ 记回空串（回到随机）", main._pending_bg_id == "")

	# 指定背景开局 —— 顺带验「随机流不被指定背景打乱」这条不变式
	var seed_probe := 20261111
	RunData.start_new_run(seed_probe)
	var bg_random := RunData.background_id
	var app_random := RunData.true_appearance().duplicate()
	RunData.start_new_run(seed_probe, 0, pick_id)
	_check("指定背景开局 → 背景就是指定的那套（实际 %s / 期望 %s）" % [
			RunData.background_id, pick_id], RunData.background_id == pick_id)
	var app_picked := RunData.true_appearance().duplicate()
	# ★ 关键不变式：`start_new_run` 里**无论指不指定都先消耗一次 randi()** ——
	#   所以原貌 / 情报 / 性情这些后续随机**完全不受影响**，同一个种子两次一致。
	#   （这条要是不成立，玩家「指定背景」就会连带换掉人物，可复现性也一起没了。）
	_check("★ 指定背景不改变后续随机流（原貌与随机开局逐项相同）",
		_dict_eq(app_random, app_picked))
	# 指定一个不存在的 id → 退回随机，不能崩
	RunData.start_new_run(seed_probe, 0, "__no_such_bg__")
	_check("指定不存在的背景 id → 退回随机（不崩）",
		RunData.background_id == bg_random)
	main._on_bg_choice("")
	# ★ 第五十九轮：第 2 轮不再锁着 —— 点它就按第 2 轮开局
	main._on_level_selected(1)
	_check("点第 2 轮 → 选关面板收起", not main._is_level_select_open())
	_check("点第 2 轮 → 准备室可见", wardrobe.visible == true)
	_check("点第 2 轮 → 开局轮次 = 第 2 轮", RunData.level_index == 1)
	_check("点第 2 轮 → 已通过轮数 = 1", RunData.cleared_levels == 1)
	_check("点第 2 轮 → 标题栏写着「第 2 / 2 轮」",
		wardrobe.run_label.text.contains("第 2 / 2 轮"))
	# 回到选关面板 —— 后面的用例都从第 1 轮开始
	main._on_title_start()
	_check("从第 2 轮回到选关面板", main._is_level_select_open())

	# 「返回」把玩家送回开始界面，再点一次「开始游戏」还能回来
	main._on_level_select_back()
	_check("选关面板的「返回」回到开始界面",
		not main._is_level_select_open() and main.title_screen.visible == true)
	main._on_title_start()
	_check("再点「开始游戏」还能回到选关面板", main._is_level_select_open())
	main._on_level_selected(0)

	print("\n-- 开局：一局已经开始（随机背景 + 随机原貌）--")
	_check("选关面板收起", not main._is_level_select_open())
	_check("开始界面收起", main.title_screen.visible == false)
	_check("准备室开局可见", wardrobe.visible == true)
	_check("盘问阶段开局隐藏", interro.visible == false)
	_check("结果覆盖层开局隐藏", main.overlay.visible == false)
	_check("WardrobeModel 已建立", wardrobe.model != null)
	_check("局号 ≥ 1", RunData.run_index >= 1)
	_check("已抽定背景", RunData.background_id != "")
	_check("背景名已显示在标题栏", wardrobe.run_label.text.contains(RunData.background_name()))
	_check("标题栏显示了轮次进度", wardrobe.run_label.text.contains("第 1 / 2 轮"))

	var m: WardrobeModel = wardrobe.model
	_check("%d 个槽位全部有装备" % OutfitData.active_slots().size(), m.equipped.size() == OutfitData.active_slots().size())
	_check("模型拿到了本局原貌", _dict_eq(m.true_appearance, RunData.true_appearance()))
	_check("开局即 A 的原貌（未改动任何部位）",
		m.matching_slots().size() == OutfitData.auto_slots().size())
	_check("开局反差值为 0", m.total_contrast() == 0)
	_check("第 1 轮接受度 = START_ACCEPTANCE", m.acceptance == OutfitData.START_ACCEPTANCE)

	print("\n-- 开局：原貌本身不超暴露值上限 --")
	_check("原貌暴露值 ≤ 第 1 关上限", m.total_exposure() <= m.exposure_cap())

	print("\n-- 开局：情报台已经替你填好了（两栏已删）--")
	# 「身份情报」「外貌情报」两栏删掉之后：
	#   · 归类按卡片的 owner 自动填好（B 卡 = 可照答，A 卡 = 禁区）
	#   · 原貌 18 处开局即全部可见
	# 信息一条没少，少的是那几十次点击。
	_check("身份情报 12/12 已归类（按 owner 自动）", intel.identity_done_count() == 12)
	_check("外貌情报 %d/%d 已可见（开局即全可见）" % [intel.clues_done_count(), OutfitData.auto_slots().size()],
		intel.clues_done_count() == OutfitData.auto_slots().size())
	_check("未归类数 = 0", intel.unassigned_count() == 0)
	_check("归类零失误", intel.identity_mistakes() == 0)
	_check("B 卡全部归入伪装档案", gd.dossier_kept.size() == DossierData.b_cards().size())
	_check("A 卡全部标为禁区", gd.dossier_sealed.size() == DossierData.a_cards().size())
	_check("手机收成了浮层 —— 开局不占地方", intel.phone_layer != null and not intel.is_phone_open())
	_check("标题栏挂着「手机」按钮", intel.phone_btn != null and intel.phone_btn.text.contains("手机"))

	print("\n-- 开局：阶段一不再替你下结论，门不锁 --")
	_check("开局就能进盘问（不再被归类门禁拦住）", wardrobe.continue_btn.disabled == false)
	_check("★ 判定栏已撤掉（脚本里不再有 verdict_label）", not ("verdict_label" in wardrobe))

	print("\n-- 开局：原貌全可见，槽位不再有问号 --")
	_check("发型标签不带问号", not wardrobe.slot_labels["hair"].text.ends_with("?"))
	_check("上衣标签不带问号", not wardrobe.slot_labels["top"].text.ends_with("?"))
	_check("GameData.revealed_slots 覆盖全部槽位",
		gd.revealed_slots.size() == OutfitData.auto_slots().size())

	print("\n-- 开局：原封不动的打扮 => 不合格（判定在阶段二结算）--")
	var ev0: Dictionary = m.evaluate()
	_check("判定为不合格", ev0["verdict"] == "instantly_exposed")
	_check("不合格理由包含反差值", _reasons_contain(ev0, "反差值"))
	_check("结果已同步给 GameData（供阶段二使用）", gd.outfit_passed == false)
	_check("不合格理由也同步过去了", gd.outfit_fail_reasons.size() > 0)

	print("\n-- 换一局：背景与原貌会重新抽 --")
	var bg_a := RunData.background_id
	var ta_a := RunData.true_appearance().duplicate()
	RunData.start_new_run(424242)
	_check("新的一局换了种子", RunData.seed_value == 424242)
	_check("同一种子可复现",
		_run_seed_matches(424242))
	var diff := 0
	if RunData.background_id != bg_a:
		diff += 1
	if not _dict_eq(RunData.true_appearance(), ta_a):
		diff += 1
	_check("新一局的背景或原貌至少有一项变了", diff >= 1)
	main._start_new_run()

# ------------------------------------------------------------
# 外貌情报栏已删：原貌开局即全部可见
# ------------------------------------------------------------
func _test_clue_reveal() -> void:
	print("\n-- 外貌情报栏已删：原貌开局即全部可见 --")
	_check("外貌情报共 %d 条" % OutfitData.auto_slots().size(),
		DossierData.clue_count() == OutfitData.auto_slots().size())

	var clue_hair := DossierData.clue_for_slot("hair")
	_check("每个槽位都有对应情报", not clue_hair.is_empty())
	_check("情报标明了来源", str(clue_hair.get("source", "")).length() > 1)
	_check("情报文案指向本局原貌的发型",
		str(clue_hair.get("text", "")) == ScenarioData.clue_text("hair", RunData.true_item("hair")))

	_check("开局 %d 处原貌全部可见" % OutfitData.auto_slots().size(),
		intel.clues_done_count() == OutfitData.auto_slots().size())
	_check("GameData.revealed_slots 覆盖全部槽位",
		gd.revealed_slots.size() == OutfitData.auto_slots().size())

	# peek = 直接看「审讯官记忆里的你」，整张脸都在，没有空白处
	wardrobe._on_peek_toggled(true)
	_check("peek 显示「A」的原貌发型", wardrobe.layer_rects["hair"].texture != null)
	_check("peek 显示「A」的原貌上衣", wardrobe.layer_rects["top"].texture != null)
	wardrobe._on_peek_toggled(false)
	_check("没有任何槽位带问号", _no_slot_label_has_question())

	# _reveal 现在只是兼容钩子：原貌本来就全可见，重复调用不该改变任何东西
	intel._reveal(str(clue_hair["id"]))
	_check("重复调用 _reveal 不改变计数", intel.clues_done_count() == OutfitData.auto_slots().size())

# ------------------------------------------------------------
# 身份情报栏已删：归类改成开局按 owner 自动填
# ------------------------------------------------------------
func _test_identity_assign() -> void:
	print("\n-- 身份情报栏已删：归类改成开局自动填 --")
	_check("身份情报共 12 条", DossierData.card_count() == 12)
	_check("其中 5 条属于 B", DossierData.b_cards().size() == 5)
	_check("其中 7 条属于 A", DossierData.a_cards().size() == 7)
	_check("开局即全部归类", intel.identity_done_count() == 12)
	_check("开局零失误", intel.identity_mistakes() == 0)
	_check("dossier_kept 记录 5 条（B 卡）", gd.dossier_kept.size() == 5)
	_check("dossier_sealed 记录 7 条（A 卡）", gd.dossier_sealed.size() == 7)
	_check("dossier_total 为 12", gd.dossier_total == 12)

	# _assign 现在只是测试钩子 —— 留着是为了构造「归档出错」这类状态
	var a_card := str(DossierData.a_cards()[0]["id"])
	intel._assign(a_card, "kept")
	_check("钩子：把 A 卡改判成「可照答」→ 记为失误", intel.identity_mistakes() == 1)
	_check("钩子：失误计数同步到 GameData", gd.dossier_mistakes == 1)

	intel._assign(a_card, "sealed")
	_check("钩子：改回后失误归零", intel.identity_mistakes() == 0)
	_check("钩子：改回后不再出现在 dossier_kept", not gd.dossier_kept.has(a_card))
	_check("钩子：重新归档后 A 卡回到禁区名单", gd.dossier_sealed.has(a_card))

# ------------------------------------------------------------
# 换装
# ------------------------------------------------------------
func _test_outfit() -> void:
	print("\n-- 换装：照着「与原貌相反」的方向改 --")
	var m: WardrobeModel = wardrobe.model
	_build_viable(m)
	wardrobe._refresh()

	var ev: Dictionary = m.evaluate()
	_check("伪装成立（反差达标 + 缺陷全遮 + 未超上限）", ev["verdict"] == "pass")
	_check("反差值达标", m.is_contrast_sufficient() == true)
	_check("暴露值未超上限", m.is_over_cap() == false)
	_check("缺陷已全部遮挡", m.exposed_defects().is_empty())
	_check("确实改动了若干部位", m.changed_slots().size() >= 4)

	print("\n-- 还没解锁的装扮显示问号 --")
	# 挑一个「接受度不够、现在穿不上」的物品按钮，它应该只显示问号、不显示图标
	var locked_slot := ""
	var locked_idx := -1
	var high_req := 0
	for slot in OutfitData.active_slots():
		var items := OutfitData.get_items_for_slot(slot)
		var cur_id := str(m.equipped.get(slot, ""))
		for i in items.size():
			var it: Dictionary = items[i]
			if str(it["id"]) == cur_id:
				continue
			if m.can_equip(it):
				continue
			if int(it.get("acceptance_req", 0)) > high_req:
				high_req = int(it.get("acceptance_req", 0))
				locked_slot = slot
				locked_idx = i
	_check("（前置）本轮确实存在还没解锁的装扮", locked_slot != "" and locked_idx >= 0)
	if locked_slot != "" and locked_idx >= 0:
		wardrobe._refresh()
		var lb: Button = wardrobe.slot_buttons[locked_slot][locked_idx]
		_check("★ 未解锁的装扮显示问号", lb.text == "?")
		_check("★ 未解锁的装扮不显示图标", lb.icon == null)
		_check("未解锁的装扮仍不可点", lb.disabled == true)
		_check("提示里不透露名字，只说还差多少接受度",
			lb.tooltip_text.contains("未解锁") and lb.tooltip_text.contains("需要接受度"))
		# 解锁之后要能恢复图标
		var keep_acc: int = m.acceptance
		m.acceptance = high_req
		wardrobe._refresh()
		_check("★ 接受度够了之后恢复显示图标",
			lb.text == "" and lb.icon != null)
		m.acceptance = keep_acc
		wardrobe._refresh()
		_check("接受度退回后重新变回问号", lb.text == "?")
	else:
		_check("★ 未解锁的装扮显示问号", false)
		_check("★ 未解锁的装扮不显示图标", false)
		_check("未解锁的装扮仍不可点", false)
		_check("提示里不透露名字，只说还差多少接受度", false)
		_check("★ 接受度够了之后恢复显示图标", false)
		_check("接受度退回后重新变回问号", false)

	print("\n-- 阶段一不再判定：只把数字摊开，门不锁 --")
	_check("伪装凑齐后按钮可用", wardrobe.continue_btn.disabled == false)
	_check("★ 判定栏已撤掉（底部不再摊结论）", not ("verdict_label" in wardrobe))
	_check("换装结果已交给 GameData（供阶段二结算）", gd.outfit_passed == true)
	_check("通过时没有留下失败理由", gd.outfit_fail_reasons.is_empty())

	# 故意把打扮退回 A 的原貌 —— 阶段一**不该**拦你，但结果会变成不通过
	var keep: Dictionary = m.equipped.duplicate()
	m._equip_defaults()
	wardrobe._refresh()
	_check("伪装不成立时按钮照样可用（赌不赌由你）", wardrobe.continue_btn.disabled == false)
	_check("但结果已同步为「不通过」", gd.outfit_passed == false)
	_check("不通过的理由已经记下", gd.outfit_fail_reasons.size() > 0)
	_check("失败理由点名到具体哪一条（反差 / 与原貌一致）",
		str(gd.outfit_fail_reasons).contains("反差值")
		and str(gd.outfit_fail_reasons).contains("与原貌一致"))
	m.equipped = keep
	wardrobe._refresh()
	_check("改回后结果恢复为通过", gd.outfit_passed == true)

# ------------------------------------------------------------
# 进入盘问
# ------------------------------------------------------------
func _test_enter_interrogation() -> void:
	print("\n-- 准备室 → 盘问：状态同步 --")
	wardrobe._on_continue()
	_check("准备室已隐藏", wardrobe.visible == false)
	_check("盘问阶段已显示", interro.visible == true)
	_check("反差达标已同步", gd.contrast_sufficient == true)
	_check("缺陷遮挡已同步", gd.defects_covered == true)
	_check("暴露值已同步", gd.outfit_exposure > 0)
	_check("外貌情报收集度已同步", gd.revealed_slots.size() == OutfitData.auto_slots().size())

	print("\n-- 盘问：按关抽题 --")
	interro.set_process(false)   # 关掉自动计时，改为手工步进
	_check("盘问已启动", interro._running == true)
	_check("开局怀疑度 = 20 + 失误 × 3", is_equal_approx(gd.suspicion_level, 20.0))
	_check("本轮抽到 6 道题", interro.level_questions().size() == 6)
	_check("题目都指向本局背景的档案", _questions_resolve(interro.level_questions()))
	# ★ 第十三轮后：一轮之内不再复问同一个事实 —— 复问只发生在**跨轮**。
	# ★ 第五十轮：题数 8 → 6。编排没变，仍是
	#   「本轮固定题（说法 / 同行者 / 盲区各一）+ 1 道跨轮复问 + 从通用池补足」，
	#   于是 6 道 = 3 + 1 + 2；第 1 轮没有复问，= 3 + 3。
	#   通用池里能抽的档案题一共 8 道，四轮各取 2 道正好对齐，不会缺题。
	# ★ 第二十九轮：题序不再由代码写死 —— 它现在**等于题目清单的顺序**，
	#   在题库页里拖一拖就能改。所以这里不再钉死开场顺序，
	#   改为断言「本轮这一批题里四种类型都出现过」。
	_check("本轮六道题里四种类型都出现了",
		_count_kind(interro.level_questions(), "card") >= 1
		and _count_kind(interro.level_questions(), "fact") >= 1
		and _count_kind(interro.level_questions(), "companion") >= 1
		and _count_kind(interro.level_questions(), "blind") >= 1)
	# ★ 第五十轮：档案题数跟着题数缩水 —— 6 道题 = 固定 3 道 + 通用池 3 道
	#   （第 1 轮无复问）→ 3 道档案题；第 2 轮起被那 1 道复问占掉一个位，落到 2 道。
	#   所以门槛从「不少于 3」降到「不少于 2」—— 仍然能抓到「通用池一道都没抽到」。
	_check("一关里档案题不少于 2 道", _count_kind(interro.level_questions(), "card") >= 2)
	_check("一关里恰好 1 道盲区题（完全没给信息的题）",
		_count_kind(interro.level_questions(), "blind") == 1)
	_check("一关里只有 1 道同行者提问", _count_kind(interro.level_questions(), "companion") == 1)
	_check("轮次名含背景与关号", interro.level_label.text.contains(RunData.background_name()))
	_check("从第 1 题开始", interro.current_question_index == 0)

	# 找一道 B 类题与一道 A 类题。
	# 一关抽 2~3 道档案题（第五十轮：题数 8 → 6 后通用池只补 2~3 道），
	# 抽到「全是同一类」的概率约 14% —— 所以这里**必须有兜底**：找不到就换一关，
	# 必要时换一局（见 _goto_level_with_card_owner）。
	#
	# ★ 这里刻意写成「先把值算出来、再统一 _check」的形状，保证**断言条数恒定**。
	#   以前用 if/else 分叉：走哪个分支取决于本轮恰好抽到哪两道档案题，
	#   于是同一份代码会跑出两个不同的总数。铁律：_check 一律放在分支外面。
	var b_idx := _find_question_index("B")
	if b_idx < 0:
		b_idx = _goto_level_with_card_owner("B")
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
	_check("本局存在含 B 类档案题的轮次", b_idx >= 0)

	# ---- B 类题：属于 B 的档案范围 → 照答即可 ----
	# 题目标签（「常规盘问 / 雷区」那行小字）已经删掉，这里改为直接验选项结构：
	# 档案题固定 4 项 —— A 主答 / B 撒谎 / C 回避 / D 沉默。
	var b_opt_count := 0
	var b_opt_kind := ""
	var b_opt_delta := 0.0
	var b_text_ok := false
	var b_silence_kind := ""
	if b_idx >= 0:
		interro._load_question(b_idx)
		b_opt_count = interro.current_options.size()
		b_opt_kind = str(interro.current_options[0]["kind"])
		b_opt_delta = float(interro.current_options[0]["delta"])
		if interro.current_options.size() > 3:
			b_silence_kind = str((interro.current_options[3] as Dictionary).get("kind", ""))
		# ★ 第二十九轮：正面回应的文案现在写在选项里（tone = correct），
		#   不再有独立的 answer 字段。这里从选项反查「摆给玩家的那一句」。
		var b_answer := ""
		for o in (interro.level_questions()[b_idx] as Dictionary).get("options", []):
			if str((o as Dictionary).get("tone", "")) == "correct":
				b_answer = str((o as Dictionary).get("text", ""))
				break
		b_text_ok = b_answer != "" and str(interro.current_options[0]["text"]).contains(b_answer)
	_check("档案题摆出 4 个选项（全篇最多四个）", b_opt_count == 4)
	_check("B 类题正面回应 = 照档案作答", b_opt_kind == "ok")
	_check("B 类题正面回应降低怀疑度", b_opt_delta < 0.0)
	_check("B 类题的正面回应文案就是档案里的 answer", b_text_ok)
	_check("第 4 项是「沉默」", b_silence_kind == "silence")

	# ---- A 类题：只有 A 才知道的事 → 照实答就是当场说漏嘴 ----
	var a_idx := _find_question_index("A")
	if a_idx < 0:
		# 本轮的档案题里没有 A 类 —— 换一关（必要时换一局）再测
		a_idx = _goto_level_with_card_owner("A")
	_check("本局存在含 A 类档案题的轮次", a_idx >= 0)

	var a_silence_delta := 0.0
	var a_opt_kind := ""
	var a_opt_delta := 0.0
	var a_text_ok := false
	if a_idx >= 0:
		interro._load_question(a_idx)
		if interro.current_options.size() > 3:
			a_silence_delta = float((interro.current_options[3] as Dictionary).get("delta", 0.0))
		a_opt_kind = str(interro.current_options[0]["kind"])
		a_opt_delta = float(interro.current_options[0]["delta"])
		# ★ 第二十九轮：A 类的「真相」同样写在选项里（tone = leak）。
		var a_leak := ""
		for o in (interro.level_questions()[a_idx] as Dictionary).get("options", []):
			if str((o as Dictionary).get("tone", "")) == "leak":
				a_leak = str((o as Dictionary).get("text", ""))
				break
		a_text_ok = a_leak != "" and str(interro.current_options[0]["text"]).contains(a_leak)
	_check("沉默项的代价是固定值（与性情无关）",
		is_equal_approx(a_silence_delta, Interrogation.SILENCE_DELTA))
	_check("A 类题正面回应 = 当场说漏嘴", a_opt_kind == "leak")
	_check("说漏嘴直接拉满怀疑度", a_opt_delta >= 100.0)
	_check("A 类题的正面回应文案就是 A 的真相", a_text_ok)

# ------------------------------------------------------------
# 说法题：前后矛盾
# ------------------------------------------------------------
# ------------------------------------------------------------
#  自行编辑模式（★ 第五十六轮）
#
#  用户口径：「在用户自己编辑的背景时，用不到的空全部删去」——
#  编辑器那边把档案卡 / 事实 / 「这句话算哪一种」都收起来了。
#  这一段测的是**运行时**跟着改对了没有，三件事：
#    ① 没有 tone 的题仍然走统一格式（否则会掉进旧「档案题」那条路，
#       只摆固定四个选项、完全不读你写的内容）；
#    ② 没有 tone 时代价按「照实答」算（以前是 0，等于不涨不跌）；
#    ③ 不再是「盲区题」（不挂卡不挂事实的题在自动生成下就是盲区）。
# ------------------------------------------------------------
func _test_manual_question_options() -> void:
	print("\n-- 自行编辑模式：选项没有「算哪种」也能跑 --")
	# ★ 只开一局就够 —— 这段全是纯函数断言（拿自己拼的 q 走 `_build_unified_options`），
	#   不需要 `_run_a_clean_level()` 里「先过一轮再重开」那套。
	#   （实测那样要 13.8 秒，占整套 7.8%；换成和「盲区题」一样的轻开局只要几秒。）
	main._start_new_run(20261011)
	_prepare_and_enter()
	interro.set_process(false)
	var bg := RunData.background()

	# ---- 纯函数：缺省 = auto ----
	_check("不写这个键 = 自动生成",
		ScenarioData.questions_source_of({}) == "auto")
	_check("写了 manual 就是自行编辑",
		ScenarioData.questions_source_of({"questions_source": "manual"}) == "manual")
	_check("写了个不认识的值 → 退回自动生成",
		ScenarioData.questions_source_of({"questions_source": "xx"}) == "auto")
	_check("出厂四套都是自动生成", not RunData.questions_are_manual())

	# ---- 一道典型的「自行编辑」题：没有 tone、不挂卡不挂事实 ----
	var q := {
		"id": "manual_probe", "level": 0, "text": "你从哪儿来？",
		"options": [
			{"text": "从北边来的。", "suspicion": -6},
			{"text": "……", "suspicion": 3},
			{"text": "干你什么事。", "suspicion": 15, "ending": "leak"},
			{},
		],
	}
	_check("没有 tone 的题仍走统一格式（不会掉进旧「档案题」那条路）",
		interro._is_unified_question(q))

	# ---- 自动生成下：不挂卡不挂事实 = 盲区题（这是原来就有的行为） ----
	# ★ interro 声明成 Control，动态调用拿回来是 Variant —— 必须写显式类型，
	#   否则 `:=` 会报 "Cannot infer the type"（整份脚本连解析都过不去）。
	var opts_auto: Array = interro._build_unified_options(q)
	_check("自动生成：不挂卡不挂事实 → 判成盲区题",
		bool((opts_auto[0] as Dictionary).get("blind", false)))

	# ---- 改成自行编辑：不再是盲区 ----
	bg["questions_source"] = "manual"
	_check("自行编辑：questions_are_manual() 为真", RunData.questions_are_manual())
	var opts: Array = interro._build_unified_options(q)
	_check("自行编辑：四个选项都读出来了（实际 %d）" % opts.size(), opts.size() == 4)
	_check("自行编辑：不再判成盲区题（否则每道题都会走「按脾性选对没选对」）",
		not bool((opts[0] as Dictionary).get("blind", false)))
	_check("自行编辑：文本原样保留",
		str((opts[0] as Dictionary).get("text", "")).ends_with("从北边来的。"))
	_check("自行编辑：显式写的怀疑值生效",
		is_equal_approx(float((opts[1] as Dictionary).get("delta", 99.0)), 3.0))
	_check("自行编辑：没写怀疑值也没有 tone → 按「照实答」算，不是 0（实际 %.1f）"
		% float((opts[3] as Dictionary).get("delta", 99.0)),
		is_equal_approx(float((opts[3] as Dictionary).get("delta", 99.0)),
			float(ScenarioData.RULES.get("correct_delta", -6.0))))
	_check("自行编辑：没写 tone 的选项按「照实答」结算（kind = ok）",
		str((opts[0] as Dictionary).get("kind", "")) == "ok")
	_check("自行编辑：选项自己写的 ending 照样生效",
		str((opts[2] as Dictionary).get("ending", "")) == "leak")
	bg.erase("questions_source")
	_check("删掉那个键就退回自动生成", not RunData.questions_are_manual())

# ------------------------------------------------------------
# 选项回应：选完的那句话，会和下一题的题面一起出现
#
#  用户口径（第五十七轮）：「选项选择后，对应的选项文本和下一个题面一起出现」。
#  选项可以自带 `echo`（编辑器里「接在下一题题面前的回应」），
#  留空就用选项文本本身 —— 所以出厂数据一条都不用补。
# ------------------------------------------------------------
func _test_option_echo() -> void:
	print("\n-- 选项回应：选完的那句接到下一题题面前 --")
	_run_a_clean_level()
	_check("开新的一轮 → 上一轮的回应不会带进来", interro.last_choice_text == "")
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_needed = false
	interro.qte_container.hide()
	interro.intf_container.hide()
	interro._load_question(0)
	_check("第 1 题题面前没有上一题的回应",
		not interro.dialogue_label.text.begins_with("你："))

	# 挑一个「照实答」的选项 —— 它不会当场收场，最能看清下一题的样子。
	var pick := -1
	for i in interro.current_options.size():
		var o: Dictionary = interro.current_options[i]
		if str(o.get("kind", "")) == "ok" and str(o.get("echo", "")) != "":
			pick = i
			break
	if pick < 0:
		for i in interro.current_options.size():
			if str((interro.current_options[i] as Dictionary).get("echo", "")) != "":
				pick = i
				break
	_check("第 1 题至少有一个带回应文本的选项", pick >= 0)
	if pick < 0 or interro.level_questions().size() < 2:
		return

	var echo := str((interro.current_options[pick] as Dictionary).get("echo", ""))
	_check("回应文本默认 = 选项原文（不带 A. 前缀）",
		echo != "" and not echo.begins_with("A. "))
	interro._select_option(pick)
	_check("选完之后记下了这句回应", interro.last_choice_text == echo)
	_check("默认回应不是「自带」——下一题前会自动加「你：」",
		interro.last_choice_is_custom == false)

	interro._ended = false
	interro._running = true
	interro._load_question(1)
	_check("下一题题面前接上了「你：<上一题选的>」",
		interro.dialogue_label.text.begins_with("你：" + echo + "\n"))
	_check("下一题的题面照旧跟在后面",
		interro.dialogue_label.text.contains(_q_text_of(interro.level_questions()[1])))

	# ---- 选项自带 echo 时优先用它；没写就回落 ----
	var opts: Array = interro._build_unified_options({
		"id": "t_echo", "text": "测试题面",
		"options": [
			{"text": "甲回答", "tone": "correct", "echo": "（测试专用回应）"},
			{"text": "乙回答", "tone": "bluff"},
		]})
	_check("选项自带 echo → 用自带的那句",
		str((opts[0] as Dictionary).get("echo", "")) == "（测试专用回应）")
	_check("选项没写 echo → 回落成选项文本",
		str((opts[1] as Dictionary).get("echo", "")) == "乙回答")
	_check("按钮文字仍然是选项文本（带 A. 前缀）",
		str((opts[0] as Dictionary).get("text", "")) == "A. 甲回答")
	_check("自带 echo → 标记为「原样显示」",
		bool((opts[0] as Dictionary).get("echo_custom", false)))
	_check("没写 echo → 标记为「回落」",
		not bool((opts[1] as Dictionary).get("echo_custom", true)))
	# ★ 第六十一轮：自带的那段原样显示 —— 它可以是「选完之后的后果」，不能自动加「你：」
	interro.last_choice_text = "（测试后果）"
	interro.last_choice_is_custom = true
	interro._load_question(1)
	_check("自带回应原样显示（不自动加「你：」）",
		interro.dialogue_label.text.begins_with("（测试后果）\n"))
	# ★ 第六十九轮：manual 背景全部按原文；auto 背景保留说话人 / 「你：」
	_check("manual 背景：回应和题面都不加说话人",
		interro._dialogue_text(true, "苦主", "回应", false, "题面") == "回应\n题面")
	_check("auto 背景：默认回应加「你：」、题面加说话人",
		interro._dialogue_text(false, "苦主", "回应", false, "题面") == "你：回应\n苦主：题面")
	# 「⚠」是读过情报后给按钮加的雷区标记 —— 屏幕上是原句，不能把标记念出来。
	var warn_opts: Array = interro._letterize([{"_label": "⚠ 测试危险项"}])
	_check("回应文本里不带「⚠」这个按钮标记",
		str((warn_opts[0] as Dictionary).get("echo", "")) == "测试危险项")

	# 收掉 _select_option 留下的「1.8 秒后自动下一题」——别让它跨到后面的用例里。
	interro._ended = true

# ------------------------------------------------------------
#  选项按钮的布局（★ 第六十九轮）
#
#  用户报的现象：「第二局第一轮第四问」选项显示不正常。
#  根因：从 3 个选项**第一次**切到 4 个选项时，第 4 个按钮是这一刻才创建的，
#  它刚 add_child 时宽度还是 0，而按钮开着自动换行 —— Button 的最小高度是按
#  **当前宽度**算的，宽度 0 时长文本被当成「一个字一行」，最小高度直接 510。
#  这个错误的最小尺寸之后再没有任何东西触发重算，于是：
#    选项区被撑到整屏高 → 第 4 个选项被拉成 510 高 → 左下角「掏出手机」被挤出屏幕。
#  而且**不会自己恢复**（等 227 帧还是坏的）。
#  为什么偏偏是「第一轮第四问」：题库顺序是 3 道 3 选项 + 3 道 4 选项，
#  第 4 道正好是第一次出现 4 个选项。
# ------------------------------------------------------------
func _test_option_button_layout() -> void:
	print("\n-- 选项按钮的布局：3 个选项切到 4 个时不能撑爆 --")
	RunData.start_new_run(20261018, 0, "town_inn")
	gd.outfit_passed = true
	interro.set_process(false)
	interro._options_locked_by_qte = false
	interro.start_interrogation()

	var qs: Array = interro.level_questions()
	var i3 := -1
	var i4 := -1
	for i in qs.size():
		var n: int = (qs[i].get("options", []) as Array).size()
		if n == 3 and i3 < 0:
			i3 = i
		elif n == 4 and i4 < 0:
			i4 = i
	_check("本轮里有 3 个选项的题", i3 >= 0)
	_check("本轮里有 4 个选项的题", i4 >= 0)
	if i3 < 0 or i4 < 0:
		return

	# 必须从「一个按钮都没有」开始 —— 这个 bug 只在**新建**第 4 个按钮时出现
	for b in interro.option_btns:
		b.free()
	interro.option_btns.clear()
	await get_tree().process_frame

	# ★ 判据一律用**相对量**，不写死像素：
	#   headless 下按钮实测 47 高（字体行高），视口尺寸也不可信（手机按钮底边能报到 10126）。
	#   硬编码 154 / 208 会变成「换个字体就红」的假失败。
	interro._load_question(i3)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("3 个选项：按钮池是 3 个", interro.option_btns.size() == 3)
	var h3: float = interro.opts_box.get_global_rect().size.y
	_check("3 个选项：选项区没被撑爆（%.0f ≤ 3×80 + 2×8）" % h3, h3 <= 3.0 * 80.0 + 2.0 * 8.0)

	# ★ 这一步就是 bug 的现场：第 4 个按钮在此刻才被创建
	interro._load_question(i4)
	await get_tree().process_frame
	await get_tree().process_frame
	var h4: float = interro.opts_box.get_global_rect().size.y
	_check("4 个选项：选项区没被撑爆（%.0f ≤ 4×80 + 3×8）" % h4, h4 <= 4.0 * 80.0 + 3.0 * 8.0)
	var tallest := 0.0
	var shortest := 9999.0
	for j in interro.current_options.size():
		var bh: float = (interro.option_btns[j] as Button).size.y
		tallest = maxf(tallest, bh)
		shortest = minf(shortest, bh)
	_check("4 个选项：每个按钮都没被拉长（最高 %.0f，上限 80）" % tallest, tallest <= 80.0)
	# ★ 这一条才是那个 bug 的指纹：坏的时候只有**第 4 个**是 510，前三个仍是 46。
	_check("4 个选项：最高与最矮的按钮差不到两行（%.0f vs %.0f）" % [tallest, shortest],
		tallest - shortest <= 2.0)

func _test_fact_consistency() -> void:
	print("\n-- 说法题：同一件事，前后必须一致 --")
	_run_a_clean_level()
	var f0 := _find_fact_question_index(0)
	var f1 := _find_fact_question_index(1)
	_check("本轮有 1 道新说法题 + 1 道跨轮复问", f0 >= 0 and f1 >= 0)
	if f0 < 0 or f1 < 0:
		return

	var q_new: Dictionary = interro.level_questions()[f0]
	var q_recall: Dictionary = interro.level_questions()[f1]
	_check("本轮那两道说法题里，一道是新的、一道是复问",
		bool(q_new.get("recall", false)) == false
		and bool(q_recall.get("recall", false)) == true)
	_check("★ 一轮之内不复问同一个事实（两道题指向不同的事）",
		str(q_new.get("fact", "")) != str(q_recall.get("fact", "")))
	# ★ 第二十九轮：题面字段从 `q` 改叫 `text`，读取要兼容两种。
	_check("复问换了另一种问法", _q_text_of(q_new) != _q_text_of(q_recall))

	var fid := str(q_new.get("fact", ""))
	var canonical := DossierData.canonical_value(fid)
	# ★ 复问指向的是**前面几轮**立过的那条事实 —— 跟本轮新题不是同一件事。
	var rid := str(q_recall.get("fact", ""))
	var r_canonical := DossierData.canonical_value(rid)

	# ---- 本轮新题：说官方口径 → 记为我的口径，不减怀疑 ----
	gd.stated_facts.clear()
	gd.contradictions = 0
	interro._ended = false
	interro._running = true
	interro._load_question(f0)
	var s0: float = gd.suspicion_level
	var canon_idx := _option_index_of_value(canonical)
	_check("选项里能找到官方口径", canon_idx >= 0)
	interro._select_option(canon_idx)
	_check("首次答官方口径 → 记进「我说过的话」", str(gd.stated_facts.get(fid, "")) == canonical)
	_check("首次答官方口径 → 不再减怀疑（轮内只涨不跌）",
		is_equal_approx(gd.suspicion_level, s0))
	_check("首次答官方口径 → 不算矛盾", gd.contradictions == 0)

	# ---- 复问：说成跟前面几轮不一样 → 前后矛盾 ----
	#   先模拟「前面几轮你已经立过口径」（跨轮复问的前提）
	gd.stated_facts[rid] = r_canonical
	gd.contradictions = 0
	interro.is_qte_active = false
	interro._ended = false
	interro._running = true
	# ★ 第三十三轮：表情 QTE 已改成「只由暴露值决定」的线性斜坡 ——
	#   所以这里把暴露值顶到**必出点**再验（斜坡本身另有 _test_qte_budget 专项覆盖）。
	var exp_keep: float = gd.outfit_exposure
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_FULL
	interro._load_question(f1)
	var other_idx := _option_index_of_value_not(r_canonical)
	_check("复问的选项里有一个跟前面几轮不同的版本", other_idx >= 0)
	var s1: float = gd.suspicion_level
	interro._select_option(other_idx)
	_check("复问改口 → 记为前后矛盾", gd.contradictions == 1)
	_check("复问改口 → 重罚（+25 起）",
		gd.suspicion_level >= s1 + Interrogation.CONTRADICTION_PENALTY - 0.01)
	_check("复问改口 → 口径仍保留第一次的说法（改不回来）",
		str(gd.stated_facts.get(rid, "")) == r_canonical)
	_check("复问改口 → 暴露值到必出点时排上压表情的 QTE（延迟几秒后弹）",
		interro.qte_needed == true)
	_check("复问改口 → 矛盾文案写明跟哪条对不上",
		interro.feedback_label.text.contains("对不上的是："))
	interro.is_qte_active = false
	interro.qte_container.hide()
	gd.outfit_exposure = exp_keep

	# ---- 复问：说成跟上次一样 → 不算矛盾 ----
	gd.contradictions = 0
	interro.is_qte_active = false
	interro._ended = false
	interro._running = true
	interro._load_question(f1)
	var s2: float = gd.suspicion_level
	interro._select_option(_option_index_of_value(r_canonical))
	_check("复问答得跟上次一致 → 不算矛盾", gd.contradictions == 0)
	_check("复问答得跟上次一致 → 不再减怀疑（轮内只涨不跌）",
		is_equal_approx(gd.suspicion_level, s2))

	# ---- 说法与官方口径不符 → 记为「临时编的」 ----
	gd.stated_facts.clear()
	gd.improvised = 0
	interro.is_qte_active = false
	interro._ended = false
	interro._running = true
	interro._load_question(f0)
	var s3: float = gd.suspicion_level
	interro._select_option(_option_index_of_value_not(canonical))
	_check("答非官方口径 → 记为临时编的说法", gd.improvised == 1)
	_check("答非官方口径 → 推高怀疑度", gd.suspicion_level > s3)

	# ---- 累计矛盾到上限 → 当场识破 ----
	_run_a_clean_level()
	var f1b := _find_fact_question_index(1)
	_check("（前置）本轮有复问题", f1b >= 0)
	if f1b >= 0:
		var rid2 := str((interro.level_questions()[f1b] as Dictionary).get("fact", ""))
		var r_can2 := DossierData.canonical_value(rid2)
		gd.contradictions = Interrogation.CONTRADICTION_LIMIT - 1
		gd.stated_facts[rid2] = r_can2
		interro._ended = false
		interro._running = true
		interro._load_question(f1b)
		var w_idx := _option_index_of_value_not(r_can2)
		if w_idx >= 0:
			interro._select_option(w_idx)
		_check("累计矛盾到上限 → 直接识破", interro._ended == true)
		_check("直接识破 → 怀疑度拉满", gd.suspicion_level >= 100.0)
		_check("识破文案点明「前后矛盾」", interro.dialogue_label.text.contains("前后矛盾"))
	else:
		_check("累计矛盾到上限 → 直接识破", false)
		_check("直接识破 → 怀疑度拉满", false)
		_check("识破文案点明「前后矛盾」", false)

	gd.contradictions = 0
	gd.improvised = 0
	gd.stated_facts.clear()

# ------------------------------------------------------------
# 跨关口径：本关新加的题，若跟本局前几轮的回答对不上 → 一样失败
#
# 用户口径：「每轮游戏还有增添新的信息」「问题新增 新增的问题的回答
# 要注意如果和本局前几轮的回答对不上也会失败」。
#
# 落在这里就是两条不变量：
#   1) 口径（stated_facts）**跨关不清** —— 审讯官是同一个人，他记得你说过什么；
#   2) 任何一道题（不管它是本轮新加的，还是复问旧事）只要碰到**已经立过口径的事实**，
#      答得不一样 = 前后矛盾，累计到上限直接识破。
#
# 同时反向守住一条：本轮**新增**的说法题必须指向一条还没问过的事实 ——
# 不能一上来就逼玩家自相矛盾，那不成设计，成了坑。
# ------------------------------------------------------------
func _test_cross_level_consistency() -> void:
	print("\n-- 跨关口径：新加的题跟本局前几轮对不上 → 一样失败 --")
	ProfileData.reset_all()
	main._start_new_run(20260214)
	interro.set_process(false)

	var fs: Array = RunData.facts()
	_check("本局有 4 条事实（一关一条）", fs.size() == OutfitData.MAX_LEVELS)
	if fs.size() != OutfitData.MAX_LEVELS:
		return

	gd.stated_facts.clear()
	gd.contradictions = 0

	var stated := {}          # fact id -> 我立下的口径（镜像 gd.stated_facts）
	var recall_checked := 0

	for li in OutfitData.MAX_LEVELS:
		var n := li + 1
		if li > 0:
			RunData.advance_level()
		_check("第 %d 轮：口径跨轮保留（没被轮次切换清掉）" % n,
			gd.stated_facts.size() == stated.size())

		interro._questions = RunData.questions_for_level(li, Interrogation.QUESTIONS_PER_LEVEL)

		# ---- 本轮新增的说法题：必须是没问过的新事 ----
		var qi_new := _fact_question_index_by_recall(false)
		_check("第 %d 轮有本轮新增的说法题" % n, qi_new >= 0)
		if qi_new >= 0:
			var fid := str((interro.level_questions()[qi_new] as Dictionary).get("fact", ""))
			_check("第 %d 轮的新说法题指向一条没立过口径的事实" % n, not stated.has(fid))
			var canon := DossierData.canonical_value(fid)
			interro.is_qte_active = false
			interro.interference_active = false
			interro._ended = false
			interro._running = true
			interro._load_question(qi_new)
			interro._select_option(_option_index_of_value(canon))
			_check("第 %d 轮立下口径：%s" % [n, fid],
				str(gd.stated_facts.get(fid, "")) == canon)
			stated[fid] = canon

		# ---- 本轮的复问题：必须落在「本局前几轮立过的口径」上 ----
		#  ★ 第 1 轮没有「上一轮」—— 它**不该**有复问题（也就没有前后矛盾）。
		var qi_old := _fact_question_index_by_recall(true)
		if li == 0:
			_check("第 1 轮没有跨轮复问（也就不会在轮内自相矛盾）", qi_old < 0)
			continue
		_check("第 %d 轮有复问题" % n, qi_old >= 0)
		if qi_old < 0:
			continue
		var rid := str((interro.level_questions()[qi_old] as Dictionary).get("fact", ""))
		_check("第 %d 轮的复问题落在本局前几轮立过的口径上" % n, stated.has(rid))
		if not stated.has(rid):
			continue
		recall_checked += 1

		# ---- 关键：这道**本关新加**的题，答得跟前面不一样 → 判前后矛盾 ----
		interro.is_qte_active = false
		interro.interference_active = false
		interro._ended = false
		interro._running = true
		interro._load_question(qi_old)
		var wrong_idx := _option_index_of_value_not(str(stated[rid]))
		_check("第 %d 轮复问题的选项里有一个跟前面不同的版本" % n, wrong_idx >= 0)
		if wrong_idx < 0:
			continue
		var c_before: int = gd.contradictions
		interro._select_option(wrong_idx)
		_check("第 %d 轮：跟本局前几轮对不上 → 记为前后矛盾" % n,
			gd.contradictions == c_before + 1)
		_check("第 %d 轮：口径仍锁在第一次的说法上（改不回来）" % n,
			str(gd.stated_facts.get(rid, "")) == str(stated[rid]))
		_check("第 %d 轮：矛盾文案点明「前后矛盾」" % n,
			interro.feedback_label.text.contains("前后矛盾"))
		# ★ 第十三轮：矛盾必须说清「跟哪一条对不上」
		_check("第 %d 轮：矛盾文案写明跟哪条对不上" % n,
			interro.feedback_label.text.contains("对不上的是："))
		_check("第 %d 轮：矛盾文案同时摆出上次与这次的两种说法" % n,
			interro.feedback_label.text.contains("上次你说的是：")
			and interro.feedback_label.text.contains("这次你说成了："))
		interro.is_qte_active = false
		interro.qte_container.hide()
		gd.contradictions = 0     # 下一轮重新数，免得提前撞上限

	_check("第 2 轮有复问题参与跨关判定",
		recall_checked == OutfitData.MAX_LEVELS - 1)

	# ---- 整局重开 → 换了一个人，口径必须清空 ----
	main._start_new_run(20260215)
	_check("整局重开后「我说过的话」清空", gd.stated_facts.is_empty())
	_check("整局重开后矛盾计数归零", gd.contradictions == 0)

	# ---- 结构性不变量：换 20 个种子，出题编排都不许把玩家推进死胡同 ----
	#   每轮都必须是「1 道新说法题 + 至少 1 道复问题」；
	#   新说法题永远问没问过的事（否则一上来就无解）；
	#   复问题永远落在「到这一轮为止已经立过口径的事实」上（否则它无从矛盾）。
	var bad_count := 0
	var bad_size := 0
	var bad_new := 0
	var bad_old := 0
	var dup_fact := 0        # 一轮之内新题和复问题撞上同一个事实的次数
	for s in 20:
		RunData.start_new_run(900000 + s)      # 只走数据层：不重建 UI，快得多
		var fdefs: Array = RunData.facts()
		if fdefs.size() != OutfitData.MAX_LEVELS:
			continue
		var asked := []
		for li in OutfitData.MAX_LEVELS:
			RunData.level_index = li
			var qs: Array = RunData.questions_for_level(li, Interrogation.QUESTIONS_PER_LEVEL)
			if qs.size() != Interrogation.QUESTIONS_PER_LEVEL:
				bad_size += 1
			var news := []
			var olds := []
			for q in qs:
				var qd: Dictionary = q
				if _q_kind(qd) != "fact":
					continue
				if bool(qd.get("recall", false)):
					olds.append(str(qd.get("fact", "")))
				else:
					news.append(str(qd.get("fact", "")))
			# 第 1 轮没有「上一轮」，只有 1 道新说法题；第 2 轮起 1 新 + 1 复问
			if news.size() != 1 or (li > 0 and olds.size() != 1):
				bad_count += 1
			if li == 0 and olds.size() != 0:
				bad_count += 1
			for nf in news:
				if olds.has(nf):
					dup_fact += 1
			var this_new := str((fdefs[li] as Dictionary).get("id", ""))
			for f in news:
				if f != this_new or asked.has(f):
					bad_new += 1
			var stated_so_far := asked.duplicate()
			stated_so_far.append(this_new)     # 本轮新立的也算「已经说过」
			for f in olds:
				if not stated_so_far.has(f):
					bad_old += 1
			asked.append(this_new)
	_check("20 个种子 × 4 关：每轮都是 %d 道题" % Interrogation.QUESTIONS_PER_LEVEL,
		bad_size == 0)
	_check("20 个种子：第 1 轮 1 道新说法、第 2 轮起 1 新 + 1 跨轮复问", bad_count == 0)
	_check("20 个种子：新说法题永远问没问过的事（不会一上来就无解）", bad_new == 0)
	_check("20 个种子：复问题永远落在已立过口径的事实上", bad_old == 0)
	_check("20 个种子：一轮之内不复问同一个事实（新题 ≠ 复问题）", dup_fact == 0)

	RunData.start_new_run(20260214)
	gd.contradictions = 0
	gd.improvised = 0
	gd.stated_facts.clear()

# 找本轮题序里的说法题：
#   want=false → 本轮**新增**的那道（recall=false）
#   want=true  → 复问旧事的那道（recall=true）
# 本轮「新说法题」的下标。
# ★ 第二十九轮：题序现在等于「题目清单的顺序」，玩家随时可以在题库页里调 ——
#   所以测试**不能再假设「第 2 题就是说法题」**，一律按类型现找（找不到退到 0）。
func _new_fact_index() -> int:
	var i := _fact_question_index_by_recall(false)
	return i if i >= 0 else 0

func _fact_question_index_by_recall(want: bool) -> int:
	var qs: Array = interro.level_questions()
	for i in qs.size():
		var q: Dictionary = qs[i]
		if _q_kind(q) != "fact":
			continue
		if bool(q.get("recall", false)) == want:
			return i
	return -1

# 取当前选项里 value == val 的下标；找不到 -1
func _option_index_of_value(val: String) -> int:
	for i in interro.current_options.size():
		if str((interro.current_options[i] as Dictionary).get("value", "")) == val:
			return i
	return -1

# 取当前选项里 value != val 的下标（优先取官方口径之后的那个）
func _option_index_of_value_not(val: String) -> int:
	for i in interro.current_options.size():
		var o: Dictionary = interro.current_options[i]
		if str(o.get("kind", "")) != "fact":
			continue
		if str(o.get("value", "")) != val:
			return i
	return -1

# 重置成一局干净的第 2 轮，并读全情报、凑好伪装、进入盘问。
# ★ 为什么是第 2 轮：第 1 轮没有「上一轮」，不会排跨轮复问 ——
#   而「前后矛盾」这件事只发生在复问上（见 RunData.questions_for_level）。
func _run_a_clean_level() -> void:
	main._start_new_run(20261011)
	_prepare_and_enter()
	_pass_current_level()
	main._on_overlay_pressed()
	interro._ended = false
	interro.is_qte_active = false
	interro.qte_needed = false
	interro.interference_active = false
	interro.qte_container.hide()
	interro.intf_container.hide()
	_reveal_all()
	_assign_all()
	_prepare_and_enter()
	interro.set_process(false)

# ------------------------------------------------------------
# 同行者提问：和审讯官的问题作用一样
# ------------------------------------------------------------
func _test_companion_question() -> void:
	print("\n-- 同行者提问：和审讯官的问题走同一套判定 --")
	_run_a_clean_level()
	# ★ 第二十九轮：同行者提问进了统一的题目清单（speaker = companion），
	#   不再有独立的 companion_questions 段。
	# ★ 第五十二轮：每套背景的同行者提问 4 条 → 2 条
	_check("同行者提问库非空", _count_kind(RunData.question_list(), "companion") >= 2)

	var ci := _find_companion_question_index()
	_check("本轮题序里有同行者提问", ci >= 0)
	if ci < 0:
		return
	var q: Dictionary = interro.level_questions()[ci]
	var fid := str(q.get("fact", ""))
	var canonical := DossierData.canonical_value(fid)
	_check("同行者提问是正式的题（speaker = companion）", _q_kind(q) == "companion")
	_check("同行者提问带 plant 文案", str(q.get("plant", "")).length() > 6)
	_check("同行者提问的选项是 3 个", (q["options"] as Array).size() == 3)

	# ---- 加载时：发言人是同行者，标签是「同行者插话」----
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	gd.stated_facts.clear()
	gd.contradictions = 0
	interro._load_question(ci)
	var comp_speaker: String = ScenarioData.ui_t("interrogation.speaker_companion", "同行者")
	_check("发言人是同行者", interro.dialogue_label.text.begins_with(comp_speaker + "："))
	_check("题面就是他的话", interro.dialogue_label.text.contains(_q_text_of(q)))
	_check("选项被刷成他的三个回应", interro.current_options.size() == 3)
	_check("按钮池跟着涨到 3 个", interro.option_btns.size() >= 3)

	# ---- 顶回去：重申自己的口径 → 不算矛盾，且照样种下钉子 ----
	var push_i := _companion_option_index(canonical)
	_check("选项里有「顶回去」的那个（value = 官方口径）", push_i >= 0)
	var plants_before: int = gd.plants
	var susp_before: float = gd.suspicion_level
	if push_i >= 0:
		interro._select_option(push_i)
	_check("★ 他这一问不替玩家立口径（本轮内没有那件事的记录）",
		gd.stated_facts.is_empty())
	_check("顶回去 → 不算前后矛盾", gd.contradictions == 0)
	_check("顶回去 → 不再减怀疑（轮内只涨不跌）",
		is_equal_approx(gd.suspicion_level, susp_before))
	_check("无论怎么答，钉子都种下了（plants +1）", gd.plants == plants_before + 1)
	_check("答完 → plant 文案接在反馈后面（右侧栏已删）",
		str(q.get("plant", "")) != "" and interro.feedback_label.text.contains(str(q.get("plant", ""))))

	# ---- 顺着他说：跟他给的那个错版本 → 立场动摇，但**一轮之内不算矛盾** ----
	#  ★ 第十三轮：他就在同一关里、你刚立完说法之后插这句话。
	#    在一轮之内给出「顺着他就前后矛盾」的选项，等于把跨轮的规则提前用掉 ——
	#    那不叫推理，叫陷阱。所以他这一问只让你掉点血，不算矛盾。
	var wrong := _companion_wrong_value(q)
	_check("选项里有一个错的版本（value ≠ 官方口径）", wrong != "")
	# 先给这件事立一个口径（模拟前面已经答过），这样「顺着他说」才有可比的对象
	gd.stated_facts[fid] = canonical
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro._ended = false
	interro._running = true
	interro._load_question(ci)
	var wrong_i := _companion_option_index(wrong)
	var susp2: float = gd.suspicion_level
	if wrong_i >= 0:
		interro._select_option(wrong_i)
	_check("★ 顺着他说 → 一轮之内**不算**前后矛盾", gd.contradictions == 0)
	_check("顺着他说 → 按该选项的代价涨怀疑度", gd.suspicion_level > susp2)
	_check("顺着他说 → 口头提醒「你的说法开始摇晃了」",
		interro.feedback_label.text.contains("摇晃"))
	_check("顺着他说 → 他自己给的错版本不写进你的口径",
		str(gd.stated_facts.get(fid, "")) == canonical)

	# ---- 回避：value 为空 → 不算表态 ----
	var evade_i := _companion_option_index("")
	_check("选项里有一个不表态的（value 为空）", evade_i >= 0)
	gd.stated_facts.clear()
	gd.contradictions = 0
	interro._ended = false
	interro._running = true
	interro._load_question(ci)
	if evade_i >= 0:
		interro._select_option(evade_i)
	_check("回避 → 不写入口径", gd.stated_facts.is_empty())
	_check("回避 → 不算前后矛盾", gd.contradictions == 0)

	# ---- 干扰（递话）仍然是可 QTE 抵抗的，且和提问是两回事 ----
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro._load_question(0)
	interro._start_interference()
	_check("干扰是递话 QTE（可抵抗）", interro.interference_active == true)
	_check("干扰期间选项被锁死", interro.option_btns[0].disabled == true)
	_check("干扰不改变题目", interro.current_question_index == 0)
	interro._end_interference(true)
	_check("抵抗成功 → 干扰结束、选项恢复", interro.interference_active == false
		and interro.option_btns[0].disabled == false)

	gd.contradictions = 0
	gd.stated_facts.clear()
	gd.plants = 0

# 找同行者提问的下标
func _find_companion_question_index() -> int:
	var qs: Array = interro.level_questions()
	for i in qs.size():
		if _q_kind(qs[i] as Dictionary) == "companion":
			return i
	return -1

# 取同行者提问里 value == 指定值的选项下标（"" 表示找那个不表态的）
func _companion_option_index(val: String) -> int:
	for i in interro.current_options.size():
		var o: Dictionary = interro.current_options[i]
		# ★ 第二十九轮：同行者提问的选项现在按 tone 分派 ——
		#   「某个版本」那两项 kind = companion；「不表态」那项迁移后是 evade
		#   （它的 value 为空，语义上就是回避，不是某个版本）。
		var k := str(o.get("kind", ""))
		if k != "companion" and k != "evade":
			continue
		if str(o.get("value", "")) == val:
			return i
	return -1

# 取同行者提问里那个「错的版本」（非空且不是官方口径）
func _companion_wrong_value(q: Dictionary) -> String:
	var fid := str(q.get("fact", ""))
	var canonical := DossierData.canonical_value(fid)
	for o in q.get("options", []):
		var od: Dictionary = o
		var v := str(od.get("value", ""))
		if v != "" and v != canonical:
			return v
	return ""

# 从新 schema 的字段反推「这道题原本属于哪一类」。
#
# ★ 第二十九轮之后题目不再有 `kind`（用户口径：「不再给问题分类」，
#   每题只按自己的选项语义说话）。但下面这些断言还想按类检查，
#   所以统一在这里推一次 —— 改动集中在这一个函数里，而不是散落到几十处断言。
#   判断顺序要紧：同行者 → 说法题 → 档案题 → 剩下的一律算盲区题
#   （既不挂卡、也不挂事实、也不是同行者问的，正是盲区题的定义）。
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

# 读题面 —— 新格式叫 `text`，旧格式（内置常量）叫 `q`。
func _q_text_of(q: Dictionary) -> String:
	var t := str(q.get("text", ""))
	return t if t != "" else str(q.get("q", ""))

func _question_kinds(arr: Array) -> String:
	var parts := []
	for q in arr:
		parts.append(_q_kind(q as Dictionary))
	return ",".join(parts)

func _count_kind(arr: Array, kind: String) -> int:
	var n := 0
	for q in arr:
		if _q_kind(q as Dictionary) == kind:
			n += 1
	return n

# ------------------------------------------------------------
# 阶段二开场识破：不合格的打扮，是门开那一刻才被认出来的
#
#  用户口径：「阶段一 不判断衣服是否能通过审查 放在第二阶段
#            如果无法通过审查 审查者说出 怎么是你【人物名字】然后直接结束这局游戏」
# ------------------------------------------------------------
func _test_recognition_on_sight() -> void:
	print("\n-- 阶段二开场识破：怎么是你，<A 真身名> --")
	main._start_new_run(20261011)
	_reveal_all()
	_assign_all()

	# 故意穿回 A 的原貌：反差为 0，绝无可能骗过他
	var m: WardrobeModel = wardrobe.model
	m._equip_defaults()
	wardrobe._refresh()

	_check("阶段一不拦门（按钮仍可用）", wardrobe.continue_btn.disabled == false)
	_check("阶段一已把「不通过」记下来", gd.outfit_passed == false)
	_check("本局 A 有真身名字", RunData.true_name() != "")

	wardrobe._on_continue()
	interro.set_process(false)

	_check("进门即被识破", interro._ended == true)
	_check("没有进入任何一道题", interro.current_question_index == 0)
	_check("本轮判定为失败", interro._success == false)
	_check("结果按钮已出现", interro.result_btn.visible == true)
	_check("识破台词点出「怎么是你」", interro.dialogue_label.text.contains("怎么是你"))
	_check("识破台词念出 A 的真身名", interro.dialogue_label.text.contains(RunData.true_name()))
	_check("识破台词列出不合格的原因", interro.dialogue_label.text.contains("反差值"))
	_check("识破后选项全部禁用", interro.option_btns[0].disabled == true)
	_check("识破后不再驱动计时器", interro._running == false)
	_check("结果按钮文案指向「重来本轮」", interro.result_btn.text.contains("重来本轮"))

	interro._on_result_pressed()
	_check("识破 → 结果覆盖层出现", main.overlay.visible == true)
	_check("识破 → 按钮指向「重来本轮」", main._pending_action == "retry_level")
	_check("识破 → 覆盖层按钮文案也写着「重来本轮」",
		main.overlay_btn.text.contains("重来本轮"))

	var run_before := RunData.run_index
	var lv_before := RunData.level_index
	var bg_before := RunData.background_id
	var app_before := RunData.true_appearance().duplicate()
	main._on_overlay_pressed()
	_check("重来本轮 → 局号不变（还是同一局）", RunData.run_index == run_before)
	_check("重来本轮 → 仍停在同一关", RunData.level_index == lv_before)
	_check("重来本轮 → 背景不变", RunData.background_id == bg_before)
	_check("重来本轮 → 原貌不变", _dict_eq(RunData.true_appearance(), app_before))
	_check("重来本轮 → 准备室可见", wardrobe.visible == true)
	_check("重来本轮 → 装备退回 A 的原貌（好重新搭一遍）",
		wardrobe.model.total_contrast() == 0)

	# 换装合格时不该误判 —— 同一套判定，正反两面都要站得住
	main._start_new_run(20261011)
	_prepare_and_enter()
	interro.set_process(false)
	_check("换装合格时不会被开场识破", interro._ended == false)
	_check("换装合格时正常出第一道题", interro.current_question_index == 0)
	_check("换装合格时结果按钮不出现", interro.result_btn.visible == false)

# ------------------------------------------------------------
# 手机：短信 / 相册
# ------------------------------------------------------------
func _test_phone() -> void:
	print("\n-- 手机：短信是口径，相册是偷拍 --")
	main._start_new_run(20261011)
	var phone: PhoneDesk = intel.phone
	_check("情报台里挂着手机", phone != null)
	if phone == null:
		return

	_check("手机默认是收起的", not intel.is_phone_open())
	intel.open_phone()
	_check("点按钮 → 手机浮层打开", intel.is_phone_open())
	intel.close_phone()
	_check("收起 → 浮层关掉", not intel.is_phone_open())
	_check("按钮上不再报计数（「0/1」「🔒N」都删了）",
		not intel.phone_btn.text.contains("/") and not intel.phone_btn.text.contains("🔒"))
	# 短信是逐关解锁的 —— 第 1 轮只有 1 条到手，往后每过一关再收到一条
	_check("第 1 轮只解锁 1 条短信", DossierData.sms_count() == 1)
	_check("本局一共 2 条短信（一轮一条）", DossierData.sms_total() == 2)
	# ★ 第五十二轮：一局 2 条短信，第 1 轮拿到 1 条 → 还剩 1 条
	_check("还有 1 条没到手", DossierData.sms_locked_count() == 1)
	_check("每局都有照片", DossierData.photo_count() > 0)

	# ---- 短信：读过才学到官方说法 ----
	_check("开局一条短信都没读", gd.sms_read.is_empty())
	_check("开局还不知道任何官方口径", gd.known_facts.is_empty())

	phone._switch_app("messages")
	_check("消息页能建出来", phone.screen_box.get_child_count() > 0)

	var first: Dictionary = DossierData.sms_threads()[0]
	var tid := str(first["id"])
	phone._open_thread(tid)
	_check("打开线程 → 记为已读", gd.sms_read.has(tid))
	_check("打开线程 → 学到官方口径", gd.known_facts.size() >= 1)
	_check("线程页有气泡", phone.screen_box.get_child_count() > 0)
	# 不要在 for 里 _check —— 揭示条数由数据决定，改一条短信就会让断言总数变。
	# 聚合成一条（踩过：断言数浮动 343/344，diff 半天）。
	var all_revealed: bool = not (first["reveals"] as Array).is_empty()
	for r in first["reveals"]:
		if not gd.known_facts.has(str((r as Dictionary)["fact"])):
			all_revealed = false
	_check("这一段揭示的口径全部记进 known_facts", all_revealed)
	phone._back_to_list()
	_check("返回后回到线程列表", phone.screen_box.get_child_count() > 0)

	# ---- 相册：擦反光提升清晰度，看清了 = 白捡一处原貌 ----
	phone._switch_app("photos")
	_check("相册页能建出来", phone.screen_box.get_child_count() > 0)
	_check("每张照片都配了 SubViewport", phone._photo_subs.size() == DossierData.photo_count())
	_check("相册页有 2 列网格", _has_grid(phone.screen_box))

	var idx0 := -1
	for i in DossierData.photo_count():
		if int(DossierData.get_photo(i).get("max_wipes", 0)) >= 3:
			idx0 = i
			break
	if idx0 < 0:
		idx0 = 0

	var c_before := phone.clarity_of(idx0)
	phone._wipe(idx0)
	_check("擦一次 → 清晰度上升", phone.clarity_of(idx0) > c_before)
	_check("擦一次 → 记进 photo_wipes", int(gd.photo_wipes.get(idx0, 0)) == 1)

	# 擦到底
	for _k in int(DossierData.get_photo(idx0).get("max_wipes", 0)) + 3:
		phone._wipe(idx0)
	var maxw := int(DossierData.get_photo(idx0).get("max_wipes", 0))
	_check("擦除次数不会超过上限", int(gd.photo_wipes.get(idx0, 0)) == maxw)
	var c_final := phone.clarity_of(idx0)
	var clear_enough: bool = c_final >= ScenarioData.PHOTO_CLEAR_AT
	_check("擦到底后要么看清、要么是废片（二选一）",
		clear_enough or c_final < ScenarioData.PHOTO_CLEAR_AT)
	# ★ 「看清」还是「废片」由本局随机决定 —— 两个分支各出 3 条断言，条数恒定。
	#   分支里只取值，_check 一律放外面。
	#
	#   注意：原貌**不靠照片解锁**（那栏已经删了，18 处开局即全可见）。
	#   照片擦清楚的意义是「你在手机里认出了他记忆里的那一处」—— 是多一条线索，
	#   不是打开一扇门。
	#   ★ 第四十三轮：一张照片是一段**半身**（可能同时有好几件），而且照片里那件
	#     只是「暴露值与原貌最接近」的 —— **不一定就是原貌**。所以「已还原」只
	#     对**真拍到原貌**（`is_true`）的槽位成立。这里按这张照片实际的内容来断言。
	var p0 := DossierData.get_photo(idx0)
	var true_slots := []
	for e in p0.get("items", []):
		var d: Dictionary = e
		if bool(d.get("is_true", false)):
			true_slots.append(str(d.get("slot", "")))
	var seen_ok: bool = gd.photos_revealed.has(idx0)
	var all_visible := true
	var all_label_ok := true
	for s in true_slots:
		if not gd.revealed_slots.has(s):
			all_visible = false
		if wardrobe.slot_labels.has(s) and wardrobe.slot_labels[s].text.ends_with("?"):
			all_label_ok = false
	if clear_enough:
		_check("看清的照片 → 记为已看清", seen_ok)
		_check("看清的照片 → 真拍到原貌的那几处才算已还原（%d 处）" % true_slots.size(),
			all_visible)
		_check("看清的照片 → 那几处的槽位标签不带问号", all_label_ok)
	else:
		print("      （这张是废片：怎么擦都看不清 —— 这就是信息不全）")
		_check("废片 → 不该记为已看清", not seen_ok)
		_check("废片 → 原貌照样可见（原貌不靠照片解锁）",
			gd.revealed_slots.size() > 0)
		_check("废片 → 槽位标签不带问号（原貌开局即全可见）", all_label_ok)
	_check("★ 相册里的照片都是「一段半身」且至少一件",
		not p0.get("items", []).is_empty() and str(p0.get("half", "")) != "")
	_check("★ 擦亮后文字会列出这张照片里的每一件（%d 件）" % true_slots.size(),
		(p0.get("items", []) as Array).size() >= 1)
	# ★ 第四十四轮：照片**排除原貌** —— 非发型件不该直接给出答案。
	#   （发型是唯一例外：用户口径要求「发型与原貌保持一致」。）
	var leak := 0
	for e in p0.get("items", []):
		var d2: Dictionary = e
		var s2 := str(d2.get("slot", ""))
		if s2 != "hair" and bool(d2.get("is_true", false)):
			leak += 1
	_check("★ 照片里没有把原貌那件直接摆出来（发型除外）", leak == 0)

	# ---- 备忘录：第一条记的就是审问者 ----
	phone._switch_app("memo")
	_check("备忘录页能建出来", phone.screen_box.get_child_count() > 0)
	var mtxt := _collect_text(phone.screen_box)
	_check("备忘录第一条写的是审问者", mtxt.contains("【第一条】"))
	_check("备忘录写出审问者名字", mtxt.contains(DossierData.interrogator_name()))
	_check("备忘录写出他的性情", mtxt.contains(str(DossierData.interrogator_trait().get("name", ""))))
	_check("备忘录写出他的喜好", mtxt.contains("喜好"))
	_check("备忘录写出他的忌讳", mtxt.contains("忌讳"))
	_check("备忘录还记了本局主人公", mtxt.contains("【第二条】"))
	_check("★ 备忘录不再有「这一轮」那一条（内容整局不变）",
		not mtxt.contains("【第三条】"))
	_check("备忘录篇幅很短（就是临出门记的几行）", mtxt.length() < 900)
	_check("★ 备忘录内容不随轮次变（没有「第 N / 4 关」这类字）",
		not mtxt.contains("强制装备：") and not mtxt.contains("反差值要求"))

	# ---- 审问官的短信（★ 第五十五轮：和另外两组完全同构）----
	#   原来是「掏手机越界收到的事件短信」，现在是**每套背景写死的普通线程**，
	#   按轮解锁、一条一条读，没有红框那一行。
	phone._switch_app("messages")
	var ith := DossierData.interrogator_sms_threads()
	_check("消息列表里有审问官的短信（本轮解锁的那条）", ith.size() > 0)
	var ltxt := _collect_text(phone.screen_box)
	_check("列表里显示他的联系人名（= 本局审讯官）",
		ltxt.contains(str((ith[0] as Dictionary).get("contact", ""))))
	var known_before: int = GameData.known_facts.size()
	phone._open_thread(str((ith[0] as Dictionary)["id"]))
	_check("能打开审问官那条对话", phone.screen_box.get_child_count() > 0)
	var itxt := _collect_text(phone.screen_box)
	var first_line := str((((ith[0] as Dictionary).get("messages", []) as Array)[0] as Dictionary).get("text", ""))
	_check("对话页显示他发来的正文", itxt.contains(first_line.substr(0, 6)))
	_check("★ 他的短信没有 reveals（他不给口径）",
		((ith[0] as Dictionary).get("reveals", []) as Array).is_empty())
	_check("★ 读他的短信不会多学到官方口径", GameData.known_facts.size() == known_before)
	phone._back_to_list()

	# ---- 备注：按轮次累积的问答记录 ----
	#  第一轮：整页空着（连说明文字都没有）
	#  第二轮起：把前面几轮问过什么、你怎么答的摊出来
	gd.answer_log = []
	RunData.level_index = 0
	gd.level_index = 0
	phone._switch_app("notes")
	_check("★ 第一轮：备注页没有任何内容", phone.screen_box.get_child_count() == 0)

	# 造两条「上一轮」的记录
	gd.answer_log = [
		{"level": 0, "q": "你说你从寒霜港来 —— 具体在城里哪一片？", "answer": "A. 寒霜港东侧旧城区"},
		{"level": 0, "q": "你这一车货，都运的什么？", "answer": "B. 布匹和铁器"},
	]
	RunData.level_index = 1
	gd.level_index = 1
	phone.rebuild()
	_check("★ 第二轮：备注页出现内容", phone.screen_box.get_child_count() > 0)
	var ntxt := _collect_text(phone.screen_box)
	_check("★ 备注写明是第 1 轮", ntxt.contains("第 1 轮"))
	_check("★ 备注记下了上一轮的问话", ntxt.contains("从寒霜港来"))
	_check("★ 备注记下了你当时的回答", ntxt.contains("布匹和铁器"))
	_check("备注按轮次分组（问 / 答各有前缀）",
		ntxt.contains("他问：") and ntxt.contains("我答："))
	_check("备注页不再出现旧版的「官方口径对照表」",
		not ntxt.contains("官方口径"))

	# 第三轮：前两轮的记录都要在；当前这一轮的**还没归档**，不显示
	gd.answer_log.append({"level": 1, "q": "（他忽然换了个问法）你老家，是在水边还是山里？", "answer": "C. 北境靠冻原的边地"})
	gd.answer_log.append({"level": 2, "q": "（他盯着你的手）这双手，做过粗活吗？", "answer": "A. 家里早年开过磨坊"})
	RunData.level_index = 2
	gd.level_index = 2
	phone.rebuild()
	var ttxt := _collect_text(phone.screen_box)
	_check("★ 第三轮：第 1 轮与第 2 轮的记录都在",
		ttxt.contains("第 1 轮") and ttxt.contains("第 2 轮"))
	_check("★ 第三轮：当前这一轮（第 3 轮）的问话还没归档（不显示）",
		not ttxt.contains("做过粗活"))
	gd.answer_log = []
	RunData.level_index = 0
	gd.level_index = 0

# ------------------------------------------------------------
# 审问者的情报：每局随机一种性情，决定 B 类题「撒谎 / 回避」的代价
# ------------------------------------------------------------
func _test_interrogator_intel() -> void:
	print("\n-- 审问者的情报：B 类题该不该撒谎，看他是什么人 --")
	main._start_new_run(20261011)

	# 情报台删掉之后，审问者的性情只活在手机备忘录第一条里 ——
	# 这里不再有页签可查，下面改为直接翻手机。
	_check("审问者的性情收进了手机（情报台已删）", intel.phone != null)

	var tid := RunData.interrogator_trait_id
	_check("每局都抽到一种性情", tid != "")
	var tr := DossierData.interrogator_trait()
	_check("抽到的性情合法", not tr.is_empty())
	_check("性情有名字", str(tr.get("name", "")) != "")
	_check("性情有对策文案", str(tr.get("hint", "")).length() > 6)
	_check("性情给出了撒谎与回避两档代价",
		tr.has("bluff_delta") and tr.has("evade_delta"))

	# 固定种子 → 性情可复现（否则截图与测试都不稳定）
	var keep := RunData.interrogator_trait_id
	main._start_new_run(20261011)
	_check("固定种子 → 性情可复现", RunData.interrogator_trait_id == keep)
	main._start_new_run(20261011)

	# 性情表本身要立得住：字段齐全，且真的有「撒谎安全」和「撒谎重罚」两种极端
	var all := ScenarioData.interrogator_traits()
	_check("性情表 ≥ 5 种", all.size() >= 5)
	var bad := 0
	var bad_memo := 0
	# ★ 第十三轮：怀疑度轮内只涨不跌 —— 所有选项都是**正**代价，
	#   差别只在「涨多少」。所以这里守的是「没有负数」+「存在高低差」。
	var has_negative := false
	var has_high_bluff := false
	var has_high_evade := false
	var has_cheap_bluff := false
	var has_cheap_evade := false
	for t in all:
		var td: Dictionary = t
		if str(td.get("id", "")) == "" or str(td.get("name", "")) == "" \
			or str(td.get("desc", "")) == "" or str(td.get("hint", "")) == "":
			bad += 1
		if not td.has("bluff_delta") or not td.has("evade_delta"):
			bad += 1
		if str(td.get("dangerous", "")) not in ["", "bluff", "evade"]:
			bad += 1
		# 备忘录那三条（性格 / 喜好 / 忌讳）—— 手机里第一条记的就是它们
		if str(td.get("memo", "")).length() < 10 \
			or str(td.get("like", "")).length() < 2 \
			or str(td.get("hate", "")).length() < 2:
			bad_memo += 1
		if float(td.get("bluff_delta", 0.0)) < 0.0 or float(td.get("evade_delta", 0.0)) < 0.0:
			has_negative = true
		if float(td.get("bluff_delta", 0.0)) >= 28.0:
			has_high_bluff = true
		if float(td.get("evade_delta", 0.0)) >= 28.0:
			has_high_evade = true
		if float(td.get("bluff_delta", 0.0)) <= 10.0:
			has_cheap_bluff = true
		if float(td.get("evade_delta", 0.0)) <= 10.0:
			has_cheap_evade = true
	_check("性情表字段齐全（id/name/desc/hint/delta/dangerous）", bad == 0)
	_check("每种性情都带备忘录三条（memo / like / hate）", bad_memo == 0)
	_check("★ 没有任何负增量（轮内只涨不跌）", not has_negative)
	_check("存在「撒谎重罚」的性情（多疑/精明）", has_high_bluff)
	_check("存在「回避重罚」的性情（急躁）", has_high_evade)
	_check("存在「撒谎最便宜」的性情（迟钝）", has_cheap_bluff)
	_check("存在「回避最便宜」的性情（心软）", has_cheap_evade)

	# ---- 审问者的一切都在手机备忘录第一条里 ----
	# 情报台删掉之后，这一条就是「他是谁 + 什么性情 + 该怎么答」的唯一出处，
	# 也是盲区题正解的来源（见 _test_blind_question）。
	_check("开局没读过审问者情报", gd.interrogator_intel_read == false)

	var phone: PhoneDesk = intel.phone
	phone._switch_app("memo")
	var ttxt := _collect_text(phone.screen_box)
	_check("备忘录第一条写出审讯官是谁", ttxt.contains(DossierData.interrogator_name()))
	_check("备忘录第一条写出性情名", ttxt.contains(str(tr.get("name", ""))))
	_check("备忘录第一条写出该性情的忌讳", ttxt.contains(DossierData.interrogator_hate()))
	_check("备忘录第一条写出「该怎么答」", ttxt.contains("该怎么答"))

	# ---- 翻开备忘录 = 记下了他的脾性（情报台删掉之后的唯一入口）----
	_check("翻开备忘录 → 记为已读", gd.interrogator_intel_read == true)
	gd.interrogator_intel_read = false
	phone._switch_app("messages")
	_check("翻别的 App 不算读过", gd.interrogator_intel_read == false)

	# ---- 盘问：B 类题的撒谎 / 回避代价跟着性情走 ----
	_prepare_and_enter()
	interro.set_process(false)
	var b_idx := _find_question_index("B")
	if b_idx < 0:
		b_idx = _goto_level_with_card_owner("B")
	_check("本局存在含 B 类档案题的轮次（前置）", b_idx >= 0)
	if b_idx < 0:
		return

	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	# ⚠ 标记要同时满足两件事：**翻过手机备忘录** 且 这一项对当前性情危险。
	# 下面这一段单独验「跟着性情走」，所以先把「翻过备忘录」这个前提摆好；
	# 「没翻过 → 不亮 ⚠」紧接在后面单独验。
	gd.interrogator_intel_read = true
	interro._load_question(b_idx)

	var bluff_opt: Dictionary = interro.current_options[1]
	var evade_opt: Dictionary = interro.current_options[2]
	_check("档案题第 2 项是撒谎", str(bluff_opt.get("kind", "")) == "bluff")
	_check("档案题第 3 项是回避", str(evade_opt.get("kind", "")) == "evade")
	_check("撒谎的代价 = 该性情的 bluff_delta",
		is_equal_approx(float(bluff_opt.get("delta", 0.0)),
			ScenarioData.trait_delta(tr, "bluff")))
	_check("回避的代价 = 该性情的 evade_delta",
		is_equal_approx(float(evade_opt.get("delta", 0.0)),
			ScenarioData.trait_delta(tr, "evade")))

	var bluff_danger := ScenarioData.trait_is_dangerous(tr, "bluff")
	_check("撒谎项的危险标记与性情一致",
		bool(bluff_opt.get("danger", false)) == bluff_danger)
	_check("回避项的危险标记与性情一致",
		bool(evade_opt.get("danger", false)) == ScenarioData.trait_is_dangerous(tr, "evade"))
	# 这局的性情是什么由随机决定 —— 两个分支各 1 条，条数恒定
	var bluff_has_warn: bool = str(bluff_opt.get("text", "")).contains("⚠")
	if bluff_danger:
		_check("危险选项上亮出 ⚠", bluff_has_warn)
	else:
		_check("非危险选项不该亮 ⚠", not bluff_has_warn)

	# 没读过情报 → 不该亮 ⚠（情报读了才有用）
	gd.interrogator_intel_read = false
	interro._load_question(b_idx)
	_check("没读过情报 → 选项不带 ⚠",
		not str((interro.current_options[1] as Dictionary).get("text", "")).contains("⚠"))
	gd.interrogator_intel_read = true
	interro._load_question(b_idx)

	# 强制换成「多疑 / 迟钝」再验一次 —— 上面的种子未必抽到危险性情，
	# 而「多疑不能撒谎、迟钝可以撒谎」正是这条需求的题眼，必须确定性覆盖。
	var keep_tid := RunData.interrogator_trait_id
	RunData.interrogator_trait_id = "suspicious"
	var sus := DossierData.interrogator_trait()
	_check("多疑的性情能取回", str(sus.get("name", "")) == "多疑")
	_check("多疑把撒谎标成危险项", ScenarioData.trait_is_dangerous(sus, "bluff"))
	interro._load_question(b_idx)
	_check("多疑 + 读过情报 → 撒谎项亮 ⚠",
		str((interro.current_options[1] as Dictionary).get("text", "")).contains("⚠"))
	_check("多疑 → 撒谎代价 = 45（全场最重）",
		is_equal_approx(float((interro.current_options[1] as Dictionary).get("delta", 0.0)), 45.0))
	_check("多疑 → 撒谎项被标 danger",
		bool((interro.current_options[1] as Dictionary).get("danger", false)))
	_check("多疑 → 回避项没被标 danger",
		not bool((interro.current_options[2] as Dictionary).get("danger", false)))

	RunData.interrogator_trait_id = "dull"
	var dull := DossierData.interrogator_trait()
	_check("迟钝的性情能取回", str(dull.get("name", "")) == "迟钝")
	_check("★ 迟钝的 bluff_delta 是全场最低（撒谎最便宜，但仍是正的代价）",
		ScenarioData.trait_delta(dull, "bluff") > 0.0
		and ScenarioData.trait_delta(dull, "bluff") <= 10.0)
	interro._load_question(b_idx)
	_check("迟钝 → 撒谎项不亮 ⚠",
		not str((interro.current_options[1] as Dictionary).get("text", "")).contains("⚠"))
	_check("迟钝 → 撒谎代价低（6），但仍然是**涨**不是降",
		is_equal_approx(float((interro.current_options[1] as Dictionary).get("delta", 0.0)), 6.0))
	RunData.interrogator_trait_id = keep_tid
	interro._load_question(b_idx)      # 选项上的 ⚠ 跟着当前性情刷新

	# ---- 顶栏那行「对审问者的说明」已经删掉 ----
	#  性情从此只活在手机备忘录第一条里（上面已验）。这里守两件事：
	#  ① 界面上再没有那个刷新方法；② 选项上的 ⚠ 仍跟着性情走。
	_check("盘问界面不再有「审问者的说明」那一行",
		not interro.has_method("_refresh_interrogator_intel"))
	_check("恢复原性情后，选项的 ⚠ 标记跟着刷新",
		str((interro.current_options[1] as Dictionary).get("text", "")).contains("⚠")
			== ScenarioData.trait_is_dangerous(tr, "bluff"))

	# 反馈文案要跟着性情走（同一道题，换个人问，后果不同）
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro._load_question(b_idx)
	interro._select_option(1)          # 撒谎
	_check("撒谎的反馈文案来自该性情的 bluff_note",
		interro.feedback_label.text == str(tr.get("bluff_note", "")))

	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro._load_question(b_idx)
	interro._select_option(2)          # 回避
	_check("回避的反馈文案来自该性情的 evade_note",
		interro.feedback_label.text == str(tr.get("evade_note", "")))

	gd.interrogator_intel_read = false

# ------------------------------------------------------------
#  盲区题：完全没给信息的题 —— 靠备忘录第一条推断怎么答
#
#  用户口径：「『完全没给信息的题』还是备忘录给的审问者信息推断出怎么答」
#
#  所以这题**没有内容上的正确答案**：档案里没有、短信里也没提。
#  唯一的安全解是「按他的脾性选」—— 撒谎还是回避，看备忘录第一条。
#  这里把五种性情逐一验一遍，确认「正解」确实由性情决定，
#  而且选完无论对错，反馈里都会把备忘录第一条摆出来。
# ------------------------------------------------------------
func _test_blind_question() -> void:
	print("\n-- 盲区题：没给信息时，靠备忘录第一条推断怎么答 --")
	main._start_new_run(20261011)
	_prepare_and_enter()
	interro.set_process(false)

	var bi := _find_kind_index("blind")
	_check("本轮抽到了盲区题", bi >= 0)
	if bi < 0:
		return
	var q: Dictionary = interro.level_questions()[bi]
	_check("盲区题不指向任何档案卡", str(q.get("card", "")) == "")
	_check("盲区题不指向任何事实", str(q.get("fact", "")) == "")
	_check("盲区题带一句「为什么你没底」的说明", str(q.get("setup", "")).length() > 6)

	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro._load_question(bi)

	_check("盲区题摆出三个选项（题面给了「硬答」）", interro.current_options.size() == 3)
	_check("选项 A 是硬答",
		str((interro.current_options[0] as Dictionary).get("kind", "")) == "made_up")
	_check("选项 B 是撒谎",
		str((interro.current_options[1] as Dictionary).get("kind", "")) == "bluff")
	_check("选项 C 是回避",
		str((interro.current_options[2] as Dictionary).get("kind", "")) == "evade")
	_check("硬答恒定重罚（与性情无关）",
		is_equal_approx(float((interro.current_options[0] as Dictionary).get("delta", 0.0)),
			Interrogation.BLIND_MADE_UP_DELTA))
	_check("三个选项都带 blind 标记（走的是盲区题判定）",
		bool((interro.current_options[0] as Dictionary).get("blind", false))
		and bool((interro.current_options[1] as Dictionary).get("blind", false))
		and bool((interro.current_options[2] as Dictionary).get("blind", false)))
	_check("题目标签已删：界面上不再有那一行提示",
		not interro.has_method("_apply_question_tag"))
	_check("题面自带一句「为什么你没底」的说明（setup 直接摆在题干里）",
		str(q.get("setup", "")).length() > 6)

	# ---- 五种性情逐一验：正解必须由性情决定 ----
	# 条数恒定：循环里不 _check，先把结果攒起来再统一断（铁律）
	var keep_tid := RunData.interrogator_trait_id
	var wrong_delta := 0
	var wrong_right := 0
	var wrong_wrong := 0
	var missing_memo := 0
	for t in ScenarioData.interrogator_traits():
		var td: Dictionary = t
		RunData.interrogator_trait_id = str(td.get("id", ""))
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
		interro.qte_container.hide()
		interro._load_question(bi)

		var bluff_d := float((interro.current_options[1] as Dictionary).get("delta", 0.0))
		var evade_d := float((interro.current_options[2] as Dictionary).get("delta", 0.0))
		if not is_equal_approx(bluff_d, ScenarioData.trait_delta(td, "bluff")):
			wrong_delta += 1
		if not is_equal_approx(evade_d, ScenarioData.trait_delta(td, "evade")):
			wrong_delta += 1

		# 正解 = 代价更低的那一个；而"哪个更低"只有备忘录里写着
		var right := 1 if bluff_d < evade_d else 2
		gd.suspicion_level = 20.0     # 每轮归零，免得连选十次直接扣到 100 结束盘问
		interro._select_option(right)
		if not interro.feedback_label.text.contains("选对了"):
			wrong_right += 1
		if not interro.feedback_label.text.contains("备忘录第一条"):
			missing_memo += 1

		# 再验选错的那一个
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
		interro.qte_container.hide()
		interro._load_question(bi)
		gd.suspicion_level = 20.0
		interro._select_option(3 - right)
		if not interro.feedback_label.text.contains("选错了"):
			wrong_wrong += 1
		if not interro.feedback_label.text.contains("备忘录第一条"):
			missing_memo += 1

	_check("撒谎 / 回避的代价都来自该性情的 bluff_delta / evade_delta", wrong_delta == 0)
	_check("选对时反馈明说「选对了」", wrong_right == 0)
	_check("选错时反馈明说「选错了」", wrong_wrong == 0)
	_check("无论对错，反馈都把备忘录第一条摆出来", missing_memo == 0)
	RunData.interrogator_trait_id = keep_tid
	interro._load_question(bi)

	# ---- 硬答：无论什么性情都是重罚 ----
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro._load_question(bi)
	var before: float = gd.suspicion_level
	interro._select_option(0)
	_check("硬答恒定扣分",
		is_equal_approx(gd.suspicion_level - before, Interrogation.BLIND_MADE_UP_DELTA))
	_check("硬答的反馈点明「编得越细越糟」",
		interro.feedback_label.text.contains("编"))

	# ---- 备忘录第一条真的写着「该怎么答」----
	# 这就是盲区题的正解来源：没有它，玩家只能三选一瞎猜。
	var phone: PhoneDesk = intel.phone
	phone._switch_app("memo")
	var mtxt := _collect_text(phone.screen_box)
	_check("备忘录第一条写出「该怎么答」", mtxt.contains("该怎么答"))
	_check("备忘录第一条写出该性情的对策",
		mtxt.contains(DossierData.interrogator_hint()))
	_check("备忘录第一条写出该性情的忌讳",
		mtxt.contains(DossierData.interrogator_hate()))

	# ---- 收尾：把盘问恢复成「干净可用」的状态 ----
	# 上面的「硬答」会启动表情 QTE，而本函数开头 set_process(false)，
	# QTE 永远不会自己超时 —— is_qte_active 会一直挂着，
	# 把后面 _test_leak_and_fail_restart() 里的 _select_option 全部挡掉。
	interro.is_qte_active = false
	interro.qte_timer = 0.0
	interro.qte_container.hide()
	interro.interference_active = false
	interro.intf_container.hide()
	interro._ended = false
	interro._running = true

# 收集一棵子树里的全部文本（用于断言 UI 内容）
func _collect_text(root: Node) -> String:
	var s := ""
	for c in root.get_children():
		if c is Label:
			s += (c as Label).text + "\n"
		elif c is RichTextLabel:
			s += (c as RichTextLabel).text + "\n"
		s += _collect_text(c)
	return s

func _has_grid(root: Node) -> bool:
	for c in root.get_children():
		if c is GridContainer:
			return true
		if _has_grid(c):
			return true
	return false

# ------------------------------------------------------------
# 盘问中「掏出手机」：掏第 4 次起，他会发消息过来
#
#  用户口径：「增加回答界面可以掏出手机的功能 回答完毕自动收回
#            掏出次数超过三次触发 收到审问者的短信的事件 提升审问者的怀疑」
#
#  ★ 第五十轮改口径（用户）：「手机拿出一次后，再次拿出增加怀疑值」
#                          + 「免罚后的收到短信功能取消」
#    · 免罚 3 次 → **1 次**；单价 15 → **8**（第 n 次越界 = 8 × n）；
#    · 越界**不再写入短信**，只震屏 + 涨怀疑度 + 弹通知条与反馈文案。
#      （`story.json` 里那 5 条 `interrogator_sms` 文案留着，手机消息界面
#        照旧能渲染这条线程，只是游戏不再往里喂内容。）
#
#  ★ 这一段的断言条数刻意保持与第五十轮之前一致（26 条）——
#    旧的两条「收到短信」换成了「没有收到短信」，另加了精确数值校验。
# ------------------------------------------------------------
func _test_phone_in_interrogation() -> void:
	print("\n-- 盘问中掏手机：掏太多次他会发现 --")
	_run_a_clean_level()

	_check("盘问界面有「掏出手机」按钮", interro.phone_btn != null)
	_check("手机覆盖层初始隐藏", interro.phone_layer.visible == false)
	_check("开局掏出次数为 0", interro.phone_pulls == 0)
	var intr0: int = DossierData.interrogator_sms_threads().size()
	_check("开局就有他本轮那条短信（第五十五轮起是普通线程，不再由掏手机触发）", intr0 > 0)
	_check("覆盖层不挡鼠标（左边选项照样能点）",
		interro.phone_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	# ---- 第 1 次：掏出 → 看两眼 → 顺手答题 → 自动收回（这一次免罚）----
	var b_idx := _find_question_index("B")
	if b_idx < 0:
		b_idx = _goto_level_with_card_owner("B")
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
	_check("本局存在 B 类档案题（掏手机前置）", b_idx >= 0)
	if b_idx < 0:
		return

	var s1_before: float = gd.suspicion_level
	interro._load_question(b_idx)
	interro._open_phone()
	_check("掏一次 → 覆盖层出现", interro.phone_layer.visible == true)
	_check("掏一次 → 计数为 1", interro.phone_pulls == 1)
	_check("掏一次 → 按钮变成「收起手机」", interro.phone_btn.text.contains("收起"))
	_check("手机里的内容建出来了", interro.phone_panel.screen_box.get_child_count() > 0)
	_check("★ 第 1 次免罚 → 他没管，也不弹通知条", interro.phone_notice.visible == false)
	_check("★ 第 1 次免罚 → 怀疑度一点没涨",
		is_equal_approx(gd.suspicion_level, s1_before))

	interro._select_option(0)          # B 类题照答 = 安全
	_check("回答完毕 → 手机自动收回", interro.phone_layer.visible == false)
	_check("回答完毕 → 按钮变回「掏出手机」", interro.phone_btn.text.contains("掏出"))

	# ---- 第 2 次：免罚已经用完 —— 他看见了 ----
	interro._ended = false
	interro._running = true
	interro.is_qte_active = false
	interro.qte_container.hide()
	interro._load_question(b_idx)
	var s2_before: float = gd.suspicion_level
	interro._open_phone()
	_check("★ 掏到第 2 次 → 他看见了（弹通知条）", interro.phone_notice.visible == true)
	_check("掏太多次 → 抬高怀疑度", gd.suspicion_level > s2_before)
	var d2: float = gd.suspicion_level - s2_before
	_check("★ 第 1 次越界恰好罚 %d" % int(Interrogation.PHONE_PULL_PENALTY),
		is_equal_approx(d2, Interrogation.PHONE_PULL_PENALTY))
	_check("★ 越界掏手机不会新增他的短信（第五十五轮起完全没有这条触发）",
		DossierData.interrogator_sms_threads().size() == intr0)
	# phone_caught 是用户可清空的文案，不再作为断言依据；结算本身看上面的怀疑度 / 通知条。
	_check("★ 通知条里写明了本次涨了多少怀疑度",
		interro.phone_notice.text.contains(str(int(round(d2)))))

	# ---- 第 3 次：罚得更重（8 × n，n = 2）----
	var s3_before: float = gd.suspicion_level
	interro._close_phone()
	interro._open_phone()
	var d3: float = gd.suspicion_level - s3_before
	_check("越掏罚得越重", d3 > d2)
	_check("★ 第 2 次越界恰好罚 %d" % int(Interrogation.PHONE_PULL_PENALTY * 2.0),
		is_equal_approx(d3, Interrogation.PHONE_PULL_PENALTY * 2.0))
	_check("★ 罚完了也还是不会新增短信", DossierData.interrogator_sms_threads().size() == intr0)
	interro._close_phone()

	# ---- 换关：次数重新数，通知条收起来 ----
	interro.start_interrogation()
	interro.set_process(false)
	_check("换关后掏出次数归零", interro.phone_pulls == 0)
	_check("换关后手机覆盖层收起", interro.phone_layer.visible == false)
	_check("换关后通知条也收起来", interro.phone_notice.visible == false)

# ------------------------------------------------------------
# 同行者干扰
# ------------------------------------------------------------
func _test_interference() -> void:
	# ★ 第三十三轮（用户口径）：「暴露值现在**只会**影响表情 QTE」——
	#   递话干扰的间隔不再跟着暴露值变密，改成固定值。
	print("\n-- 同行者干扰：固定间隔（第 33 轮起不再随暴露值变密）--")
	_check("干扰台词库非空", DossierData.interference_lines().size() >= 4)

	gd.outfit_exposure = 0
	_check("暴露值 0 时间隔 = 14.0 秒", is_equal_approx(interro.interference_interval(), 14.0))
	gd.outfit_exposure = 20
	_check("★ 暴露值 20 时间隔**不变**（暴露值只管表情 QTE）",
		is_equal_approx(interro.interference_interval(), 14.0))
	gd.outfit_exposure = 45
	_check("★ 暴露值 45 时间隔也不变", is_equal_approx(interro.interference_interval(), 14.0))
	gd.outfit_exposure = 20
	_check("反应窗口加长到 2.6 秒", is_equal_approx(Interrogation.INTERFERENCE_WINDOW, 2.6))

	interro._load_question(0)
	var susp_before: float = gd.suspicion_level
	var count_before: int = interro.interference_count

	# 同行者交替出手：奇数 = 递话 QTE，偶数 = 反问。这里先把计数归零，锁定「递话」分支。
	interro.interference_count = 0
	interro._start_interference()
	_check("干扰已激活", interro.interference_active == true)
	_check("干扰计数 +1", interro.interference_count == count_before + 1)
	_check("干扰期间选项被锁死", interro.option_btns[0].disabled == true)
	_check("干扰条显示同行者递的那句话", interro.intf_label.text.length() > 10)

	interro._end_interference(true)
	_check("打断成功后干扰结束", interro.interference_active == false)
	_check("打断成功计入统计", interro.interference_blocked == 1)
	_check("打断成功不再降怀疑度（轮内只涨不跌）",
		is_equal_approx(gd.suspicion_level, susp_before))
	_check("打断后选项恢复可用", interro.option_btns[0].disabled == false)

	var susp2: float = gd.suspicion_level
	interro.interference_count = 0
	interro._start_interference()
	interro._end_interference(false)
	_check("打断失败抬高怀疑度", gd.suspicion_level > susp2)

	var susp3: float = gd.suspicion_level
	interro.interference_count = 0
	interro._start_interference()
	interro._process_interference(Interrogation.INTERFERENCE_WINDOW + 0.1)
	_check("干扰窗口超时自动判负", interro.interference_active == false)
	_check("超时判负同样抬高怀疑度", gd.suspicion_level > susp3)

	# ------------------------------------------------------------
	#  组合干扰：每 3 次里出 1 次，要依次敲 J → K → L
	#  （下面连着扣好几笔怀疑度，先把起点压低，免得半路撞到 100 结束盘问）
	# ------------------------------------------------------------
	gd.suspicion_level = 20.0
	_check("组合干扰的键位是 J / K / L",
		Interrogation.COMBO_LEN == 3
		and int(Interrogation.COMBO_KEYS[0]) == KEY_J
		and int(Interrogation.COMBO_KEYS[2]) == KEY_L)

	# 第 1、2 次仍是单键（按空格）
	interro.interference_count = 0
	interro._start_interference()
	_check("第 1 次干扰是单键干扰", interro.interference_kind == "single")
	interro._end_interference(true)

	interro.interference_count = 1
	interro._start_interference()
	_check("第 2 次干扰仍是单键干扰", interro.interference_kind == "single")
	interro._end_interference(true)

	# 第 3 次：组合
	interro.interference_count = 2
	interro._start_interference()
	_check("第 3 次干扰是组合干扰", interro.interference_kind == "combo")
	_check("组合干扰提示写明「依次敲」", interro.intf_label.text.contains("依次敲"))
	_check("组合干扰起手进度为 0", interro.combo_index == 0)

	interro.press_combo_key(KEY_J)
	_check("敲对第 1 个键 → 进度 1、干扰未结束",
		interro.combo_index == 1 and interro.interference_active == true)
	interro.press_combo_key(KEY_K)
	_check("敲对第 2 个键 → 进度 2、干扰未结束",
		interro.combo_index == 2 and interro.interference_active == true)
	var blocked_before: int = interro.interference_blocked
	interro.press_combo_key(KEY_L)
	_check("敲完第 3 个键 → 组合干扰被打断", interro.interference_active == false)
	_check("组合干扰打断同样计入统计", interro.interference_blocked == blocked_before + 1)

	# 敲错：当场判负
	interro.interference_count = 2
	interro._start_interference()
	var susp4: float = gd.suspicion_level
	interro.press_combo_key(KEY_L)          # 第一个键就敲错
	_check("组合干扰敲错 → 当场判负", interro.interference_active == false)
	_check("组合干扰敲错抬高怀疑度", gd.suspicion_level > susp4)

	# 组合干扰也会超时
	interro.interference_count = 2
	interro._start_interference()
	var susp5: float = gd.suspicion_level
	interro._process_interference(Interrogation.INTERFERENCE_WINDOW + 0.1)
	_check("组合干扰窗口超时同样判负", interro.interference_active == false)
	_check("组合干扰超时同样抬高怀疑度", gd.suspicion_level > susp5)

	# 收尾：把干扰状态清干净，别影响后面的用例
	interro.interference_count = 0
	interro.interference_active = false
	interro.interference_kind = "single"
	interro.combo_index = 0
	interro.intf_container.hide()
	interro._set_options_enabled(true)
	gd.outfit_exposure = 20

# ------------------------------------------------------------
# 表情 QTE（第十三轮重做：延迟起手 / 单阶段 / 不挡操作）
# ------------------------------------------------------------
func _test_expression_qte() -> void:
	print("\n-- 表情 QTE：切题后延迟几秒才出现，答完即结束 --")
	gd.suspicion_level = 40.0
	gd.suspicion_carry = 0.0
	interro.start_interrogation()
	interro.set_process(false)
	_check("重开后怀疑度 = 基准 20", is_equal_approx(gd.suspicion_level, 20.0))
	_check("重开后计时器重新驱动", interro._running == true)
	_check("重开后结果按钮隐藏", interro.result_btn.visible == false)

	# ★ 第 1 题固定不出 QTE —— 要验 QTE 必须从第 2 题起找
	var a_idx := _find_question_index("A", 1)
	if a_idx < 0:
		a_idx = _goto_level_with_card_owner("A")
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
	_check("本局存在含 A 类档案题的轮次（QTE 前置）", a_idx >= 0)
	_check("这道 A 类题不在第 1 题上（第 1 题固定不出 QTE）", a_idx >= 1)
	if a_idx <= 0:
		return

	# ---- 第 1 题：不排 QTE ----
	interro._load_question(0)
	_check("第 1 题不排 QTE", interro.qte_needed == false)

	# ---- 第 2 题（A 类）：排上，但**不立刻弹** ----
	# 手工步进前先把状态摆正：计时器要驱动、不能残留干扰
	interro._ended = false
	interro._running = true
	interro.interference_active = false
	interro.interference_timer = 999.0
	# ★ 第三十三轮：表情 QTE 只由暴露值触发 —— 顶到必出点，任何题都会排上
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_FULL
	interro._load_question(a_idx)
	_check("暴露值到必出点时排上了 QTE", interro.qte_needed == true)
	_check("延迟还没走完时不弹面板", interro.is_qte_active == false)
	_check("延迟倒计时 = EXPR_QTE_DELAY",
		is_equal_approx(interro.qte_delay_left, Interrogation.EXPR_QTE_DELAY))

	# 手动把延迟推完 → 面板出现，进度从中间值起手
	interro._process(Interrogation.EXPR_QTE_DELAY + 0.1)
	_check("延迟走完后 QTE 弹出", interro.is_qte_active == true)
	_check("QTE 从中间值起手", is_equal_approx(interro.qte_progress, 50.0))
	_check("QTE 面板可见", interro.qte_container.visible == true)
	_check("★ 表情 QTE 通过线是 80%", is_equal_approx(Interrogation.EXPR_QTE_PASS, 80.0))
	var qte_events: Array = InputMap.action_get_events(Interrogation.QTE_ACTION)
	_check("★ 表情 QTE 只映射空格（没有鼠标 / 回车）",
		qte_events.size() == 1 and qte_events[0] is InputEventKey
		and (qte_events[0] as InputEventKey).physical_keycode == KEY_SPACE)
	_check("★ 表情 QTE 同时出现换装下腹部小图", interro.body_layer.visible == true)
	_check("下腹部小图有截图纹理", interro.body_tex.texture != null)
	_check("★ 下腹部缩略图塞在 QTE 条里（64×64）",
		interro.qte_strip.is_ancestor_of(interro.body_layer)
		and interro.body_layer.custom_minimum_size == Vector2(64, 64))

	# ★ 第六十七轮：QTE 未到 80% 之前，选项和手机都锁着。
	_check("★ QTE 未到 80% 时选项锁着", interro.option_btns[0].disabled == true)
	var q_before: int = interro.current_question_index
	interro._select_option(0)
	_check("★ 未到 80% 时点选项无效",
		interro.current_question_index == q_before and interro.is_qte_active == true)
	_check("★ QTE 期间「掏出手机」按钮变灰", interro.phone_btn.disabled == true)
	var pulls_keep: int = interro.phone_pulls
	# ★ 走**按钮真正调用的那条路**（_toggle_phone），不是直接调 _open_phone()
	interro._toggle_phone()
	_check("★ QTE 期间点「掏出手机」掏不出来", interro.phone_layer.visible == false)
	_check("★ QTE 期间也没算一次「掏手机」", interro.phone_pulls == pulls_keep)

	# 按住空格顶过 80% → 选项解锁（不用等 QTE 整段结束）
	Input.action_press("qte_space")
	for i in 12:
		interro._process_expression_qte(0.05)
	Input.action_release("qte_space")
	_check("★ 长按空格把进度顶过 80%",
		interro.qte_progress >= Interrogation.EXPR_QTE_PASS)
	_check("★ 顶过 80% 后选项解锁", interro.option_btns[0].disabled == false)
	# 松手回落到线下，仍然算「已经通过」—— 这是「顶过 80% 即通过」的口径
	for i in 12:
		interro._process_expression_qte(0.05)
	_check("★ 顶过 80% 后回落，仍记为通过", interro._qte_passed == true)

	# 压完表情（QTE 收掉）→ 手机要重新解锁
	interro._cancel_qte()
	_check("★ QTE 收掉后手机解锁", interro.phone_btn.disabled == false)
	_check("★ QTE 收掉 → 下腹部小图一起消失", interro.body_layer.visible == false)
	interro._toggle_phone()
	_check("★ QTE 收掉后能正常掏出手机", interro.phone_layer.visible == true)
	interro._close_phone()
	interro.phone_pulls = pulls_keep

	# 后面的用例还要接着用「QTE 正在进行」这个状态，把它摆回来
	interro._start_expression_qte()
	_check("★ 重新排上 QTE 后手机又锁上", interro.phone_btn.disabled == true)
	_check("★ 重排 QTE 后选项又锁上", interro.option_btns[0].disabled == true)
	_check("★ 重排 QTE → 下腹部小图一起出现", interro.body_layer.visible == true)
	_check("★ 重排时手机被自动收回", interro.phone_layer.visible == false)
	# ★ 两条提示条共用屏幕最下方那一层 —— 压表情期间不许再排递话（否则会叠）
	interro.interference_active = false
	interro._start_interference()
	_check("★ QTE 进行中不排递话（两条提示条不会叠在一起）",
		interro.interference_active == false)
	var opt_before: int = interro.current_question_index

	# 按住空格 → 进度顶上去；松手 → 掉下来
	Input.action_press("qte_space")
	for i in 40:
		interro._process_expression_qte(0.05)
	Input.action_release("qte_space")
	_check("长按空格能把进度顶到通过线", interro.qte_progress >= Interrogation.EXPR_QTE_PASS)
	_check("顶过 80% 后选项解锁（可以答题）", interro.option_btns[1].disabled == false)

	# ★ 答完题 → 本题的 QTE 立刻结算（单阶段，不续下一轮）
	#   答的这一步本身要付「撒谎」的代价（按性情算），
	#   所以基准分开算：QTE 成功**不该再额外加**，也不该减。
	var susp_answered: float = gd.suspicion_level
	var answer_cost: float = float((interro.current_options[1] as Dictionary).get("delta", 0.0))
	interro._select_option(1)
	_check("答题后 QTE 立刻结束", interro.is_qte_active == false)
	_check("答题后 QTE 面板收起", interro.qte_container.visible == false)
	_check("答题结束后下腹部小图一起收起", interro.body_layer.visible == false)
	_check("★ QTE 成功不加不减（只算了「撒谎」那一笔）",
		is_equal_approx(gd.suspicion_level - susp_answered, answer_cost))
	_check("QTE 成功提示写明「没有露出破绽」",
		interro.feedback_label.text.contains("没有露出破绽"))
	_check("本题的 QTE 标记为已完成", interro.qte_done == true)

	# ---- 失败：松手 → +EXPR_QTE_FAIL ----
	interro._ended = false
	interro._running = true
	interro.interference_active = false
	interro.interference_timer = 999.0
	interro._load_question(a_idx)
	interro._process(Interrogation.EXPR_QTE_DELAY + 0.1)
	_check("重新加载后又排上了 QTE", interro.is_qte_active == true)
	gd.suspicion_level = 0.0
	interro._process_expression_qte(Interrogation.EXPR_QTE_TIME + 0.1)
	_check("松手则这条走完 → 判负", interro.is_qte_active == false)
	_check("QTE 失败抬高怀疑度", gd.suspicion_level > 0.0)
	_check("失败扣的量 = EXPR_QTE_FAIL",
		is_equal_approx(gd.suspicion_level, Interrogation.EXPR_QTE_FAIL))
	_check("QTE 失败提示写明「失败」",
		interro.feedback_label.text.contains("失败"))
	_check("失败只扣一次（不再按额度连做数轮）",
		is_equal_approx(gd.suspicion_level, Interrogation.EXPR_QTE_FAIL))

	print("\n-- 怀疑度：轮内只涨不跌 --")
	gd.suspicion_level = 40.0
	interro._add_suspicion(-30.0)
	_check("负增量被拦在门外（轮内只涨不跌）", is_equal_approx(gd.suspicion_level, 40.0))
	interro._add_suspicion(0.0)
	_check("零增量不改变怀疑度", is_equal_approx(gd.suspicion_level, 40.0))
	interro._add_suspicion(7.0)
	_check("正增量照常生效", is_equal_approx(gd.suspicion_level, 47.0))
	gd.suspicion_level = 95.0
	interro._add_suspicion(50.0)
	_check("怀疑度上限钳制在 100", gd.suspicion_level <= 100.0)

	# ★ 第三十九轮：妙妙工具「尼古喵尾」（OutfitData 的 tool 栏，只能手动装备）
	#   用户口径：「无论选择什么选项都不会提高怀疑值，但触发游戏结束的选项依然会使游戏结束」。
	print("\n-- 妙妙工具「尼古喵尾」：装备后不再提高怀疑值 --")
	gd.carried_tools = []
	gd.suspicion_level = 40.0
	interro._add_suspicion(Interrogation.CONTRADICTION_PENALTY)
	_check("没带尼古喵尾 → 照常涨怀疑值",
		is_equal_approx(gd.suspicion_level, 40.0 + Interrogation.CONTRADICTION_PENALTY))

	gd.carried_tools = ["tool_tail"]
	_check("GameData.carried_tool() 认得出来", gd.carried_tool("tool_tail"))
	gd.suspicion_level = 40.0
	interro._add_suspicion(Interrogation.CONTRADICTION_PENALTY)
	_check("带着尼古喵尾 → 前后矛盾也不涨怀疑值",
		is_equal_approx(gd.suspicion_level, 40.0))
	interro._add_suspicion(Interrogation.SILENCE_DELTA)
	interro._add_suspicion(Interrogation.IMPROVISE_PENALTY)
	interro._add_suspicion(Interrogation.EXPR_QTE_FAIL)
	interro._add_suspicion(Interrogation.BLIND_MADE_UP_DELTA)
	interro._add_suspicion(Interrogation.PHONE_PULL_PENALTY * 3.0)
	_check("沉默 / 编造 / 盲区硬答 / QTE 失败 / 掏手机 全都不涨",
		is_equal_approx(gd.suspicion_level, 40.0))

	# 一击致命的那条路照旧放行 —— 说漏嘴的增量就是 `leak_delta`（默认 100），一次顶满
	interro._add_suspicion(interro._rf("leak_delta", 100.0))
	_check("★ 说漏嘴（一击致命）依然把怀疑度顶满、游戏照样结束",
		gd.suspicion_level >= 100.0)
	gd.carried_tools = []
	gd.suspicion_level = 100.0   # 恢复成上面那一段留下的状态，不给后面的用例改环境

# ------------------------------------------------------------
# 表情 QTE 的「真·主循环」—— 必须走 _process()，不能手工调
#
#  ★ 为什么非要单独测这一层：
#    上面那些用例都是直接调 `_process_expression_qte(delta)`，
#    于是「_process() 往里传的 delta 是多少」这件事根本没被测到。
#    结果就是 `var qte_delta := 0.0` 那个笔误（永远传 0）一路溜过去 ——
#    进度条不动、计时器不倒数、按住空格毫无反应、QTE 永不结束。
#    所以这里必须用 `_process(delta)` 逐帧驱动，把整条链走完。
# ------------------------------------------------------------
func _test_qte_live_loop() -> void:
	print("\n-- 表情 QTE 主循环：逐帧 _process 驱动（按住 → 顶上去 → 超时结算）--")
	interro.set_process(false)
	var keep_li: int = RunData.level_index
	var keep_exp: float = float(gd.outfit_exposure)
	# ★ 第三十三轮：表情 QTE 只由暴露值触发 —— 顶到必出点来保证一定有 QTE
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_FULL

	# 找一道会触发 QTE 的题（不是第 1 题 —— 第 1 题恒不出）
	var a_idx := _find_question_index("A", 1)
	if a_idx < 0:
		a_idx = _goto_level_with_card_owner("A")
	_check("（前置）找到一道会出 QTE 的题", a_idx > 0)
	if a_idx <= 0:
		interro.set_process(false)
		return

	interro._ended = false
	interro._running = true
	interro.interference_active = false
	interro.interference_timer = 9999.0
	interro._load_question(a_idx)
	_check("这道题排上了 QTE", interro.qte_needed == true)
	_check("刚切题时面板还没出来", interro.is_qte_active == false)

	var frame := 1.0 / 60.0

	# ---- ① 延迟必须由 _process 自己走完 ----
	var frames := 0
	while not interro.is_qte_active and frames < 600:
		interro._process(frame)
		frames += 1
	_check("★ 逐帧 _process 能把延迟走完、面板弹出来", interro.is_qte_active == true)
	_check("弹出的那一帧不计时（窗口从 4 秒开始）",
		is_equal_approx(interro.qte_timer, Interrogation.EXPR_QTE_TIME))
	_check("从中间值 50 起手", is_equal_approx(interro.qte_progress, 50.0))

	# ---- ② 按住 → 进度真的会涨（这就是之前失灵的地方）----
	#  按住 30 帧 = 0.5 秒，进度应当精确地涨 BOOST × 0.5 = 40 ——
	#  断言具体数值而不是「变大了」，这样「delta 传小了一半」之类的错也能抓到。
	Input.action_press("qte_space")
	for i in 30:
		interro._process(frame)
	Input.action_release("qte_space")
	var expect_up: float = 50.0 + Interrogation.EXPR_QTE_BOOST * 30.0 * frame
	_check("★ 按住以后进度按 BOOST × 时长上涨（delta 真的传进来了）",
		is_equal_approx(interro.qte_progress, expect_up))
	_check("★ 计时器按真实时间倒数",
		is_equal_approx(interro.qte_timer, Interrogation.EXPR_QTE_TIME - 30.0 * frame))

	# ---- ③ 松手 → 进度按 DECAY 回落 ----
	var peak: float = interro.qte_progress
	for i in 8:
		interro._process(frame)
	var expect_down: float = peak - Interrogation.EXPR_QTE_DECAY * 8.0 * frame
	_check("★ 松手以后进度按 DECAY 回落", is_equal_approx(interro.qte_progress, expect_down))

	# ---- ④ 一直按住 → 顶过通过线 → 超时自动结算，判定为成功 ----
	gd.suspicion_level = 30.0
	var susp_before: float = gd.suspicion_level
	Input.action_press("qte_space")
	var guard := 0
	while interro.is_qte_active and guard < 2000:
		interro._process(frame)
		guard += 1
	Input.action_release("qte_space")
	_check("★ 窗口走完后 QTE 自动结束（不会永远挂着）",
		interro.is_qte_active == false)
	_check("★ 通过的进度留在通过线之上",
		interro.qte_progress >= Interrogation.EXPR_QTE_PASS)
	_check("★ 由 _process 驱动的超时结算算成功：不加怀疑度",
		is_equal_approx(gd.suspicion_level, susp_before))
	_check("成功提示写明「没有露出破绽」",
		interro.feedback_label.text.contains("没有露出破绽"))
	_check("面板收起来了", interro.qte_container.visible == false)
	_check("本题的 QTE 标记为已完成", interro.qte_done == true)

	# ---- ⑤ 失败路径：全程不按住 → 超时判负 +24 ----
	interro._ended = false
	interro._running = true
	interro.interference_active = false
	interro.interference_timer = 9999.0
	interro._load_question(a_idx)
	frames = 0
	while not interro.is_qte_active and frames < 600:
		interro._process(frame)
		frames += 1
	_check("第二次也弹了出来", interro.is_qte_active == true)
	gd.suspicion_level = 5.0
	guard = 0
	while interro.is_qte_active and guard < 2000:
		interro._process(frame)
		guard += 1
	_check("★ 全程不按住 → 超时判负", interro.is_qte_active == false)
	_check("★ 判负扣的量 = EXPR_QTE_FAIL",
		is_equal_approx(gd.suspicion_level, 5.0 + Interrogation.EXPR_QTE_FAIL))
	_check("失败提示写明「失败」",
		interro.feedback_label.text.contains("失败"))

	# ---- ⑥ 两条提示条都贴在屏幕最下方（用户口径：「qte改为显示在最下方」）----
	#  这里量的是**真实渲染位置**，不是 anchor 的「意图」——
	#  上一版就是把 MarginContainer 的内边距当外边距用，anchor 看着没问题、
	#  实际两条都贴死在底边叠着。所以必须等布局落地后量 global_rect。
	interro.show()
	interro.qte_container.show()
	interro.intf_container.show()
	await get_tree().process_frame
	await get_tree().process_frame
	var vh: float = get_viewport().get_visible_rect().size.y
	var qte_r: Rect2 = interro.qte_strip.get_global_rect()
	var intf_r: Rect2 = interro.intf_strip.get_global_rect()
	print("     [量] 屏高 %.0f ｜ QTE %s ｜ 递话 %s" % [vh, str(qte_r), str(intf_r)])
	_check("★ QTE 面板落在屏幕下半部分",
		qte_r.size.y > 1.0 and qte_r.get_center().y > vh * 0.5)
	_check("★ 递话面板也落在屏幕下半部分",
		intf_r.size.y > 1.0 and intf_r.get_center().y > vh * 0.5)
	_check("★ QTE 面板底边几乎贴着屏幕底边（差 16 上下）",
		vh - qte_r.end.y < 40.0)
	_check("★ 两条共用屏幕最下方那一层（互斥，不会叠）",
		is_equal_approx(qte_r.end.y, intf_r.end.y))
	_check("两条都够宽（左右各留了 170 的边）",
		qte_r.size.x > 600.0 and intf_r.size.x > 600.0)
	# ★ 递话那条必须排成一行 —— 两行就会比占位带高，又会压回选项上去。
	_check("★ 递话提示条排成一行（高度是确定的）",
		interro.intf_label.get_line_count() == 1)

	# ---- ⑥b 提示条不许压住最后一个选项 ----
	#  用户口径：「按住空格键的 qte 挡住了最后一个选项」。
	#
	#  ★ 这里验的是**版式不变量**，不是某一次渲染的坐标：
	#    上面那一串用例全是同步操作（不留帧），长文本是在控件宽度还是 0 的时候
	#    塞进去的 —— Godot 会把容器的最小尺寸算成上万像素、并把已经算好的尺寸
	#    **卡住**（尺寸只有在父节点重新铺一遍时才回退），现场这具的 margin 容器
	#    实际高度已经不是 720 了，量 global_rect 量不出真话。
	#    所以改成验「占位带够不够高」这条**与字体、文案都无关**的不变量：
	#      · 占位带是 root 的最后一个孩子（贴着屏底那一头）；
	#      · root 待在一条 full-rect 的边距层里 ⇒ 它的底边 = 屏底 - 16；
	#      · 选项区排在占位带之上 ⇒「选项底边 ≤ 提示条顶边」
	#        等价于 STRIP_BAND_H + 16 - 14 ≥ QTE_FROM_BOTTOM + 提示条高度。
	var band: Control = interro.strip_band
	_check("底部常驻占位带建出来了", band != null)
	if band != null:
		var holder: Control = band.get_parent()
		var band_frame: Control = holder.get_parent()
		_check("★ 占位带挂在 root 末尾（贴着屏底那一头）",
			holder.get_child_count() - 1 == band.get_index())
		_check("★ 占位带所在那层是 full-rect（所以它真的贴着屏底）",
			is_equal_approx(band_frame.anchor_top, 0.0)
			and is_equal_approx(band_frame.anchor_bottom, 1.0))
		_check("占位带的高度 = STRIP_BAND_H",
			is_equal_approx(band.custom_minimum_size.y,
				Interrogation.STRIP_BAND_H))
		var strip_h: float = maxf(
			interro.qte_strip.get_combined_minimum_size().y,
			interro.intf_strip.get_combined_minimum_size().y)
		print("     [量] 提示条高 %.0f ｜ 占位带 %.0f ｜ 屏高 %.0f"
			% [strip_h, Interrogation.STRIP_BAND_H, vh])
		_check("★ 占位带盖得住整条提示条（选项区一定让得开）",
			Interrogation.STRIP_BAND_H + 30.0
				>= Interrogation.QTE_FROM_BOTTOM + strip_h)
		# 反向兜底：占位带别把整屏撑爆 —— 撑爆的话 margin 会被钳到比屏幕还高，
		# 整个界面往下淌，选项反而掉进提示条里。
		_check("★ 盘问界面的最小高度塞得进 720 的屏（没被占位带撑爆）",
			band_frame.get_combined_minimum_size().y <= vh)
	# 位置关系：选项区确实排在占位带之上（这两个都在同一个父链里，相对关系不受卡尺寸影响）
	var last_opt: Button = null
	for b in interro.option_btns:
		if (b as Button).visible:
			last_opt = b
	if last_opt != null and band != null:
		_check("★ 选项区排在占位带之上（底边已经让开了）",
			last_opt.get_global_rect().end.y
				<= band.get_global_rect().position.y + 1.0)
	else:
		_check("★ 选项区排在占位带之上（底边已经让开了）", false)

	# ---- ⑦ 通过线：进度条上那道竖线，标出「按到哪儿才算过」----
	_check("★ 表情 QTE 的进度条上标了通过线", interro.qte_pass_mark != null)
	if interro.qte_pass_mark != null:
		var frac: float = interro.qte_pass_mark.anchor_left
		_check("★ 通过线的位置就是 EXPR_QTE_PASS",
			is_equal_approx(frac, Interrogation.EXPR_QTE_PASS / 100.0))
		_check("通过线是竖着的（上下都撑满条）",
			is_equal_approx(interro.qte_pass_mark.anchor_top, 0.0)
			and is_equal_approx(interro.qte_pass_mark.anchor_bottom, 1.0))
	else:
		_check("★ 通过线的位置就是 EXPR_QTE_PASS", false)
		_check("通过线是竖着的（上下都撑满条）", false)
	_check("同行者递话那条没有通过线（它只是按一下打断）",
		interro.intf_bar != null and interro.qte_pass_mark != interro.intf_bar)

	RunData.level_index = keep_li
	gd.level_index = keep_li
	gd.outfit_exposure = keep_exp
	_cancel_qte_quiet()

func _cancel_qte_quiet() -> void:
	interro._ended = false
	interro._running = false
	interro.is_qte_active = false
	interro.qte_needed = false
	interro.qte_done = true
	interro.interference_active = false
	if interro.qte_container != null:
		interro.qte_container.hide()
	if interro.intf_container != null:
		interro.intf_container.hide()

# ------------------------------------------------------------
# 表情 QTE 的「起手条件」—— 谁需要压表情、谁不需要
# ------------------------------------------------------------
func _test_qte_budget() -> void:
	# ★★ 第三十三轮重写（用户口径）：
	#    「暴露值越高现在只会影响按住空格的 QTE 即表情管理的 QTE，越高触发次数越多；
	#     表情管理 QTE 现在不会因为别的原因触发」。
	#   所以这里验的是：**唯一**的触发来源是暴露值，而且是线性斜坡。
	print("\n-- 表情 QTE 起手条件：只由暴露值决定（第 33 轮重写）--")
	_check("延迟常量 = 2.5 秒", is_equal_approx(Interrogation.EXPR_QTE_DELAY, 2.5))
	_check("失败代价 = 24", is_equal_approx(Interrogation.EXPR_QTE_FAIL, 24.0))
	_check("斜坡两端：起效点 10 / 必出点 60",
		Interrogation.EXPOSURE_QTE_MIN < Interrogation.EXPOSURE_QTE_FULL)

	var keep_li: int = RunData.level_index
	var keep_exp: float = float(gd.outfit_exposure)
	interro.set_process(false)

	# ---- 第 1 题：恒不出（哪怕暴露值拉满）----
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_FULL + 200
	_check("第 1 题恒不出（哪怕暴露值拉满）",
		interro.needs_expression_for(0, "card", [{"kind": "leak"}]) == false)

	# ---- 滑到最低：一次都不出 ----
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_MIN
	_check("暴露值 = 起效点 → 概率 0",
		is_equal_approx(interro.expression_qte_chance(), 0.0))
	_check("暴露值 = 起效点 → 寻常题不出",
		interro.needs_expression_for(1, "card", [{"kind": "ok"}]) == false)
	# ★ 本轮删掉的旧触发原因（就是那句「别的原因」）
	_check("★ 选项里有「说漏嘴」也不再触发（旧原因已删）",
		interro.needs_expression_for(1, "card", [{"kind": "ok"}, {"kind": "leak"}]) == false)
	_check("★ 盲区题的「当场硬答」也不再触发（旧原因已删）",
		interro.needs_expression_for(1, "blind", [{"kind": "made_up"}]) == false)
	_check("★ 题面类型是「盲区 / 硬答」也不再触发（旧原因已删）",
		interro.needs_expression_for(1, "made_up", []) == false
		and interro.needs_expression_for(1, "gap", []) == false)

	# ---- 滑到最高：每题必出 ----
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_FULL
	_check("暴露值 = 必出点 → 概率 1",
		is_equal_approx(interro.expression_qte_chance(), 1.0))
	_check("暴露值 = 必出点 → 寻常题也出",
		interro.needs_expression_for(1, "card", [{"kind": "ok"}]) == true)
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_FULL + 80
	_check("超过必出点概率仍夹在 1",
		is_equal_approx(interro.expression_qte_chance(), 1.0))

	# ---- 中间：线性，且越高越大 ----
	var mid_e := (Interrogation.EXPOSURE_QTE_MIN + Interrogation.EXPOSURE_QTE_FULL) / 2.0
	gd.outfit_exposure = mid_e
	var ch_mid: float = interro.expression_qte_chance()
	_check("斜坡中点概率 = 0.5（实测 %.2f）" % ch_mid, is_equal_approx(ch_mid, 0.5))
	#   三个递增的取样点：起效点 + 5 / 中点 / 必出点 − 5
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_MIN + 5.0
	var ch_low: float = interro.expression_qte_chance()
	gd.outfit_exposure = Interrogation.EXPOSURE_QTE_FULL - 5.0
	var ch_high: float = interro.expression_qte_chance()
	_check("★ 暴露值越高，触发概率越大（%.2f < %.2f < %.2f）" % [ch_low, ch_mid, ch_high],
		ch_low < ch_mid and ch_mid < ch_high)

	# ---- 稳定：同一道题反复判，结果必须一致 ----
	#   不能每次现摇 —— 同一题可能被反复装载（来回切题 / 重来本轮 / 测试里多次 _load），
	#   否则会变成「同一题一会儿出一会儿不出」。
	gd.outfit_exposure = mid_e
	var first: bool = interro.needs_expression_for(3, "card", [])
	var stable := true
	for i in 16:
		if interro.needs_expression_for(3, "card", []) != first:
			stable = false
	_check("★ 同一道题反复判 → 结果稳定（不会一会儿出一会儿不出）", stable)

	# ---- 题目自带的 QTE 提示文字（第 33 轮：可以编辑）----
	#   题目写了 `qte.prompt` 就用它；没写就回落全局那句。
	var qs: Array = interro.level_questions()
	if qs.size() > 1:
		var q1: Dictionary = qs[1]
		var saved: Variant = q1.get("qte", null)
		q1["qte"] = {"kind": "expression", "delay": 0.5, "prompt": "测试专用提示"}
		interro._load_question(1)
		_check("★ 题目自带 qte.prompt → 提示条用它",
			interro.qte_prompt_used == "测试专用提示")
		# 没写 prompt 的题 → 回落（留空，由 _begin_qte 取全局那句）
		q1["qte"] = {"kind": "expression", "delay": 0.5}
		interro._load_question(1)
		_check("题目没写 prompt → 留空（弹出时回落到全局那句）",
			interro.qte_prompt_used == "")
		# 还原
		if saved == null:
			q1.erase("qte")
		else:
			q1["qte"] = saved
	_check("全局那句提示文字存在且非空（编辑器可改）",
		ScenarioData.ui_t_d("interrogation.qte_prompt").length() > 10)

	# 装回界面
	RunData.level_index = keep_li
	gd.level_index = keep_li
	gd.outfit_exposure = keep_exp

func _test_intro_and_help() -> void:
	print("\n-- 开场介绍浮窗：开局弹一次，关掉后能再打开 --")
	main._start_new_run(20261011)
	_check("浮窗建出来了", main.intro_layer != null)
	_check("★ 开局自动弹出", main.intro_layer.visible == true)
	_check("浮窗里写着这一局的背景介绍", main.intro_body.text.length() > 40)
	_check("介绍里点出你在哪儿（背景）",
		main.intro_body.text.contains(RunData.background_name())
			or main.intro_body.text.length() > 80)
	_check("★ 介绍文本来自数据层（可用编辑器改）",
		main.intro_body.text == DossierData.intro_text())
	_check("每套背景都有自己的介绍",
		ScenarioData.intro_of(ScenarioData.get_background("border_post")) != ""
		and ScenarioData.intro_of(ScenarioData.get_background("town_inn")) != "")

	# ★ 第六十轮：第二轮也要弹浮窗，而且用**这一轮自己的**说明（与第一轮不同）
	var r1_intro: String = main.intro_body.text
	var keep_li: int = RunData.level_index
	var keep_cleared: int = RunData.cleared_levels
	main._close_intro()
	RunData.level_index = 1
	RunData.cleared_levels = 1
	main._start_level()
	_check("★ 进入第 2 轮时浮窗再次弹出", main.intro_layer.visible == true)
	var r2_intro: String = main.intro_body.text
	_check("★ 第 2 轮的介绍与第 1 轮不同",
		r1_intro != r2_intro and r2_intro.length() > 40)
	_check("第 2 轮的介绍就是这一轮 levels[].intro",
		r2_intro == str(RunData.current_level().get("intro", "")))
	_check("DossierData 按当前轮取说明", DossierData.intro_text() == r2_intro)
	_check("两轮都写了说明（不是拿空串凑数）",
		str(RunData.levels()[0].get("intro", "")).length() > 40
		and str(RunData.levels()[1].get("intro", "")).length() > 40)
	# 回到第 1 轮，后面的用例仍按第 1 轮的状态跑
	main._close_intro()
	RunData.level_index = keep_li
	RunData.cleared_levels = keep_cleared
	main._start_level()

	main._close_intro()
	_check("关掉之后收起来", main.intro_layer.visible == false)

	# 关掉之后靠按钮再打开
	_check("准备室有「本局背景」按钮", wardrobe.intro_btn != null)
	main._show_intro()
	_check("★ 关掉后还能再打开", main.intro_layer.visible == true)
	main._close_intro()

	print("\n-- 玩法说明：分「手机未开 / 手机已开 / 盘问」三套 --")
	_check("玩法说明浮层建出来了", main.help_overlay != null)
	_check("准备室有「玩法说明」按钮", wardrobe.help_btn != null)
	_check("盘问界面有「玩法说明」按钮", interro.help_btn != null)
	_check("初始是关着的", main.help_overlay.is_open() == false)

	# ---------- 阶段一 · 手机没打开：讲换装区域 / 数值量表 / 换装预览 / 手机 ----------
	main._show_stage_help()
	_check("★ 阶段一（手机未开）：标注浮层打开", main.help_overlay.is_open() == true)
	_check("阶段一（手机未开）：标题有字", main.help_overlay.title.contains("阶段一"))
	var wm: Array = main._wardrobe_marks()
	_check("★ 阶段一（手机未开）：恰好 4 处标注（卡片墙 / 量表 / 预览 / 手机）",
		wm.size() == 4)
	var wtxt := ""
	for m in wm:
		wtxt += str((m as Dictionary).get("t", "")) + "\n"
	_check("★ 讲了「换装区域」", wtxt.contains("换装区域"))
	_check("★ 不再讲「判定栏」（该栏已撤掉）", not wtxt.contains("判定栏"))
	_check("★ 讲了「手机」", wtxt.contains("手机"))
	# ★ 第三十一轮：卡片上只剩一行点阵（C. 反差值那行按用户口径撤掉了）
	_check("★ 讲了一行点阵 E.（暴露值）", wtxt.contains("E. 暴露值"))
	_check("★ 玩法说明里不再提 C. 反差值点阵", not wtxt.contains("C. 反差值"))
	_check("★ 不再讲第三行 A. 接受度（已撤掉）", not wtxt.contains("A. 接受度"))
	_check("★ 不再讲接受度门槛的斜标签（已撤掉）", not wtxt.contains("斜标签"))
	_check("★ 讲了卡片的边框含义（已装备 / 强制装备）",
		wtxt.contains("强制装备"))
	_check("★ 量表讲了「七颗圆点＝量级、颜色＝档位」（DoL 的读法）",
		wtxt.contains("七颗圆点"))
	_check("★ 量表讲了阈值刻线与指针",
		wtxt.contains("阈值") and wtxt.contains("指针"))
	_check("★ 量表只讲两条（暴露值 / 反差值），不再有未改部位",
		wtxt.contains("两条") and not wtxt.contains("未改部位"))
	_check("阶段一（手机未开）：每处标注都有编号与说明", _mark_wellformed(wm))
	# 标注框取的是**运行时控件矩形** —— 得等这一帧的布局算完才准
	await get_tree().process_frame
	await get_tree().process_frame
	_check("阶段一（手机未开）：框与线不交叉", _layout_clean(main._wardrobe_marks()))
	main.help_overlay.close()
	_check("阶段一（手机未开）：关掉之后收起", main.help_overlay.is_open() == false)

	# ---------- 阶段一 · 手机已打开：逐个讲四个界面 ----------
	_check("准备室的手机按钮在", wardrobe.intel.phone_btn != null)
	wardrobe.intel.open_phone()
	_check("★ 手机已经拿在手里", wardrobe.intel.is_phone_open() == true)
	_check("手机浮层里也给了「玩法说明」入口", wardrobe.intel.phone_help_btn != null)
	main._show_stage_help()
	_check("★ 阶段一（手机已开）：标注浮层打开", main.help_overlay.is_open() == true)
	_check("★ 阶段一（手机已开）：标题写明是手机", main.help_overlay.title.contains("手机"))
	var pm: Array = main._phone_marks()
	_check("★ 阶段一（手机已开）：恰好 4 处标注（四个界面）", pm.size() == 4)
	var ptxt := ""
	for m in pm:
		ptxt += str((m as Dictionary).get("t", "")) + "\n"
	_check("★ 讲了「消息」", ptxt.contains("消息"))
	_check("★ 讲了「相册」", ptxt.contains("相册"))
	_check("★ 讲了「备忘录」", ptxt.contains("备忘录"))
	_check("★ 讲了「备注」", ptxt.contains("备注"))
	_check("阶段一（手机已开）：每处标注都有编号与说明", _mark_wellformed(pm))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("阶段一（手机已开）：框与线不交叉", _layout_clean(pm))
	main.help_overlay.close()
	wardrobe.intel.close_phone()
	_check("手机收起", wardrobe.intel.is_phone_open() == false)

	# 阶段二
	_run_a_clean_level()
	main._show_stage_help()
	_check("★ 阶段二：标注浮层打开", main.help_overlay.is_open() == true)
	_check("阶段二：标题有字", main.help_overlay.title.contains("阶段二"))
	var im: Array = main._interrogation_marks()
	_check("★ 阶段二：恰好 5 处标注（怀疑度 / 题面 / 反馈 / 选项 / 提示条）",
		im.size() == 5)
	var itxt := ""
	for m in im:
		itxt += str((m as Dictionary).get("t", "")) + "\n"
	_check("★ 阶段二说明了「怀疑度」", itxt.contains("怀疑度") and itxt.contains("100%"))
	_check("★ 阶段二说明了「题面 / 反馈 / 选项」",
		itxt.contains("题面") and itxt.contains("反馈") and itxt.contains("选项"))
	# ★ 手机不再重复讲（用户口径：「第二阶段的玩法说明中不需要再次说明手机」）——
	#   阶段一已经逐个讲过四个界面了。
	_check("★ 阶段二不再重复讲「掏出手机」这个按钮", not itxt.contains("掏出手机"))
	_check("★ 阶段二说明了两种提示条（表情控制 / 同行者递话）",
		itxt.contains("提示条") and itxt.contains("按住空格") and itxt.contains("递话"))
	_check("★ 提示条说明了「压表情时手机用不了」（这是规定）",
		itxt.contains("手机得先收起来"))
	_check("阶段二：每处标注都有编号与说明", _mark_wellformed(im))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("★ 阶段二：框与线不交叉", _layout_clean(im))
	main.help_overlay.close()
	_check("阶段二：关掉之后收起", main.help_overlay.is_open() == false)
	main._close_intro()

# 标注项必须字段齐全：有矩形（相对矩形或运行时控件之一）、有编号、有说明文字
func _mark_wellformed(arr: Array) -> bool:
	for m in arr:
		var md: Dictionary = m
		var has_shape: bool = (md.get("r") is Rect2) or md.has("ctrl")
		if not has_shape:
			return false
		if int(md.get("n", 0)) < 1:
			return false
		if str(md.get("t", "")).length() < 10:
			return false
	return true

# ------------------------------------------------------------
#  玩法说明的几何不变量
#
#  用户口径：「玩法说明的框和线交叉在一起了看不清请改正」
#  这三条就是「看不清」的机器判据：
#    · 文字块两两不重叠（否则字叠字）
#    · 连接线两两不相交（否则线打结）
#    · 每条连接线只连到自己的文字块，不横穿别人的块
#  之前那版之所以过不了，是因为「谁的框贴谁旁边」——
#  左边的框把文字贴到右边、右边的框贴到左边，两条线必然交叉。
# ------------------------------------------------------------
func _layout_clean(marks: Array) -> bool:
	var sz := Vector2(1280, 720)      # 与 project.godot 一致
	help_check_overlay.marks = marks
	var L: Dictionary = help_check_overlay.layout(sz)
	var items: Array = L["items"]
	var lines: Array = L["lines"]

	# 1) 文字块两两不重叠
	for i in items.size():
		var a: Rect2 = (items[i] as Dictionary)["block"]
		for j in range(i + 1, items.size()):
			var b: Rect2 = (items[j] as Dictionary)["block"]
			if a.intersects(b, false):
				print("      [geo] 块 %d 与块 %d 重叠：%s ｜ %s" % [i, j, str(a), str(b)])
				return false

	# 2) 连接线两两不相交
	for i in lines.size():
		var la: Array = lines[i]
		for j in range(i + 1, lines.size()):
			var lb: Array = lines[j]
			if _segments_cross(la[0], la[1], lb[0], lb[1]):
				print("      [geo] 线 %d 与线 %d 相交：%s->%s ｜ %s->%s" % [i, j, str(la[0]), str(la[1]), str(lb[0]), str(lb[1])])
				return false

	# 3) 每条箭头都指进「自己那个框」的内部 —— 认不错
	for i in items.size():
		var ln: Array = lines[i]
		var own: Rect2 = (items[i] as Dictionary)["box"]
		if not own.grow(4.0).has_point(ln[1]):
			print("      [geo] 第 %d 条箭头没指进自己的框：终点 %s ｜ 框 %s" % [i, str(ln[1]), str(own)])
			return false
		# 也不该指进别人的标注框
		for j in items.size():
			if i == j:
				continue
			var other: Rect2 = (items[j] as Dictionary)["box"]
			if other.grow(-4.0).has_point(ln[1]):
				print("      [geo] 第 %d 条箭头指进了别处的框 %d" % [i, j])
				return false

	# 4) 徽章两两不重叠
	for i in items.size():
		var ba: Vector2 = (items[i] as Dictionary)["badge"]
		for j in range(i + 1, items.size()):
			var bb: Vector2 = (items[j] as Dictionary)["badge"]
			if ba.distance_to(bb) < 30.0:
				print("      [geo] 徽章 %d 与徽章 %d 太近：%s ｜ %s" % [i, j, str(ba), str(bb)])
				return false
	return true

# 两条线段是否真正相交（共端点不算 —— 扇形的起点/终点本来就会重合在块边上）
func _segments_cross(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	if p1.is_equal_approx(p3) or p1.is_equal_approx(p4) \
		or p2.is_equal_approx(p3) or p2.is_equal_approx(p4):
		return false
	var d1 := _cross(p3, p4, p1)
	var d2 := _cross(p3, p4, p2)
	var d3 := _cross(p1, p2, p3)
	var d4 := _cross(p1, p2, p4)
	return ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) \
		and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0))

func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

# 线段是否穿过矩形内部（留一点边距，贴着边走过去不算）
func _segment_hits_rect(p1: Vector2, p2: Vector2, r: Rect2) -> bool:
	var inner := r.grow(-6.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return false
	if inner.has_point(p1) or inner.has_point(p2):
		return false
	var c := [inner.position,
		inner.position + Vector2(inner.size.x, 0),
		inner.position + inner.size,
		inner.position + Vector2(0, inner.size.y)]
	for i in 4:
		if _segments_cross(p1, p2, c[i], c[(i + 1) % 4]):
			return true
	return false

# ------------------------------------------------------------
# 本轮新增：怀疑度「轮内不降 / 轮间衰减」
# ------------------------------------------------------------
func _test_suspicion_decay() -> void:
	print("\n-- 怀疑度：轮内只涨不跌，轮次之间按比例衰减 --")
	_check("衰减比例 = 0.5", is_equal_approx(GameData.SUSPICION_DECAY, 0.5))
	_check("衰减下限 = 10", is_equal_approx(GameData.SUSPICION_FLOOR, 10.0))
	_check("基准开局怀疑度 = 20", is_equal_approx(GameData.SUSPICION_BASE, 20.0))

	# 第 1 轮：没有 carry → 用基准值
	gd.suspicion_carry = 0.0
	gd.reset_level_state()
	_check("第 1 轮开局怀疑度 = 基准 20", is_equal_approx(gd.suspicion_level, 20.0))

	# 第 2 轮：上一轮带着 80 分进来 → 对折成 40
	gd.suspicion_carry = 80.0
	gd.reset_level_state()
	_check("★ 上一轮 80 → 这一轮开局 40（对折）",
		is_equal_approx(gd.suspicion_level, 40.0))

	# 极低分也不会一路归零
	gd.suspicion_carry = 12.0
	gd.reset_level_state()
	_check("★ 上一轮 12 → 6 被下限兜住成 10",
		is_equal_approx(gd.suspicion_level, GameData.SUSPICION_FLOOR))

	# 通关流程里真的会写 carry
	main._start_new_run(20261011)
	gd.suspicion_carry = 0.0
	gd.suspicion_level = 90.0
	interro.set_process(false)
	_check("（前置）开局把 carry 清掉", is_equal_approx(gd.suspicion_carry, 0.0))
	_prepare_and_enter()
	interro.set_process(false)
	_pass_current_level()
	_check("★ 本轮结束时把怀疑度写进了 carry",
		is_equal_approx(gd.suspicion_carry, 30.0))
	main._on_overlay_pressed()
	_check("★ 进入下一轮：怀疑度按比例衰减（30 → 15）",
		is_equal_approx(gd.suspicion_level, 15.0))
	_check("★ 衰减后的值小于上一轮结束时的值",
		gd.suspicion_level < gd.suspicion_carry)

	# 收尾
	gd.suspicion_carry = 0.0
	gd.reset_level_state()

# ------------------------------------------------------------
# DoL 风格层：换装卡片 + 七点色阶 + 渐变刻度条
#
#   用户口径：「参考 Degrees of Lewdity 下的换装系统的样式，
#             将本游戏的系统替换那样的；暴露值等数值的表现方式
#             也参考相应的样式」
#   这里守三件事：色阶的语义、点阵的档位、量表阈值刻线的位置。
# ------------------------------------------------------------
func _test_dol_style() -> void:
	print("\n-- DoL 风格层：七点色阶 / 卡片三态 / 渐变刻度条 --")
	# ---- 色阶本身（照 DoL 的 getRevealInfo / getIntegrityInfo 的 7 档色阶）----
	_check("7 颗点", DolStyle.PIP_COUNT == 7)
	_check("暴露色阶 7 档，绿 → 红（越高越危险，照 DoL 的 reveal 色阶）",
		DolStyle.RAMP_EXPOSE.size() == 7
		and DolStyle.RAMP_EXPOSE[0] == DolStyle.GREEN
		and DolStyle.RAMP_EXPOSE[6] == DolStyle.RED)
	_check("反差色阶是暴露色阶的反序（越高越安全）",
		DolStyle.RAMP_CONTRAST.size() == 7
		and DolStyle.RAMP_CONTRAST[0] == DolStyle.RED
		and DolStyle.RAMP_CONTRAST[6] == DolStyle.GREEN)
	_check("接受度色阶走灰 → 金",
		DolStyle.RAMP_DEMAND.size() == 7
		and DolStyle.RAMP_DEMAND[6] == DolStyle.YELLOW)

	# ---- 档位切分：点亮几颗 = 量级，颜色 = 档位 ----
	_check("值 0 时一颗都不点亮", DolStyle.level_of(0.0, 22.0) == 0)
	_check("只要有一点就点亮第 1 颗", DolStyle.level_of(0.5, 22.0) == 1)
	_check("值到一半时 4 颗", DolStyle.level_of(11.0, 22.0) == 4)
	_check("值到上限时满 7 颗", DolStyle.level_of(22.0, 22.0) == 7)
	_check("超过上限也封顶在 7 颗", DolStyle.level_of(99.0, 22.0) == 7)
	_check("量程为 0 时不炸", DolStyle.level_of(3.0, 0.0) == 0)

	# ---- 卡片三态（照 DoL 的 .clothing-item 边框）----
	var eq := DolStyle.card_style("equipped")
	var fo := DolStyle.card_style("forced")
	var lk := DolStyle.card_style("locked")
	_check("已装备时是绿框", eq.border_color == DolStyle.GREEN)
	_check("本轮强制时是橙框", fo.border_color == DolStyle.ORANGE)
	_check("未解锁时是灰框", lk.border_color == DolStyle.CARD_BORDER_DIM)
	_check("卡片一律 1px 实线", eq.border_width_left == 1 and fo.border_width_left == 1)
	_check("悬停换底色（照 DoL 的 :hover）",
		DolStyle.card_style("hover").bg_color == DolStyle.CARD_BG_HOVER)

	# ---- 装到界面上 ----
	# ★ 「未解锁的卡片」要有接受度不够的物品才成立。跑到这里时跨局加成
	#   已经被前面的用例攒起来了（过关会加接受度），所以先清零；
	#   测完原样还回去 —— 后面的用例依赖它。
	var keep_gain: int = ProfileData.bonus()
	ProfileData.reset_all()
	main._start_new_run(20261011)
	main._close_intro()
	wardrobe.show()
	wardrobe._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var exp_mx := OutfitData.stat_max_of("exposure")
	var con_mx := OutfitData.stat_max_of("contrast")
	var acc_mx := OutfitData.stat_max_of("acceptance_req")
	_check("物品满值是从数据现算的（暴露 %d / 反差 %d / 接受度 %d）"
		% [exp_mx, con_mx, acc_mx],
		exp_mx >= 8 and con_mx >= 7 and acc_mx >= 10)

	var n_cards := 0
	var wrong := 0
	for slot in OutfitData.active_slots():
		var refs: Array = wardrobe.card_refs[slot]
		var items := OutfitData.get_items_for_slot(slot)
		if refs.size() != items.size():
			wrong += 1
		for i in items.size():
			n_cards += 1
			var pair: Dictionary = refs[i]
			var it: Dictionary = items[i]
			var pe: DolStyle.Pips = pair["e"]
			if not (is_equal_approx(pe.value, float(it["exposure"]))):
				wrong += 1
			if not (is_equal_approx(pe.max_value, float(exp_mx))):
				wrong += 1
			if pair.has("a") or pair.has("tag"):
				wrong += 1   # ★ A. 点阵行与右上角斜标签都已撤掉
			# ★ 第三十一轮（用户口径）：卡上不再有「C. 反差值」那一行
			if pair.has("c"):
				wrong += 1
	_check("每个槽位的候选衣物都有一张卡（共 %d 张），暴露值点阵的读数与量程都对"
		% n_cards, wrong == 0 and n_cards == _active_item_count())
	_check("★ 卡上只剩一行点阵（E. 暴露值）—— C. 反差值那行已按用户口径去掉",
		not (wardrobe.card_refs["hair"][0] as Dictionary).has("c")
		and not (wardrobe.card_refs["hair"][0] as Dictionary).has("a")
		and not (wardrobe.card_refs["hair"][0] as Dictionary).has("tag"))

	# ---- 悬停文案不再泄露「这件与原貌一致 / 不同」（本轮口径）----
	# 原貌开局就全可见，悬停里再写一句「与他记忆里的一致」等于把答案印在卡片上，
	# 搭配的乐趣全没了 —— 所以那两行被撤掉，只留三项精确读数。
	var tip_known: String = wardrobe._tip_for(OutfitData.get_item("hair_short"), false, true)
	_check("悬停不再提示「与他记忆里的一致 / 不同」", not tip_known.contains("记忆"))
	_check("悬停只给两项读数（暴露值 / 需接受度）—— 反差值已按用户口径去掉",
		tip_known.contains("暴露值") and tip_known.contains("需接受度")
		and not tip_known.contains("反差"))
	_check("悬停对「未解锁」的装扮只说还差多少接受度",
		wardrobe._tip_for(OutfitData.get_item("hair_up"), true, true).contains("需要接受度"))
	_check("悬停对「超上限」的装扮仍然给出警告",
		wardrobe._tip_for(OutfitData.get_item("hair_short"), false, false).contains("超出暴露值上限"))

	# ---- 下架的槽位（外袍 + 耳饰）在换装界面里彻底不存在 ----
	_check("换装界面没有下架槽位的分区（robe / earrings）",
		not wardrobe.card_refs.has("robe") and not wardrobe.slot_labels.has("robe")
		and not wardrobe.slot_notes.has("robe")
		and not wardrobe.card_refs.has("earrings") and not wardrobe.slot_labels.has("earrings")
		and not wardrobe.slot_notes.has("earrings"))
	_check("下架槽位连一张卡片都没有",
		OutfitData.get_items_for_slot("robe").is_empty()
		and OutfitData.get_items_for_slot("earrings").is_empty())

	# ---- 卡片按 3 列铺开 ----
	var hair: Array = wardrobe.card_refs["hair"]
	var b0: Button = hair[0]["btn"]
	var b1: Button = hair[1]["btn"]
	_check("卡片按 3 列铺开（同宽、依次右移）",
		b0.size.x > 200.0 and b1.size.x > 200.0
		and is_equal_approx(b0.size.x, b1.size.x)
		and is_equal_approx(b1.position.x - b0.position.x, b0.size.x + 6.0))
	_check("第 4 张卡片换行回到第 1 张的 x（每行 3 张）",
		hair.size() >= 4
		and is_equal_approx((hair[3]["btn"] as Button).position.x, b0.position.x))
	_check("换行后卡片落在下一行", (hair[3]["btn"] as Button).position.y > b0.position.y)

	# ---- 未解锁：问号 + 不透露名字（第十四轮的口径仍然成立）----
	var lp: Dictionary = {}
	for slot in OutfitData.active_slots():
		for pair in wardrobe.card_refs[slot]:
			if (pair["btn"] as Button).text == "?":
				lp = pair
				break
		if not lp.is_empty():
			break
	_check("（前置）确实有还没解锁的卡片", not lp.is_empty())
	if not lp.is_empty():
		var lb: Button = lp["btn"]
		var lkst := lb.get_theme_stylebox("normal") as StyleBoxFlat
		_check("未解锁卡片只显示问号、不亮图标", lb.icon == null)
		_check("未解锁卡片不透露物品名",
			(lp["name"] as Label).text == "未解锁的装扮")
		_check("未解锁卡片的边框是灰的", lkst != null
			and lkst.border_color == DolStyle.CARD_BORDER_DIM)
	else:
		_check("未解锁卡片只显示问号、不亮图标", false)
		_check("未解锁卡片不透露物品名", false)
		_check("未解锁卡片的边框是灰的", false)

	# ---- 量表：绝对量程 + 阈值刻线 ----
	# ★ 第四十九轮重标：起始接受度 10 → 14（第 4 轮上限 54 → 70），反差改成全槽位求和
	#   （可达上限从 ~99 涨到 ~235）—— 旧的 55 / 100 都装不下了。
	_check("量程是绝对量程（暴露 71 / 反差 270；未改部位已撤掉）",
		wardrobe.SCALE_MAX["expose"] == 71.0
		and wardrobe.SCALE_MAX["contrast"] == 270.0
		and not wardrobe.SCALE_MAX.has("matching"))
	for key in ["expose", "contrast"]:
		var blk: Dictionary = wardrobe.stat_blocks[key]
		_check("量表「%s」的点阵 + 刻度条 + 读数都在" % key,
			blk.has("pips") and blk.has("scale") and blk.has("value"))
	_check("★ 量表只剩两条（未改部位那条已撤掉）",
		wardrobe.stat_blocks.size() == 2 and not wardrobe.stat_blocks.has("matching"))
	var sc_e: DolStyle.Scale = wardrobe.stat_blocks["expose"]["scale"]
	var sc_c: DolStyle.Scale = wardrobe.stat_blocks["contrast"]["scale"]
	_check("暴露量表带阈值刻线（本关上限）", sc_e.warn_at > 0.0)
	_check("反差点量表带阈值刻线（本轮要求）", sc_c.warn_at > 0.0)
	_check("★ 两条刻线的相对位置不同（都落在同一个百分比就等于没画）",
		not is_equal_approx(sc_e.warn_at / sc_e.max_value, sc_c.warn_at / sc_c.max_value))
	_check("刻线落在条内（0 < 阈值 < 量程）",
		sc_e.warn_at < sc_e.max_value and sc_c.warn_at < sc_c.max_value)
	_check("暴露值的读数写成「当前 / 上限」",
		(wardrobe.stat_blocks["expose"]["value"] as Label).text
			== "%d / %d" % [gd.outfit_exposure, gd.outfit_exposure_cap])
	_check("暴露和反差的「坏方向」是相反的",
		wardrobe.stat_blocks["expose"]["dir"] == "over_bad"
		and wardrobe.stat_blocks["contrast"]["dir"] == "under_bad")

	# 把跨局加成还回去
	ProfileData.reset_all()
	ProfileData.add_gain(keep_gain)

# ------------------------------------------------------------
# 本轮新增：视角晃动
# ------------------------------------------------------------
func _test_shake() -> void:
	print("\n-- 视角晃动：QTE 失败 / 被识破时整屏抖一下 --")
	interro.set_process(false)
	_check("有被抖的那一层", interro.shake_target != null)
	interro.shake_target.position = Vector2.ZERO
	interro._shake_time = 0.0
	interro._shake_mag = 0.0
	interro._shake_t = 0.0

	interro.shake(0.0, 0.0)
	_check("幅度或时长 <= 0 时不抖", interro._shake_time <= 0.0)

	interro.shake(Interrogation.SHAKE_QTE_FAIL, 0.42)
	_check("shake() 排上了一次抖动", interro._shake_time > 0.0)
	_check("记录了幅度", is_equal_approx(interro._shake_mag, Interrogation.SHAKE_QTE_FAIL))

	interro._process_shake(0.05)
	_check("抖动真的挪动了那一层", interro.shake_target.position != Vector2.ZERO)

	# 弱的盖不掉强的
	interro.shake(Interrogation.SHAKE_QTE_PASS, 0.18)
	_check("弱抖动盖不掉正在进行的强抖动",
		is_equal_approx(interro._shake_mag, Interrogation.SHAKE_QTE_FAIL))

	# 走完时长 → 归位
	var guard := 0
	while interro._shake_time > 0.0 and guard < 200:
		guard += 1
		interro._process_shake(0.02)
	_check("抖动走完后归位到 (0, 0)", interro.shake_target.position == Vector2.ZERO)

	# 识别 / 暴露时的重抖
	_check("识破用的重抖幅度 = 18", is_equal_approx(Interrogation.SHAKE_HIT, 18.0))
	_check("QTE 失败抖得比成功重",
		Interrogation.SHAKE_QTE_FAIL > Interrogation.SHAKE_QTE_PASS)

# ------------------------------------------------------------
#  本轮新增：强制装备 / 短信逐关解锁 / 接受度跨局保留
# ------------------------------------------------------------
func _test_new_mechanics() -> void:
	print("\n-- 强制装备：本轮随机 0~2 件高暴露，换掉就当场识破 --")
	ProfileData.reset_all()
	ProfileData.add_gain(30)          # 把强制池撑大，保证抽得出来
	var forced: Array = []
	var first_level_clean := true
	for k in 60:
		RunData.start_new_run(310000 + k * 131)
		# ★ 每局第一轮没有强制服装要求
		if RunData.has_forced_items():
			first_level_clean = false
		RunData._roll_forced_items(1)
		if RunData.has_forced_items():
			forced = RunData.forced_item_ids().duplicate()
			break
	_check("★ 每局第一轮没有强制服装要求", first_level_clean)
	_check("第 2 轮起仍然会抽到强制装备（机制不是空转）", not forced.is_empty())
	if forced.is_empty():
		ProfileData.reset_all()
		return

	main._start_level()
	var m: WardrobeModel = wardrobe.model
	_reveal_all()
	_assign_all()
	wardrobe._refresh()

	_check("换装模型拿到了本轮强制装备", m.forced_items.size() == forced.size())
	_check("开局不替你穿 —— 强制装备得自己动手",
		m.missing_forced().size() == forced.size())
	_check("没穿强制装备 → 失败理由里写明原因",
		str(gd.outfit_fail_reasons).contains("强制装备"))
	_check("没穿强制装备 → 门禁照样不锁（阶段一不下结论）",
		wardrobe.continue_btn.disabled == false)
	_check("但换装结果已同步为不通过", gd.outfit_passed == false)
	_check("数值面板列出了强制装备", wardrobe.stats_label.text.contains("强制装备"))
	_check("每件强制装备都是高暴露", _all_forced_high_exposure(m.forced_items_info()))

	# 穿齐 + 凑够其余条件 → 结果变为通过
	_build_viable(m)                 # 内部会先把强制装备穿上
	wardrobe._refresh()
	_check("强制装备已穿齐", m.missing_forced().is_empty())
	_check("穿齐强制装备并凑够反差 → 结果通过", gd.outfit_passed == true)
	_check("强制装备齐全时不会被误判",
		not _reasons_contain(m.evaluate(), "强制装备"))

	# 换掉强制槽位 → 又变成不通过
	var fslot := str(OutfitData.get_item(str(forced[0])).get("slot", ""))
	var alt := {}
	for it in OutfitData.get_items_for_slot(fslot):
		if str(it["id"]) != str(forced[0]) and m.can_equip(it):
			alt = it
			break
	if not alt.is_empty():
		var keep := str(m.equipped.get(fslot, ""))
		m.equip(alt)
		_check("换掉强制槽位 → 判为强制装备未穿",
			_reasons_contain(m.evaluate(), "强制装备"))
		_check("换掉强制槽位 → 结果同步为不通过", gd.outfit_passed == false)
		m.equip(OutfitData.get_item(keep))
		_check("穿回去 → 结果重新通过",
			m.missing_forced().is_empty() and gd.outfit_passed == true)
	else:
		print("      （该槽位只有一件可选，跳过换装判定）")

	print("\n-- 短信逐关解锁：每过一关，手机里多一条 --")
	ProfileData.reset_all()
	main._start_new_run(20261011)
	var counts := []
	var btn_clean := true
	for li in OutfitData.MAX_LEVELS:
		var n: int = DossierData.sms_count()
		counts.append(n)
		if intel.phone_btn.text.contains("/") or intel.phone_btn.text.contains("🔒"):
			btn_clean = false
		if li < OutfitData.MAX_LEVELS - 1:
			RunData.advance_level()
			main._start_level()
	_check("第 1~2 轮解锁条数依次是 1/2", counts == [1, 2])
	_check("手机按钮各关都不显示计数（字样已删）", btn_clean)
	_check("到第 2 轮全部解锁", DossierData.sms_locked_count() == 0)

	# 新解锁的那条短信，正好写着本轮要问的那个说法
	main._start_new_run(20261011)
	var reveal_ok := true
	for li in OutfitData.MAX_LEVELS:
		var f := DossierData.fact_for_level(li)
		var want := DossierData.canonical_value(str(f.get("id", "")))
		var got := ""
		for t in DossierData.sms_threads():
			for r in (t as Dictionary).get("reveals", []):
				if str((r as Dictionary).get("fact", "")) == str(f.get("id", "")):
					got = str((r as Dictionary).get("value", ""))
		if got != want:
			reveal_ok = false
		if li < OutfitData.MAX_LEVELS - 1:
			RunData.advance_level()
			main._start_level()
	_check("本轮新解锁的短信正好揭示本轮要问的官方口径", reveal_ok)

	print("\n-- 接受度跨局保留：整局作废也不退还 --")
	ProfileData.reset_all()
	main._start_new_run(555001)
	_check("空账号开局接受度 = 起始值", RunData.acceptance == OutfitData.START_ACCEPTANCE)
	RunData.advance_level()
	var gain0 := int(OutfitData.LEVELS[0]["acceptance_gain"])
	_check("过关后这一关的 gain 进了账号", ProfileData.bonus() == gain0)
	_check("当前接受度立刻跟着涨", RunData.acceptance == OutfitData.START_ACCEPTANCE + gain0)
	wardrobe._refresh()
	_check("准备室数值面板写明跨局保留",
		wardrobe.stats_label.text.contains("跨局保留"))

	var acc_mid := RunData.acceptance
	main._start_new_run(555002)       # 相当于失败重开
	_check("新一局开局带着跨局收益", RunData.acceptance == acc_mid)
	_check("新一局仍然从第 1 轮开始", RunData.level_index == 0)
	_check("新一局局号 +1（换背景换原貌）", RunData.run_index >= 2)

	# 战绩记账
	# ★ 第五十二轮：一局 2 轮 —— 所以「打了一半」只能是 1 关、通关是 2 关
	ProfileData.note_run_finished(1, false)
	_check("记战绩：打过 1 局", ProfileData.runs_played == 1)
	_check("记战绩：单局最好 1 轮", ProfileData.best_cleared == 1)
	ProfileData.note_run_finished(2, true)
	_check("记战绩：通关 1 局", ProfileData.runs_cleared == 1)
	_check("记战绩：单局最好刷新到 2", ProfileData.best_cleared == 2)
	ProfileData.reset_all()

# ------------------------------------------------------------
# 本轮新增：开始界面 + 局内存档（继续游戏 = 从上次退出的那一关接着玩）
# ------------------------------------------------------------
func _test_title_and_save() -> void:
	print("\n-- 开始界面：继续游戏 = 从上次退出的那一关接着玩 --")

	# 存档写到 user:// —— 先备份玩家真实的存档，测完还原，绝不弄丢
	var path := RunSave.SAVE_PATH
	var had_file := FileAccess.file_exists(path)
	var backup := ""
	if had_file:
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf != null:
			backup = rf.get_as_text()
			rf.close()

	RunSave.autosave_enabled = true
	main._start_new_run(20261011)
	_check("开局写档：种子已记下", RunSave.seed_value == 20261011)
	_check("开局写档：has_run = true", RunSave.has_run == true)
	_check("开局写档：落在第 1 轮", RunSave.level_index == 0)

	# 走到第 2 轮（第 1 轮通过 → 覆盖层 → 进第 2 轮的准备室）
	_prepare_and_enter()
	_pass_current_level()
	main._on_overlay_pressed()
	_check("推进到第 2 轮", RunData.level_number() == 2)
	_check("第 2 轮准备室写档：level_index = 1", RunSave.level_index == 1)

	# 换一身不一样的打扮 + 记一条手机进度，验证「打扮」和「手机」都能续上
	var m: WardrobeModel = wardrobe.model
	var changed := false
	for slot in OutfitData.active_slots():
		if m.is_forced_slot(slot):
			continue
		var cur_id := str(m.item_at(slot).get("id", ""))
		for cand in OutfitData.get_items_for_slot(slot):
			if str(cand["id"]) == cur_id:
				continue
			if m.can_equip(cand):
				m.equipped[slot] = str(cand["id"])
				changed = true
				break
		if changed:
			break
	m.changed.emit()
	_check("改打扮后立即写档（%d 个槽位都在）" % OutfitData.active_slots().size(), RunSave.equipped.size() == OutfitData.active_slots().size())

	var probe_sms := "__probe_sms__"
	gd.sms_read = [probe_sms]
	gd.stated_facts = {"__probe_fact__": "probe_val"}
	gd.contradictions = 1
	gd.interrogator_intel_read = true
	RunSave.save_progress(m.equipped)

	# 把内存里的存档清掉，再从磁盘读回来（模拟重启）
	var saved_seed := RunSave.seed_value
	var saved_level := RunSave.level_index
	var saved_run := RunSave.run_index
	var saved_equipped := RunSave.equipped.duplicate()
	RunSave.has_run = false
	RunSave.seed_value = 0
	RunSave.equipped = {}
	RunSave.game = {}
	RunSave.load_save()
	_check("读档：has_run 恢复", RunSave.has_run == true)
	_check("读档：种子恢复", RunSave.seed_value == saved_seed)
	_check("读档：轮次恢复", RunSave.level_index == saved_level)
	_check("读档：局号恢复", RunSave.run_index == saved_run)
	_check("读档：打扮恢复（%d 个槽位）" % OutfitData.active_slots().size(), RunSave.equipped.size() == OutfitData.active_slots().size())
	_check("读档：手机进度恢复", (RunSave.game.get("sms_read", []) as Array).has(probe_sms))
	_check("读档：口径恢复",
		str((RunSave.game.get("stated_facts", {}) as Dictionary).get("__probe_fact__", "")) == "probe_val")
	_check("读档：矛盾计数恢复", int(RunSave.game.get("contradictions", 0)) == 1)
	_check("存档摘要写明停在第 2 / 2 轮", RunSave.summary().contains("第 2 / 2 轮"))

	# 开始界面：有存档 → 「继续游戏」可点
	main._show_title()
	_check("有存档时「继续游戏」可点", main.title_continue_btn.disabled == false)
	_check("开始界面摘要写明进度", main.title_info.text.contains("第 2 / 2 轮"))

	# 模拟「关掉再打开」：内存里换成另一局，只剩磁盘上的存档
	RunData.start_new_run(555001)
	gd.sms_read = []
	gd.stated_facts = {}
	gd.contradictions = 0
	gd.interrogator_intel_read = false
	wardrobe.start_run()
	_check("模拟重启后内存里已是另一局", RunData.seed_value == 555001)

	# 点「继续游戏」
	main._show_title()
	main._on_title_continue()
	_check("继续游戏：种子还原", RunData.seed_value == saved_seed)
	_check("继续游戏：轮次还原到第 2 轮", RunData.level_index == saved_level)
	_check("继续游戏：局号还原", RunData.run_index == saved_run)
	_check("继续游戏：背景还原", RunData.background_name() == RunSave.background_name)
	_check("继续游戏：回到准备室（标题界面收起）",
		wardrobe.visible == true and main.title_screen.visible == false)
	_check("继续游戏：标题栏写明第 2 轮",
		wardrobe.run_label.text.contains("第 2 / 2 轮"))
	_check("继续游戏：打扮还原", _dict_eq(wardrobe.model.equipped, saved_equipped))
	_check("继续游戏：手机进度还原", gd.sms_read.has(probe_sms))
	_check("继续游戏：口径还原",
		str(gd.stated_facts.get("__probe_fact__", "")) == "probe_val")
	_check("继续游戏：矛盾计数还原", gd.contradictions == 1)

	# 还原玩家真实存档 + 把测试状态清干净
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf != null:
		wf.store_string(backup if had_file else "{}")
		wf.close()
	RunSave.autosave_enabled = false
	RunSave.clear()

	help_check_overlay = HelpOverlay.new()

func _all_forced_high_exposure(arr: Array) -> bool:
	for it in arr:
		if not OutfitData.is_high_exposure(it):
			return false
	return true

# ------------------------------------------------------------
# 玩法数值 / 界面文案 / 结局文案：全部走 data/story.json
#
# 这一节要证明的不是「常量还在」，而是「改 JSON 真的会改游戏」——
# 所以每一条都先把值改掉、再问一遍，最后还原。
# ------------------------------------------------------------
func _test_story_config() -> void:
	print("\n-- 玩法数值 / 界面文案 / 结局文案：全部走 data/story.json --")
	var sd := ScenarioData

	# ---- 1. 三个新段落都在，而且和出厂兜底同构 ----
	# ★ 第二十九轮加了 contrast_req_base / contrast_req_step（反差值要求自增曲线）
	# ★ 第三十一轮又加了 contrast_per_exposure（反差新算法的换算系数）
	# ★ 第三十三轮：阈值拆成「起效点 / 必出点」，并删掉干扰的暴露值耦合两项 → 34 − 1 + 2 − 2 = 33
	_check("ScenarioData.RULES 有 33 项", sd.RULES.size() == 33)
	_check("ScenarioData.DEFAULT_RULES 有 33 项", sd.DEFAULT_RULES.size() == 33)
	_check("表情 QTE 的斜坡两端都在 rules 里（起效点 / 必出点）",
		sd.RULES.has("exposure_qte_min") and sd.RULES.has("exposure_qte_full"))
	_check("干扰不再受暴露值影响（两个耦合项已删）",
		not sd.RULES.has("interference_min") and not sd.RULES.has("interference_per_exposure"))
	_check("反差值曲线参数在 rules 里，且都是正数",
		int(sd.RULES.get("contrast_req_base", -1)) > 0 and int(sd.RULES.get("contrast_req_step", -1)) > 0)
	var rule_same := true
	for k in sd.DEFAULT_RULES.keys():
		if not sd.RULES.has(k):
			rule_same = false
	_check("RULES 覆盖 DEFAULT_RULES 的每一个键", rule_same)

	_check("ScenarioData.UI 有 6 段", sd.UI.size() == 6)
	var ui_same := true
	for s in ["common", "title", "wardrobe", "interrogation", "feedback", "help"]:
		if not sd.UI.has(s):
			ui_same = false
	_check("UI 含 common / title / wardrobe / interrogation / feedback / help", ui_same)

	_check("DEFAULT_ENDINGS 有 27 条", sd.DEFAULT_ENDINGS.size() == 27)
	var end_all := true
	for b in sd.BACKGROUNDS:
		if sd.endings_of(b).size() != 27:
			end_all = false
	_check("4 套背景各有 27 条结局文案", end_all)
	_check("DossierData.endings() 拿到本局背景那一份", DossierData.endings().size() == 27)

	# ---- 2. 数值：改了 _rules，取的时候立刻变 ----
	var old_rule: Variant = sd._rules.get("pass_suspicion", null)
	sd._rules["pass_suspicion"] = 33.0
	_check("改了 _rules → ScenarioData.rule_f 立刻读到 33",
		is_equal_approx(sd.rule_f("pass_suspicion", 60.0), 33.0))
	_check("改了 _rules → Interrogation._rf 也读到 33（不是缓存的常量）",
		is_equal_approx(interro._rf("pass_suspicion", 60.0), 33.0))
	if old_rule != null:
		sd._rules["pass_suspicion"] = old_rule
	_check("还原后 rule_f 回到原值",
		is_equal_approx(sd.rule_f("pass_suspicion", -1.0), float(old_rule)))

	_check("rule_i 取整数值（combo_len = 3）", sd.rule_i("combo_len", 3) == 3)
	_check("rule_arr 取数组（combo_keys 3 个）",
		(sd.rule_arr("combo_keys", []) as Array).size() == 3)
	_check("rule_f 遇到没写的键 → 用调用点给的兜底",
		is_equal_approx(sd.rule_f("__no_such_rule__", 7.5), 7.5))
	_check("rule_i 遇到没写的键 → 用调用点给的兜底",
		sd.rule_i("__no_such_rule__", 9) == 9)
	# 组合键位是从字母翻成键码的 —— 翻不出来要整组退回出厂
	var cks: Array = interro.combo_keys()
	_check("combo_keys() 翻出 3 个键码", cks.size() == 3)
	_check("combo_keys() 翻出来的是 J / K / L",
		cks == [KEY_J, KEY_K, KEY_L])

	# ---- 3. 界面文案 ----
	_check("ui_t 取到标题", sd.ui_t("title.title", "") == "千面人 · 换装与盘问")
	_check("ui_t 走不存在的路径 → 用调用点给的兜底",
		sd.ui_t("title.__nope__", "兜底") == "兜底")
	_check("ui_t_d 走不存在的路径 → 从 DEFAULT_UI 兜底",
		sd.ui_t_d("common.help_btn") == str(sd.DEFAULT_UI["common"]["help_btn"]))
	_check("ui_arr 取选项字母（4 个）",
		(sd.ui_arr("common.option_letters", []) as Array).size() == 4)
	_check("ui_arr 走不存在的路径 → 用调用点给的兜底",
		(sd.ui_arr("common.__nope__", ["X"]) as Array) == ["X"])

	var old_title: Variant = sd._ui["title"]["title"]
	sd._ui["title"]["title"] = "【测试】标题"
	_check("改了 _ui → ui_t 立刻读到新标题", sd.ui_t("title.title", "") == "【测试】标题")
	sd._ui["title"]["title"] = old_title
	_check("还原后标题回到原值", sd.ui_t("title.title", "") == "千面人 · 换装与盘问")

	# 玩法说明的三套标注：段数对不上时要能退回出厂那套
	_check("玩法说明的准备室标注有 4 段",
		sd.ui_arr_d("help.wardrobe_marks").size() == 4)
	_check("玩法说明的手机标注有 4 段",
		sd.ui_arr_d("help.phone_marks").size() == 4)
	_check("玩法说明的盘问标注有 5 段",
		sd.ui_arr_d("help.interrogation_marks").size() == 5)

	# ---- 4. 结局文案：每套背景一份，互不串味 ----
	var e0: Dictionary = sd.BACKGROUNDS[0]["endings"]
	var e1: Dictionary = sd.BACKGROUNDS[1]["endings"]
	var keep0: Variant = e0["recognized_line"]
	var keep1: Variant = e1["recognized_line"]
	e0["recognized_line"] = "【背景 0 的认出句】"
	e1["recognized_line"] = "【背景 1 的认出句】"
	_check("改背景 0 的结局不影响背景 1（各存一份）",
		str(sd.endings_of(sd.BACKGROUNDS[1])["recognized_line"]) == "【背景 1 的认出句】")

	var keep_bg_id: String = RunData.background_id
	RunData.background_id = str(sd.BACKGROUNDS[0]["id"])
	RunData._bg = {}
	_check("DossierData.end_t 读的是本局背景那一份",
		DossierData.end_t("recognized_line", "") == "【背景 0 的认出句】")
	_check("Interrogation._et 也读本局背景那一份",
		interro._et("recognized_line", "") == "【背景 0 的认出句】")
	RunData.background_id = str(sd.BACKGROUNDS[1]["id"])
	RunData._bg = {}
	_check("换一套背景 → 读到的是另一份",
		DossierData.end_t("recognized_line", "") == "【背景 1 的认出句】")
	RunData.background_id = keep_bg_id
	RunData._bg = {}
	e0["recognized_line"] = keep0
	e1["recognized_line"] = keep1

	_check("end_t 遇到没写的键 → 用调用点给的兜底",
		sd.end_t(sd.BACKGROUNDS[0], "__no_such_ending__", "兜底") == "兜底")
	_check("背景整块没有 endings → 退回出厂模板",
		sd.endings_of({"id": "__no_endings__"}).size() == 27)
	_check("还原后结局文案回到原值",
		str(sd.endings_of(sd.BACKGROUNDS[0])["recognized_line"]) == str(keep0))

	# ---- 5. 编辑器会把 endings 写回 JSON；DumpStory 导出的结构要对得上 ----
	var missing := []
	for b in sd.BACKGROUNDS:
		if not (b as Dictionary).has("endings"):
			missing.append(str((b as Dictionary).get("id", "?")))
	_check("4 套背景的 endings 都实打实存在于数据里（不是靠兜底拼的）", missing.is_empty())


# ------------------------------------------------------------
# 核心：多轮流程（通过 → 下一关 → … → 整局通关 → 再来一局）
# ------------------------------------------------------------
func _test_multi_level_flow() -> void:
	print("\n-- 多轮流程：从第 1 关一路走到整局通关 --")
	main._start_new_run()
	_check("新局回到第 1 轮", RunData.level_number() == 1)
	_check("新局：情报台按新背景重填（12 条归类 + %d 处原貌）" % OutfitData.auto_slots().size(),
		intel.clues_done_count() == OutfitData.auto_slots().size() and intel.unassigned_count() == 0)
	_check("新局原貌已重抽", wardrobe.model.matching_slots().size() == OutfitData.auto_slots().size())

	var run_id := RunData.run_index
	var bg_id := RunData.background_id
	var true_app := RunData.true_appearance().duplicate()

	for lvl in OutfitData.MAX_LEVELS:
		var n := RunData.level_number()
		var acc_before := RunData.acceptance

		_check("第 %d 轮准备室可见" % n, wardrobe.visible == true)
		_check("第 %d 轮接受度 = acceptance_at(%d)" % [n, lvl],
			acc_before == RunData.acceptance_at(lvl))
		_check("第 %d 轮模型接受度同步" % n, wardrobe.model.acceptance == acc_before)
		_check("第 %d 轮模型轮次索引同步" % n, wardrobe.model.level_index == lvl)
		_check("第 %d 轮反差要求 = %d" % [n, int(RunData.levels()[lvl]["contrast_req"])],
			wardrobe.model.contrast_requirement() == int(RunData.levels()[lvl]["contrast_req"]))
		if lvl > 0:
			_check("第 %d 轮开局装备退回原貌（反差归零）" % n, wardrobe.model.total_contrast() == 0)
			_check("第 %d 轮情报进度跨轮保留" % n,
				intel.clues_done_count() == OutfitData.auto_slots().size() and intel.unassigned_count() == 0)

		_prepare_and_enter()
		# 伪装必须成立 —— 断言放在这儿（调用点）而不是 _prepare_and_enter() 里，
		# 那个辅助函数会被条件调用，放里面会让断言总数浮动。
		_check("第 %d 轮伪装成立" % n, wardrobe.model.evaluate()["verdict"] == "pass")
		_check("第 %d 轮已进入盘问" % n, interro.visible == true and wardrobe.visible == false)
		_check("第 %d 轮抽到 6 道题" % n, interro.level_questions().size() == 6)

		_pass_current_level()

		if lvl < OutfitData.MAX_LEVELS - 1:
			_check("第 %d 轮通过 → 结果覆盖层出现" % n, main.overlay.visible == true)
			_check("第 %d 轮通过 → 按钮指向下一轮" % n, main._pending_action == "next_level")
			main._on_overlay_pressed()
			_check("进入第 %d 轮" % (n + 1), RunData.level_number() == n + 1)
			_check("背景跨关不变", RunData.background_id == bg_id)
			# ★ 第四十九轮：出厂 story.json 带了「原貌逐轮递进」（`true_presets.by_level`），
			#   所以「跨轮完全不变」只在**没有配按轮覆写**时才成立。配了覆写时改判两条：
			#     ① 本轮被覆写的槽位 == 覆写值；
			#     ② 没被覆写的槽位仍等于开局那一套（`_apply_preset` 不再每轮重摇）。
			var lv_presets: Array = ScenarioData.true_preset_by_level()
			var lv_override: Dictionary = {}
			if RunData.level_index < lv_presets.size() \
					and not (lv_presets[RunData.level_index] as Dictionary).is_empty():
				lv_override = (lv_presets[RunData.level_index] as Dictionary).get("slots", {})
			var now_app: Dictionary = RunData.true_appearance()
			if lv_override.is_empty():
				_check("原貌跨关不变（本轮没有配按轮覆写）", _dict_eq(now_app, true_app))
			else:
				var miss := []
				for s in lv_override.keys():
					if str(now_app.get(str(s), "")) != str(lv_override[s]):
						miss.append(str(s))
				_check("原貌按本轮覆写生效（%d 个槽位）" % lv_override.size(), miss.is_empty())
				var drift := []
				for s in now_app.keys():
					if lv_override.has(str(s)):
						continue
					if str(now_app[s]) != str(true_app.get(str(s), "")):
						drift.append(str(s))
				_check("没被覆写的槽位仍沿用开局那套（不逐轮重摇）", drift.is_empty())
			_check("局号跨关不变", RunData.run_index == run_id)
			_check("接受度提升", RunData.acceptance > acc_before)
			_check("暴露值上限随之放宽",
				RunData.exposure_cap_at(RunData.level_index) > OutfitData.exposure_cap(acc_before))
			_check("覆盖层已关闭", main.overlay.visible == false)
		else:
			# ★ 第五十二轮：末轮从第 4 轮变成第 2 轮
			_check("第 2 轮通过 → 整局已通关", RunData.is_run_complete() == true)
			_check("已通过 2 轮", RunData.cleared_levels == 2)
			_check("第 2 轮通过 → 通关覆盖层出现", main.overlay.visible == true)
			_check("通关 → 按钮指向新的一局", main._pending_action == "new_run")

			var old_bg := RunData.background_id
			var old_app := RunData.true_appearance().duplicate()
			var old_run := RunData.run_index
			main._on_overlay_pressed()
			_check("重开后局号 +1", RunData.run_index == old_run + 1)
			_check("重开后回到第 1 轮", RunData.level_number() == 1)
			# ★ 接受度跨局保留：整局通关/作废都不会把赚到的还回去
			_check("重开后接受度 = 起始值 + 跨局保留",
				RunData.acceptance == OutfitData.START_ACCEPTANCE + ProfileData.bonus())
			_check("跨局保留确实积累起来了", ProfileData.bonus() > 0)
			_check("重开后已通过关数归零", RunData.cleared_levels == 0)
			_check("重开后情报台按新背景重填",
				intel.clues_done_count() == OutfitData.auto_slots().size() and intel.unassigned_count() == 0)
			var changed := 0
			if RunData.background_id != old_bg:
				changed += 1
			if not _dict_eq(RunData.true_appearance(), old_app):
				changed += 1
			_check("重开后背景或原貌至少有一项变了", changed >= 1)
			_check("重开后准备室可见", wardrobe.visible == true)

# ------------------------------------------------------------
# 核心：说漏嘴 → 本局失败 → 从头开始
# ------------------------------------------------------------
func _test_leak_and_fail_restart() -> void:
	print("\n-- 核心机制：接住 A 才知道的话 = 说漏嘴 --")
	_reveal_all()
	_assign_all()
	_prepare_and_enter()

	var a_idx := _find_question_index("A")
	if a_idx < 0:
		a_idx = _goto_level_with_card_owner("A")
		interro._ended = false
		interro._running = true
		interro.is_qte_active = false
	_check("本局存在含 A 类档案题的轮次", a_idx >= 0)
	if a_idx < 0:
		return

	var a_card := str(interro.level_questions()[a_idx]["card"])
	_check("测试目标确实是 A 的情报", DossierData.owner_of(a_card) == "A")

	# 归类删掉之后，「说漏嘴」不再是「归档出错」的后果 ——
	# 而是「你正面接住了只有 A 才知道的话头」。A 类题的正面回应本身就是真相。
	interro._load_question(a_idx)
	_check("A 类题的正面回应就是「说漏嘴」", interro.current_options[0]["kind"] == "leak")
	# ★ 第二十九轮：不再有 `leak` 字段（它是选项的 tone），从选项里取。
	var leak_line := ""
	for o in (interro.level_questions()[a_idx] as Dictionary).get("options", []):
		if str((o as Dictionary).get("tone", "")) == "leak":
			leak_line = str((o as Dictionary).get("text", ""))
			break
	_check("说漏嘴的台词就是 A 的真相（且非空）",
		leak_line.length() > 4 and str(interro.current_options[0]["text"]).contains(leak_line))

	interro._select_option(0)
	_check("说漏嘴 → 当场暴露", interro._ended == true)
	_check("说漏嘴 → 怀疑度拉满", gd.suspicion_level >= 100.0)
	_check("暴露结局文案已呈现", interro.dialogue_label.text.contains("身份暴露"))
	_check("暴露后不再驱动计时器", interro._running == false)
	_check("暴露后选项全部禁用", interro.option_btns[0].disabled == true)
	_check("暴露后出现结果按钮", interro.result_btn.visible == true)

	print("\n-- 失败 → 回到本轮开始（同一局 · 同一关）--")
	var bg_before := RunData.background_id
	var app_before := RunData.true_appearance().duplicate()
	var run_before := RunData.run_index
	var acc_before := RunData.acceptance
	# ★ 第五十六轮：这里原来写死「重来后回到第 1 轮」—— 但这一局是从上一个测试
	#   （`_test_multi_level_flow`，用 `_start_new_run()` **随机种子**）继承来的，
	#   第 1 轮偶尔抽不到 A 类档案题，本测试就会先 `_goto_level_with_card_owner()`
	#   跳到后面某一轮，于是「回到第 1 轮」自然不成立 —— 一条时好时坏的假失败
	#   （本轮跑第一次挂、第二次过，两次代码完全一样，靠诊断打印才认出来）。
	#   契约本身是「回到**本轮**开始」，所以判据改成「和失败时那一轮相同」；
	#   「从第 2 轮重来仍停在第 2 轮」由 `_test_retry_level_semantics` 钉着。
	var lvl_before := RunData.level_number()

	interro._on_result_pressed()
	_check("失败 → 结果覆盖层出现", main.overlay.visible == true)
	_check("失败 → 按钮指向「重来本轮」", main._pending_action == "retry_level")
	_check("失败时还没有重来（局号未变）", RunData.run_index == run_before)

	main._on_overlay_pressed()
	_check("重来本轮 → 局号不变（还是同一局）", RunData.run_index == run_before)
	_check("重来本轮 → 回到本轮开始（失败在第 %d 轮）" % lvl_before,
		RunData.level_number() == lvl_before)
	_check("重来本轮 → 接受度不退",
		RunData.acceptance == acc_before and RunData.acceptance == OutfitData.START_ACCEPTANCE + ProfileData.bonus())
	_check("重来本轮 → 已通过关数不变", RunData.cleared_levels == 0)
	_check("重来本轮 → 背景不变", RunData.background_id == bg_before)
	_check("重来本轮 → 原貌不变", _dict_eq(RunData.true_appearance(), app_before))
	_check("重来本轮 → 情报台照旧（还是本局那套）",
		intel.clues_done_count() == OutfitData.auto_slots().size() and intel.unassigned_count() == 0)
	_check("重来本轮 → 准备室可见", wardrobe.visible == true)
	_check("重来本轮 → 装备退回 A 的原貌（好重新搭一遍）",
		wardrobe.model.total_contrast() == 0)
	_check("重来本轮 → 模型拿的还是本局原貌",
		_dict_eq(wardrobe.model.true_appearance, RunData.true_appearance()))

# ------------------------------------------------------------
# 第二十一轮：失败 → 回到本轮开始
#
#  用户口径：「失败后返回本轮开始」
#  这条测试把契约钉死：
#    · 同一局、同一关、同一套背景与原貌、同一身强制装备；
#    · 接受度不退，情报进度保留；
#    · **本轮**立下的口径 / 问答记录被回滚，**前面几轮**立下的口径留着；
#    · 局内存档不清 —— 这一局还在进行中。
# ------------------------------------------------------------
func _test_retry_level_semantics() -> void:
	print("\n-- 失败 → 回到本轮开始（回滚本轮，保留跨关）--")
	main._start_new_run(20261011)
	_prepare_and_enter()

	# 第 1 轮：立一条口径（第 2 题就是本轮的新事实）
	interro.set_process(false)
	interro._load_question(_new_fact_index())
	var f0 := str(interro._current_question().get("fact", ""))
	interro._select_option(0)
	_check("第 1 轮立下的口径已记下", f0 != "" and gd.stated_facts.has(f0))

	# 通过第 1 轮 → 进第 2 轮
	interro._finish_interrogation()
	interro._on_result_pressed()
	main._on_overlay_pressed()
	_check("进入第 2 轮", RunData.level_number() == 2)
	_check("跨轮保留：第 1 轮的口径还在", gd.stated_facts.has(f0))

	# 第 2 轮：先摆一套能过的伪装，再立一条**本轮**口径 + 记一条问答记录
	_prepare_and_enter()
	interro.set_process(false)
	var susp_at_open: float = gd.suspicion_level
	var log_at_open: int = gd.answer_log.size()

	# ① 盲区题（kind == blind）—— 答完会进「备注」的问答记录
	var blind_idx := _find_kind_index("blind")
	_check("第 2 轮有盲区题（用来验证问答记录的回滚）", blind_idx >= 0)
	if blind_idx >= 0:
		interro._load_question(blind_idx)
		interro._select_option(0)
	_check("本轮确实多了一条问答记录", gd.answer_log.size() > log_at_open)

	# ② 说法题 —— 立下**本轮**的口径
	interro._load_question(_new_fact_index())
	var f1 := str(interro._current_question().get("fact", ""))
	interro._select_option(0)
	_check("第 2 轮立下的口径已记下", f1 != "" and gd.stated_facts.has(f1))

	var run_before := RunData.run_index
	var bg_before := RunData.background_id
	var app_before := RunData.true_appearance().duplicate()
	var acc_before := RunData.acceptance
	var forced_before: Array = RunData.forced_item_ids().duplicate()
	var clues_before := intel.clues_done_count()

	# 故意失败：怀疑度爆表
	interro._running = true
	interro._ended = false
	gd.suspicion_level = 100.0
	interro._game_over()
	_check("怀疑度爆表 → 结果按钮出现", interro.result_btn.visible == true)
	interro._on_result_pressed()
	_check("失败 → 按钮指向「重来本轮」", main._pending_action == "retry_level")

	main._on_overlay_pressed()

	_check("重来本轮 → 还在第 2 轮", RunData.level_number() == 2)
	_check("重来本轮 → 局号不变", RunData.run_index == run_before)
	_check("重来本轮 → 背景不变", RunData.background_id == bg_before)
	_check("重来本轮 → 原貌不变", _dict_eq(RunData.true_appearance(), app_before))
	_check("重来本轮 → 接受度不退", RunData.acceptance == acc_before)
	_check("重来本轮 → 强制装备不变", _arr_eq(RunData.forced_item_ids(), forced_before))
	_check("重来本轮 → 第 1 轮立的口径留着（跨轮保留）", gd.stated_facts.has(f0))
	_check("重来本轮 → 本轮立的口径被回滚", not gd.stated_facts.has(f1))
	_check("重来本轮 → 问答记录回到进关那一刻", gd.answer_log.size() == log_at_open)
	_check("重来本轮 → 怀疑度回到本轮开局值",
		is_equal_approx(gd.suspicion_level, susp_at_open))
	_check("重来本轮 → 情报进度保留", intel.clues_done_count() == clues_before)
	_check("重来本轮 → 准备室可见", wardrobe.visible == true)
	_check("重来本轮 → 装备退回 A 的原貌", wardrobe.model.total_contrast() == 0)

	# 失败不再清档 —— 这一局还在进行中（临时打开存盘验证一次，随后抹掉）
	var prev_auto: bool = RunSave.autosave_enabled
	RunSave.autosave_enabled = true
	RunSave.clear()
	main._on_outfit_changed()
	_check("重来本轮 → 局内存档还在（这一局可以接着走）", RunSave.has_run)
	RunSave.clear()
	RunSave.autosave_enabled = prev_auto

# ------------------------------------------------------------
# 第二十二轮：内衣内裤的曝光门控（界面侧）
#
#  用户口径：「内裤内衣的反差值和暴露值只有在**能够显示在人物身上**时才会计算，
#            如透明外衣能计算、直接外穿能计算、镂空开档能计算」
#
#  规则本身在 WardrobeTest 里逐条验过；这里验玩家真正看得到的三件事：
#    · 藏起来时卡片上的两行点阵压暗、悬停多一行说明；
#    · 透出来时一切恢复正常；
#    · 换外衣会连带把内衣的暴露值算进去（量表跟着动）。
# ------------------------------------------------------------
func _test_underwear_gate_ui() -> void:
	print("\n-- 内衣内裤的曝光门控（界面侧：点阵压暗 + 悬停说明）--")
	main._start_new_run(20261011)
	_reveal_all()
	_assign_all()
	var m: WardrobeModel = wardrobe.model

	m.equipped["top"] = "top_highneck"       # 盖得严实
	m.equipped["bra"] = "bra_lace"
	# ★ 第二十六轮：`dress` 也是 bra 的开门人（UNDER_GATE["bra"] = [top, dress, robe]）。
	#   本局随机出的原貌可能正是一条吊带连衣裙 —— 那它就会**独立于 top** 把 bra 盖死，
	#   下面「透出来」那一组全都拍不出效果（实测：6 条一起挂）。
	#   这一组验的是 bra ↔ top 的门控，所以把 dress 显式压成「不穿」，隔离掉干扰项。
	m.equipped["dress"] = "dress_none"
	wardrobe._refresh()

	var bra_card: Dictionary = wardrobe.card_refs["bra"][1]   # bra_lace 那张卡
	var tip_hidden: String = (bra_card["btn"] as Button).tooltip_text
	# ★ 第三十一轮：反差值那行点阵已去掉，文案也跟着只说暴露值
	_check("藏着时：悬停写明「不计入暴露值」", tip_hidden.contains("不计入暴露值"))
	_check("藏着时：悬停还写清三条看得见的路", tip_hidden.contains("直接外穿"))
	_check("藏着时：暴露值点阵压暗了",
		(bra_card["e"] as Control).modulate.a < 0.5)
	var e_hidden: int = m.total_exposure()

	m.equipped["top"] = "top_lace"           # 半透 → 透出来
	wardrobe._refresh()
	var tip_shown: String = (wardrobe.card_refs["bra"][1]["btn"] as Button).tooltip_text
	_check("透出来时：悬停不再提「不计入」", not tip_shown.contains("不计入暴露值"))
	_check("透出来时：两行点阵恢复正常不透明度",
		is_equal_approx((wardrobe.card_refs["bra"][1]["e"] as Control).modulate.a, 1.0))
	_check("透出来时：暴露值把内衣那 4 点算进去了",
		m.total_exposure() == e_hidden + 6 + 4)
	_check("换的是上衣 → 内衣卡片的读数说明跟着变（同一张卡，前后文案不同）",
		tip_hidden != tip_shown)

	# 直接外穿：这一层空着，内衣就是最外层
	m.equipped["top"] = "top_none"
	wardrobe._refresh()
	_check("（不穿上衣）时内衣照算", m.counts_toward_totals("bra"))
	_check("（不穿上衣）时门控原因是 bare", m.underwear_visibility("bra") == "bare")

	# ★ 第二十六轮补一条：dress 单独就能开关 bra 的门 —— 这是新槽位带来的新语义。
	#   top 空着（直接外穿），但只要穿着连衣裙，内衣仍然看不见。
	m.equipped["top"] = "top_none"
	m.equipped["dress"] = "dress_sundress"
	wardrobe._refresh()
	_check("穿连衣裙 + 不穿上衣 → 内衣被连衣裙挡住，不算数",
		not m.counts_toward_totals("bra"))
	_check("穿连衣裙 + 不穿上衣 → 门控原因是 hidden（不是 bare）",
		m.underwear_visibility("bra") == "hidden")
	m.equipped["dress"] = "dress_none"
	wardrobe._refresh()

	# 量表读数与模型同步（界面上的数字就是这么来的）
	wardrobe._refresh()
	_check("量表读数 = 模型的总暴露值", str(m.total_exposure()) != "")



# ------------------------------------------------------------
# 第二十三轮：可编辑的流程数据在真实流程里生效
#
#  编辑器能不能改是编辑器冒烟测试的事；这里验**游戏真的按它走**：
#  ① QTE 计划：指定的题准点弹 / 指定「无」就真不出 / 不在表里的题按自动；
#  ② 强制穿着：写死「固定一件 + 几件选一件」之后，准备室与判定都认。
# ------------------------------------------------------------
func _test_editable_flow_data() -> void:
	print("\n-- 可编辑的 QTE 计划：指定的题准点出、指定「无」就真不出 --")
	main._start_new_run(20261011)
	_prepare_and_enter()
	interro.set_process(false)

	# 2 号题指定成「无」；3 号题指定成「表情控制，1.5 秒后出现」
	ScenarioData.set_qte_plan([
		{"qte": "auto", "delay": -1},
		{"qte": "none", "delay": -1},
		{"qte": "expression", "delay": 1.5},
		{"qte": "none", "delay": -1},
	])
	interro._load_question(_new_fact_index())
	_check("指定「无」的题不出 QTE", interro.qte_needed == false and interro.qte_done == true)
	_check("指定「无」的题连延迟也是 0", is_equal_approx(interro.qte_delay_left, 0.0))

	interro._load_question(2)
	_check("指定「表情控制」的题一定要出", interro.qte_needed == true and interro.qte_done == false)
	_check("延迟用的是计划里写的 1.5 秒", is_equal_approx(interro.qte_delay_left, 1.5))
	_check("计划的类型记下来了", interro.qte_plan_kind == "expression")

	interro._process(1.0)
	_check("还没到点 → 面板不弹", interro.is_qte_active == false)
	interro._process(0.6)
	_check("到点了 → 表情面板弹出来", interro.is_qte_active == true)

	ScenarioData.set_qte_plan([])
	interro._cancel_qte()
	interro._load_question(2)
	_check("计划清空后回到自动判定", interro.qte_plan_kind == "auto")

	print("\n-- 可编辑的 QTE 计划：指定的递话准点来一次、且不再随机补 --")
	interro.set_process(false)
	# ★ 第二十九轮：这张计划表是**按题号**索引的，而题序现在由题目清单决定 ——
	#   所以针对「实际要加载的那道题」的下标来写，不要再写死第 2 项。
	var qi_intf := _new_fact_index()
	var plan_intf := []
	for _k in maxi(qi_intf + 1, 1):
		plan_intf.append({"qte": "auto", "delay": -1})
	plan_intf[qi_intf] = {"qte": "interference", "delay": 2.0}
	ScenarioData.set_qte_plan(plan_intf)
	interro._load_question(qi_intf)
	_check("指定的递话被排上了", interro._intf_scheduled == true)
	_check("排期用的是计划里的 2 秒", is_equal_approx(interro._intf_delay_left, 2.0))
	interro._process(1.0)
	_check("1 秒时他还没开口", interro.interference_active == false)
	interro._process(1.1)
	_check("2 秒到 → 他开口了", interro.interference_active == true)
	_check("类型是单键递话", interro.interference_kind == "single")
	interro._end_interference(true)
	_check("拦下之后不再排第二次（指定的那道只来一次）", interro._intf_scheduled == false)
	var cnt: int = interro.interference_count
	interro._process(30.0)
	_check("之后 30 秒内不会再来（老规则的计时器被停掉了）",
		interro.interference_count == cnt and interro.interference_active == false)

	var plan_combo := []
	for _k in maxi(qi_intf + 1, 1):
		plan_combo.append({"qte": "auto", "delay": -1})
	plan_combo[qi_intf] = {"qte": "combo", "delay": 0.0}
	ScenarioData.set_qte_plan(plan_combo)
	interro._load_question(qi_intf)
	interro._process(0.1)
	_check("指定「组合干扰」→ 出来就是组合的", interro.interference_kind == "combo")
	_check("组合干扰还没敲对任何键", interro.combo_index == 0)
	interro._end_interference(false)
	ScenarioData.set_qte_plan([])

	print("\n-- 可编辑的强制穿着：固定一件 + 几件选一件 --")
	var m: WardrobeModel = wardrobe.model
	m.reset_for_level(30, 0, RunData.true_appearance(),
		["panties_lace"], [
			{"pick": "all", "items": ["panties_lace"]},
			{"pick": "any", "items": ["bottom_mini", "bottom_cut"]},
		])
	wardrobe._refresh()
	_check("规则表被模型收下", m.forced_groups.size() == 2)
	m.equipped["panties"] = "panties_plain"
	m.equipped["bottom"] = "bottom_longskirt"
	_check("两条规则都没满足 → 判定不成立", not m.forced_satisfied())
	_check("失败理由按规则逐条写（含「任选一件」）",
		_str_has(m.evaluate()["reasons"], "任选一件"))
	m.equipped["panties"] = "panties_lace"
	m.equipped["bottom"] = "bottom_mini"
	_check("穿上固定那件 + 任选一件里的一件 → 成立", m.forced_satisfied())
	m.equipped["bottom"] = "bottom_cut"
	_check("任选一件里换另一件 → 照样成立", m.forced_satisfied())
	m.equipped["bottom"] = "bottom_longskirt"
	_check("换成组外的 → 又不成立", not m.forced_satisfied())
	_check("强制装备能按规则说人话（供 UI 用）", RunData.forced_rule_lines() is Array)

func _str_has(arr: Array, needle: String) -> bool:
	for x in arr:
		if str(x).contains(needle):
			return true
	return false

func _active_item_count() -> int:
	var n := 0
	for slot in OutfitData.active_slots():
		n += OutfitData.get_items_for_slot(slot).size()
	return n

# ------------------------------------------------------------
# 把情报读全、归类好，然后凑一套能过本轮的伪装并进入盘问。
#
# 注意：这个辅助函数里**不能放 _check** —— 它会被 _goto_level_with_card_owner()
# 条件调用（只在需要换关时才调），断言总数会随局面浮动。踩过这个坑：同一份代码
# 跑出 348 / 349 两个总数，diff 出来是「第 2 轮伪装成立」时有时无。
# 需要断言的地方，在调用点自己 _check。
func _prepare_and_enter() -> void:
	_reveal_all()
	_assign_all()
	var m: WardrobeModel = wardrobe.model
	_build_viable(m)
	wardrobe._refresh()
	print("   [准备] 第 %d 轮伪装：%s" % [RunData.level_number(),
		"✅ 成立" if m.evaluate()["verdict"] == "pass" else "🚨 不成立"])
	wardrobe._on_continue()

# 让本轮以「低怀疑度」收尾，并点掉结果按钮
func _pass_current_level() -> void:
	interro.set_process(false)
	interro._running = true
	interro._ended = false
	gd.suspicion_level = 30.0
	interro._finish_interrogation()
	_check("第 %d 轮判定为通过" % RunData.level_number(), interro._success == true)
	interro._on_result_pressed()

# 凑一套能过当前关的伪装：
#   阶段一 —— 先把暴露在外的缺陷补上（允许反差不变甚至下降）
#   阶段二 —— 在不超上限、不露缺陷的前提下，按「反差 / 暴露」效率贪心堆反差
# 造一套「这一轮过得去」的打扮。
#
# ★ 第二十七轮从「贪心（先补缺陷、再按性价比堆反差）」改成**直接用游戏里那个 DP**
#   （`auto_complete_outfit()`）：
#     · 成装与上装 / 下装互斥之后，贪心那种「逐槽位试探」会凑出事后被拆掉的搭配；
#     · 第 4 轮的反差要求虽然重标过，但贪心本来就低估上限
#       （同一个局面贪心 47 / DP 54），实测第 4 轮直接判「伪装不成立」。
#   DP 正是玩家在准备室里按「🧪 一键达标」跑的那个求解器 ——
#   用它来造测试用的伪装，才代表「玩家真的做得到」。
func _build_viable(m: WardrobeModel) -> void:
	m._equip_defaults()
	m.auto_complete_outfit()

func _reveal_all() -> void:
	for clue in DossierData.appearance_clues():
		intel._reveal(str(clue["id"]))

func _assign_all() -> void:
	for card in DossierData.cards():
		intel._assign(card["id"], "kept" if card["owner"] == "B" else "sealed")

# from 用来跳过第 1 题 —— 第 1 题固定不出 QTE（见 Interrogation.qte_budget_for），
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

# 找到第一道指定 kind 的题（盲区题用）
func _find_kind_index(kind: String) -> int:
	var qs: Array = interro.level_questions()
	for i in qs.size():
		if _q_kind(qs[i] as Dictionary) == kind:
			return i
	return -1

# 找到第 n 道「说法题」（kind == fact）
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

# 题目是否「指向本局背景里真实存在的东西」。
#
# ★ 第二十九轮重写：原来是按四类分别检查各自的字段（answer / leak / made_up…），
#   现在只认新 schema —— 题面 + 选项 + 引用（card / fact）三类都必须成立。
#   比原来更严：以前盲区题只要三段文本非空，现在连「挂了事实就必须真的存在」也查。
func _questions_resolve(arr: Array) -> bool:
	for q in arr:
		var qd: Dictionary = q
		# 题面（新格式 text，旧格式 q）
		if str(qd.get("text", qd.get("q", ""))) == "":
			return false
		# 选项：至少一个，且除「沉默」外都得有文本（否则盘问里会出现空按钮）
		var opts: Array = qd.get("options", [])
		if opts.is_empty():
			return false
		for o in opts:
			var od: Dictionary = o
			if str(od.get("text", "")) == "" and str(od.get("tone", "")) != "silence":
				return false
		# 引用完整性：挂了什么就得真有什么
		var fid := str(qd.get("fact", ""))
		if fid != "" and DossierData.get_fact(fid).is_empty():
			return false
		var cid := str(qd.get("card", ""))
		if cid != "" and DossierData.get_card(cid).is_empty():
			return false
		continue
		if DossierData.get_card(str(qd.get("card", ""))).is_empty():
			return false
	return true

# 一关只抽 2 道档案题，未必含 A 类。在当前局 4 关里找；还找不到就换种子重开。
# 只读数据、不动 UI。
# 只认「不在第 1 题上」的那道 —— 第 1 题的 QTE 额度固定为 0（见 qte_budget_for）。
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

# 拨到「含有指定归属档案题」的那一关并重新进盘问，返回那道题的序号（找不到 -1）
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

func _dict_eq(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if str(a[k]) != str(b.get(k, "")):
			return false
	return true

# 数组按字符串逐项比 —— 强制装备这类 Array[String] 用得上
func _arr_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true

func _run_seed_matches(s: int) -> bool:
	var bg := RunData.background_id
	var app := RunData.true_appearance().duplicate()
	RunData.start_new_run(s)
	var ok: bool = RunData.background_id == bg and _dict_eq(RunData.true_appearance(), app)
	RunData.start_new_run(s)
	return ok and RunData.background_id == bg

func _reasons_contain(ev: Dictionary, kw: String) -> bool:
	for r in ev.get("reasons", []):
		if str(r).contains(kw):
			return true
	return false

func _no_slot_label_has_question() -> bool:
	for slot in OutfitData.active_slots():
		var lab: Label = wardrobe.slot_labels.get(slot)
		if lab != null and lab.text.ends_with("?"):
			return false
	return true

# ★ 第五十二轮：分段计时（与 WardrobeTest 同一套做法）。
#   起因是用户口径「适当减少测试时间」—— 这套端到端测试原本要跑 ~3 分钟，
#   但它几乎不等待帧（只有几次 `await process_frame`），所以时间基本全花在**计算**上。
#   打点方式是「在两段测试之间记一次时间」，不是给每个函数加装饰器 ——
#   这套里有 4 个 `await` 的协程，用动态 `call()` 包起来会把执行顺序弄乱。
var _t_prev := 0
var _marks: Array = []

func _tick(label: String) -> void:
	var now := Time.get_ticks_msec()
	_marks.append([label, now - _t_prev])
	_t_prev = now

func _finish() -> void:
	print("\n=========================================")
	print(" Checks: ", checks, "   Failures: ", failures)
	print(" Result: ", "ALL TESTS PASSED" if failures == 0 else "SOME TESTS FAILED")
	var total_ms := 0
	for m in _marks:
		total_ms += int(m[1])
	print(" 耗时合计 %.1f 秒" % (float(total_ms) / 1000.0))
	if not _marks.is_empty():
		var sorted_m := _marks.duplicate()
		sorted_m.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		print(" 最耗时的前 8 段：")
		for i in mini(8, sorted_m.size()):
			var ms: int = int(sorted_m[i][1])
			var pct := 100.0 * float(ms) / float(maxi(1, total_ms))
			print("   %-30s %7.2f 秒  %5.1f%%" % [str(sorted_m[i][0]), float(ms) / 1000.0, pct])
	print("=========================================")
	get_tree().quit(0 if failures == 0 else 1)
