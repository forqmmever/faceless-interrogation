extends Node

# ============================================================
#  换装系统 + 多轮制单元测试
#  运行: godot --headless --fixed-fps 60 --path <proj> res://tests/WardrobeTest.tscn --quit-after 900
#
#  本测试不依赖任何 UI，只测数据与规则。
#  重点之一：用**动态规划**求出「每轮在全部约束下能达到的最大反差值」，
#  然后对大量随机种子断言 4 关全部可解 —— 这是多轮制唯一真正的安全网。
#  随机原貌一旦抽出一组无解的组合，玩家就会卡死在某一关。
# ============================================================

const PROBE_SEEDS := 40      # 可解性验证用的随机种子数
const NEG := -999999

var checks := 0
var failures := 0

var _slot_items := {}        # slot -> Array of [exp, con, covbits, req, id]

func _check(label: String, cond: bool) -> void:
	checks += 1
	if cond:
		print("  [PASS] ", label)
	else:
		failures += 1
		print("  [FAIL] ", label)

func _ready() -> void:
	print("=========================================")
	print(" Wardrobe System + Multi-Run - Unit Test")
	print("=========================================")

	# 存档层：关掉自动存盘 + 清零。
	# 不这么做的话断言会随「这台机器上玩过几局」而变，
	# 而且测试会把真实的 user://profile.json 写脏。
	ProfileData.autosave_enabled = false
	ProfileData.reset_all()

	_build_slot_cache()

	# ★ 第五十二轮：加**分段计时**。
	#   起因是用户口径「适当减少测试时间」—— 但没有数据就没法知道该砍哪里：
	#   这套里既有毫秒级的纯数据断言，也有几千次 DP 求解（`auto_complete_outfit`
	#   一次要 70~80 ms）。先量出来，再决定动谁。
	#   这份计时**常驻保留**：以后每次加测试都能看到自己那一段花了多少。
	var t_all := Time.get_ticks_msec()
	var sections := [
		["槽位体系", "_test_slots"],
		["下架槽位", "_test_disabled_slots"],
		["妙妙工具", "_test_manual_slot_tool"],
		["数值覆写", "_test_item_overrides"],
		["原貌预设", "_test_true_presets"],
		["背景级覆写", "_test_bg_overrides"],
		["题目出场序号", "_test_question_order"],
		["相册", "_test_photos_v2"],
		["内衣门控", "_test_underwear_gate"],
		["纹身多件", "_test_tattoo_multi"],
		["原貌候选池", "_test_true_pool"],
		["剧本数据", "_test_scenario_data"],
		["每局随机化", "_test_run_randomization"],
		["模型基础", "_test_model_basics"],
		["缺陷权衡", "_test_defect_tradeoff"],
		["暴露上限", "_test_exposure_cap"],
		["反差值", "_test_contrast"],
		["轮次曲线", "_test_level_curve"],
		["可编辑段", "_test_editable_sections"],
		["选关开放", "_test_open_levels"],
		["账号存档", "_test_profile"],
		["强制装备", "_test_forced_items"],
		["强制装备可解性", "_test_forced_solvability"],
		["一键达标", "_test_auto_complete"],
		["短信解锁", "_test_sms_levels"],
		["同行者短信", "_test_companion_sms"],
		["手机文案", "_test_phone_text"],
		["盲区题", "_test_blind_questions"],
		["主人公", "_test_cast"],
		["资产完整性", "_test_assets"],
	]
	var timings: Array = []
	for ent in sections:
		var t0 := Time.get_ticks_msec()
		call(str(ent[1]))
		timings.append([str(ent[0]), Time.get_ticks_msec() - t0])

	print("\n=========================================")
	print(" Checks: ", checks, "   Failures: ", failures)
	print(" Result: ", "ALL TESTS PASSED" if failures == 0 else "SOME TESTS FAILED")
	var total_ms := Time.get_ticks_msec() - t_all
	print(" 耗时合计 %.1f 秒" % (float(total_ms) / 1000.0))
	# 按耗时降序，只看前 8 段（占大头的永远是那几段 DP 重的）
	var sorted_t := timings.duplicate()
	sorted_t.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	print(" 最耗时的前 8 段：")
	for i in mini(8, sorted_t.size()):
		var ms: int = int(sorted_t[i][1])
		var pct := 100.0 * float(ms) / float(maxi(1, total_ms))
		print("   %-18s %7.2f 秒  %5.1f%%" % [str(sorted_t[i][0]), float(ms) / 1000.0, pct])
	print("=========================================")
	get_tree().quit(0 if failures == 0 else 1)

# ------------------------------------------------------------
#  槽位体系（移植自 WTS）
# ------------------------------------------------------------
func _test_slots() -> void:
	print("\n-- 槽位体系（移植自 WTS）--")
	var m := WardrobeModel.new(OutfitData)
	# ★ 第三十七轮：吊袜带整栏并入袜类，槽位 19 → 18
	# ★ 第三十九轮：新增「妙妙工具」一栏，18 → 19
	_check("槽位数量为 19", OutfitData.SLOT_ORDER.size() == 19)
	_check("绘制顺序槽位数一致", OutfitData.PREVIEW_ORDER.size() == 19)
	_check("zorder 表覆盖全部槽位", OutfitData.SLOT_ZORDER.size() == 19)
	_check("已无 garterbelt 槽位（并入袜类）", not OutfitData.SLOT_ORDER.has("garterbelt"))
	_check("garterbelt 不在绘制顺序里", not OutfitData.PREVIEW_ORDER.has("garterbelt"))
	_check("garterbelt 不在 zorder 表里", not OutfitData.SLOT_ZORDER.has("garterbelt"))
	_check("原吊袜带两件已挂到袜类槽", _garter_items_moved_to_stockings())
	_check("含 piercing 穿环槽位", OutfitData.SLOT_ORDER.has("piercing"))
	_check("含 neckwear 颈饰槽位", OutfitData.SLOT_ORDER.has("neckwear"))
	_check("含 gloves 手套槽位", OutfitData.SLOT_ORDER.has("gloves"))
	_check("含 headgear 头饰槽位", OutfitData.SLOT_ORDER.has("headgear"))
	_check("含 dress 整件式槽位（第二十六轮新增）", OutfitData.SLOT_ORDER.has("dress"))
	_check("★ 含 tool 妙妙工具槽位（第三十九轮新增）", OutfitData.SLOT_ORDER.has("tool"))
	_check("★ 妙妙工具排在最后（界面上在服装最下面）",
		OutfitData.SLOT_ORDER[OutfitData.SLOT_ORDER.size() - 1] == "tool")
	_check("★ 妙妙工具也在绘制顺序里", OutfitData.PREVIEW_ORDER.has("tool"))
	_check("绘制顺序按 zorder 递增", _zorder_sorted())
	_check("每个槽位至少 2 件物品", _every_slot_has_items())
	_check("每个槽位都有默认装备定义", _every_slot_has_default())
	_check("默认装备 id 全部存在", _defaults_resolve())
	_check("物品 id 全局唯一", _ids_unique())
	_check("物品 slot 值均在 SLOT_ORDER 内", _slots_valid())
	_check("所有槽位都有默认装备", m.equipped.size() == OutfitData.active_slots().size())

	# ★ 第三十五轮：纹身槽补了 heart / paw 两件（都落左大腿）
	# ★ 第三十六轮：再补四件刻字（bitch / free-use / slave / cum-rag），共 10 件
	# ★ 第四十七轮：爪印扩到胸口与脸颊两处，共 12 件
	# ★ 第五十一轮：脸颊那件按用户口径整件删除 → 11 件
	var tattoo_ids := []
	for it in OutfitData.ITEMS:
		if str(it["slot"]) == "tattoo":
			tattoo_ids.append(str(it["id"]))
	_check("纹身槽现有 11 件", tattoo_ids.size() == 11)
	_check("含大腿心形纹身", tattoo_ids.has("tattoo_heart"))
	_check("含大腿爪印", tattoo_ids.has("tattoo_paw"))
	# ★ 第五十一轮：这一条原来是「胸口 / 脸颊两枚爪印都在」。
	#   脸颊那件删掉之后，改成「胸口在 + 脸颊确实走了」——
	#   留着后半句是为了**防它被误加回来**：整件删除是本轮的明确口径。
	_check("★ 爪印只剩胸口那枚（脸颊的已按口径删除）",
		tattoo_ids.has("tattoo_paw_chest") and not tattoo_ids.has("tattoo_paw_face"))
	_check("★ 四件刻字纹身都在（bitch / free-use / slave / cum-rag）",
		tattoo_ids.has("tattoo_bitch") and tattoo_ids.has("tattoo_freeuse")
		and tattoo_ids.has("tattoo_slave") and tattoo_ids.has("tattoo_cumrag"))
	_check("★ 每件纹身都写了目击描述（第三十五 / 三十六轮补齐）",
		_tattoo_desc_ok())

	# ★ 第三十九轮：从 AU `clothes/genitals/` 引入的平坦贞操笼
	#   （用户口径「引入平坦贞操笼放在下内衣，暴露度取最高」）
	_check("含平坦贞操笼（第三十九轮引入）",
		not OutfitData.get_item("panties_flatcage").is_empty())
	_check("平坦贞操笼挂在下内衣槽",
		str(OutfitData.get_item("panties_flatcage").get("slot", "")) == "panties")
	_check("平坦贞操笼的暴露值 = 下内衣这一栏的最高档",
		int(OutfitData.get_item("panties_flatcage").get("exposure", -1))
		== _max_exposure_of("panties"))

# ------------------------------------------------------------
#  内衣内裤的曝光门控（第二十二轮）
#
#  用户口径：「内裤内衣的反差值和暴露值只有在**能够显示在人物身上**时才会计算，
#            如透明外衣能计算、直接外穿能计算、镂空开档能计算」
#
#  这里把三条路 + 「盖得严实就不算」这条反面，逐条钉死。
# ------------------------------------------------------------
func _test_underwear_gate() -> void:
	print("\n-- 内衣内裤的曝光门控（透明 / 直接外穿 / 镂空开档）--")
	_check("受门控的槽位是 bra 与 panties",
		OutfitData.gated_slots().size() == 2
		and OutfitData.is_gated_slot("bra") and OutfitData.is_gated_slot("panties"))
	_check("bra 的开门人是 top / dress / robe",
		OutfitData.outer_slots_of("bra") == ["top", "dress", "robe"])
	_check("panties 的开门人是 bottom / dress",
		OutfitData.outer_slots_of("panties") == ["bottom", "dress"])
	_check("其余槽位不受门控",
		not OutfitData.is_gated_slot("top") and not OutfitData.is_gated_slot("stockings"))

	# ---- 标注本身：外衣必须显式标 see，空件必须显式标 bare ----
	var kinds := {}
	for it in OutfitData.ITEMS:
		var k := OutfitData.see_through_kind(it)
		if k != "":
			kinds[str(it["id"])] = k
	_check("透明款标的是 sheer（薄纱 / 蕾丝半透）",
		kinds.get("top_sheer", "") == "sheer" and kinds.get("top_lace", "") == "sheer"
		and kinds.get("robe_lace", "") == "sheer" and kinds.get("bottom_pleat", "") == "sheer")
	_check("镂空款标的是 cutout",
		kinds.get("top_corset", "") == "cutout" and kinds.get("top_crop", "") == "cutout"
		and kinds.get("bottom_mini", "") == "cutout" and kinds.get("bottom_hotpants", "") == "cutout")
	# ★ 第二十七轮：这三件按用户口径「降级成普通下装」—— 它们的 cutout 旗当年是拿
	#   旧的高腰 gstring 量的（18/22/30 px 露内裤），换成 lacepanties 之后实测 0 px，
	#   旗子不再成立。现在它们只是普通下装：穿在内裤外面，内裤不算数。
	_check("★ 三件降级的镂空下装现在不标 see（第二十七轮）",
		kinds.get("bottom_cut", "") == "" and kinds.get("bottom_school_navy", "") == ""
		and kinds.get("bottom_slit", "") == "")
	_check("不标 see 的外衣一律露不出来（高领衬衫 / 长裙 / 直筒裤）",
		not OutfitData.is_sheer(OutfitData.get_item("top_highneck"))
		and not OutfitData.is_sheer(OutfitData.get_item("bottom_longskirt"))
		and not OutfitData.is_sheer(OutfitData.get_item("bottom_trousers")))
	_check("两个「（不穿）」外衣标了 bare",
		OutfitData.is_bare(OutfitData.get_item("top_none"))
		and OutfitData.is_bare(OutfitData.get_item("bottom_none")))
	_check("空件不进强制装备池（「强制你别穿」不是一条说得通的指令）",
		_forced_pool_excludes_bare())

	# ---- 三条路逐条验：用真的模型，量 exposed / contrast 两个总和 ----
	# ① 盖得严实 → 两个值都不算
	var m := WardrobeModel.new(OutfitData)
	m.equipped["top"] = "top_highneck"
	m.equipped["bottom"] = "bottom_longskirt"
	m.equipped["bra"] = "bra_lace"          # 暴露 4 / 反差 5
	m.equipped["panties"] = "panties_lace"  # 暴露 5 / 反差 5
	_check("①盖得严实：bra 不计入", not m.counts_toward_totals("bra"))
	_check("①盖得严实：panties 不计入", not m.counts_toward_totals("panties"))
	_check("①盖得严实：门控原因是 hidden", m.underwear_visibility("bra") == "hidden")
	var e_hidden: int = m.total_exposure()
	var c_hidden: int = m.total_contrast()

	# ② 透明外衣 → 两个值都算（上衣由 0 变 6，bra 的 4 点同时生效）
	m.equipped["top"] = "top_lace"          # see = sheer
	_check("②透明外衣：bra 计入了", m.counts_toward_totals("bra"))
	_check("②透明外衣：门控原因是 sheer", m.underwear_visibility("bra") == "sheer")
	_check("②透明外衣：暴露值 = 原值 + 上衣 6 + 内衣 4",
		m.total_exposure() == e_hidden + 6 + 4)
	# ★ 第三十一轮：反差只算上衣与下装 —— 内衣**一个点都不贡献**（老算法里 bra 的 5 点没了）。
	_check("②透明外衣：反差只随上衣变（内衣不再贡献反差）",
		m.total_contrast() == _expect_contrast(m))
	_check("②透明外衣：bra 那 5 点**没有**进反差",
		m.total_contrast() != c_hidden + int(OutfitData.get_item("top_lace")["contrast"])
			+ int(OutfitData.get_item("bra_lace")["contrast"]))
	_check("②透明外衣：panties 仍不计入（下装没换）", not m.counts_toward_totals("panties"))

	# ③ 镂空开档 → 两个值都算
	m.equipped["top"] = "top_corset"        # see = cutout
	_check("③镂空开档：bra 计入了", m.counts_toward_totals("bra"))
	_check("③镂空开档：门控原因是 cutout", m.underwear_visibility("bra") == "cutout")

	# ④ 直接外穿 → 两个值都算（这一层空着，内衣就是最外层）
	m.equipped["top"] = "top_none"
	_check("④直接外穿：bra 计入了", m.counts_toward_totals("bra"))
	_check("④直接外穿：门控原因是 bare", m.underwear_visibility("bra") == "bare")
	_check("④直接外穿：暴露值 = 原值 + 不穿上衣的 9 + 内衣 4",
		m.total_exposure() == e_hidden + int(OutfitData.get_item("top_none")["exposure"]) + 4)

	# ---- 反差值与暴露值走同一条门控 ----
	m.equipped["top"] = "top_highneck"      # 盖回去
	m.equipped["bra"] = "bra_none"          # 暴露 6 / 反差 6，比 bra_lace 更贵
	_check("盖得严实：换成「（不穿内衣）」也不改变暴露值", m.total_exposure() == e_hidden)
	# ★ 第三十一轮：内衣本来就不参与反差了，所以这条现在恒成立（保留它是为了防止回归）
	_check("换成「（不穿内衣）」不改变反差（内衣不参与反差）", m.total_contrast() == c_hidden)
	m.equipped["bottom"] = "bottom_mini"    # see = cutout → 连带 panties 一起点亮
	_check("换上镂空下装 → 内裤立刻计入（门控是连动的）",
		m.counts_toward_totals("panties"))
	_check("连带点亮后暴露值随之上升", m.total_exposure() > e_hidden)

	# ---- 第二十四轮补的两套校服：最短那条开门、普通那条不开 ----
	var school_ids := [
		"top_school_navy", "bottom_school_navy", "shoes_school_navy", "stockings_school_navy",
		"top_school_green", "bottom_school_green", "shoes_school_green", "stockings_school_green",
	]
	var school_ok := true
	for sid in school_ids:
		var sit: Dictionary = OutfitData.get_item(str(sid))
		if sit.is_empty() or not OutfitData.slot_enabled(str(sit.get("slot", ""))):
			school_ok = false
	_check("★ 第二十四轮的两套校服 8 件都在库里、槽位都可用", school_ok)

	var m4 := WardrobeModel.new(OutfitData)
	m4.equipped["panties"] = "panties_lace"
	# ★ 第二十七轮：这身超短校服裙按用户口径「降级成普通下装」—— 不再标 see，
	#   所以它把内裤盖住了（第二十五轮换 lacepanties 之后实测露 0 px，旗子本就不成立）。
	m4.equipped["bottom"] = "bottom_school_navy"
	_check("超短校服裙（已降级成普通下装）：panties 不计入", not m4.counts_toward_totals("panties"))
	_check("超短校服裙：门控原因是 hidden", m4.underwear_visibility("panties") == "hidden")
	m4.equipped["bottom"] = "bottom_school_green"   # 普通及膝校裙，不标 see
	_check("普通及膝校裙：panties 也不计入", not m4.counts_toward_totals("panties"))
	_check("普通及膝校裙：门控原因是 hidden", m4.underwear_visibility("panties") == "hidden")
	# 仍然能开门的下装只剩这三件（超短皮裙 / 超薄百褶短裙 sheer / 黑色皮短裤）
	m4.equipped["bottom"] = "bottom_mini"
	_check("超短皮裙：panties 照常计入（唯一还标 cutout 的短裙）", m4.counts_toward_totals("panties"))
	_check("超短皮裙：门控原因是 cutout", m4.underwear_visibility("panties") == "cutout")

	# ---- 「换上之后会不会超上限」必须按门控后的真实值算 ----
	var m2 := WardrobeModel.new(OutfitData)
	m2.acceptance = 22
	m2.equipped["top"] = "top_highneck"
	m2.equipped["bra"] = "bra_none"         # 藏着的 6 点
	var hidden_e: int = m2.total_exposure()
	_check("藏着的内衣不占预算（换掉它暴露值不变）",
		m2.total_exposure_with({"bra": "bra_plain"}) == hidden_e)
	_check("换上半透上衣后，内衣的暴露值立刻计入",
		m2.total_exposure_with({"top": "top_lace"}) > hidden_e)

	# ---- DP（一键达标 / 可解性）也必须按门控算 —— 否则会给出对不上的「最优解」----
	var m3 := WardrobeModel.new(OutfitData)
	m3.acceptance = 22
	var groups: Array = m3.dp_groups(OutfitData.active_slots())
	var paired := false
	for g in groups:
		if (g["slots"] as Array).has("bra") and (g["slots"] as Array).has("top"):
			paired = true
	_check("DP 把「上衣 + 内衣」并成一组（内衣的贡献取决于外衣）", paired)
	var paired2 := false
	for g in groups:
		if (g["slots"] as Array).has("panties") and (g["slots"] as Array).has("bottom"):
			paired2 = true
	_check("DP 把「下装 + 内裤」并成一组", paired2)
	_check("分组后槽位一个没漏",
		_group_slot_count(groups) == OutfitData.active_slots().size())

# ------------------------------------------------------------
#  纹身的「多件 + 露出门控」（第三十六轮）
#
#  用户口径两条：
#    ① 「可装备的纹身上限设为 2，将纹身暴露度设置为 2」
#    ② 「纹身与内衣内裤处理方法相同，不漏出来时，不计算暴露值反差度」
# ------------------------------------------------------------
func _test_tattoo_multi() -> void:
	print("\n-- 纹身：多件槽位 + 露出门控（第三十六轮）--")

	# ---- ① 多件槽位的声明 ----
	_check("tattoo 是多件槽位，上限 2", OutfitData.is_multi_slot("tattoo")
		and OutfitData.max_equip("tattoo") == 2)
	_check("其余槽位仍是单件", not OutfitData.is_multi_slot("top")
		and OutfitData.max_equip("top") == 1
		and OutfitData.max_equip("bra") == 1)

	# ---- ② 每件纹身的暴露值都是 2（「（无）」除外） ----
	var bad := []
	for it in OutfitData.ITEMS:
		if str(it["slot"]) != "tattoo" or str(it["id"]) == "tattoo_none":
			continue
		if int(it["exposure"]) != 2:
			bad.append("%s=%d" % [it["id"], int(it["exposure"])])
	_check("除「（无）」外每件纹身暴露值都是 2", bad.is_empty())
	if not bad.is_empty():
		print("      偏离的：", ", ".join(bad))
	_check("「（无）」仍然是 0", int(OutfitData.get_item("tattoo_none")["exposure"]) == 0)

	# ---- ③ 按件门控：大腿看下装 / 胸口看上装 / 面颊不受门控 ----
	_check("大腿纹身的开门人是 bottom / dress",
		OutfitData.outer_slots_of_item(OutfitData.get_item("tattoo_bitch")) == ["bottom", "dress"])
	_check("胸口纹身的开门人是 top / dress",
		OutfitData.outer_slots_of_item(OutfitData.get_item("tattoo_slave")) == ["top", "dress"])
	_check("面颊纹身不受门控（没有衣服盖得住脸）",
		not OutfitData.is_gated_item(OutfitData.get_item("tattoo_cheek")))
	_check("内衣仍然走槽位级门控（按件表里没有它）",
		OutfitData.outer_slots_of_item(OutfitData.get_item("bra_lace")) == ["top", "dress", "robe"])

	# ---- ④ 装上 / 装满 / 顶掉 / 再点脱下 ----
	var m := WardrobeModel.new(OutfitData)
	m.acceptance = 40
	_check("开局纹身槽是「（无）」", m.ids_at("tattoo") == ["tattoo_none"])
	m.equip(OutfitData.get_item("tattoo_bitch"))
	_check("装第 1 件后槽里是它", m.ids_at("tattoo") == ["tattoo_bitch"])
	m.equip(OutfitData.get_item("tattoo_slave"))
	_check("装第 2 件后两件并存", m.ids_at("tattoo") == ["tattoo_bitch", "tattoo_slave"])
	_check("实体件计数为 2", m.solid_ids("tattoo").size() == 2)
	m.equip(OutfitData.get_item("tattoo_cumrag"))
	_check("★ 装第 3 件时顶掉最早那件（上限 2）",
		m.ids_at("tattoo") == ["tattoo_slave", "tattoo_cumrag"])
	_check("★ 再点已装备的那件 → 脱下",
		m.toggle(OutfitData.get_item("tattoo_slave"))
		and m.ids_at("tattoo") == ["tattoo_cumrag"])
	_check("装「（无）」= 全部卸掉",
		m.equip(OutfitData.get_item("tattoo_none"))
		and m.ids_at("tattoo") == ["tattoo_none"])

	# ---- ⑤ 门控真的作用在暴露值上 ----
	var g := WardrobeModel.new(OutfitData)
	g.acceptance = 40
	# 大腿纹身 × 下装：下装穿着 = 盖住 → 0；下装「（不穿）」= 露着 → 2
	g.equipped["bottom"] = "bottom_longskirt"        # 不透明长裙
	g.equipped["top"] = "top_highneck"
	g.equipped["tattoo"] = ["tattoo_bitch"]
	_check("大腿纹身被长裙盖住 → 不计入", not g.item_counts("tattoo", "tattoo_bitch"))
	_check("被盖住时「这一槽位不计入」", not g.counts_toward_totals("tattoo"))
	_check("被盖住时这一槽位算 0 点", g.effective_stat("tattoo", "exposure") == 0)
	_check("门控原因是 hidden", g.item_visibility("tattoo", "tattoo_bitch") == "hidden")
	g.equipped["bottom"] = "bottom_none"             # 直接外穿
	_check("下装换成「（不穿）」→ 大腿纹身露出来",
		g.item_counts("tattoo", "tattoo_bitch"))
	_check("露出来之后这一槽位正好算 2 点", g.effective_stat("tattoo", "exposure") == 2)
	g.equipped["bottom"] = "bottom_pleat"            # see = sheer
	_check("半透下装也能透出纹身", g.item_counts("tattoo", "tattoo_bitch"))
	_check("门控原因是 sheer", g.item_visibility("tattoo", "tattoo_bitch") == "sheer")

	# 胸口纹身：下装换开不影响它，上装才是它的开门人
	g.equipped["tattoo"] = ["tattoo_slave"]
	_check("上装还穿着 → 胸口纹身仍被盖住", not g.item_counts("tattoo", "tattoo_slave"))
	g.equipped["top"] = "top_none"
	_check("上装换成「（不穿）」→ 胸口纹身露出来",
		g.item_counts("tattoo", "tattoo_slave"))

	# 面颊纹身不受门控
	g.equipped["tattoo"] = ["tattoo_cheek"]
	_check("面颊纹身恒计入", g.item_counts("tattoo", "tattoo_cheek"))
	_check("面颊纹身的门控原因是 always",
		g.item_visibility("tattoo", "tattoo_cheek") == "always")

	# ---- ⑥ 两件同时露出来 = 4 点；盖住就一分不给 ----
	# 对照组：同样一身衣服、但纹身槽是「（无）」。
	var two := WardrobeModel.new(OutfitData)
	two.acceptance = 40
	two.equipped["top"] = "top_none"
	two.equipped["bottom"] = "bottom_none"
	two.equipped["tattoo"] = ["tattoo_bitch", "tattoo_slave"]
	var two_bare := WardrobeModel.new(OutfitData)
	two_bare.acceptance = 40
	two_bare.equipped["top"] = "top_none"
	two_bare.equipped["bottom"] = "bottom_none"
	_check("★ 两件纹身同时露出来 = 比不穿纹身正好多 4 点",
		two.total_exposure() == two_bare.total_exposure() + 4)
	# 盖回去：纹身一分不给，总量与对照组完全一致
	two.equipped["top"] = "top_highneck"
	two.equipped["bottom"] = "bottom_longskirt"
	var two_bare2 := WardrobeModel.new(OutfitData)
	two_bare2.acceptance = 40
	two_bare2.equipped["top"] = "top_highneck"
	two_bare2.equipped["bottom"] = "bottom_longskirt"
	_check("★ 两件纹身被盖住 → 与不穿纹身一模一样",
		two.total_exposure() == two_bare2.total_exposure())

	# ---- ⑦ 与原貌一致性的口径 ----
	var t := WardrobeModel.new(OutfitData)
	t.acceptance = 40
	_check("纹身槽开局与原貌一致", t._matches_true("tattoo"))
	t.equip(OutfitData.get_item("tattoo_paw"))
	_check("装上纹身后不再与原貌一致", not t._matches_true("tattoo"))

	# ---- ⑧ DP 把多件槽位单独成组，且选项含「一件不穿」 ----
	var d := WardrobeModel.new(OutfitData)
	d.acceptance = 40
	var groups2: Array = d.dp_groups(OutfitData.active_slots())
	var solo := {}
	for gg in groups2:
		var sl: Array = gg["slots"]
		if sl.size() == 1 and str(sl[0]) == "tattoo":
			solo = gg
	_check("★ DP 里纹身自成一个单元素组", not solo.is_empty())
	if not solo.is_empty():
		var has_empty := false
		var has_pair := false
		for o in (solo["opts"] as Array):
			var ids: Array = (o["pick"] as Dictionary).get("tattoo", [])
			if ids == ["tattoo_none"]:
				has_empty = true
			if (ids as Array).size() == 2:
				has_pair = true
		_check("选项里有「一件不穿」", has_empty)
		_check("选项里有两件的组合", has_pair)
	_check("分组后槽位一个没漏（含纹身）",
		_group_slot_count(groups2) == OutfitData.active_slots().size())

	# ---- ⑨ 一键达标后总量与逐件重算一致（多件槽位不能算漏） ----
	var a := WardrobeModel.new(OutfitData)
	a.acceptance = 40
	var rep: Dictionary = a.auto_complete_outfit()
	var sum_e := 0
	for s in OutfitData.active_slots():
		sum_e += a.effective_stat(str(s), "exposure")
	_check("★ 一键达标：暴露值总和 == 逐槽位门控后求和",
		a.total_exposure() == sum_e)
	_check("一键达标不超上限", not a.is_over_cap())
	_check("一键达标后纹身槽是合法的（0 ~ 2 件实体 + 最多 1 个空件）",
		a.solid_ids("tattoo").size() <= 2 and a.ids_at("tattoo").size() >= 1)

func _forced_pool_excludes_bare() -> bool:
	for acc in [0, 6, 12, 24, 40]:
		for it in OutfitData.forced_pool(acc):
			if OutfitData.is_bare(it):
				return false
	return true

func _group_slot_count(groups: Array) -> int:
	var n := 0
	for g in groups:
		n += (g["slots"] as Array).size()
	return n

# ------------------------------------------------------------
#  暂时下架的槽位（DISABLED_SLOTS）
#  契约：下架只影响「玩家能看到的那些」——
#    界面 / 原貌 / 情报 / 相册 / 强制装备池 一律看不到它；
#    而槽位定义、物品、贴图、描述**一件都不能少**（以后要原样恢复）。
# ------------------------------------------------------------
func _test_disabled_slots() -> void:
	print("\n-- 暂时下架的槽位 DISABLED_SLOTS --")
	var off: Array = OutfitData.DISABLED_SLOTS
	# ★ 第五十一轮：配饰（用户口径「去掉配饰一栏」）与妙妙工具
	#   （「妙妙工具暂时去掉」）一并下架 → 5 → 7 项。
	_check("当前下架列表是外袍 + 耳饰 + 手套 + 头饰 + 穿环 + 配饰 + 妙妙工具",
		off.size() == 7 and off.has("robe") and off.has("earrings")
		and off.has("gloves") and off.has("headgear") and off.has("piercing")
		and off.has("accessory") and off.has("tool"))
	_check("下架的槽位仍在 SLOT_ORDER 里（数据没删）",
		OutfitData.SLOT_ORDER.has("robe") and OutfitData.SLOT_ORDER.has("earrings")
		and OutfitData.SLOT_ORDER.has("gloves") and OutfitData.SLOT_ORDER.has("headgear")
		and OutfitData.SLOT_ORDER.has("piercing")
		and OutfitData.SLOT_ORDER.has("accessory") and OutfitData.SLOT_ORDER.has("tool"))
	_check("active_slots() = SLOT_ORDER - DISABLED_SLOTS",
		OutfitData.active_slots().size() == OutfitData.SLOT_ORDER.size() - off.size())
	_check("active_slots() 不含下架的槽位",
		not OutfitData.active_slots().has("robe")
		and not OutfitData.active_slots().has("earrings")
		and not OutfitData.active_slots().has("gloves")
		and not OutfitData.active_slots().has("headgear")
		and not OutfitData.active_slots().has("piercing")
		and not OutfitData.active_slots().has("accessory")
		and not OutfitData.active_slots().has("tool"))
	_check("slot_enabled() 语义正确",
		OutfitData.slot_enabled("top") and not OutfitData.slot_enabled("robe")
		and not OutfitData.slot_enabled("earrings")
		and not OutfitData.slot_enabled("gloves")
		and not OutfitData.slot_enabled("headgear")
		and not OutfitData.slot_enabled("piercing")
		and not OutfitData.slot_enabled("accessory")
		and not OutfitData.slot_enabled("tool"))
	_check("下架槽位对外「一件都没有」",
		OutfitData.get_items_for_slot("robe").is_empty()
		and OutfitData.get_items_for_slot("earrings").is_empty()
		and OutfitData.get_items_for_slot("gloves").is_empty()
		and OutfitData.get_items_for_slot("headgear").is_empty()
		and OutfitData.get_items_for_slot("piercing").is_empty()
		and OutfitData.get_items_for_slot("accessory").is_empty()
		and OutfitData.get_items_for_slot("tool").is_empty())
	_check("下架槽位不进强制装备池", _forced_pool_excludes_disabled())
	_check("下架的物品仍然完整定义着（28 件：4×5 栏 + 配饰 6 + 妙妙工具 2）", _disabled_items_intact())
	_check("下架的物品仍有目击描述（恢复后立刻可用）", _disabled_items_have_desc())
	_check("每局原貌不含下架的槽位", _true_appearance_excludes_disabled())
	_check("每局相册不含下架的槽位", _photos_exclude_disabled())

func _forced_pool_excludes_disabled() -> bool:
	for acc in [0, 6, 12, 24, 40]:
		for it in OutfitData.forced_pool(acc):
			if not OutfitData.slot_enabled(str(it.get("slot", ""))):
				return false
	return true

func _disabled_items_intact() -> bool:
	var n := 0
	for it in OutfitData.ITEMS:
		if not OutfitData.slot_enabled(str(it["slot"])):
			n += 1
	# ★ 第二十七轮：手套与头饰也下架了 → 8 → 16
	#   （robe 4 + earrings 4 + gloves 4 + headgear 4）
	# ★ 第三十七轮：穿环也下架了 → 16 → 20（再加 piercing 4）
	# ★ 第五十一轮：配饰与妙妙工具也下架了 → 20 → 28
	#   （accessory 6 + tool 2）
	#   ★ 配饰那 6 件 = 空件 + 束腰皮带 + 4 件项圈 —— 银质心形吊坠**不算在内**，
	#     它按用户口径挪到颈饰去了，现在是**可见**物品（这正是本条断言的意义：
	#     它替我们抓住「挪栏之后还剩几件真正下架」这件事）。
	return n == 28

func _disabled_items_have_desc() -> bool:
	# 只有「可能是 A 的原貌」的那些才需要目击描述（robe_none / robe_travel）；
	# robe_lace / robe_leather 不在 TRUE_POOL 里，本来就没有描述
	for it in OutfitData.ITEMS:
		if OutfitData.slot_enabled(str(it["slot"])):
			continue
		if not (OutfitData.TRUE_POOL.get(str(it["slot"]), []) as Array).has(str(it["id"])):
			continue
		if ScenarioData.desc_of(str(it["id"])) == "":
			print("      missing ITEM_DESC: ", it["id"])
			return false
	return true

func _true_appearance_excludes_disabled() -> bool:
	for s in range(1, 8):
		RunData.start_new_run(s)
		for slot in RunData.true_appearance().keys():
			if not OutfitData.slot_enabled(str(slot)):
				return false
	return true

func _photos_exclude_disabled() -> bool:
	for s in range(1, 8):
		RunData.start_new_run(s)
		for p in RunData.photos:
			if not OutfitData.slot_enabled(str(p.get("slot", ""))):
				return false
	return true

# ------------------------------------------------------------
#  妙妙工具（MANUAL_SLOTS，第三十九轮）
#
#  用户口径：「在服装最下面新增一栏名称为妙妙工具，此栏专门为减少换装环节难度的
#            设置的，只能手动装备，调试计算反差值时请不要使用」。
#
#  契约与 DISABLED_SLOTS **恰好相反** ——
#    下架 = 玩家**看不到**（界面 / 原貌 / 情报 / 相册 / 强制池全跳过）
#    手动 = 玩家**看得到、点得到**，但**系统从不代劳**：
#      · 界面能看到它（active_slots 含它）
#      · 不进原貌 / 情报 / 相册 / 强制池 / 一键达标
#      · 不进「与原貌一致 / 已改掉 / 相似度」这些统计 → 也就不影响反差值口径
#
#  ★ 第五十一轮：用户口径「妙妙工具暂时去掉」→ `tool` 同时进了 DISABLED_SLOTS。
#    于是上面「看得到、点得到」那一行**当前不成立**（下架优先），
#    但 `MANUAL_SLOTS` 里那条**刻意保留** —— 两件事合起来的效果是：
#      · 现在：玩家看不到这一栏（下架），也就装不上尼古喵尾，
#        「不涨怀疑值」那套机制在代码里照旧存在、但**实际不可达**；
#      · 恢复：把 "tool" 从 DISABLED_SLOTS 里删掉即可，MANUAL_SLOTS 不用动。
#    本段的断言按这个新口径改写（「声明保留」+「当前看不到」两条都要守）。
# ------------------------------------------------------------
func _test_manual_slot_tool() -> void:
	print("\n-- 妙妙工具（只能手动装备的一栏）--")
	# ★ 第五十一轮：用户口径「妙妙工具暂时去掉」→ `tool` 已进 DISABLED_SLOTS。
	#   本段的口径随之改成：**声明仍然保留**（恢复只需从 DISABLED_SLOTS 里删一个
	#   字符串，不用同时记着往 MANUAL_SLOTS 里加回来），而「看得到、点得到」
	#   这一条按现状断言为「看不到」。下面第一条断言就守着「声明别被顺手删掉」。
	_check("MANUAL_SLOTS 目前只有 tool 一栏",
		OutfitData.MANUAL_SLOTS.size() == 1 and OutfitData.MANUAL_SLOTS.has("tool"))
	_check("is_manual_slot() 语义正确",
		OutfitData.is_manual_slot("tool") and not OutfitData.is_manual_slot("top"))
	_check("★ 妙妙工具暂时下架（不在界面可见槽位里）",
		not OutfitData.slot_enabled("tool")
		and not OutfitData.active_slots().has("tool"))
	# ★ 对照式要**先求交集**：`auto_slots()` 的实现是「先按 active_slots 过滤、
	#   再滤掉 MANUAL_SLOTS」，所以当一张槽位**同时**出现在下架表与手动表里时
	#   （`tool` 现在就是），「两边相减」的写法会多减 1
	#   （同一处修正也做在 tools/editor_smoke.js 里）。
	var manual_in_active := 0
	for s in OutfitData.MANUAL_SLOTS:
		if OutfitData.active_slots().has(str(s)):
			manual_in_active += 1
	_check("auto_slots() = active_slots() 去掉「其中标了手动的」",
		OutfitData.auto_slots().size() == OutfitData.active_slots().size() - manual_in_active
		and not OutfitData.auto_slots().has("tool"))
	_check("槽位中文名是「妙妙工具」",
		str(OutfitData.SLOT_NAMES.get("tool", "")) == "妙妙工具")

	# ★ 第五十一轮：这里原来走 `get_items_for_slot("tool")` —— 下架之后它按约定
	#   返回空数组（与 robe 那几条一样），所以改成**直接扫 ITEMS** 数：
	#   这一条要守的恰恰是「下架 ≠ 删数据」，扫 ITEMS 才是它的本意。
	var tool_ids := []
	for it in OutfitData.ITEMS:
		if str(it["slot"]) == "tool":
			tool_ids.append(str(it["id"]))
	_check("妙妙工具有 2 件（空件 + 尼古喵尾）", tool_ids.size() == 2)
	_check("空件 tool_none 是「（不携带）」且标了 bare",
		OutfitData.is_bare(OutfitData.get_item("tool_none")))
	_check("尼古喵尾的名字与介绍都是用户口径那两句",
		str(OutfitData.get_item("tool_tail").get("name", "")) == "尼古喵尾"
		and str(OutfitData.get_item("tool_tail").get("desc", "")) == "喵什么错都没有")
	_check("尼古喵尾不吃暴露值预算（带与不带都不影响暴露值）",
		int(OutfitData.get_item("tool_tail").get("exposure", -1)) == 0)
	_check("默认装备是「不携带」（系统不主动送）", _manual_default_is_bare())
	_check("妙妙工具不进强制装备池", _manual_excluded_from_forced())
	_check("每局原貌不含妙妙工具", _manual_excluded_from_true())
	_check("每局情报不含妙妙工具", _manual_excluded_from_clues())
	_check("每局相册不含妙妙工具", _manual_excluded_from_photos())
	_check("「与原貌一致 / 已改掉」统计不含妙妙工具", _manual_excluded_from_matching())
	_check("一键达标不会替玩家装 / 脱妙妙工具", _manual_excluded_from_auto())

func _manual_default_is_bare() -> bool:
	ProfileData.reset_all()
	RunData.start_new_run(1)
	var m := WardrobeModel.new(OutfitData, RunData.true_appearance(), OutfitData.LEVELS)
	var id := str(m.equipped.get("tool", ""))
	# ★ 第五十一轮：槽位下架后 `equipped` 里**根本没有 tool 这个键**
	#   （默认装备是按 active_slots 铺的）—— 「没有这一栏」与「这一栏是空件」
	#   在「系统不主动送」这件事上等价，所以两种都算通过。
	if id == "":
		return true
	return OutfitData.is_bare(OutfitData.get_item(id))

func _manual_excluded_from_forced() -> bool:
	for acc in [0, 6, 12, 24, 40]:
		for it in OutfitData.forced_pool(acc):
			if OutfitData.is_manual_slot(str(it.get("slot", ""))):
				return false
	return true

func _manual_excluded_from_true() -> bool:
	for s in range(1, 8):
		ProfileData.reset_all()
		RunData.start_new_run(s)
		for slot in RunData.true_appearance().keys():
			if OutfitData.is_manual_slot(str(slot)):
				return false
	return true

func _manual_excluded_from_clues() -> bool:
	for s in range(1, 8):
		ProfileData.reset_all()
		RunData.start_new_run(s)
		for c in RunData.clues:
			if OutfitData.is_manual_slot(str((c as Dictionary).get("slot", ""))):
				return false
	return true

func _manual_excluded_from_photos() -> bool:
	for s in range(1, 8):
		ProfileData.reset_all()
		RunData.start_new_run(s)
		for p in RunData.photos:
			if OutfitData.is_manual_slot(str((p as Dictionary).get("slot", ""))):
				return false
	return true

func _manual_excluded_from_matching() -> bool:
	ProfileData.reset_all()
	RunData.start_new_run(3)
	var m := WardrobeModel.new(OutfitData, RunData.true_appearance(), OutfitData.LEVELS)
	if m.matching_slots().has("tool") or m.changed_slots().has("tool"):
		return false
	# 相似度的分母也必须是 auto_slots（不含妙妙工具），否则口径与分子对不上
	var hit := 0
	for s in OutfitData.auto_slots():
		if m.matching_slots().has(s):
			hit += 1
	return is_equal_approx(m.resemblance(),
		float(hit) / float(OutfitData.auto_slots().size()))

func _manual_excluded_from_auto() -> bool:
	# ★ 第五十一轮改写：`tool` 下架之后，`WardrobeModel.equip()` 会在
	#   **模型层**直接拒绝它（第二十七轮补的那道下架闸），所以原来那套
	#   「先手动装上尼古喵尾、再点一键达标看它还在不在」的做法已经走不通了。
	#   改成验同一件事的两半，反而更严：
	#     ① 下架之后**装不上去**（下架闸没漏）；
	#     ② 一键达标也不会凭空把它装上去。
	ProfileData.reset_all()
	RunData.start_new_run(5)
	var m := WardrobeModel.new(OutfitData, RunData.true_appearance(), OutfitData.LEVELS)
	m.reset_for_level(RunData.acceptance_at(0), 0, RunData.true_appearance(), [])
	if m.equip(OutfitData.get_item("tool_tail")):
		return false                       # 下架了却还能装 → 闸漏了
	m.auto_complete_outfit()
	return str(m.item_at("tool").get("id", "")) == ""

# 某一栏里最高的暴露值（第三十九轮：核对「平坦贞操笼的暴露度取最高」）
func _max_exposure_of(slot: String) -> int:
	var mx := -999
	for it in OutfitData.get_items_for_slot(slot):
		mx = maxi(mx, int(it.get("exposure", 0)))
	return mx

# ------------------------------------------------------------
#  服装数值覆写（第四十轮）
#
#  用户口径：「生成服装的暴露度和接受度编辑器」。
#  纯编辑器是不够的 —— 数值原本写死在 OutfitData.gd 的 ITEMS 里，
#  必须有一条「story.json 改得动它」的通路。这个用例测的就是那条通路：
#  apply_item_overrides() 覆盖之后，**所有**读 ITEMS 的地方都看得到新值。
# ------------------------------------------------------------
func _test_item_overrides() -> void:
	print("\n-- 服装数值覆写（暴露度 / 接受度）--")
	OutfitData.reset_items_to_base()
	var pid := "top_plain"
	var base_exp := int(OutfitData.get_item(pid).get("exposure", -99))
	var base_acc := int(OutfitData.get_item(pid).get("acceptance_req", -99))
	_check("起点是内置值（exposure %d / acceptance_req %d）" % [base_exp, base_acc],
		base_exp >= 0 and base_acc >= 0)

	# ---- 覆写生效 ----
	OutfitData.apply_item_overrides({pid: {"exposure": base_exp + 3, "acceptance_req": base_acc + 2}})
	_check("★ 覆写后 get_item() 拿到新值",
		int(OutfitData.get_item(pid).get("exposure", -99)) == base_exp + 3
		and int(OutfitData.get_item(pid).get("acceptance_req", -99)) == base_acc + 2)
	# 索引缓存必须跟着重建 —— 否则按槽位查还是旧的那一份
	var via_slot := false
	for it in OutfitData.get_items_for_slot("top"):
		if str(it.get("id", "")) == pid:
			via_slot = (int(it.get("exposure", -99)) == base_exp + 3)
	_check("★ 按槽位查（走索引缓存）也是新值 —— 缓存重建了", via_slot)
	_check("applied_item_overrides() 记下了这条", 
		OutfitData.applied_item_overrides().has(pid))

	# ---- 数值真的参与判定（不是只改了个显示值）----
	var m := WardrobeModel.new(OutfitData, {}, OutfitData.LEVELS)
	m.reset_for_level(99, 0, {}, [])
	m.set_ids("top", [pid])
	_check("★ 生效后的暴露值进了模型（改数值真的改判定）",
		m.total_exposure() >= base_exp + 3)

	# ---- 坏数据一律跳过，不能把游戏弄崩 ----
	OutfitData.reset_items_to_base()
	OutfitData.apply_item_overrides({
		"__no_such_item__": {"exposure": 5},          # 未知 id
		pid: {"exposure": 999},                        # 越界
		"top_lace": {"exposure": "不是数字"},           # 类型不对
		"top_crop": {"slot": "bottom"},                # 改槽位 —— 不该被接受
	})
	_check("未知 id / 越界值 / 非数字 / 改槽位 全部被跳过（只作用于 exposure 与 acceptance_req）",
		int(OutfitData.get_item(pid).get("exposure", -99)) == base_exp
		and OutfitData.applied_item_overrides().is_empty())
	_check("改槽位那一条被忽略后，top_crop 还在它原本的槽位",
		str(OutfitData.get_item("top_crop").get("slot", "")) == "top")

	# ---- 还原 ----
	OutfitData.reset_items_to_base()
	_check("reset_items_to_base() 能还原成内置值",
		int(OutfitData.get_item(pid).get("exposure", -99)) == base_exp
		and OutfitData.applied_item_overrides().is_empty())

	# ---- 默认状态：文件里没写这一段时间，什么都不改 ----
	OutfitData.apply_item_overrides({})
	_check("空覆写 = 不做任何改动",
		int(OutfitData.get_item(pid).get("exposure", -99)) == base_exp)
	OutfitData.reset_items_to_base()

# ------------------------------------------------------------
#  原貌预设（第四十轮）
#
#  用户口径：「每局每轮游戏的原貌编辑器，能够从已有的服装选择组成原貌」。
#  两条路：随机池（整套抽）+ 按关覆写（切关换人）。
#  ★ 这里直接测 `_apply_preset()` —— 它才是「从已有服装组成原貌」的落地函数，
#    不依赖磁盘上的 story.json。
# ------------------------------------------------------------
func _test_true_presets() -> void:
	print("\n-- 原貌预设（随机池 / 按关覆写）--")
	var slots: Array = OutfitData.auto_slots()
	# ★ 第四十九轮：下面会临时把 `_true_presets` 换成测试夹具，
	#   收尾必须**还原成全局那份**（以前直接写成 `{}`，那时全局是空的看不出来；
	#   现在全局钉死了四轮原貌，写 `{}` 会让后面所有用例都读到「四轮都不覆写」）。
	#   ★ 先摸一下读取入口，逼 `_ensure_story()` 把 story.json 读进来 ——
	#     否则这里抓到的是一份**还没装数据的空壳**，还原等于清空（实测踩过）。
	ScenarioData.true_preset_by_level()
	var keep_global: Dictionary = (ScenarioData._true_presets as Dictionary).duplicate(true)

	# ---- 默认：随机池为空；按轮覆写**四轮都配齐了** ----
	#   ★ 第四十轮这里断言的是「四轮都不覆写」。第四十九轮按用户口径
	#     「A 的暴露水平随轮次提升 + 收窄最优值区间」，出厂数据改成**四轮全钉死**，
	#     断言也跟着反过来：缺哪一轮，那一轮就退回 TRUE_POOL 随机，
	#     最优值区间立刻重新变宽（用户口径「收窄区间」就白做了）。
	_check("默认没有随机池", ScenarioData.true_preset_pool().is_empty())
	var by_lv: Array = ScenarioData.true_preset_by_level()
	_check("默认的按关覆写**四轮都配齐**（不是「不覆写」）",
		by_lv.size() == OutfitData.level_count()
		and by_lv.all(func(x): return not (x as Dictionary).is_empty()))

	# ---- 一套里只写几件也算数 ----
	ProfileData.reset_all()
	RunData.start_new_run(20261011)
	var one := {"name": "只钉上衣", "slots": {"top": "top_plain"}}
	var app: Dictionary = RunData._apply_preset(one)
	_check("★ 预设里指定的槽位就是它（top → top_plain）",
		str(app.get("top", "")) == "top_plain")
	_check("没写到的槽位照样补全（覆盖全部 %d 个槽位）" % slots.size(),
		app.size() == slots.size())
	_check("没写到的槽位取自原貌候选池",
		(OutfitData.TRUE_POOL.get("hair", []) as Array).has(str(app.get("hair", ""))))

	# ---- 指定空件也是有效指定（「他就是不穿下装」）----
	var bare_one := {"name": "空件", "slots": {"bottom": "bottom_none"}}
	var app2: Dictionary = RunData._apply_preset(bare_one)
	_check("指定空件（「不穿下装」）会被照实采用",
		str(app2.get("bottom", "")) == "bottom_none")

	# ---- 同一份预设、同一个种子 → 结果可复现 ----
	ProfileData.reset_all()
	RunData.start_new_run(777)
	var a1: Dictionary = RunData._apply_preset(one)
	ProfileData.reset_all()
	RunData.start_new_run(777)
	var a2: Dictionary = RunData._apply_preset(one)
	_check("同一预设 + 同一种子 → 结果完全一致（可复现）",
		str(a1) == str(a2))

	# ---- 互斥归一化：一套里同时写了成装与上装 → 只留成装 ----
	var clash := {"name": "冲突", "slots": {"dress": "dress_maid", "top": "top_plain", "bottom": "bottom_mini"}}
	var app3: Dictionary = RunData._apply_preset(clash)
	RunData.true_app = app3.duplicate()
	RunData._normalize_true_exclusive()
	var dress_solid: bool = not OutfitData.is_bare(OutfitData.get_item(str(RunData.true_app.get("dress", ""))))
	_check("★ 一套里「成装 + 上装 + 下装」并写时，归一化后只留成装",
		dress_solid
		and OutfitData.is_bare(OutfitData.get_item(str(RunData.true_app.get("top", ""))))
		and OutfitData.is_bare(OutfitData.get_item(str(RunData.true_app.get("bottom", "")))))

	# ---- 预设清洗：非法项被丢掉（不存在的物品 / 槽位对不上）----
	var dirty := {
		"pool": [
			{"name": "好套", "slots": {"top": "top_plain"}},
			{"name": "坏套", "slots": {"top": "__no_such__"}},
			{"name": "错槽", "slots": {"bottom": "top_plain"}},
			{"name": "空套", "slots": {}},
			null,
		],
		# ★ 第五十二轮：一局 2 轮，所以夹具也降到 2 项
		"by_level": [{"name": "第1轮", "slots": {"hair": "hair_short"}}, null],
	}
	ScenarioData._true_presets = dirty
	var cleaned: Array = ScenarioData.true_preset_pool()
	_check("★ 清洗后被丢掉 4 项，只剩「好套」1 套（实际 %d）" % cleaned.size(),
		cleaned.size() == 1 and str(cleaned[0].get("name", "")) == "好套")
	var lv2: Array = ScenarioData.true_preset_by_level()
	_check("按轮覆写保留位置：第 1 轮有值，第 2 轮是空",
		not (lv2[0] as Dictionary).is_empty()
		and (lv2[1] as Dictionary).is_empty())

	# ---- ★ 未配覆写的关必须「回到基础原貌」，不能粘着上一轮 ----
	#   这个 bug 是端到端探针抓出来的：第 2 轮配了覆写、第 3 轮没配，
	#   第 3 轮却还在用第 2 轮的衣服（true_app 被覆写覆盖后就丢了基础那套）。
	#   修法：基础原貌（base_true_app）整局只算一次，按关覆写只临时顶替它。
	# ★ 第五十二轮：只剩两轮，所以把覆写放在**第 1 轮**、第 2 轮不配 ——
	#   这样「未配的那一轮必须回到基础原貌、不能粘着上一轮的覆写」这条不变式
	#   照样验得到（原来是「第 2 轮配、第 3 轮不配」）。
	ScenarioData._true_presets = {
		"pool": [{"name": "基础套", "slots": {"top": "top_longsleeve"}}],
		"by_level": [{"name": "第1轮", "slots": {"top": "top_highneck"}}, {}],
	}
	ProfileData.reset_all()
	RunData.start_new_run(4242)
	var t1 := str(RunData.true_item("top"))
	RunData.advance_level()
	var t2 := str(RunData.true_item("top"))
	_check("★ 第 1 轮（配了覆写）换成覆写那套：" + t1, t1 == "top_highneck")
	_check("★ 第 2 轮（未配）**回到基础那套**，不粘着第 1 轮：" + t2, t2 == "top_longsleeve")
	# 第 1 轮就配了覆写，于是「回到基础」这件事要在别的轮次上再确认一次：
	# 重开一局、这次两轮都不配覆写 → 两轮都该是基础那套
	ScenarioData._true_presets = {
		"pool": [{"name": "基础套", "slots": {"top": "top_longsleeve"}}],
		"by_level": [{}, {}],
	}
	ProfileData.reset_all()
	RunData.start_new_run(4242)
	var t1b := str(RunData.true_item("top"))
	RunData.advance_level()
	var t2b := str(RunData.true_item("top"))
	_check("两轮都不配覆写时，两轮都用基础那套（且一致）", t1b == t2b and t1b == "top_longsleeve")

	# ★★ 上面那个子用例把夹具换成了「两轮都不配」——下面两条要验的是**配了覆写**的
	#    那套行为，所以这里必须把夹具装回来。
	#    （第五十二轮第一版漏了这一步，于是下面两条拿「两轮都不配」的夹具去跑，
	#      104/105 两条当场假红 —— 是**夹具**的问题，不是产品的。）
	ScenarioData._true_presets = {
		"pool": [{"name": "基础套", "slots": {"top": "top_longsleeve"}}],
		"by_level": [{"name": "第1轮", "slots": {"top": "top_highneck"}}, {}],
	}

	# ---- 从选关面板直接进「配了覆写的那一轮」→ 开局就该用那一轮的覆写 ----
	#   ★ level_index 必须**先**设好再抽原貌（以前它在抽完之后才设，会取错轮次）
	#   ★ 第五十二轮：覆写配在第 1 轮（见上），所以这里直接进第 1 轮
	ProfileData.reset_all()
	RunData.start_new_run(4242, 0)
	_check("★ 直接进第 1 轮时开局原貌就是覆写那套：" + str(RunData.true_item("top")),
		str(RunData.true_item("top")) == "top_highneck")

	# ---- 换原貌时情报要跟着换（条数不变、文案跟着新原貌）----
	ProfileData.reset_all()
	RunData.start_new_run(4242)
	var clue_before := ""
	for c in RunData.clues:
		if str((c as Dictionary).get("slot", "")) == "top":
			clue_before = str((c as Dictionary).get("text", ""))
	RunData.advance_level()
	var clue_after := ""
	for c in RunData.clues:
		if str((c as Dictionary).get("slot", "")) == "top":
			clue_after = str((c as Dictionary).get("text", ""))
	_check("★ 切关换原貌后情报文案跟着换（不是还说着旧的那件）",
		clue_before != "" and clue_after != "" and clue_before != clue_after)
	_check("情报条数不变（还是每个可覆写槽位一条）",
		RunData.clues.size() == OutfitData.auto_slots().size())

	# ★ 收尾必须清干净：上面反复调了 advance_level()，而它会
	#   `ProfileData.add_gain()` —— 接受度是**跨局保留**的，不 reset 就会污染后面所有用例
	#   （实测：不清的话，后面「开局接受度 = START_ACCEPTANCE」当场挂）。
	ScenarioData._true_presets = keep_global
	ProfileData.reset_all()
	RunData.base_true_app = {}

# ------------------------------------------------------------
#  背景级流程覆写（第四十一轮）
#
#  用户口径：「每局游戏应该能够设置不同强制穿着，qte计划，身体缺陷，
#            轮次轮数，原貌」，并补充「原貌也是按背景的四关每轮都可以设置不同的」。
#
#  一局 = 一套背景 + 若干轮。所以「挂在背景上」=「每局都能不同」。
#  这里测的是运行时那条链：背景里写了 → 灌进 OutfitData → 各读取入口看到新值；
#  背景里没写 → 完全回退全局那份（默认行为与以前逐字节相同）。
# ------------------------------------------------------------
func _test_bg_overrides() -> void:
	print("\n-- 背景级流程覆写（每局不同的轮数 / 强制 / QTE / 缺陷 / 原貌）--")
	var bgs: Array = ScenarioData._backgrounds
	if bgs.is_empty():
		_check("背景表非空（否则这条用例是空转）", false)
		return
	var b0: Dictionary = bgs[0]
	var bg_id := str(b0.get("id", ""))

	# ---- 基准：清掉覆写后就是全局那份 ----
	OutfitData.clear_run_overrides()
	ScenarioData.clear_run_overrides()
	var g_levels := OutfitData.level_count()
	var g_forced := OutfitData.forced_rules_at(1).duplicate(true)
	var g_defects := OutfitData.defects().size()
	# ★ 第四十九轮：这一段末尾原来写的是 `ScenarioData._true_presets = {}`，
	#   把**全局那份预设**直接抹掉了 —— 第四十轮时全局是空的，抹了看不出来；
	#   现在全局钉死了四轮原貌，抹掉之后后面所有用例都读到「四轮都不覆写」，
	#   于是「按轮覆写」相关的断言全部假红。改成**先存后还**。
	ScenarioData.true_preset_by_level()      # 逼 _ensure_story() 先读完数据
	var keep_global_presets: Dictionary = (ScenarioData._true_presets as Dictionary).duplicate(true)
	_check("没有覆写时 = 全局那份（%d 轮 / 第 2 轮强制 mode=%s / 缺陷 %d 项）" % [
		g_levels, str(g_forced.get("mode", "")), g_defects], g_levels >= 1)

	# ---- 给第 1 套背景写上五项覆写 ----
	var keep_levels: Array = (b0.get("levels", []) as Array).duplicate(true)
	var keep_forced: Variant = b0.get("forced_rules", null)
	var keep_defects: Variant = b0.get("defects", null)
	var keep_qte: Variant = b0.get("qte_plan", null)
	var keep_presets: Variant = b0.get("true_presets", null)

	var new_levels := [
		{"name": "测试一轮", "acceptance_gain": 7, "contrast_req": 30},
		{"name": "测试二轮", "acceptance_gain": 8},
		{"name": "测试三轮", "acceptance_gain": 0},
	]
	b0["levels"] = new_levels
	b0["forced_rules"] = [
		{"mode": "none", "rules": []},
		{"mode": "fixed", "rules": [{"pick": "all", "items": ["top_longsleeve"]}]},
		{"mode": "none", "rules": []},
	]
	b0["defects"] = [{"id": "neck_brand", "name": "测试缺陷", "slot_hint": "颈侧",
		"cover_tags": ["high_collar"]}]
	b0["qte_plan"] = [{"qte": "expression", "delay": 1.5}, {"qte": "none", "delay": -1.0}]
	b0["true_presets"] = {"pool": [], "by_level": [
		{"name": "一轮原貌", "slots": {"top": "top_plain"}},
		{"name": "二轮原貌", "slots": {"top": "top_highneck"}},
		{"name": "三轮原貌", "slots": {"top": "top_longsleeve"}},
	]}

	OutfitData.apply_run_overrides(bg_id)
	ScenarioData.apply_run_qte_plan(bg_id)
	ScenarioData.apply_run_true_presets(bg_id)

	# ---- ① 轮数 ----
	_check("★ 轮数按背景变（3 条 = 这一局打 3 轮）：%d" % OutfitData.level_count(),
		OutfitData.level_count() == 3)
	_check("RunData.level_count() 同步", RunData.level_count() == 3)
	# ★ 轮次名走的是「两条路」，这里把口径写清楚：
	#   · OutfitData.level_at().name = **全局名** —— 选轮面板在开局前就要用，
	#     那时还没抽背景，所以它拿不到、也不该拿背景的名字；
	#   · RunData.levels() 把**本局背景**的 name / derived_profile 叠上去 —— 游戏里显示的是它。
	_check("覆写里的轮次名就是「测试一轮」",
		str((ScenarioData.bg_levels(bg_id)[0] as Dictionary).get("name", "")) == "测试一轮")
	_check("OutfitData.level_at() 保留的是全局名（不被背景覆写抢先）",
		str(OutfitData.level_at(0).get("name", "")) != "测试一轮")
	_check("覆写的接受度生效（+7）", int(OutfitData.level_at(0).get("acceptance_gain", -1)) == 7)
	_check("覆写的反差要求生效（30）", int(OutfitData.level_at(0).get("contrast_req", -1)) == 30)
	# ★ 第四十九轮：step 从 3 抬到 30（全槽位口径下可达上限大了约 2.9 倍）。
	#   ★★ 同一轮里全局曲线又改成**四关全手写**（149/179/199/224），
	#   于是「背景覆写里留空的那一轮」不再走自增 —— 按「逐条按索引覆写」的语义
	#   它**继承全局那一关的值**（第 2 轮 = 179）。自增机制本身没坏，
	#   由下面「临时清空第 3/4 关再解析」那两条守着。
	var global_req_1 := int((OutfitData.DEFAULT_LEVELS[1] as Dictionary).get("contrast_req", -1))
	_check("背景覆写里留空的那一轮继承全局值（第 2 轮 = %d，实测 %d）" % [
			global_req_1, int(OutfitData.level_at(1).get("contrast_req", -1))],
		int(OutfitData.level_at(1).get("contrast_req", -1)) == global_req_1)

	# ---- ② 强制穿着 ----
	_check("★ 第 2 轮强制 mode=fixed（覆写生效）",
		str(OutfitData.forced_rules_at(1).get("mode", "")) == "fixed")
	_check("强制清单里就是那件长袖",
		OutfitData.forced_groups_at(1).size() == 1
		and (OutfitData.forced_groups_at(1)[0]["items"] as Array).has("top_longsleeve"))

	# ---- ③ 缺陷 ----
	_check("★ 缺陷表按背景换（1 项）", OutfitData.defects().size() == 1)
	_check("缺陷就是覆写那一项",
		str(OutfitData.defects()[0].get("id", "")) == "neck_brand")

	# ---- ④ QTE 计划 ----
	_check("★ QTE 第 1 道按覆写（expression / 1.5s）",
		str(OutfitData.qte_plan_entry(0).get("qte", "")) == "expression"
		and is_equal_approx(float(OutfitData.qte_plan_entry(0).get("delay", -1.0)), 1.5))
	_check("QTE 第 2 道按覆写（none）",
		str(OutfitData.qte_plan_entry(1).get("qte", "")) == "none")

	# ---- ⑤ 原貌（按背景 + 逐轮不同）----
	ProfileData.reset_all()
	RunData.start_new_run(909090)
	_check("抽到的背景就是被覆写的那一套（否则这条用例是空转）",
		RunData.background_id != "")
	var per_level := []
	for li in RunData.level_count():
		RunData.level_index = li
		RunData._roll_true_appearance()
		per_level.append(str(RunData.true_item("top")))
	_check("★ 三轮的原貌各不相同：" + str(per_level),
		per_level == ["top_plain", "top_highneck", "top_longsleeve"])

	# ---- 清掉覆写 → 回到全局那份 ----
	OutfitData.clear_run_overrides()
	ScenarioData.clear_run_overrides()
	_check("clear_run_overrides() 后轮数回到全局（%d）" % OutfitData.level_count(),
		OutfitData.level_count() == g_levels)
	_check("强制穿着回到全局那份",
		str(OutfitData.forced_rules_at(1).get("mode", "")) == str(g_forced.get("mode", "")))
	_check("缺陷回到全局那份（%d 项）" % OutfitData.defects().size(),
		OutfitData.defects().size() == g_defects)

	# 还原背景数据
	b0["levels"] = keep_levels
	for f in [["forced_rules", keep_forced], ["defects", keep_defects],
			["qte_plan", keep_qte], ["true_presets", keep_presets]]:
		var k := str(f[0])
		if f[1] == null:
			b0.erase(k)
		else:
			b0[k] = f[1]
	# ★ 第四十九轮：这里原来写的是 `ScenarioData._true_presets = {}` —— 把**全局那份**
	#   预设直接抹掉了。第四十轮全局是空的，抹了看不出来；现在全局钉死了四轮原貌，
	#   抹掉之后（本用例跑在「原貌候选池」之前）后面所有用例都读到「四轮都不覆写」，
	#   于是「按轮覆写」相关的断言全部假红。改成**先存后还**。
	ScenarioData._true_presets = keep_global_presets
	ProfileData.reset_all()
	RunData.base_true_app = {}

# ------------------------------------------------------------
#  题目出场序号（第四十一轮）
#
#  用户口径：「题目出现顺序也应该可以设置」。
#  做法：题目多一个 `order`。同一轮的固定题按 order 升序；
#  没写 order 的用它在清单里的**下标**当序号 ——
#  所以「一道都不写」时顺序与以前完全一样。
# ------------------------------------------------------------
func _test_question_order() -> void:
	print("\n-- 题目出场序号 order --")
	var qs := [
		{"id": "a", "order": 50},
		{"id": "b", "order": 10},
		{"id": "c", "order": 20},
		{"id": "d", "order": 30},
	]
	var out := RunData._sorted_by_order(qs)
	var ids := []
	for q in out:
		ids.append(str((q as Dictionary).get("id", "")))
	_check("★ 按 order 升序排：" + str(ids), ids == ["b", "c", "d", "a"])

	# 一道都不写 → 顺序不变（用下标当序号）
	var plain := [{"id": "x"}, {"id": "y"}, {"id": "z"}]
	var p2 := []
	for q in RunData._sorted_by_order(plain):
		p2.append(str((q as Dictionary).get("id", "")))
	_check("★ 不写 order 时顺序原样（下标当序号）", p2 == ["x", "y", "z"])

	# 部分写：写了 order 的插队，没写的按原位置
	var mix := [{"id": "m0"}, {"id": "m1", "order": -5}, {"id": "m2"}]
	var m2 := []
	for q in RunData._sorted_by_order(mix):
		m2.append(str((q as Dictionary).get("id", "")))
	_check("★ 只给一道写 order = 把它插到指定位置：" + str(m2), m2 == ["m1", "m0", "m2"])

	# 相同 order → 按原下标决胜（稳定）
	var dup := [{"id": "p", "order": 5}, {"id": "q", "order": 5}]
	var d2 := []
	for q in RunData._sorted_by_order(dup):
		d2.append(str((q as Dictionary).get("id", "")))
	_check("相同 order 时按清单先后决胜（稳定排序）", d2 == ["p", "q"])

	# 真实链路：把某套背景第 1 轮的四道题的 order 打乱，看出题顺序跟着变
	var bgs: Array = ScenarioData._backgrounds
	if bgs.is_empty():
		return
	var b0: Dictionary = bgs[0]
	var keep_q: Array = (b0.get("questions", []) as Array).duplicate(true)
	# 4 道专属第 1 轮的题，order 依次写成 40/10/30/20
	var made := []
	for i in 4:
		made.append({"id": "ordq%d" % i, "level": 0, "order": [40, 10, 30, 20][i],
			"options": [{"tone": "correct", "text": "x"}], "text": "t%d" % i})
	b0["questions"] = made
	ProfileData.reset_all()
	RunData.start_new_run(20261011)
	var got := []
	for q in RunData.questions_for_level(0, 4):
		got.append(str((q as Dictionary).get("id", "")))
	_check("★ 真实出题链路按 order 排：" + str(got),
		got == ["ordq1", "ordq3", "ordq2", "ordq0"])
	b0["questions"] = keep_q
	ProfileData.reset_all()

# ------------------------------------------------------------
#  相册（第四十三轮重写）
#
#  用户口径：「相册里图片的照片只会出现眼镜，发型，上衣，下装，鞋子这五类，
#            并且可能会同时出现，如出现下半身时可以同时有下装和鞋子，
#            但不能有头发眼镜，上半身可以同时有眼镜发型上衣，但不能有鞋子，
#            擦亮后应同时显示多个服装，照片中的服装选取与原貌的暴露值相近的服装，
#            发型与原貌保持一致，照片数量每局开始时有三个，每轮增加两个」
# ------------------------------------------------------------
const PHOTO_SEEDS := 12

func _test_photos_v2() -> void:
	print("\n-- 相册：五类槽位 / 半身分组 / 相邻暴露值 / 每轮 +2 张 --")

	_check("相册只收这五类：" + str(ScenarioData.PHOTO_SLOTS),
		(ScenarioData.PHOTO_SLOTS as Array).size() == 5
		and ScenarioData.PHOTO_SLOTS.has("glasses") and ScenarioData.PHOTO_SLOTS.has("hair")
		and ScenarioData.PHOTO_SLOTS.has("top") and ScenarioData.PHOTO_SLOTS.has("bottom")
		and ScenarioData.PHOTO_SLOTS.has("shoes"))
	_check("上半身组 = 眼镜 / 发型 / 上衣",
		ScenarioData.PHOTO_UPPER == ["glasses", "hair", "top"])
	_check("下半身组 = 下装 / 鞋子",
		ScenarioData.PHOTO_LOWER == ["bottom", "shoes"])
	_check("开局 3 张、每轮 +2 张",
		ScenarioData.PHOTO_COUNT_START == 3 and ScenarioData.PHOTO_COUNT_PER_LEVEL == 2)

	# ---- 开局张数 ----
	ProfileData.reset_all()
	RunData.start_new_run(31415)
	_check("★ 开局正好 3 张（实际 %d）" % RunData.photos.size(),
		RunData.photos.size() == ScenarioData.PHOTO_COUNT_START)

	# ---- 逐种子核对每张照片的合法性 ----
	var bad := []
	var multi := 0        # 统计「一张照片里同时有多件」出现了几次
	var saw_upper := 0
	var saw_lower := 0
	var all_slots := {}
	for k in PHOTO_SEEDS:
		ProfileData.reset_all()
		RunData.start_new_run(50000 + k * 7919)
		for i in RunData.photos.size():
			var p: Dictionary = RunData.photos[i]
			var half := str(p.get("half", ""))
			var items: Array = p.get("items", [])
			if half == ScenarioData.PHOTO_HALF_UPPER:
				saw_upper += 1
			elif half == ScenarioData.PHOTO_HALF_LOWER:
				saw_lower += 1
			else:
				bad.append("半身标记非法：" + half)
			if items.is_empty():
				bad.append("第 %d 张一件都没有" % i)
			if items.size() > 1:
				multi += 1
			var group: Array = ScenarioData.PHOTO_UPPER \
				if half == ScenarioData.PHOTO_HALF_UPPER else ScenarioData.PHOTO_LOWER
			var other: Array = ScenarioData.PHOTO_LOWER \
				if half == ScenarioData.PHOTO_HALF_UPPER else ScenarioData.PHOTO_UPPER
			for e in items:
				var d: Dictionary = e
				var s := str(d.get("slot", ""))
				var shown := str(d.get("shown", ""))
				all_slots[s] = true
				# ① 必须是这五类之一
				if not ScenarioData.PHOTO_SLOTS.has(s):
					bad.append("出现了不该有的槽位：" + s)
				# ② 必须属于它那一组，且**不能**是对面那组
				if not group.has(s):
					bad.append("[%s] 的 %s 不属于这一组" % [half, s])
				if other.has(s):
					bad.append("[%s] 混进了对面那组：%s" % [half, s])
				# ③ 头发 / 眼镜 不能出现在下半身；鞋子不能出现在上半身
				if half == ScenarioData.PHOTO_HALF_LOWER and (s == "hair" or s == "glasses"):
					bad.append("下半身出现了头发 / 眼镜：" + s)
				if half == ScenarioData.PHOTO_HALF_UPPER and s == "shoes":
					bad.append("上半身出现了鞋子")
				# ④ 照片里那件必须存在、且属于该槽位
				var it: Dictionary = OutfitData.get_item(shown)
				if it.is_empty() or str(it.get("slot", "")) != s:
					bad.append("%s 里记的 %s 不是该槽位的物品" % [s, shown])
					continue
				# ⑤ 发型必须与原貌一致
				if s == "hair" and shown != RunData.true_item("hair"):
					bad.append("发型与原貌不一致：%s vs %s" % [shown, RunData.true_item("hair")])
				# ⑥ 其余各件：**排除原貌**，取「暴露值最接近原貌」的那件
				if s != "hair":
					var tid := RunData.true_item(s)
					var te := int(OutfitData.get_item(tid).get("exposure", 0))
					var se := int(it.get("exposure", 0))
					# ★ 第四十四轮：照片不该直接给出答案 —— 非发型件不得等于原貌那件
					if shown == tid:
						bad.append("%s 显示了原貌那件（%s）—— 应该排除" % [s, shown])
					# 最优差要在**排除原貌之后**的候选里算
					var best := 999
					for x in OutfitData.get_items_for_slot(s):
						var xid := str((x as Dictionary).get("id", ""))
						if xid == tid:
							continue
						best = mini(best, absi(int((x as Dictionary).get("exposure", 0)) - te))
					if best < 999 and absi(se - te) != best:
						bad.append("%s 选了 e%d，原貌 e%d（排除原貌后的最优差 %d，实际差 %d）" % [
							s, se, te, best, absi(se - te)])

	_check("★ %d 个种子：每张照片都符合全部约束（问题 %d 条）" % [PHOTO_SEEDS, bad.size()],
		bad.is_empty())
	if not bad.is_empty():
		for m in bad.slice(0, 6):
			print("      · " + m)
	_check("上半身与下半身都出现过（不是一个偏的随机）",
		saw_upper > 0 and saw_lower > 0)
	_check("★ 确实出现过「一张照片里同时有好几件」（%d 张）" % multi, multi > 0)
	_check("照片里出现过的槽位只有那五类：" + str(all_slots.keys()),
		all_slots.size() <= ScenarioData.PHOTO_SLOTS.size())

	# ---- ★ 第四十四轮：点缀（眼镜 / 发型 / 鞋子）整局各自最多一次 ----
	#   用户口径：「鞋子、发型、眼镜这三样在**所有照片里各自最多出现一次**」，
	#   理由「因为这三样东西类型太少」—— 款式少，重复出现容易被玩家对比出答案。
	#   ★ 要跑**完整一局**（逐轮 +2 张）才能验到「累加之后也不重复」。
	var one_of_over := 0
	var one_of_runs := 0
	var one_of_seen := {"glasses": 0, "hair": 0, "shoes": 0}
	var main_repeat := 0
	for k in 24:
		ProfileData.reset_all()
		RunData.start_new_run(880000 + k * 7919)
		for li in range(1, OutfitData.level_count()):
			RunData.advance_level()
		one_of_runs += 1
		var seen := {"glasses": 0, "hair": 0, "shoes": 0}
		for i in RunData.photos.size():
			for e in (RunData.photos[i] as Dictionary).get("items", []):
				var s := str((e as Dictionary).get("slot", ""))
				if seen.has(s):
					seen[s] += 1
		for s in seen.keys():
			one_of_seen[s] = maxi(int(one_of_seen[s]), int(seen[s]))
			if int(seen[s]) > 1:
				one_of_over += 1
		# 主体（上衣 / 下装）不受这条限制 —— 它们本来就该在多张照片里出现
		var top_n := 0
		for i in RunData.photos.size():
			for e in (RunData.photos[i] as Dictionary).get("items", []):
				if str((e as Dictionary).get("slot", "")) == "top":
					top_n += 1
		if top_n > 1:
			main_repeat += 1
	_check("★ %d 局完整跑完：眼镜 / 发型 / 鞋子 各自最多出现一次（超标 %d 次）" % [
		one_of_runs, one_of_over], one_of_over == 0)
	_check("★ 三样的单局出现次数上界都 ≤ 1：" + str(one_of_seen),
		int(one_of_seen["glasses"]) <= 1 and int(one_of_seen["hair"]) <= 1
		and int(one_of_seen["shoes"]) <= 1)
	_check("★ 主体（上衣）**不受**这条限制、可以在多张照片里出现（%d 局如此）" % main_repeat,
		main_repeat > 0)

	# ---- 每轮 +2 张（累加、旧照片保留）----
	ProfileData.reset_all()
	RunData.start_new_run(271828)
	var first_ids := []
	for p in RunData.photos:
		first_ids.append(str(p.get("start_clarity", "")) + str(p.get("half", "")))
	var expect := ScenarioData.PHOTO_COUNT_START
	var count_ok := true
	var kept_ok := true
	for li in range(1, OutfitData.level_count()):
		RunData.advance_level()
		expect += ScenarioData.PHOTO_COUNT_PER_LEVEL
		if RunData.photos.size() != expect:
			count_ok = false
		# 旧照片必须原样保留（累加而不是重抽）
		for i in first_ids.size():
			var now: Dictionary = RunData.photos[i]
			if str(now.get("start_clarity", "")) + str(now.get("half", "")) != first_ids[i]:
				kept_ok = false
	_check("★ 每轮 +2 张：3 → %d（逐轮核对）" % expect, count_ok)
	_check("★ 旧照片原样保留（累加，不是重抽）", kept_ok)
	_check("推进到最后一轮后共 %d 张（实际 %d）" % [
		3 + 2 * (OutfitData.level_count() - 1), RunData.photos.size()],
		RunData.photos.size() == 3 + 2 * (OutfitData.level_count() - 1))

	# ---- 取景框：半身框的比例要与照片视口接近（否则画面留黑边）----
	var vp_ratio := 108.0 / 158.0
	for h in [ScenarioData.PHOTO_HALF_UPPER, ScenarioData.PHOTO_HALF_LOWER]:
		var r: Rect2 = ScenarioData.photo_focus_half(h)
		var ratio := r.size.x / r.size.y
		_check("★ %s 的取景框比例与照片视口接近（%.3f vs %.3f）" % [h, ratio, vp_ratio],
			absf(ratio - vp_ratio) < 0.05)

	# ---- 擦亮：只有「真拍到原貌」的槽位才算已还原 ----
	#   ★ 第四十四轮起照片**排除原貌**，所以非发型件的 `is_true` 应该全是 false；
	#     只有**发型**照旧照实显示原貌（所以它的 `is_true` 是 true）。
	#   ★ 统计要跨多个种子 —— 单一种子可能恰好没抽到发型（实测踩到过）。
	var flag_ok := true        # is_true 与「显示的是不是原貌」是否一致
	var nonhair_true := 0      # 非发型件里「恰好等于原貌」的次数（应为 0）
	var nonhair_total := 0
	var hair_total := 0
	var hair_true := 0
	for k in PHOTO_SEEDS:
		ProfileData.reset_all()
		RunData.start_new_run(160000 + k * 6151)
		for i in RunData.photos.size():
			var p: Dictionary = RunData.photos[i]
			for e in p.get("items", []):
				var d: Dictionary = e
				var s := str(d.get("slot", ""))
				var shown := str(d.get("shown", ""))
				var is_true: bool = bool(d.get("is_true", false))
				if is_true != (shown == RunData.true_item(s)):
					flag_ok = false
				if s == "hair":
					hair_total += 1
					if is_true:
						hair_true += 1
				else:
					nonhair_total += 1
					if is_true:
						nonhair_true += 1
	_check("★ `is_true` 与「显示的是不是原貌那件」完全一致", flag_ok)
	_check("★ 非发型件**一律不出现原貌**（命中 %d 次 / 共抽样 %d 件）" % [
		nonhair_true, nonhair_total], nonhair_true == 0 and nonhair_total > 0)
	_check("★ 发型照旧与原貌一致（%d / %d）" % [hair_true, hair_total],
		hair_total > 0 and hair_true == hair_total)
	ProfileData.reset_all()

# ------------------------------------------------------------
#  原貌候选池（多轮制的基础）
# ------------------------------------------------------------
func _test_true_pool() -> void:
	print("\n-- 原貌候选池 TRUE_POOL --")
	_check("候选池覆盖全部 %d 个槽位" % OutfitData.auto_slots().size(),
		_pool_covers_all_slots())
	_check("池内物品 id 全部存在", _pool_items_resolve())
	_check("池内物品都属于它所在的槽位", _pool_slots_match())
	_check("每个槽位至少 1 个候选", _pool_non_empty())
	_check("池内每件物品都有目击描述（ITEM_DESC）", _pool_has_desc())
	_check("默认原貌取自候选池", _default_true_in_pool())
	# ★ 第四十九轮：下面两条是**配套的一对**，缺一不可 ——
	#   ① 池里必须有中高暴露的候选（否则全槽位求和会退化成
	#      「暴露值 × 系数」的共线关系，改口径就白改了）；
	#   ② 但整体仍不超第 1 关的暴露上限（否则「穿得和 A 一模一样」
	#      这条路被封死，情报台全中变得不可能）。
	#   只满足其中一条都会出问题，所以两条都钉住。
	_check("★ 池里有中高暴露候选（暴露 ≥ 5 的至少 3 件）—— 防共线回归",
		_pool_has_exposed_candidates())
	_check("★ 最坏情况原貌本身不超第 1 关上限 —— 防「无法复现原貌」",
		_pool_within_first_cap())

	print("\n-- 原貌候选池的暴露值上界 --")
	var worst := 0
	for slot in OutfitData.SLOT_ORDER:
		var best := 0
		for id in OutfitData.TRUE_POOL.get(slot, []):
			best = maxi(best, int(OutfitData.get_item(id).get("exposure", 0)))
		worst += best
	print("      最坏情况原貌暴露值合计 = %d（第 1 关上限 %d）" % [
		worst, OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE)])

	# ------------------------------------------------------------
	#  ★ 第四十九轮：按轮覆写的原貌（`true_presets.by_level`）
	#
	#  用户口径：「A 的暴露水平要不要随轮次提升？」→ 逐轮提升。
	#  实现就是给四轮各钉死一套原貌。下面这几条守的是**这套覆写本身**：
	#    · 四轮都配齐 —— 缺哪一轮，那一轮就退回 TRUE_POOL 随机，
	#      最优值区间立刻重新变宽（用户口径「收窄区间」就白做了）；
	#    · id 存在、且挂在它写的那个槽位上；
	#    · 暴露总和逐轮**不降**（A 变露），但第 1 轮不超上限。
	# ------------------------------------------------------------
	print("\n-- 按轮覆写的原貌 true_presets.by_level --")
	var by: Array = ScenarioData.true_preset_by_level()
	_check("按轮覆写覆盖全部 %d 轮" % OutfitData.level_count(),
		by.size() == OutfitData.level_count())
	var all_set := true
	var items_ok := true
	var slots_ok := true
	var totals: Array = []
	for e in by:
		var d: Dictionary = e
		if d.is_empty():
			all_set = false
			continue
		var sl: Dictionary = d.get("slots", {})
		if sl.is_empty():
			all_set = false
			continue
		var t := 0
		for k in sl.keys():
			var it := OutfitData.get_item(str(sl[k]))
			if it.is_empty():
				items_ok = false
				continue
			if str(it.get("slot", "")) != str(k):
				slots_ok = false
			t += int(it.get("exposure", 0))
		totals.append(t)
	_check("两轮都配了原貌覆写（缺一轮就退回随机，最优值区间会重新变宽）", all_set)
	_check("覆写里的物品 id 全部存在", items_ok)
	_check("覆写里的物品都挂在它写的那个槽位上", slots_ok)
	print("      两轮原貌暴露总和 = %s" % str(totals))
	var rising := totals.size() == OutfitData.level_count()
	for i in range(1, totals.size()):
		if int(totals[i]) < int(totals[i - 1]):
			rising = false
	_check("原貌暴露总和逐轮不降（A 逐轮变露）", rising)
	_check("第二轮确实比第一轮露得多", totals.size() > 1 and int(totals[-1]) > int(totals[0]))
	_check("★ 第一轮的原貌自己就穿得起（否则「复现原貌」这条路被堵死）",
		totals.size() > 0 and int(totals[0]) <= OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE))

# ------------------------------------------------------------
#  背景库（随机背景的来源）
# ------------------------------------------------------------
func _test_scenario_data() -> void:
	print("\n-- 背景库 ScenarioData --")
	# 文本数据的来源 —— 从 data/story.json 读，还是回退到了内置 DEFAULT_* 常量。
	# 这里只报「读到没有 / 从哪儿读的」，不做强制断言：两种来源都算正常，
	# 真正的把关在下面那一堆「字段齐全 / id 唯一 / 引用可解析」的断言上，
	# 它们跑的就是当前这份数据 —— 所以 story.json 改坏了，这里会直接红。
	print("   数据来源：", "data/story.json" if ScenarioData.story_from_file else "内置 DEFAULT_* 常量（未找到 story.json）")
	# ★ 第五十三轮：背景可以标成「草稿」（enabled:false）—— 草稿不参与抽取、
	#   也不做下面这一圈内容校验。所以这里与下面都只看**已启用**的那些。
	#   （id 唯一性仍查全部，见 `_bg_ids_unique()` —— 重名是真问题，草稿也躲不过。）
	_check("已启用的背景 ≥ 4 套（草稿不计）", ScenarioData.enabled_backgrounds().size() >= 4)
	_check("至少有一套已启用（否则开局没背景可抽）", ScenarioData.bg_count() >= 1)
	_check("全部背景（含草稿）不少于已启用的",
		ScenarioData.all_bg_count() >= ScenarioData.bg_count())
	_check("性情表读到 ≥ 5 种", ScenarioData.INTERROGATOR_TRAITS.size() >= 5)
	_check("衣物目击描述非空", ScenarioData.ITEM_DESC.size() > 0)
	_check("至少 4 套背景", ScenarioData.bg_count() >= 4)
	_check("背景 id 唯一", _bg_ids_unique())
	_check("每套背景字段齐全", _bg_fields_ok())

	for bg in ScenarioData.enabled_backgrounds():
		var nm := str(bg["name"])
		# ★ 第五十二轮：轮次名改成通用「第一轮 / 第二轮」，每套背景的 `levels` 覆写整段删掉 ——
		#   所以这里不再要求「本套背景自己配了 N 条名字」，而是要求它**不超过**轮数
		#   （0 = 回落全局通用名，这是出厂状态）。
		_check("[%s] 轮次名覆写不超轮数（0 = 回落全局）" % nm,
			(bg["levels"] as Array).size() <= OutfitData.MAX_LEVELS)
		_check("[%s] 身份情报 12 条" % nm, (bg["cards"] as Array).size() == 12)
		_check("[%s] 其中 B 的档案 5 条" % nm, _count_owner(bg, "B") == 5)
		_check("[%s] 其中 A 的禁区 7 条" % nm, _count_owner(bg, "A") == 7)
		_check("[%s] 情报 id 唯一" % nm, _bg_card_ids_unique(bg))
		_check("[%s] 每道题都指向存在的卡" % nm, _bg_questions_resolve(bg))
		_check("[%s] 每道题的选项类型合法、文本齐全（除「沉默」）" % nm, _bg_questions_options(bg))
		_check("[%s] 干扰台词 ≥ 4 条" % nm, (bg["interference_lines"] as Array).size() >= 4)
		_check("[%s] 题目数 ≥ 每轮抽题数" % nm,
			(bg["questions"] as Array).size() >= Interrogation.QUESTIONS_PER_LEVEL)

	print("\n-- 审问者的性情（审问者的情报）--")
	var traits: Array = ScenarioData.interrogator_traits()
	_check("性情表 ≥ 5 种", traits.size() >= 5)
	_check("性情 id 唯一", _trait_ids_unique())
	var bad_t := 0
	var bad_memo := 0
	# ★ 第十三轮：怀疑度轮内只涨不跌 → 所有代价都是正的，守「没有负数」
	var any_negative := false
	var hi_bluff := false
	var hi_evade := false
	var cheap_bluff := false
	var cheap_evade := false
	for t in traits:
		var td: Dictionary = t
		if str(td.get("id", "")) == "" or str(td.get("name", "")) == "" \
			or str(td.get("tag", "")) == "" or str(td.get("desc", "")) == "" \
			or str(td.get("hint", "")) == "":
			bad_t += 1
		if not td.has("bluff_delta") or not td.has("evade_delta"):
			bad_t += 1
		if str(td.get("dangerous", "")) not in ["", "bluff", "evade"]:
			bad_t += 1
		# 手机备忘录第一条记的就是这三条（性格 / 喜好 / 忌讳）
		if str(td.get("memo", "")).length() < 10 \
			or str(td.get("like", "")).length() < 2 \
			or str(td.get("hate", "")).length() < 2:
			bad_memo += 1
		if float(td.get("bluff_delta", 0.0)) < 0.0 or float(td.get("evade_delta", 0.0)) < 0.0:
			any_negative = true
		if float(td.get("bluff_delta", 0.0)) >= 28.0:
			hi_bluff = true
		if float(td.get("evade_delta", 0.0)) >= 28.0:
			hi_evade = true
		if float(td.get("bluff_delta", 0.0)) <= 10.0:
			cheap_bluff = true
		if float(td.get("evade_delta", 0.0)) <= 10.0:
			cheap_evade = true
	# 这三条是「整张表」的聚合断言 —— 必须放在循环外，
	# 放进循环里会在第一轮迭代就断言，那时 neg_bluff 还没轮到「迟钝」置真。
	_check("性情字段齐全（id/name/tag/desc/hint/delta/dangerous）", bad_t == 0)
	_check("每种性情都带备忘录三条（memo / like / hate）", bad_memo == 0)
	_check("★ 没有任何负增量（怀疑度轮内只涨不跌）", not any_negative)
	_check("存在「撒谎重罚」的性情（多疑/精明）", hi_bluff)
	_check("存在「回避重罚」的性情（急躁）", hi_evade)
	_check("存在「撒谎最便宜」的性情（迟钝）", cheap_bluff)
	_check("存在「回避最便宜」的性情（心软）", cheap_evade)
	_check("每个性情 id 都能取回", _trait_lookup_ok())

	print("\n-- 外貌情报句式 --")
	_check("CLUE_FRAME 覆盖全部槽位", _frame_covers_all_slots())
	_check("CLUE_SOURCES 覆盖全部槽位", _sources_covers_all_slots())
	_check("每个槽位至少 2 个来源", _sources_enough())
	_check("ITEM_DESC 与候选池完全对齐", _desc_matches_pool())

# ------------------------------------------------------------
#  每局随机化
# ------------------------------------------------------------
func _test_run_randomization() -> void:
	print("\n-- 每局随机化 RunData --")

	# 固定种子必须完全可复现
	RunData.start_new_run(20261011)
	var bg_a := RunData.background_id
	var ta_a := RunData.true_appearance().duplicate()
	var clue_a := RunData.clues.size()
	var tr_a := RunData.interrogator_trait_id
	RunData.start_new_run(20261011)
	_check("同一种子 → 同一背景", RunData.background_id == bg_a)
	_check("同一种子 → 同一原貌", _dict_eq(RunData.true_appearance(), ta_a))
	_check("同一种子 → 同样条数的外貌情报", RunData.clues.size() == clue_a)
	_check("同一种子 → 同一审问者性情", RunData.interrogator_trait_id == tr_a)

	print("\n-- 审问者性情确实每局在变 --")
	var traits := {}
	for s in range(1, 61):
		RunData.start_new_run(s)
		traits[RunData.interrogator_trait_id] = true
	print("      60 个种子 → %d 种性情" % traits.size())
	_check("多种子能抽到多种性情", traits.size() >= 4)
	_check("抽到的性情都能取回档案", _trait_lookup_ok())

	print("\n-- 随机化确实产生了差异 --")
	var bgs := {}
	var apps := {}
	for s in range(1, 61):
		RunData.start_new_run(s)
		bgs[RunData.background_id] = true
		apps[_app_signature()] = true
	print("      60 个种子 → %d 种背景 / %d 种原貌" % [bgs.size(), apps.size()])
	_check("多种子能抽到多种背景", bgs.size() >= 3)
	_check("多种子能生成多种原貌", apps.size() >= 20)

	print("\n-- 随机原貌的合法性 --")
	var n_slots := OutfitData.auto_slots().size()
	var all_slots_ok := true
	var exposure_ok := true
	var pool_ok := true
	var clue_ok := true
	var source_ok := true
	# ★ 第四十九轮：出厂把四轮的**主干槽位**按轮钉死（story.json `true_presets.by_level`），
	#   所以「取自候选池」要放宽成「取自候选池 ∪ 钉死的预设」——
	#   否则这条会误报（钉死的那几件本来就不在随机池里）。
	ScenarioData.true_preset_by_level()      # 逼 _ensure_story() 先读完数据
	var pinned_by_slot := {}
	for pres in ScenarioData.true_preset_by_level():
		var pslots: Dictionary = (pres as Dictionary).get("slots", {})
		for ps in pslots.keys():
			var pss := str(ps)
			if not pinned_by_slot.has(pss):
				pinned_by_slot[pss] = []
			if not (pinned_by_slot[pss] as Array).has(str(pslots[ps])):
				(pinned_by_slot[pss] as Array).append(str(pslots[ps]))
	for s in range(1, PROBE_SEEDS + 1):
		RunData.start_new_run(s)
		var ta: Dictionary = RunData.true_appearance()
		if ta.size() != n_slots:
			all_slots_ok = false
		var exp := 0
		for slot in OutfitData.auto_slots():
			var id := str(ta.get(slot, ""))
			var pool: Array = OutfitData.TRUE_POOL.get(slot, [])
			# ★ 第二十七轮：成装与上装 / 下装互斥之后，`dress` 这一池**只放空件**
			#   （A 的原貌永远是「上衣 + 下装」，成装留给玩家主动穿）——
			#   所以「取自候选池」这条断言本身不用放宽，dress_none 就在池里。
			if not pool.has(id) and not (pinned_by_slot.get(slot, []) as Array).has(id):
				pool_ok = false
			exp += int(OutfitData.get_item(id).get("exposure", 0))
		if exp > OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE):
			exposure_ok = false
		if RunData.clues.size() != n_slots:
			clue_ok = false
		for c in RunData.clues:
			if str(c.get("source", "")).length() < 2 or str(c.get("text", "")).length() < 6:
				source_ok = false
	_check("每局原貌覆盖全部 %d 个槽位" % n_slots, all_slots_ok)
	_check("每局原貌都取自候选池", pool_ok)
	_check("每局原貌暴露值都不超第 1 关上限", exposure_ok)
	_check("每局生成 %d 条外貌情报" % n_slots, clue_ok)
	_check("每条情报都有来源与文案", source_ok)

	print("\n-- 外貌情报必须与本局原貌一致 --")
	RunData.start_new_run(7)
	var mismatch := 0
	for slot in OutfitData.auto_slots():
		var clue := DossierData.clue_for_slot(slot)
		if clue.is_empty():
			mismatch += 1
			continue
		var want := ScenarioData.clue_text(slot, RunData.true_item(slot))
		if str(clue["text"]) != want:
			mismatch += 1
	_check("%d 条情报文案全部由本局原貌拼出" % n_slots, mismatch == 0)
	_check("DossierData.clue_count() = %d" % n_slots, DossierData.clue_count() == n_slots)

	print("\n-- 按关抽题 --")
	var q0: Array = RunData.questions_for_level(0, Interrogation.QUESTIONS_PER_LEVEL)
	var q1: Array = RunData.questions_for_level(1, Interrogation.QUESTIONS_PER_LEVEL)
	_check("每轮抽 %d 道题" % Interrogation.QUESTIONS_PER_LEVEL,
		q0.size() == Interrogation.QUESTIONS_PER_LEVEL)
	_check("同局同关题目稳定",
		_questions_eq(RunData.questions_for_level(0, Interrogation.QUESTIONS_PER_LEVEL), q0))
	_check("同一局不同关题目不同", not _questions_eq(q0, q1))
	_check("抽出的题都指向存在的卡 / 事实", _questions_resolve_arr(q0))

	# ---- 编排（一关 6 道，★ 第十三轮；题数 8 → 6 见第五十轮）：
	#      第 1 轮：0 新说法 · 1 同行者提问 · 2 ★盲区题 · 3~5 档案题
	#      第 2 轮起：上面三道固定题 + 1 道跨轮复问 + 从通用池补足
	#    ★ 改动点：第 4 道原来是「同关复问」，现在**改回档案题** ——
	#      一轮之内不再复问同一个事实，所以一轮之内也不会出现前后矛盾。
	#      第 1 轮没有「上一轮」，那道位置让给档案题（于是第 1 轮 3 道档案题）。
	#    ★ 第五十轮：题数 8 → 6，通用池从 5 道减到 3 道（第 1 轮）。
	#      通用池里出厂有 8 道档案题，每轮独立洗牌各取所需，四轮都够。
	var f0 := _fact_questions(q0)
	var c0 := _card_questions(q0)
	var comp0 := _companion_questions(q0)
	var b0 := _blind_questions(q0)
	_check("第 1 轮：3 道档案题 + 1 道新说法题 + 1 道同行者提问 + 1 道盲区题",
		c0.size() == 3 and f0.size() == 1 and comp0.size() == 1 and b0.size() == 1)
	# ★ 第二十九轮：题序 = **题目清单的顺序**（固定题先出 → 复问 → 通用池抽取），
	#   不再由代码写死成「档案 / 说法 / 同行者 / 档案 / 档案 / 盲区 / 档案」。
	#   出厂迁移过来的那一份是「新说法 → 同行者 → 盲区 → 档案题…」。
	# ★ 第二十九轮：新 schema 里「没写 recall」就是普通题（默认 false）——
	#   原先这里默认 true 是旧格式的写法（旧格式里 recall 由代码标）。
	_check("第 1 道是本轮新增的说法题（不是复问）",
		_q_kind(q0[0]) == "fact" and not bool((q0[0] as Dictionary).get("recall", false)))
	_check("第 2 道是同行者提问", _q_kind(q0[1]) == "companion")
	_check("第 3 道是盲区题（「完全没给信息的题」）", _q_kind(q0[2]) == "blind")
	_check("第 4~6 道都是档案题（第 1 轮不排复问）",
		_q_kind(q0[3]) == "card" and _q_kind(q0[4]) == "card" and _q_kind(q0[5]) == "card")
	_check("同行者提问打的是本轮刚立下的事实",
		str((q0[1] as Dictionary).get("fact", "")) == str((q0[0] as Dictionary).get("fact", "")))
	_check("同行者提问带 3 个回应", ((q0[1] as Dictionary)["options"] as Array).size() == 3)
	_check("同行者提问带 plant 文案", str((q0[1] as Dictionary).get("plant", "")).length() > 6)

	var nf0 := str((q0[0] as Dictionary).get("fact", ""))
	_check("★ 第 1 轮只有 1 道说法题（没有复问）", f0.size() == 1)
	_check("第 1 轮没有跨轮复问（那道位置让给档案题）", not _has_fact_recall(q0, nf0, 1))

	# 第 2 轮：1 道新事实 + 1 道跨轮复问（★ 不再有同关复问）
	var f1 := _fact_questions(q1)
	_check("第 2 轮有 2 道说法题（1 新 + 1 跨轮复问）", f1.size() == 2)
	var nf1 := str((f1[0] as Dictionary).get("fact", ""))
	_check("第 2 轮问的是新事实", nf1 != nf0)
	var recall_hits := 0
	for q in f1:
		var qd: Dictionary = q
		if not bool(qd.get("recall", false)):
			continue
		var rfid := str(qd.get("fact", ""))
		if rfid == nf1 or rfid == nf0:
			recall_hits += 1
	_check("第 2 轮的复问题都落在已立过口径的事实上", recall_hits == f1.size() - 1)
	_check("第 2 轮有跨轮复问（复问第 1 轮立下的事实）", _has_fact_recall(q1, nf0, 1))

	# ---- 说法题：三个版本 + 官方口径是第一项 ----
	var fact0 := DossierData.get_fact(nf0)
	_check("事实有 3 个候选版本", (fact0.get("values", []) as Array).size() == 3)
	_check("官方口径 = values[0]",
		DossierData.canonical_value(nf0) == str((fact0["values"][0] as Dictionary)["id"]))
	_check("事实至少 2 种问法", (fact0.get("prompts", []) as Array).size() >= 2)
	# ★ 第二十九轮：选项不再是 {id,label}，而是 {text, tone, value}——
	#   版本 id 在 `value` 里，且只有 tone = version 的那些才代表版本。
	var opt_ids := []
	for o in (q0[0] as Dictionary)["options"]:
		var od: Dictionary = o
		if str(od.get("tone", "")) == "version":
			opt_ids.append(str(od.get("value", "")))
	_check("选项就是该事实的三个版本（顺序被打乱但集合一致）",
		opt_ids.size() == 3
		and opt_ids.has(DossierData.canonical_value(nf0)))

	# ---- 每套背景都必须配齐 facts / sms / companion_questions ----
	var bad_bg := 0
	for bid in ScenarioData.background_ids():
		var bg := ScenarioData.get_background(str(bid))
		# ★ 第五十二轮：轮数 4 → 2，事实与短信的下限跟着从 4/3 降到 2/2
		if ScenarioData.facts_of(bg).size() < OutfitData.MAX_LEVELS:
			bad_bg += 1
		if ScenarioData.sms_of(bg).size() < OutfitData.MAX_LEVELS:
			bad_bg += 1
		# ★ 第二十九轮：同行者提问已并入统一题目清单（speaker = companion）
		var comp_n := 0
		for q in (bg.get("questions", []) as Array):
			if str((q as Dictionary).get("speaker", "")) == "companion":
				comp_n += 1
		if comp_n < OutfitData.MAX_LEVELS:
			bad_bg += 1
	_check("每套背景都有 ≥2 个事实 / ≥2 段短信 / ≥2 条同行者提问（第五十二轮：2 轮制）",
		bad_bg == 0)

	# ---- 短信必须能推出一条官方口径，且 value id 合法 ----
	var bad_sms := 0
	for bid in ScenarioData.background_ids():
		var bg := ScenarioData.get_background(str(bid))
		for s in ScenarioData.sms_of(bg):
			var reveals: Array = (s as Dictionary).get("reveals", [])
			if reveals.is_empty():
				bad_sms += 1
			for r in reveals:
				var fid := str((r as Dictionary)["fact"])
				var vid := str((r as Dictionary)["value"])
				if DossierData.fact_value_label(fid, vid).begins_with("("):
					bad_sms += 1
	_check("每段短信都揭示 ≥1 条事实，且 value id 全部合法", bad_sms == 0)

	# ---- 同行者提问：3 个选项、一个能顶回去、value 全部合法 ----
	#      同行者的问题和审讯官的题走同一套判定，所以 value 必须指向真实版本
	var bad_cq := 0
	var bad_cq_val := 0
	var missing_canonical := 0
	# ★ 第二十九轮：同行者提问已并入统一题目清单（speaker = companion）。
	#   注意这里如果还读旧的 companion_questions 段，循环体一次都不会进 ——
	#   三个计数器全是 0，断言会**空转通过**（比失败更隐蔽，所以必须改）。
	var seen_cq := 0
	for bid in ScenarioData.background_ids():
		var bg := ScenarioData.get_background(str(bid))
		for cq in (bg.get("questions", []) as Array):
			var cqd: Dictionary = cq
			if str(cqd.get("speaker", "")) != "companion":
				continue
			seen_cq += 1
			var fid := str(cqd.get("fact", ""))
			var opts: Array = cqd.get("options", [])
			if opts.size() != 3:
				bad_cq += 1
				continue
			var has_pushback := false
			for o in opts:
				var od: Dictionary = o
				# 新 schema：代价在 `suspicion`（老字段叫 delta）
				if float(od.get("suspicion", 0.0)) < 0.0:
					has_pushback = true
				var vid := str(od.get("value", ""))
				if vid != "" and ScenarioData.fact_value_label(bg, fid, vid) == "":
					bad_cq_val += 1
			if not has_pushback:
				bad_cq += 1
			# 顶回去的那个必须就是 B 的官方说法（新 schema 里在 options 里按 value 找）
			var canon := ScenarioData.canonical_value(bg, fid)
			var has_canon := false
			for o in opts:
				if str((o as Dictionary).get("value", "")) == canon:
					has_canon = true
			if not has_canon:
				missing_canonical += 1
		# ★ 第五十二轮：每套背景的同行者提问从 4 条降到 2 条 → 4 套共 8 条
	_check("样本里确实查到了同行者提问（否则这几条断言是空转）", seen_cq >= 8)
	_check("每条同行者提问都有 3 个选项且至少一个能顶回去", bad_cq == 0)
	_check("同行者提问的每个 value 都能解析成真实版本", bad_cq_val == 0)
	_check("同行者提问「顶回去」的那个就是官方口径", missing_canonical == 0)

	# ---- 照片：清晰度上限与阈值 ----
	var bad_photo := 0
	for bid in ScenarioData.background_ids():
		RunData.start_new_run(9000 + int(bid.hash() % 1000))
		for i in RunData.photos.size():
			var ph: Dictionary = RunData.photo_at(i)
			# ★ 第四十三轮：取景框按**半身**取（照片是一段身体，不是一处特写）
			if ScenarioData.photo_focus_half(str(ph.get("half", ""))) == Rect2():
				bad_photo += 1
			if int(ph["max_wipes"]) < 1:
				bad_photo += 1
	_check("每张照片都能对上一个裁剪区域，且至少能擦 1 次", bad_photo == 0)

# ------------------------------------------------------------
#  换装模型（用默认原貌，与随机化无关）
# ------------------------------------------------------------
func _test_model_basics() -> void:
	print("\n-- 初始化 --")
	var m := WardrobeModel.new(OutfitData)
	_check("初始接受度为 0", m.acceptance == 0)
	_check("模型使用了默认原貌", _dict_eq(m.true_appearance, OutfitData.TRUE_APPEARANCE))
	_check("开局即 A 的原貌", m.matching_slots().size() == OutfitData.auto_slots().size())
	_check("开局反差值为 0（一眼就会被认出）", m.total_contrast() == 0)
	_check("开局相似度为 1.0", is_equal_approx(m.resemblance(), 1.0))
	_check("原貌本身已遮住全部缺陷", m.exposed_defects().is_empty())

	print("\n-- 传入自定义原貌（模拟随机局）--")
	var custom := {
		"hair": "hair_long", "headgear": "head_hat", "glasses": "glasses_round",
		"earrings": "ear_stud", "makeup": "makeup_light", "piercing": "piercing_none",
		"tattoo": "tattoo_none", "neckwear": "neck_none", "top": "top_plain",
		"bra": "bra_plain", "gloves": "gloves_none", "accessory": "acc_belt",
		"bottom": "bottom_trousers", "panties": "panties_plain",
		"stockings": "stockings_opaque", "shoes": "shoes_boots", "robe": "robe_none",
		"dress": "dress_none",
	}
	var mc := WardrobeModel.new(OutfitData, custom)
	_check("自定义原貌下开局仍是 0 反差", mc.total_contrast() == 0)
	_check("自定义原貌被完整套用", mc.matching_slots().size() == OutfitData.auto_slots().size())
	_check("自定义原貌下短袖+空脖子 → 两处缺陷都暴露", mc.exposed_defects().size() == 2)
	_check("换上高领长袖后两处缺陷一起遮住",
		_try_equip(mc, "top_highneck") and mc.exposed_defects().is_empty())

	print("\n-- 暴露值上限公式 --")
	_check("接受度0 -> 上限10", OutfitData.exposure_cap(0) == 10)
	_check("接受度5 -> 上限20", OutfitData.exposure_cap(5) == 20)
	# ★ 第四十九轮：起始接受度 10 → 14（用户口径「起始低接受度时搭配太少」），
	#   所以开局上限 30 → 38。
	_check("接受度%d（开局）-> 上限%d" % [OutfitData.START_ACCEPTANCE,
			OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE)],
		OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE) == 38)

	print("\n-- 接受度门槛 --")
	var corset := OutfitData.get_item("top_corset")
	_check("束身马甲需接受度9", int(corset["acceptance_req"]) == 9)
	_check("接受度0时无法装备", m.can_equip(corset) == false)
	_check("equip() 被拒绝返回 false", m.equip(corset) == false)
	m.acceptance = 9
	_check("接受度9时可装备", m.can_equip(corset) == true)

	print("\n-- 反差值方向 --")
	_check("反差值越高越安全（当前设定）", OutfitData.CONTRAST_HIGHER_IS_SAFER == true)

	# ---- ★ 第三十一轮：新算法的三条不变量 ----
	var mm := WardrobeModel.new(OutfitData)
	# ★ 注意：新模型的接受度是 0，而待会儿要装的 top_lace 需要接受度 6 ——
	#   不放开的话 equip() 会直接拒绝，反差永远是 0（第一次就踩了）。
	mm.acceptance = 20
	# ★ 第四十九轮：用户口径「游戏的反差应该对所有槽位求和」——
	#   原来的白名单 `CONTRAST_SLOTS := ["top","bottom"]` 改成**排除表**
	#   `CONTRAST_EXCLUDED_SLOTS`，且内容为空（= 一个槽位都不排除）。
	_check("新算法（第四十九轮）：全部槽位都参与反差（排除表为空）",
		WardrobeModel.CONTRAST_EXCLUDED_SLOTS.is_empty())
	_check("新算法：开场（穿着原貌）反差 = 0", mm.total_contrast() == 0)
	_check("新算法：反差的量纲 = |暴露度差| × 系数",
		mm.total_contrast() == _expect_contrast(mm))
	# 改一件与原貌**完全相同**的件 → 差为 0 → 反差不动
	mm.equip(OutfitData.get_item("hair_short"))
	_check("新算法：换回原貌那件 → 反差仍为 0",
		mm.total_contrast() == 0 and mm.total_contrast() == _expect_contrast(mm))
	# ★ 第四十九轮：**非 top/bottom 的槽位现在也参与反差**。
	#   原来这里查的是「改发型不影响反差」（那时只有 top/bottom 算）。
	#   现在改判「任意槽位只要暴露值有差，单件贡献就 > 0」——
	#   取几个非 top/bottom 槽位里暴露值最大的那件直接问 `_contrast_of`，
	#   避免撞上「暴露值恰好与原貌相同」的件而误判。
	var nonzero_slots := 0
	var probed := []
	for slot in ["neckwear", "accessory", "tattoo", "stockings", "shoes", "piercing"]:
		var best_id := ""
		var best_e := -1
		for it in OutfitData.get_items_for_slot(str(slot)):
			var e := int(it["exposure"])
			if e > best_e:
				best_e = e
				best_id = str(it["id"])
		if best_e <= 0:
			continue
		probed.append(str(slot))
		if mm._contrast_of(str(slot), best_id) > 0:
			nonzero_slots += 1
	_check("全槽位：非 top/bottom 槽位也贡献反差（实测 %d/%d 个非零）"
		% [nonzero_slots, probed.size()],
		nonzero_slots == probed.size() and probed.size() >= 3)
	# 改上衣 → 按暴露度差给分
	var top_id := "top_lace"
	mm.equip(OutfitData.get_item(top_id))
	var base_e := int(OutfitData.get_item(str(mm.true_appearance.get("top", "")))["exposure"])
	var want: int = absi(int(OutfitData.get_item(top_id)["exposure"]) - base_e) \
		* OutfitData.contrast_per_exposure()
	_check("新算法：换上衣后反差 = |暴露度差| × %d = %d（实测 %d）"
		% [OutfitData.contrast_per_exposure(), want, mm.total_contrast()],
		mm.total_contrast() == want)
	# 系数必须 > 0，否则整条曲线无从谈起
	_check("反差系数 > 0（在 rules.contrast_per_exposure 里）",
		OutfitData.contrast_per_exposure() > 0)

# ------------------------------------------------------------
#  缺陷遮挡：与原貌相反的代价
# ------------------------------------------------------------
func _test_defect_tradeoff() -> void:
	print("\n-- 缺陷遮挡：与原貌相反的代价 --")
	var m := WardrobeModel.new(OutfitData)
	m.acceptance = 6
	# 默认原貌用高领长袖衬衫一件同时遮两处。一旦为了"相反"换成短袖，缺陷立刻暴露
	m.equip(OutfitData.get_item("top_plain"))
	var uncovered := m.exposed_defects()
	_check("换成短袖后手背刺青暴露", _has_defect(uncovered, "hand_tattoo"))
	_check("换成短袖后颈侧烙印暴露", _has_defect(uncovered, "neck_brand"))
	_check("换成短袖后反差值上升", m.total_contrast() > 0)

	m.equip(OutfitData.get_item("neck_scarf"))
	# ★ 第二十七轮：手套槽位已下架（`equip` 现在会在模型层直接拒绝），
	#   而 `hand_tattoo` 的另外几个遮挡物（gloves_*）全在手套槽位里 ——
	#   所以补遮只剩「长袖上衣」这一条路。这正好也说明了下架带来的实际影响：
	#   手背刺青现在**只能靠上衣遮**，而成装又会顶掉上衣 → 想穿成装就得接受露出刺青。
	_check("下架的手套在模型层也装不上（equip 直接拒绝）",
		not m.equip(OutfitData.get_item("gloves_leather")))
	m.equip(OutfitData.get_item("top_longsleeve"))
	_check("颈饰+长袖上衣可补回遮挡", m.exposed_defects().is_empty())
	_check("补遮用的颈饰/长袖上衣与原貌不同",
		m.changed_slots().has("neckwear") and m.changed_slots().has("top"))
	# ★ 第四十九轮：口径从「只算上衣与下装」改成**全槽位求和**，
	#   所以颈饰**现在也计入**反差了（第三十一轮那条「不再计入」的断言反过来了）。
	#   ★ 这一件（neck_scarf）的暴露值与原貌那件恰好相同（都是 0），
	#     所以它本次的贡献是 0 —— 「非 top/bottom 槽位确实参与」这件事
	#     由 `_test_contrast_algorithm` 里那条「非 top/bottom 槽位也贡献反差」把守，
	#     这里只验「总和 == 独立重算的结果」（两边口径必须一致）。
	_check("长袖上衣的反差计入总和", m.total_contrast() > 0)
	_check("全槽位：总和 = 逐槽位累加（含颈饰等非 top/bottom 槽位）",
		m.total_contrast() == _expect_contrast(m))

	var before_true := m.total_contrast()
	m.equipped["hair"] = "hair_short"   # 原貌就是 hair_short
	_check("改回原貌物品不增加反差", m.total_contrast() == before_true)
	_check("改回原貌物品会增加相似槽位", m.matching_slots().has("hair"))

# ------------------------------------------------------------
#  暴露值上限校验
# ------------------------------------------------------------
func _test_exposure_cap() -> void:
	print("\n-- 暴露值上限校验 --")
	var m := WardrobeModel.new(OutfitData)
	m.acceptance = 0
	m._equip_defaults()
	_check("默认套装未超上限", m.is_over_cap() == false)
	# 强行塞入高暴露物品绕过 UI，验证超限检测
	m.equipped["top"] = "top_corset"       # exposure 8
	m.equipped["bottom"] = "bottom_mini"   # exposure 7
	_check("暴露值总和正确累加", m.total_exposure() == _sum_exposure(m))
	_check("超过上限时 is_over_cap 为真", m.is_over_cap() == true)
	var ev := m.evaluate()
	_check("超限时判定为直接识破", ev["verdict"] == "instantly_exposed")
	_check("识破理由包含暴露值", _reasons_contain(ev, "暴露值"))

# ------------------------------------------------------------
#  反差值判定
# ------------------------------------------------------------
func _test_contrast() -> void:
	print("\n-- 反差值判定 --")
	var m2 := WardrobeModel.new(OutfitData)
	m2.acceptance = RunData.acceptance_at(3)
	m2.level_index = 3
	m2._equip_defaults()
	_check("默认朴素套装反差值为 0", m2.total_contrast() == 0)
	_check("默认套装反差不足 => is_contrast_sufficient 为假", m2.is_contrast_sufficient() == false)

	print("\n-- 取舍验证：高反差低暴露 vs 高暴露低反差 --")
	var veil := OutfitData.get_item("head_veil")
	var sheer := OutfitData.get_item("top_sheer")
	_check("黑纱反差高暴露低", int(veil["contrast"]) > int(sheer["contrast"]))
	_check("薄纱暴露高反差低", int(sheer["exposure"]) > int(veil["exposure"]))

# ------------------------------------------------------------
#  轮次曲线与多关可解性
# ------------------------------------------------------------
func _test_level_curve() -> void:
	print("\n-- 轮次曲线 --")
	# ★ 第五十二轮：一局 4 轮 → **2 轮**（用户口径「现在的四个背景改成两轮」）
	_check("一局 2 轮", OutfitData.LEVELS.size() == 2)
	_check("MAX_LEVELS = 2", OutfitData.MAX_LEVELS == 2)
	_check("起始接受度 > 0（否则第 1 轮几乎无物可换）", OutfitData.START_ACCEPTANCE > 0)
	_check("反差要求逐轮递增", _req_increasing())
	_check("暴露值上限逐轮递增", _cap_increasing())
	# 两个轮次都给接受度（原来 4 轮时最后一轮是 0，因为后面没有更强的东西了）
	_check("两轮都给接受度", int(OutfitData.LEVELS[0]["acceptance_gain"]) > 0
		and int(OutfitData.LEVELS[1]["acceptance_gain"]) > 0)

	# ★ 第二十九轮：反差值要求改成「自增 + 可手写覆盖」——
	#   留空的关 = 上一轮 + rules.contrast_req_step；手写的值成为后面自增的新起点。
	#   游戏端解析在 OutfitData._resolve_contrast_req，这里验最终结果。
	#
	# ★★ 第四十九轮：出厂曲线改成**四关都手写**（149 / 179 / 199 / 224）——
	#   新曲线的增量是 30 / 20 / 25，**不是等差**，`base + step × 关号`
	#   这条公式表达不了。于是「自增」这条路径出厂时走不到，
	#   所以拆成两段验：① 四关的值对不对；② 机制本身还在不在（临时清空再解析）。
	var rq_base := int(ScenarioData.rule_i("contrast_req_base", -1))
	var rq_step := int(ScenarioData.rule_i("contrast_req_step", -1))
	_check("反差值曲线的 base / step 都在 rules 里",
		rq_base > 0 and rq_step > 0)
	_check("两轮的反差要求都是**手写**的（不是自增出来的）",
		not OutfitData.contrast_req_is_auto(0) and not OutfitData.contrast_req_is_auto(1))
	# ★ 第五十二轮：曲线 = 125 / **150**。150 是**实测定的** ——
	#   150 种子真实求解器量出第 2 轮可达 155~215（中位 215），
	#   所以 150 留 +5 余量；原本想写的 160 会让最不利那批原貌**无解**。
	_check("两轮要求 = 125 / 150（实测第 2 轮可达下限 155）",
		int(OutfitData.level_at(0)["contrast_req"]) == 125
		and int(OutfitData.level_at(1)["contrast_req"]) == 150)

	# ---- 自增机制本身：临时清空第 2 轮的要求，重跑一次解析 ----
	#   ★ 第五十二轮：只剩两轮，可用来验自增的「留空那一格」也只有第 2 轮这一处，
	#     所以断言从两条减到一条（原来是「第 3 关 = 第 2 关 + step」与
	#     「第 4 关再 + step」）。机制一行没改，只是可验的格子少了。
	var saved_rq: Array = []
	for i in OutfitData.MAX_LEVELS:
		saved_rq.append((OutfitData.LEVELS[i] as Dictionary).duplicate())
	OutfitData.LEVELS[1].erase("contrast_req")
	OutfitData._resolve_contrast_req()
	var lv2_want: int = int(OutfitData.LEVELS[0]["contrast_req"]) + rq_step
	_check("★ 留空的关仍走自增：第 2 轮 = %d + step %d = %d（实测 %d）" % [
			int(OutfitData.LEVELS[0]["contrast_req"]), rq_step, lv2_want,
			int(OutfitData.LEVELS[1]["contrast_req"])],
		int(OutfitData.LEVELS[1]["contrast_req"]) == lv2_want)
	# 还原
	for i in OutfitData.MAX_LEVELS:
		OutfitData.LEVELS[i] = saved_rq[i]

	print("\n-- 轮次推进（模型层）--")
	var m3 := WardrobeModel.new(OutfitData)
	m3.acceptance = OutfitData.START_ACCEPTANCE
	var acc_before := m3.acceptance
	var lvl_before := m3.level_index
	m3.clear_level()
	_check("通关后接受度提升",
		m3.acceptance == acc_before + int(OutfitData.LEVELS[lvl_before]["acceptance_gain"]))
	_check("通关后关卡索引推进", m3.level_index == lvl_before + 1)
	_check("通关后暴露值上限提高", m3.exposure_cap() > OutfitData.exposure_cap(acc_before))

	print("\n-- 局状态（RunData）--")
	RunData.start_new_run(99)
	_check("开局在第 1 轮", RunData.level_index == 0)
	_check("开局未通过任何关", RunData.cleared_levels == 0)
	_check("开局接受度 = START_ACCEPTANCE", RunData.acceptance == OutfitData.START_ACCEPTANCE)
	_check("开局未通关", RunData.is_run_complete() == false)
	_check("GameData 同步了局号", GameData.run_index == RunData.run_index)
	_check("GameData 同步了背景名", GameData.background_name == RunData.background_name())
	_check("GameData 同步了种子", GameData.run_seed == RunData.seed_value)

	RunData.advance_level()
	_check("推进后到第 2 轮", RunData.level_index == 1)
	_check("推进后接受度提升", RunData.acceptance == RunData.acceptance_at(1))
	# ★ 第五十二轮：两轮制 —— 推进 1 次就整局通关
	_check("第 2 轮仍未通关", RunData.is_run_complete() == false)
	RunData.advance_level()
	_check("第 2 轮推进后整局通关", RunData.is_run_complete() == true)
	_check("已通过 2 轮", RunData.cleared_levels == 2)

	print("\n-- 背景跨关不变 · 原貌按轮切换 --")
	# ★ 第四十九轮：原貌的语义从「整局固定」改成「**逐轮提升**」——
	#   用户口径「A 的暴露水平要不要随轮次提升？」→ 逐轮提升。
	#   实现走的是第四十轮就建好的「按关覆写」机制（story.json 的
	#   true_presets.by_level 钉死四套），所以这里断言的也跟着改成：
	#   背景不变、原貌**逐轮都不同**、且暴露总和逐轮上升。
	RunData.start_new_run(1234)
	var bg0 := RunData.background_id
	var ta0 := RunData.true_appearance().duplicate()
	var t0 := _true_total_exposure(ta0)
	RunData.advance_level()
	_check("进入下一轮后背景不变", RunData.background_id == bg0)
	var ta_next := RunData.true_appearance().duplicate()
	_check("进入下一轮后原貌**按覆写换掉了**（不再是上一轮那套）",
		not _dict_eq(ta_next, ta0))
	var t1 := _true_total_exposure(ta_next)
	_check("第二轮的暴露总和 ≥ 第一轮（A 逐轮变露）", t1 >= t0)
	_check("进入下一轮后外貌情报跟着换（不再复述上一轮的脸）",
		str(DossierData.clue_for_slot("hair")["text"]) == ScenarioData.clue_text("hair", ta_next["hair"]))
	# ★ 第五十二轮：一局只剩两轮，不再有「第三、四轮」——
	#   原来这里连推两次 `advance_level()` 再取原貌，两轮制下那两次推进
	#   会把 level_index 推过末尾（`is_run_complete()` 在 index==2 时才成立，
	#   所以推进不会提前返回），量到的是「超出轮次范围」的兜底原貌，
	#   于是总数出现 [5, 14, 8, 8] 这种先升后降的假象。
	#   现在只断言两轮：单调不降 + 第 2 轮确实比第 1 轮露 + 两套原貌不同。
	var totals := [t0, t1]
	var rising := totals.size() >= 2 and int(totals[1]) >= int(totals[0])
	_check("两轮的暴露总和单调不降（%s）" % str(totals), rising)
	_check("第二轮确实比第一轮露得多", int(totals[1]) > int(totals[0]))
	_check("两套原貌各不相同", _all_distinct(ScenarioData.true_preset_by_level()))

	print("\n-- 本轮重来（失败 → 回到本轮开始）--")
	ProfileData.reset_all()          # 从零开始，好精确断言「跨局保留」
	RunData.start_new_run(20260101)
	var bg1 := RunData.background_id
	RunData.advance_level()
	# ★ 第四十九轮：原貌逐轮变 —— 要在**切到这一轮之后**再取，
	#   否则拿到的是上一轮那套，下面的「重来后原貌不变」必然挂。
	var ta1 := RunData.true_appearance().duplicate()
	var banked := ProfileData.bonus()
	_check("过关后这一关的接受度立刻进账号",
		banked == int(OutfitData.LEVELS[0]["acceptance_gain"]))

	# 这一轮里发生的事（说法 / 矛盾 / 问答记录），失败重来要回滚
	GameData.snapshot_level_state()
	GameData.stated_facts["trip"] = "by_sea"
	GameData.contradictions = 2
	GameData.answer_log.append({"level": 1, "q": "测试", "answer": "测试"})
	GameData.companion_asked = 3
	GameData.suspicion_carry = 77.0

	var lv_before := RunData.level_index
	var run_before := RunData.run_index
	var forced_before: Array = RunData.forced_item_ids().duplicate()
	RunData.retry_level()

	_check("重来后仍停在同一关", RunData.level_index == lv_before)
	_check("重来后已通过关数不变", RunData.cleared_levels == lv_before)
	_check("重来后局号不变（还是同一局）", RunData.run_index == run_before)
	_check("重来后背景不变", RunData.background_id == bg1)
	_check("重来后原貌不变", _dict_eq(RunData.true_appearance(), ta1))
	_check("重来后本轮立下的说法回滚", GameData.stated_facts.is_empty())
	_check("重来后矛盾计数回滚", GameData.contradictions == 0)
	_check("重来后问答记录回滚", GameData.answer_log.is_empty())
	_check("重来后同行者插话次数回滚", GameData.companion_asked == 0)
	_check("重来后怀疑度底子回滚", is_equal_approx(GameData.suspicion_carry, 0.0))
	# ★ 接受度是**跨局保留**的 —— 本轮重来也不会把已经赚到的还回去
	_check("重来后接受度 = 起始值 + 跨局保留",
		RunData.acceptance == OutfitData.START_ACCEPTANCE + banked)
	_check("本轮重来不退还已赚到的接受度",
		banked > 0 and RunData.acceptance > OutfitData.START_ACCEPTANCE)
	_check("重来后强制装备与原来一致（同一关同一个种子）",
		_arr_eq(RunData.forced_item_ids(), forced_before))

	print("\n-- 多轮可解性（动态规划，%d 个种子 × %d 轮；原貌按轮钉死）--" % [PROBE_SEEDS, OutfitData.MAX_LEVELS])
	# ★ 第四十九轮：这里必须清掉跨局累积的接受度加成 ——
	#   否则量到的是「打了 120 局之后」的口径，
	#   而真实新账号是 14/19/24/30（cap 38/48/58/70）。
	#   标定 contrast_req 必须按**新账号**来。
	ProfileData.reset_all()
	var all_ok := true
	var worst := []
	var best := []
	var worst_ta := []
	for li in OutfitData.MAX_LEVELS:
		worst.append(999999)
		best.append(0)
		worst_ta.append({})
	var unsolvable := 0

	for s in range(1, PROBE_SEEDS + 1):
		# ★ 第四十九轮：这一圈里会 `advance_level()`（原貌逐轮变，必须逐轮取），
		#   而 advance_level 会把接受度加成写进**跨局保留**的账号 ——
		#   40 个种子跑完会累到 acc=650（cap 1310），量到的完全不是新账号。
		#   所以每个种子开始前都清一次。
		ProfileData.reset_all()
		RunData.start_new_run(s)
		for li in OutfitData.MAX_LEVELS:
			# ★ 第四十九轮：原貌现在**逐轮变**（`true_presets.by_level` 钉死了四套），
			#   所以必须在每一轮里**重新取一次** —— 在循环外取一次会把第 1 轮的原貌
			#   当成四轮共用的，量出来的上限跟实际曲线对不上。
			var ta: Dictionary = RunData.true_appearance()
			var acc: int = RunData.acceptance_at(li)
			var cap: int = OutfitData.exposure_cap(acc)
			var opt: int = _dp_optimum(ta, acc, cap)
			if opt < 0:
				unsolvable += 1
				all_ok = false
			else:
				if opt < worst[li]:
					worst_ta[li] = ta.duplicate()
				worst[li] = mini(worst[li], opt)
				best[li] = maxi(best[li], opt)
			if li < OutfitData.MAX_LEVELS - 1:
				RunData.advance_level()

	for li in OutfitData.MAX_LEVELS:
		var req: int = int(OutfitData.LEVELS[li]["contrast_req"])
		print("      第%d轮 acc=%2d cap=%2d 要求=%3d 最优 %3d~%3d ｜ 压力比 %.1f%%" % [
			li + 1, RunData.acceptance_at(li), OutfitData.exposure_cap(RunData.acceptance_at(li)),
			req, worst[li], best[li], float(req) / float(maxi(1, worst[li])) * 100.0])
		# 最差种子的原貌 —— 标定 contrast_req 时要看它「为什么低」
		var ws := []
		for k in (worst_ta[li] as Dictionary).keys():
			ws.append("%s=%s(%d)" % [str(k), str((worst_ta[li] as Dictionary)[k]),
				int(OutfitData.get_item(str((worst_ta[li] as Dictionary)[k])).get("exposure", 0))])
		ws.sort()
		print("         ↳ 本轮原貌: %s" % ", ".join(ws))
		_check("第%d轮存在满足全部约束的配置" % (li + 1), worst[li] >= req)
		_check("第%d轮默认原貌本身不达标（不白送）" % (li + 1), 0 < req)
		# ★ 第四十九轮：按轮覆写钉死的是**主干槽位**（上下装 / 内衣 / 袜子 / 鞋 / 颈饰），
		#   其余槽位仍由 TRUE_POOL 随机 —— 所以最优值只允许在钉死基准附近**小幅**波动。
		#   若波动很大（几十点），说明覆写没生效
		#   （比如某个背景自己覆写了 true_presets，把全局那套盖掉了）。
		_check("第%d轮最优值只在钉死基准附近波动（≤ 20，实测 %d）" % [
				li + 1, best[li] - worst[li]], best[li] - worst[li] <= 20)

	_check("全部 %d 个种子的 4 关都可解" % PROBE_SEEDS, all_ok and unsolvable == 0)

# ------------------------------------------------------------
#  资产完整性
# ------------------------------------------------------------
func _test_assets() -> void:
	print("\n-- 资产完整性（图层与图标）--")
	_check("全部物品均有卡片图标（%s，30×30 图标放 2 倍）" % DolDoll.root(),
		_all_assets_exist("icons"))
	_check("每件物品都有卡片图标", _doll_icons_complete())
	_check("每件衣物的贴图都有可见内容（不是全透明占位图）", _doll_layers_visible())
	# ★ 第四十九轮补的两条 —— 抓「成装只烘了上半身」那类 bug。
	#   背景：AU 把每件成装拆成 `upper/<款>` + `lower/<款>` 两个文件，
	#   而第三十七轮补的 8 件成装**只取了 upper 那一层**，于是护士服 / 和服
	#   在换装界面里只有上半截 —— 这个 bug 从第三十七轮活到第四十九轮，
	#   **期间 580 条断言一条都没响**（因为「文件存在」「有可见内容」都满足）。
	#   所以这里改判**几何形状**：成装的贴图必须同时覆盖肩部与大腿。
	_check("成装覆盖上+下（顶边 ≤ 72 且底边 ≥ 104）", _dress_covers_both_halves())
	# ★ 对照断言（按「只对部分对象生效的规则要配对照」的约定）：
	#   「短」不是一刀切禁止的 —— 上衣里本来就有露脐的短款。
	#   没有这条，一个「所有槽位都必须延伸到 y≥104」的写歪实现也能让上面那条通过。
	_check("对照：短款上衣确实短（露脐款底边 < 90）", _crop_tops_are_short())
	_check("DolDoll.PACK 与图层表里的 pack 字段一致（%s）" % DolDoll.pack(),
		str(DolDoll.info().get("pack", "")) == DolDoll.pack())

# 每件非空件的每一层贴图都得有**不透明像素**。
#   ★ 这条是补的护栏：图包里混着全透明的占位 png（AU 的 winterjacket/3.png），
#     挑错了会让那件衣服在预览里整个消失 —— 而且「文件存在」这类检查发现不了。
func _doll_layers_visible() -> bool:
	var root := DolDoll.root()
	var bad: Array = []
	for it in OutfitData.ITEMS:
		var id := str(it["id"])
		for L in DolDoll.layers_of(id):
			var p := root + str(L.get("file", ""))
			if not ResourceLoader.exists(p):
				continue
			var tex := load(p) as Texture2D
			if tex == null:
				continue
			var used := tex.get_image().get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				bad.append(id)
	if bad.is_empty():
		return true
	print("      全透明的图层: ", bad)
	return false

# 成装（dress 槽）的贴图必须**同时覆盖肩部与大腿** ——
#   「一整件」这个语义落到像素上就是：顶边够高（在肩上）、底边够低（有裙摆）。
#
# ★ 为什么用几何而不是「文件存在 / 有内容」：
#   AU 把每件成装拆成 `upper/<款>`（上衣）+ `lower/<款>`（裙子）两个文件。
#   第三十七轮补的 8 件只取了 upper 那一层 —— 文件在、内容有、图标也有，
#   所以旧断言全绿，但换装界面里护士服 / 和服只有上半截（用户第四十九轮报的）。
#   唯一能把这种「少叠了一层」看出来的，就是贴图**实际延伸到哪里**。
#
# 阈值怎么定的（实测，取景框 68×203、小人鞋底 y=189）：
#   上衣 27 件底边 76~112（最长的是长袖衬衫 112）；下装典型区段 y83..124。
#   顶边 72：修好后 48~69（最高是和服的领口 69），留 3 px 余量。
#
#   ★ 第五十一轮把底边阈值从 104 下调到 **95** —— 这一条是**重新实测后标的**，
#     不是为了让测试通过而放宽：
#
#     新成装 `dress_seethrough`（透明连体泳衣，由两件内衣合并而来）底边只有 101。
#     它是**连体泳衣**，本来就到裆部为止（y87..102 那一段），不是「少烘了一层」。
#     于是把「只叠 upper」与「两层都叠」的真实分布重新量了一遍
#     （只取 col0，与 crop_clip 一致）：
#
#       只叠 upper 的底边：74 / 89 / 85 / 88 / 83   → **74..89**
#       两层都叠的底边：  112 / 122 / 106 / 101 / 121 → **101..122**
#
#     两段之间只有 **89 → 101** 这 12 px 的空档，中点 95。取 95 之后：
#       · 每一个「只叠 upper」的样本（最高 89）都仍被抓出 —— 断言没有失去作用；
#       · 最短的合法成装（101，那件泳衣）留 6 px 余量。
#     ★ 留这段推导的目的：下次再加一件「本来就很短」的成装时，
#       先量出它的底边落在哪一段，再决定是调阈值还是承认那件本来就该短 ——
#       别直接把阈值往下拽。
const DRESS_TOP_MAX := 72
const DRESS_BOTTOM_MIN := 95

func _dress_covers_both_halves() -> bool:
	var bad: Array = []
	for it in OutfitData.ITEMS:
		if str(it["slot"]) != "dress":
			continue
		var id := str(it["id"])
		if bool(it.get("bare", false)):
			continue                              # 空件（不穿成装）不参与
		var used := _used_rect_of(id)
		if used.size.y <= 0:
			bad.append("%s（无贴图）" % id)
			continue
		var top := used.position.y
		var bottom := used.position.y + used.size.y - 1
		if top > DRESS_TOP_MAX or bottom < DRESS_BOTTOM_MIN:
			bad.append("%s（y%d-%d，需 y%d-%d 以上）" % [
				id, top, bottom, DRESS_TOP_MAX, DRESS_BOTTOM_MIN])
	if bad.is_empty():
		return true
	print("      没覆盖上下两截的成装: ", bad)
	return false

# 对照断言：**短**不是一刀切禁止的 —— 上衣里本来就有露脐的短款。
#   没有这条，一个「所有槽位都必须延伸到 y≥104」的写歪实现
#   也能让 `_dress_covers_both_halves()` 通过。
func _crop_tops_are_short() -> bool:
	var bad: Array = []
	for id in ["top_tube", "top_towel", "top_crop", "top_leathercrop"]:
		var used := _used_rect_of(str(id))
		if used.size.y <= 0:
			bad.append("%s（无贴图）" % id)
			continue
		var bottom := used.position.y + used.size.y - 1
		if bottom >= 90:
			bad.append("%s（底边 %d，应 < 90）" % [id, bottom])
	if bad.is_empty():
		return true
	print("      不符预期的短上衣: ", bad)
	return false

# 取一件物品**全部图层叠起来**之后的不透明范围（视口坐标）。
#   成装是两层叠出来的，所以必须合并全部图层 —— 只看第一层会漏掉下半截。
func _used_rect_of(id: String) -> Rect2i:
	var root := DolDoll.root()
	var min_x := 1 << 30
	var min_y := 1 << 30
	var max_x := -1
	var max_y := -1
	for L in DolDoll.layers_of(id):
		var p := root + str(L.get("file", ""))
		if not ResourceLoader.exists(p):
			continue
		var tex := load(p) as Texture2D
		if tex == null:
			continue
		var r := tex.get_image().get_used_rect()
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		min_x = mini(min_x, r.position.x)
		min_y = mini(min_y, r.position.y)
		max_x = maxi(max_x, r.position.x + r.size.x - 1)
		max_y = maxi(max_y, r.position.y + r.size.y - 1)
	if max_x < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

# ------------------------------------------------------------
#  可编辑的四段（第二十三轮）
#
#  用户口径：「编辑器还应该具备编辑一局游戏的轮数以及一轮游戏的问题数，
#            每个问题的 qte 类型 出现时间」
#            「强制穿着的服装，可以是固定几件衣服里选一件即可
#              和固定一件的自由组合」
#            「缺陷遮掩这部分也要可编辑」
#
#  这里验的是**游戏侧真的会按这几段走** —— 编辑器能不能改是编辑器冒烟测试的事。
# ------------------------------------------------------------
func _test_editable_sections() -> void:
	print("\n-- 可编辑的流程数据（轮次 / 强制穿着 / QTE 计划 / 缺陷）--")

	# ---- ① 轮次表 ----
	_check("默认读到 2 轮", OutfitData.level_count() == 2)
	var lv0 := OutfitData.level_at(0)
	_check("第 1 轮带齐四个字段",
		lv0.has("name") and lv0.has("acceptance_gain") and lv0.has("contrast_req")
		and lv0.has("derived_profile"))
	_check("越界的下标会被夹回最后一关",
		OutfitData.level_at(99) == OutfitData.level_at(OutfitData.level_count() - 1))
	_check("level_count 与 levels() 的长度一致",
		OutfitData.level_count() == OutfitData.levels().size())

	# ---- ② 强制穿着：三种模式 ----
	var r0 := OutfitData.forced_rules_at(0)
	_check("出厂第 1 轮是「没有强制要求」", str(r0.get("mode", "")) == OutfitData.FORCED_MODE_NONE)
	_check("出厂第 2 轮是「随机抽」", str(OutfitData.forced_rules_at(1).get("mode", ""))
		== OutfitData.FORCED_MODE_RANDOM)
	_check("「随机抽」模式下没有写死的规则", OutfitData.forced_groups_at(1).is_empty())
	_check("越界的轮次会被夹回最后一条规则",
		OutfitData.forced_rules_at(99) == OutfitData.forced_rules_at(3))

	# 造一关「固定一件 + 几件选一件」的组合，看模型认不认
	var m := WardrobeModel.new(OutfitData)
	m.reset_for_level(30, 1, OutfitData.TRUE_APPEARANCE,
		["panties_lace"], [
			{"pick": OutfitData.PICK_ALL, "items": ["panties_lace"]},
			{"pick": OutfitData.PICK_ANY, "items": ["bottom_mini", "bottom_cut"]},
		])
	m.equipped["panties"] = "panties_plain"
	m.equipped["bottom"] = "bottom_longskirt"
	_check("all 组 + any 组都没满足 → 差两条", m.missing_forced_text().size() == 2)
	m.equipped["panties"] = "panties_lace"
	_check("all 组：穿了之后那一条就不再算差", m.missing_forced_text().size() == 1)
	m.equipped["bottom"] = "bottom_mini"
	_check("any 组：穿上组内第一件 → 满足", m.missing_forced().is_empty())
	m.equipped["bottom"] = "bottom_cut"
	_check("any 组：换成组内第二件 → 照样满足（这就是「任选一件」）", m.missing_forced().is_empty())
	m.equipped["bottom"] = "bottom_pleat"
	_check("any 组：穿了组外的衣服 → 不满足", not m.missing_forced().is_empty())
	_check("any 组：还差什么用一句人话写出来",
		_str_any(m.missing_forced_text(), "任选一件"))
	_check("all 组的槽位被锁死成那一件",
		(m.forced_allowed_ids("panties") as Array) == ["panties_lace"])
	_check("any 组的槽位放开成组内那几件",
		(m.forced_allowed_ids("bottom") as Array).size() == 2)
	_check("不受规则管的槽位不锁", m.forced_allowed_ids("hair") == null)
	_check("any 组里的每一件都被标成「本轮指定」",
		m.is_forced_id("bottom_mini") and m.is_forced_id("bottom_cut"))
	_check("evaluate 的失败理由写明「任选一件」",
		_str_any(m.evaluate()["reasons"], "任选一件"))

	# 组内一件都穿不起时不该把玩家卡死（编辑器写了件贵的）
	var m2 := WardrobeModel.new(OutfitData)
	m2.reset_for_level(0, 1, OutfitData.TRUE_APPEARANCE, [], [
		{"pick": OutfitData.PICK_ANY, "items": ["bottom_mini", "bottom_cut"]},
	])
	var rep2 := m2.auto_complete_outfit()
	_check("组内的衣服全都没到接受度 → 一键达标不会崩，且如实报告没解",
		rep2.has("ok"))

	# ---- ③ QTE 计划 ----
	_check("没写计划的题按「自动」处理",
		str(OutfitData.qte_plan_entry(0).get("qte", "")) == OutfitData.QTE_AUTO)
	_check("越界的题号也返回「自动」",
		str(OutfitData.qte_plan_entry(999).get("qte", "")) == OutfitData.QTE_AUTO)
	_check("五种 QTE 类型都在表里", OutfitData.QTE_KINDS.size() == 5)
	_check("每种类型都有一句人话说明",
		OutfitData.QTE_KINDS.all(func(k): return OutfitData.QTE_KIND_LABELS.has(str(k))))

	# ---- ④ 身体缺陷 ----
	var defs := OutfitData.defects()
	_check("默认读到 2 处缺陷", defs.size() == 2)
	_check("每处缺陷都有 id / name / cover_tags", _defects_wellformed(defs))
	_check("缺陷的覆盖判定仍按标签走（手套遮手背 + 立领遮颈侧 = 两处全遮）",
		_outfit_covers("gloves_leather", "neck_collar") == 2)
	_check("遮不住的搭配就是遮不住（不戴手套 + 不戴颈饰 = 两处都露着）",
		_outfit_covers("gloves_none", "neck_none") == 0)

func _str_any(arr: Array, needle: String) -> bool:
	for x in arr:
		if str(x).contains(needle):
			return true
	return false

func _defects_wellformed(arr: Array) -> bool:
	for d in arr:
		var dd: Dictionary = d
		if str(dd.get("id", "")) == "" or str(dd.get("name", "")) == "":
			return false
		if typeof(dd.get("cover_tags", null)) != TYPE_ARRAY:
			return false
	return true

# 两件衣服能遮住几处缺陷（手套遮手背 / 立领遮颈侧）。
# ★ 上衣必须先换成不遮的（默认那件高领长袖本身就把两处都盖住了），
#   否则测的是上衣、不是这两件。
func _outfit_covers(a: String, b: String) -> int:
	var m := WardrobeModel.new(OutfitData)
	m._equip_defaults()
	m.equipped["top"] = "top_plain"
	m.equipped["gloves"] = a
	m.equipped["neckwear"] = b
	return OutfitData.defects().size() - m.exposed_defects().size()

# ------------------------------------------------------------
#  选关开放状态（第二十一轮；第五十九轮起全部开放）
#
#  用户口径（第五十九轮）：「点击开始游戏后的选择界面现在不再对第一关以外上锁」。
#  这里把「每一轮都点得动」钉死，同时保留「开放表不越界」的检查。
# ------------------------------------------------------------
func _test_open_levels() -> void:
	print("\n-- 选关开放状态（两轮入口，全部开放）--")
	_check("开放表非空", not OutfitData.OPEN_LEVELS.is_empty())
	_check("第 1 轮开放", OutfitData.level_unlocked(0))
	_check("第 2 轮也开放（第五十九轮起不再上锁）", OutfitData.level_unlocked(1))
	_check("开放轮数 = 全部轮数", OutfitData.open_level_count() == OutfitData.MAX_LEVELS)
	var all_open := true
	for i in OutfitData.MAX_LEVELS:
		if not OutfitData.level_unlocked(i):
			all_open = false
	_check("每一轮都开放", all_open)
	_check("开放表里没有越界下标",
		OutfitData.OPEN_LEVELS.all(func(li): return int(li) >= 0 and int(li) < OutfitData.MAX_LEVELS))

	# 开放不等于删除：两轮的数值曲线与名字全都还在
	_check("轮次数值曲线还在（LEVELS 仍是 2 条）", OutfitData.LEVELS.size() == 2)
	_check("轮次名字还在", OutfitData.LEVELS[1].get("name", "") != "")
	var all_named := true
	for lv in OutfitData.LEVELS:
		if str(lv.get("name", "")) == "" or int(lv.get("contrast_req", -1)) < 0:
			all_named = false
	_check("两轮都有名字与反差要求", all_named)

	# 从某一轮开局：轮次索引与已通过轮数都拨到那一轮，接受度不白送
	#   ★ 第五十二轮：只剩两轮，所以拿第 2 轮（索引 1）来验
	RunData.start_new_run(8888, 1)
	_check("从第 2 轮开局 → 轮次索引 = 1", RunData.level_index == 1)
	_check("从第 2 轮开局 → 已通过轮数 = 1", RunData.cleared_levels == 1)
	_check("从第 2 轮开局 → 接受度不白送",
		RunData.acceptance == OutfitData.START_ACCEPTANCE + ProfileData.bonus())
	# 同一个种子 + 同一轮 → 强制装备可复现（重来时靠的就是这条）
	var forced_at_2: Array = RunData.forced_item_ids().duplicate()
	RunData.start_new_run(8888, 1)
	_check("同一轮同一个种子 → 强制装备可复现",
		_arr_eq(RunData.forced_item_ids(), forced_at_2))
	# 越界的起始关会被夹回最后一关，而不是崩掉
	RunData.start_new_run(8889, 99)
	_check("越界的起始关会被夹回最后一关", RunData.level_index == OutfitData.MAX_LEVELS - 1)
	_check("越界的起始关：已通过关数跟着夹回来",
		RunData.cleared_levels == OutfitData.MAX_LEVELS - 1)


func _test_profile() -> void:
	print("\n-- 账号存档 ProfileData（接受度跨局保留）--")
	ProfileData.reset_all()
	_check("清档后累计加成为 0", ProfileData.bonus() == 0)
	_check("清档后没有进度", not ProfileData.has_progress())

	ProfileData.add_gain(5)
	ProfileData.add_gain(6)
	_check("add_gain 累加", ProfileData.bonus() == 11)
	ProfileData.add_gain(0)
	_check("add_gain(0) 不改变累计", ProfileData.bonus() == 11)
	ProfileData.add_gain(-3)
	_check("add_gain(负数) 不改变累计", ProfileData.bonus() == 11)

	ProfileData.note_level_failed()      # 第二十一轮：失败只作废本轮
	ProfileData.note_run_finished(2, true)
	_check("记战绩：本轮重来 1 次", ProfileData.level_failures == 1)
	_check("记战绩：通关 1 局", ProfileData.runs_cleared == 1)
	_check("记战绩：单局最好 2 轮", ProfileData.best_cleared == 2)
	_check("失败不计入「打过几局」（它只作废本轮）", ProfileData.runs_played == 1)
	_check("战绩摘要里写着重来次数", ProfileData.summary().contains("本轮重来 1 次"))

	ProfileData.reset_all()
	_check("reset_all 清空一切",
		ProfileData.bonus() == 0 and ProfileData.runs_played == 0
		and ProfileData.runs_cleared == 0 and ProfileData.best_cleared == 0
		and ProfileData.level_failures == 0)

	# 接受度是派生值：起始值 + 账号累计
	RunData.start_new_run(20261011)
	_check("开局接受度 = 起始值（账号为空时）",
		RunData.acceptance == OutfitData.START_ACCEPTANCE)
	ProfileData.add_gain(9)
	_check("账号一加，当前接受度立刻跟着涨",
		RunData.acceptance == OutfitData.START_ACCEPTANCE + 9)
	ProfileData.reset_all()

# ------------------------------------------------------------
#  强制装备：每轮随机 0~2 件高暴露衣物
# ------------------------------------------------------------
func _test_forced_items() -> void:
	print("\n-- 强制装备（每轮随机 0~2 件高暴露）--")

	# ---- 池子规则 ----
	var low_acc: Array = OutfitData.forced_pool(OutfitData.START_ACCEPTANCE)
	var high_acc: Array = OutfitData.forced_pool(OutfitData.START_ACCEPTANCE + 30)
	_check("强制池里的每一件都是高暴露",
		_all_high_exposure(low_acc) and _all_high_exposure(high_acc))
	_check("强制池里的每一件当前接受度都穿得起",
		_all_affordable(low_acc, OutfitData.START_ACCEPTANCE))
	# ★ 第四十九轮：下装 / 成装被排除出强制池（见 FORCED_NEVER_SLOTS）之后，
	#   「高接受度池更大」不再处处成立 —— 剩下的高暴露件门槛都很低，两档一样大。
	#   改成扫一遍接受度：验**单调不降**，并单配一条「确实变大过」防空转。
	var sizes := []
	for a in [0, 6, 10, 14, 20, 30, 60]:
		sizes.append(OutfitData.forced_pool(a).size())
	var mono := true
	var grew := false
	for i in range(1, sizes.size()):
		if int(sizes[i]) < int(sizes[i - 1]):
			mono = false
		if int(sizes[i]) > int(sizes[i - 1]):
			grew = true
	_check("接受度越高，强制池不会变小（%s）" % str(sizes), mono)
	_check("样本里确实出现过池子变大（否则这条断言空转）", grew)
	_check("低接受度时池子非空（否则机制永远不出现）", low_acc.size() > 0)
	_check("强制池覆盖多个槽位（能凑出 2 件）", _pool_slot_count(high_acc) >= 2)
	_check("强制阈值确实是「高暴露」", OutfitData.FORCED_EXPOSURE_MIN >= 5)
	_check("最多两件", OutfitData.FORCED_MAX == 2)

	# ---- 抽取：数量与槽位 ----
	var seen_counts := {}
	var all_distinct := true
	var first_level_clean := true
	for s in range(60):
		ProfileData.reset_all()
		ProfileData.add_gain(30)          # 让池子够大，能抽满 2 件
		RunData.start_new_run(900000 + s)
		# ★ 每局第一轮刻意不抽强制装备 —— 先断言这一点，再看第 2 轮
		if not RunData.forced_item_ids().is_empty():
			first_level_clean = false
		RunData._roll_forced_items(1)
		var ids: Array = RunData.forced_item_ids()
		seen_counts[ids.size()] = int(seen_counts.get(ids.size(), 0)) + 1
		if ids.size() > OutfitData.FORCED_MAX:
			all_distinct = false
		var slots := []
		for id in ids:
			var it: Dictionary = OutfitData.get_item(str(id))
			if it.is_empty() or not OutfitData.is_high_exposure(it):
				all_distinct = false
			var slot := str(it.get("slot", ""))
			if slots.has(slot):
				all_distinct = false          # 同一槽位不能强制两件
			slots.append(slot)
	_check("★ 每局第一轮没有强制服装要求", first_level_clean)
	_check("强制件数从不超过 2", _max_key(seen_counts) <= OutfitData.FORCED_MAX)
	_check("强制件数至少出现过 0（最少可以没有）", seen_counts.has(0))
	_check("60 个种子能抽到 1 件和 2 件",
		seen_counts.has(1) and seen_counts.has(2))
	_check("强制装备都是高暴露且槽位互不重复", all_distinct)

	# ---- 确定性 ----
	ProfileData.reset_all()
	ProfileData.add_gain(30)
	RunData.start_new_run(424242)
	_check("新开的这一局（第 1 轮）没有强制装备", RunData.forced_item_ids().is_empty())
	RunData._roll_forced_items(1)
	var f1: Array = RunData.forced_item_ids().duplicate()
	RunData.start_new_run(424242)
	RunData._roll_forced_items(1)
	_check("同一种子 → 同一批强制装备", _arr_eq(f1, RunData.forced_item_ids()))
	# 第 1 轮即使把接受度堆很高，也还是不抽
	ProfileData.reset_all()
	ProfileData.add_gain(60)
	RunData.start_new_run(777001)
	_check("接受度再高，第一轮也一样没有强制装备",
		RunData.forced_item_ids().is_empty())

	# ---- 判定：没穿 = 当场识破 ----
	var m := WardrobeModel.new(OutfitData, OutfitData.TRUE_APPEARANCE, OutfitData.LEVELS)
	m.acceptance = OutfitData.START_ACCEPTANCE + 30    # 不抬接受度的话高暴露件根本穿不上
	var pick: Dictionary = OutfitData.forced_pool(OutfitData.START_ACCEPTANCE + 30)[0]
	m.set_forced_items([pick["id"]])
	_check("刚设了强制装备、还没穿 → 判为未穿",
		_reasons_contain(m.evaluate(), "强制装备") and m.missing_forced().size() == 1)
	m.equip(pick)
	_check("穿上强制装备 → 不再报缺失",
		not _reasons_contain(m.evaluate(), "强制装备"))
	# 换成同槽位的另一件 → 又成「没穿」
	var other := _other_item_in_slot(str(pick["slot"]), str(pick["id"]))
	if not other.is_empty():
		m.equip(other)
		_check("换成同槽位别的衣物 → 判为强制装备未穿",
			_reasons_contain(m.evaluate(), "强制装备"))
		_check("missing_forced 报出那一件", m.missing_forced().size() == 1)
		m.equip(pick)
		_check("穿回去 → 判定恢复", m.missing_forced().is_empty())
	else:
		print("      （该槽位只有一件可选，跳过换装判定）")
	ProfileData.reset_all()

# ------------------------------------------------------------
#  强制装备不能让轮次变成无解
#
#  这是本轮唯一真正的风险点：强制件是**高暴露**的，它既吃暴露值预算，
#  又把你原本用来遮缺陷 / 拉反差的槽位锁死。
#  如果某组原貌 + 强制件组合恰好无解，玩家就会卡死在一关里。
#
#  所以照真实流程跑：start_new_run(seed) → 逐关取 RunData 抽出来的强制件 →
#  用「先补缺陷、再拉反差」的贪心求解（强制槽位不许动）→ 断言 verdict == pass。
# ------------------------------------------------------------
# ★★ 第五十二轮：**这两个常量是整套测试的耗时大头**（实测 147 秒里占 96%）。
#   用户口径「适当减少测试时间」，于是这一轮做了三件事：
#     ① 给 `_ready()` 加了分段计时（常驻），以后调优有数据可依；
#     ② `_test_forced_solvability` 只对**真的抽到强制装备的轮次**走 DP ——
#        实测 240 个轮次里只有 71 个带强制装备，**70% 的 DP 是白跑的**
#        （没强制装备的那一轮等于在重复验「普通可解性」，已被别的段落覆盖）；
#     ③ 两个种子数各减一档。
#   ★ 想再快/再稳就调这两个数；改完记得看跑完时打印的「耗时合计」与
#     「最耗时的前 8 段」—— 别再凭感觉猜哪个段慢。
#   ★★ 种子数**没有**动（`FORCED_SEEDS` 仍是 120）：第 ② 条是**零覆盖损失**的
#      优化（跳过本来就白跑的那些轮次），所以不必顺手砍种子。
#      实测：只做第 ② 条 + 下面的 `AUTO_SEEDS` 减一档，总时就够低了。
const FORCED_SEEDS := 120

func _test_forced_solvability() -> void:
	print("\n-- 强制装备的可解性（%d 个种子 × %d 轮）--" % [FORCED_SEEDS, OutfitData.MAX_LEVELS])
	var bad := 0
	var levels_with_forced := 0
	var first_level_forced := 0
	var total_levels := 0
	var worst := ""
	var solved := 0
	for k in FORCED_SEEDS:
		ProfileData.reset_all()
		RunData.start_new_run(400000 + k * 7919)
		for li in OutfitData.MAX_LEVELS:
			total_levels += 1
			var forced: Array = RunData.forced_item_ids().duplicate()
			if not forced.is_empty():
				levels_with_forced += 1
			if li == 0 and not forced.is_empty():
				first_level_forced += 1
			# ★★ 第五十二轮减时：**没抽到强制装备的轮次直接跳过 DP**。
			#   这一段要验的是「强制装备不会造成死局」—— 没有强制装备的轮次
			#   不构成这个检验，跑它等于重复验「普通可解性」（`PROBE_SEEDS`
			#   那段多轮可解性 + 「一键达标」段都已覆盖）。
			#   实测 240 个轮次里只有 71 个带强制装备 → 这一步砍掉约 70% 的 DP。
			#   ★ 但 `first_level_forced` 与 `levels_with_forced` 两个统计
			#     **照旧在跳过之前算** —— 它们是「强制规则确实按轮生效」的证据，
			#     一个都不能省。
			if forced.is_empty():
				if li < OutfitData.MAX_LEVELS - 1:
					RunData.advance_level()
				continue
			solved += 1
			var ev := _solve_with_forced(RunData.true_appearance(), li, forced)
			if str(ev["verdict"]) != "pass":
				bad += 1
				if worst == "":
					worst = "seed=%d 第%d轮 forced=%s ｜ %s" % [
						400000 + k * 7919, li + 1, str(forced),
						" / ".join(ev["reasons"])]
				if bad <= 6:
					print("      无解#%d: seed=%d 第%d轮 forced=%s ｜ %s" % [
						bad, 400000 + k * 7919, li + 1, str(forced),
						" / ".join(ev["reasons"])])
			if li < OutfitData.MAX_LEVELS - 1:
				RunData.advance_level()
	_check("每轮都至少存在一种满足全部约束的搭配（含强制装备）", bad == 0)
	_check("★ %d 个种子的第 1 轮全都没有强制装备" % FORCED_SEEDS, first_level_forced == 0)
	_check("样本里确实出现过带强制装备的关（否则这条断言是空转）",
		levels_with_forced > 0)
	if worst != "":
		print("      首个无解：", worst)
	print("      （%d / %d 轮带强制装备；其中 %d 轮走了 DP，其余跳过——减时）" % [
		levels_with_forced, total_levels, solved])
	ProfileData.reset_all()

# 带强制装备的贪心求解：强制件先穿上并锁死，其余槽位「先补缺陷、再拉反差」
# 带强制装备的可解性求解：**直接用游戏里那个 DP**（`auto_complete_outfit`）。
#
# ★ 第二十七轮从「贪心」改成「DP」：贪心是逐槽位试探，一旦某个槽位被强制锁死，
#   它就再也绕不回来 —— 实测「只锁了 `panties`」的关只能凑到反差 47，
#   而同一个局面 DP 能拿到 54（贪心低估了上限，会把本来能过的关判成无解）。
#   而且 `auto_complete_outfit` 正是玩家在准备室里按「🧪 一键达标」时跑的那个求解器，
#   用它来判「这关到底有没有解」才对得上真实流程。
func _solve_with_forced(true_app: Dictionary, li: int, forced_ids: Array) -> Dictionary:
	var m := WardrobeModel.new(OutfitData, true_app, OutfitData.LEVELS)
	m.reset_for_level(RunData.acceptance_at(li), li, true_app, forced_ids)
	m.auto_complete_outfit()
	return m.evaluate()

# ------------------------------------------------------------
#  测试按钮：一键满足服装要求（WardrobeModel.auto_complete_outfit）
#
#  这是给调试用的捷径，但它的正确性可以直接量：照真实流程跑
#  （start_new_run → 逐关 → 抽到本轮的强制装备），每轮都点一次，
#  断言求解出来的搭配真的通过 evaluate()，而且没有越权
#  （不会穿上接受度还不够的东西），也不比贪心解差。
# ------------------------------------------------------------
# 一键达标用的种子数（每次 `auto_complete_outfit()` 约 0.5 秒，是第二大耗时段）
const AUTO_SEEDS := 16

func _test_auto_complete() -> void:
	print("\n-- 一键达标（%d 个种子 × %d 轮）--" % [AUTO_SEEDS, OutfitData.MAX_LEVELS])
	var total := AUTO_SEEDS * OutfitData.MAX_LEVELS
	var bad := 0                 # 违反硬约束的次数
	var not_pass := 0
	var worst := ""
	var no_forced := 0
	var over_req := 0
	var min_changed := 999
	var exact := 0
	var exact_dbg := 0
	var cap_bound := 0
	var pack_ok := 0

	for k in AUTO_SEEDS:
		ProfileData.reset_all()
		RunData.start_new_run(700000 + k * 104729)
		for li in OutfitData.MAX_LEVELS:
			var forced: Array = RunData.forced_item_ids().duplicate()
			if forced.is_empty():
				no_forced += 1

			var m := WardrobeModel.new(OutfitData, RunData.true_appearance(), OutfitData.LEVELS)
			m.reset_for_level(RunData.acceptance_at(li), li, RunData.true_appearance(), forced)
			var rep: Dictionary = m.auto_complete_outfit()
			var ev: Dictionary = m.evaluate()

			# ① 报告说 ok，就必须真的 pass —— evaluate() 是唯一裁判
			var pass_ok: bool = str(ev["verdict"]) == "pass"
			if not bool(rep["ok"]) or not pass_ok:
				not_pass += 1
				if worst == "":
					worst = "seed=%d 第%d轮 forced=%s ｜ %s" % [
						700000 + k * 104729, li + 1, str(forced), " / ".join(ev["reasons"])]

			# ② 四条硬约束逐条复核（报告字段与实际状态必须一致）
			if m.is_over_cap() or int(rep["exposure"]) != m.total_exposure():
				bad += 1
			if not m.is_contrast_sufficient() or int(rep["contrast"]) != m.total_contrast():
				bad += 1
			if not m.exposed_defects().is_empty() or not (rep["uncovered"] as Array).is_empty():
				bad += 1
			if not m.missing_forced().is_empty() or not (rep["missing_forced"] as Array).is_empty():
				bad += 1

			# ③ 不许穿接受度穿不起的东西
			for slot in OutfitData.SLOT_ORDER:
				var it: Dictionary = m.item_at(slot)
				if it.is_empty():
					continue
				if int(it.get("acceptance_req", 0)) > m.acceptance:
					bad += 1

			# ④ 精确性：没有任何「只换一个槽位」的改动能再拉高反差
			#    （DP 是**它那本账下**的全局最优，所以局部最优必须成立 ——
			#      不成立就是求解器写错了。账的口径见 _is_locally_optimal）
			if _is_locally_optimal(m):
				exact += 1
			elif exact_dbg < 4:
				exact_dbg += 1
				print("      [非局部最优#%d] seed=%d 第%d轮 反差=%d 暴露=%d/%d forced=%s" % [
					exact_dbg, 700000 + k * 104729, li + 1, m.total_contrast(),
					m.total_exposure(), m.exposure_cap(), str(forced)])
				print("        ↳ 可改进: %s" % str(_first_improving_move(m)))
				print("        ↳ 原貌: %s" % str(m.true_appearance))
			# ④ 的伴随守卫：确认「保守账卡满上限」的局面确实出现过 ——
			#    否则 ④ 可能是因为样本里压根没有卡上限的轮次而空转通过。
			if m.conservative_exposure() >= m.exposure_cap():
				cap_bound += 1
			# ⑤ 次级目标：同反差下，也不该再有一个槽位能靠换一件来减少「与原貌一致」
			if _packing_optimal(m):
				pack_ok += 1

			if m.total_contrast() > m.contrast_requirement():
				over_req += 1
			min_changed = mini(min_changed, (rep["changed"] as Array).size())

			if li < OutfitData.MAX_LEVELS - 1:
				RunData.advance_level()

	_check("每个种子每一关都能一键达标", not_pass == 0)
	_check("四条硬约束（暴露 / 反差 / 缺陷 / 强制件）无一被违反", bad == 0)
	_check("报告的数值与模型实际状态一致（无「报喜不报忧」）", bad == 0)
	_check("求解结果都是局部最优（精确解，不是贪心近似）", exact == total)
	_check("同反差下也不会再留下可改的部位（次级目标也到位）", pack_ok == total)
	_check("样本里出现过「DP 账卡满上限」的轮次（否则局部最优断言空转）", cap_bound > 0)
	_check("一键达标确实动过衣服（不是空操作）", min_changed > 0)
	_check("样本里出现过没有强制装备的关（否则断言空转）", no_forced > 0)
	_check("样本里出现过带强制装备的关", no_forced < total)
	_check("至少有一部分关求解后留有余量（反差高于要求）", over_req > 0)
	if worst != "":
		print("      首个不达标：", worst)
	print("      （%d / %d 轮没有强制装备 ｜ 余量关 %d ｜ 最少改动 %d 个槽位 ｜ 卡满上限 %d 轮）" % [
		no_forced, total, over_req, min_changed, cap_bound])

	# ---- 幂等：连点两次结果必须一致 ----
	ProfileData.reset_all()
	RunData.start_new_run(314159)
	var m2 := WardrobeModel.new(OutfitData, RunData.true_appearance(), OutfitData.LEVELS)
	m2.reset_for_level(RunData.acceptance_at(0), 0, RunData.true_appearance(),
		RunData.forced_item_ids())
	var r1: Dictionary = m2.auto_complete_outfit()
	var snap: Dictionary = m2.equipped.duplicate()
	var r2: Dictionary = m2.auto_complete_outfit()
	_check("连点两次搭配完全一致（幂等）", _dict_eq(snap, m2.equipped))
	_check("第二次没有可改的槽位", (r2["changed"] as Array).is_empty())
	_check("两次报告的反差值一致", int(r1["contrast"]) == int(r2["contrast"]))

	# ---- 开局即原貌时，一键必须把强制装备穿上 ----
	ProfileData.reset_all()
	ProfileData.add_gain(30)
	RunData.start_new_run(424242)
	var forced2: Array = RunData.forced_item_ids().duplicate()
	if not forced2.is_empty():
		var m3 := WardrobeModel.new(OutfitData, RunData.true_appearance(), OutfitData.LEVELS)
		m3.reset_for_level(RunData.acceptance_at(0), 0, RunData.true_appearance(), forced2)
		_check("一键之前：强制装备确实没穿", m3.missing_forced().size() == forced2.size())
		m3.auto_complete_outfit()
		_check("一键之后：强制装备全穿上", m3.missing_forced().is_empty())
		_check("一键之后：整体判定通过", str(m3.evaluate()["verdict"]) == "pass")
	else:
		print("      （该种子没有强制装备，跳过这一条）")
	ProfileData.reset_all()

# 只换一个槽位，能不能在满足全部约束的前提下把反差再拉高
#
# ★ 第四十九轮：可行性按 **DP 那本账** 判（`conservative_exposure()`），不是真实账。
#   多件槽位（纹身）的可见性取决于别的槽位，而 DP 把它单独分了一组
#   （并进门控组选项数会从 3.8k 涨到 420 万），只能按「全都当作露着」计 ——
#   这本账**一定不小于**真实账，所以 DP 解绝不会超上限（安全），
#   代价是偶尔剩下一点真实余量没用上。
#   于是「真实度量下的局部最优」在少数局面下**不可能成立**（不是求解器写错了），
#   局部最优只能在同一本账下讲。实测（480 轮）：按真实账判有 4 轮不通过，
#   按 DP 账判 480/480 通过 —— 而那 4 轮全部是「DP 以为卡在上限、其实还剩 2 点」。
func _is_locally_optimal(m: WardrobeModel) -> bool:
	return _first_improving_move(m).is_empty()

# 诊断用：找出第一个「只换一个槽位就能拉高反差」的改动（没有则返回 {}）
func _first_improving_move(m: WardrobeModel) -> Dictionary:
	var base: int = m.total_contrast()
	var keep: Dictionary = m.equipped.duplicate()
	for slot in OutfitData.SLOT_ORDER:
		var cur := str(keep.get(slot, ""))
		for it in OutfitData.get_items_for_slot(slot):
			if str(it["id"]) == cur:
				continue
			if not m.can_equip(it):
				continue
			m.equipped[slot] = str(it["id"])
			var better: bool = m.total_contrast() > base \
				and not m.is_over_cap() \
				and m.conservative_exposure() <= m.exposure_cap() \
				and m.exposed_defects().is_empty() \
				and m.missing_forced().is_empty()
			var got := m.total_contrast()
			m.equipped[slot] = cur
			if better:
				m.equipped = keep
				return {"slot": slot, "from": cur, "to": str(it["id"]),
					"contrast": "%d -> %d" % [base, got]}
	m.equipped = keep
	return {}

# 同反差下，能不能只换一个槽位就让「与原貌一致」的部位更少（且约束仍满足）
func _packing_optimal(m: WardrobeModel) -> bool:
	var base_c: int = m.total_contrast()
	var base_m: int = m.matching_slots().size()
	var keep: Dictionary = m.equipped.duplicate()
	var ok := true
	for slot in OutfitData.SLOT_ORDER:
		var cur := str(keep.get(slot, ""))
		for it in OutfitData.get_items_for_slot(slot):
			if str(it["id"]) == cur:
				continue
			if not m.can_equip(it):
				continue
			m.equipped[slot] = str(it["id"])
			var better: bool = m.total_contrast() == base_c \
				and m.matching_slots().size() < base_m \
				and not m.is_over_cap() \
				and m.conservative_exposure() <= m.exposure_cap() \
				and m.exposed_defects().is_empty() \
				and m.missing_forced().is_empty()
			m.equipped[slot] = cur
			if better:
				ok = false
				break
		if not ok:
			break
	m.equipped = keep
	return ok

# ------------------------------------------------------------
#  短信逐关解锁
# ------------------------------------------------------------
func _test_sms_levels() -> void:
	print("\n-- 短信逐关解锁 --")
	var bad_count := 0
	var bad_level := 0
	var bad_reveal := 0
	var bad_canon := 0
	for bg in ScenarioData.enabled_backgrounds():
		var sms: Array = ScenarioData.sms_of(bg)
		var fs: Array = ScenarioData.facts_of(bg)
		if sms.size() != OutfitData.MAX_LEVELS or fs.size() != OutfitData.MAX_LEVELS:
			bad_count += 1
			continue
		for i in sms.size():
			var s: Dictionary = sms[i]
			if ScenarioData.sms_level_of(s) != i:
				bad_level += 1
			var rev: Array = s.get("reveals", [])
			# 第 i 关解锁的那条，正好揭示 facts[i]
			if rev.size() != 1 or str(rev[0].get("fact", "")) != str(fs[i].get("id", "")):
				bad_reveal += 1
			elif str(rev[0].get("value", "")) != ScenarioData.canonical_value(bg, str(fs[i].get("id", ""))):
				bad_canon += 1
	_check("每套背景 4 条短信 / 4 条事实（一关一条）", bad_count == 0)
	_check("每条短信的 level 正好是 0/1/2/3", bad_level == 0)
	_check("第 i 关解锁的短信正好揭示 facts[i]", bad_reveal == 0)
	_check("揭示的值就是该事实的官方口径（values[0]）", bad_canon == 0)

	# 过滤：轮次越深，看到的短信越多
	var grow_ok := true
	var one_per_level := true
	for bg in ScenarioData.enabled_backgrounds():
		var prev := 0
		for li in OutfitData.MAX_LEVELS:
			var n: int = ScenarioData.sms_for_level(bg, li).size()
			if n != li + 1:
				one_per_level = false
			if n < prev:
				grow_ok = false
			prev = n
	_check("第 li 关能看到 li+1 条（一关解锁一条）", one_per_level)
	_check("解锁数量只增不减", grow_ok)

	# 跨关：RunData.sms_threads 跟着轮次走
	ProfileData.reset_all()
	RunData.start_new_run(20261011)
	var seen: Array = []
	var mono := true
	for li in OutfitData.MAX_LEVELS:
		var n: int = RunData.sms_threads().size()
		seen.append(n)
		if li > 0 and n <= int(seen[li - 1]):
			mono = false
		if li < OutfitData.MAX_LEVELS - 1:
			RunData.advance_level()
	_check("RunData.sms_threads 随轮次增长", mono)
	_check("第 1 轮只解锁 1 条", int(seen[0]) == 1)
	# ★★ 第五十三轮修一个**假绿**：这一行原来是 `seen[3]`，而第 52 轮把一局压成
	#   2 轮之后 `seen` 只有 MAX_LEVELS(2) 个元素 —— 访问 `seen[3]` 越界，
	#   Godot 报 SCRIPT ERROR 并**跳过这一行**（`_check` 根本没执行），
	#   于是这条断言从第 52 轮起就一直「没跑过」而测试照旧全绿。
	#   改成按 MAX_LEVELS 取末项，并把标题里的「第 4 轮 / 4 条」也改成动态的。
	_check("末轮解锁全部 %d 条" % OutfitData.MAX_LEVELS,
		int(seen[OutfitData.MAX_LEVELS - 1]) == OutfitData.MAX_LEVELS)
	_check("sms_total 是全部条数", RunData.sms_total() == OutfitData.MAX_LEVELS)
	ProfileData.reset_all()

# ------------------------------------------------------------
#  本局主人公：A 真身 / B 马甲 / C 同行人
# ------------------------------------------------------------
func _test_cast() -> void:
	print("\n-- 本局主人公（A 真身 / B 马甲 / C 同行人）--")
	ProfileData.reset_all()
	RunData.start_new_run(20261011)
	var c: Dictionary = RunData.cast()
	_check("主人公有 A 真身 / B 马甲 / 审讯官 / C 同行人",
		c.has("true_role") and c.has("cover_role")
		and c.has("interrogator") and c.has("companion"))
	_check("A 与 B 不是同一个人", str(c["true_role"]) != str(c["cover_role"]))
	_check("A 与 B 都有内容", str(c["true_role"]) != "" and str(c["cover_role"]) != "")
	_check("审讯官有名字", str(c["interrogator"]) != "")
	_check("同行人 C 有名字与关系",
		str(c["companion"]) != "" and str(c["companion_relation"]) != "")
	_check("玩家是女性", str(c["player_gender"]) == "女")
	_check("审讯官是男性", str(c["interrogator_gender"]) == "男")
	_check("同行人是男性", str(c["companion_gender"]) == "男")
	_check("同行人有自己的来历描述", str(c["companion_desc"]).length() > 10)

	# 一局之内绝不换人：跨关后主人公完全一致
	var before := RunData.cast()
	RunData.advance_level()
	RunData.advance_level()
	var after := RunData.cast()
	_check("跨关之后主人公一个都没换", _dict_eq(before, after))

	# 换一局才会换人（而且不一定换）
	var seen_bg := {}
	var seen_comp := {}
	for s in range(30):
		RunData.start_new_run(700000 + s)
		seen_bg[RunData.background_id] = true
		seen_comp[RunData.companion_name()] = true
	_check("多局能抽到多套背景", seen_bg.size() >= 2)
	_check("多局能抽到多个同行人", seen_comp.size() >= 2)
	ProfileData.reset_all()

# ============================================================
#  动态规划：在「暴露值上限 + 两处缺陷必须遮住 + 接受度门槛」约束下
#  求能达到的最大反差值。返回 -1 表示无解。
#
#  状态 = (已用暴露值, 覆盖位)，覆盖位 bit0 = 颈侧烙印，bit1 = 手背刺青。
#  第 1 关上限只有 22，状态空间极小，可以求精确最优 —— 比贪心可靠得多。
# ============================================================
func _build_slot_cache() -> void:
	_slot_items = {}
	# 只建「玩家能看到的槽位」—— 下架槽位的候选是空的，
	# 留在 DP 里会让状态全灭（一整列没有可选项 → 无解）
	for slot in OutfitData.active_slots():
		var arr := []
		for it in OutfitData.get_items_for_slot(slot):
			var cov := 0
			for t in it.get("tags", []):
				if t == "high_collar" or t == "scarf":
					cov |= 1
				if t == "glove" or t == "long_sleeve":
					cov |= 2
			# ★★ 第四十九轮：第 2 位（反差）**改成占位 0**。
			#
			#   原来这里存的是 `int(it["contrast"])` —— 物品**手填**的那个反差字段，
			#   那是第三十一轮**之前**的旧算法。第三十一轮把反差换成
			#   `|暴露值差| × 系数` 之后，这个 DP 没跟着改，一直用旧口径在算
			#   「最优值」—— 因为旧曲线的要求很低（24/27/30/33），
			#   两种口径算出来都远超要求，所以**一直没暴露**。
			#   第四十九轮要求抬到 149/179/199/224，旧口径只能算出 75，
			#   这条差异才第一次显形。
			#
			#   为什么不能在这里直接算：差值要跟**本局的原貌那一件**比，
			#   而原貌是每局不同的、`_build_slot_cache()` 看不到它。
			#   所以改成在 `_walk_combos()` 里现算（那里拿得到 `true_app`）。
			arr.append([int(it["exposure"]), 0, cov,
				int(it["acceptance_req"]), str(it["id"])])
		_slot_items[slot] = arr

# 门控对（外衣 + 它里面的内衣）必须一起选 —— 内衣的暴露值 / 反差值取决于
# 同侧外衣够不够露（OutfitData.UNDER_GATE）。分开选算出来的「上限」是假的：
# 它会让 DP 以为内衣的贡献是固定的，从而低估或高估每轮的真实可解空间。
func _dp_groups() -> Array:
	var act: Array = OutfitData.active_slots()
	var owner := {}
	for gated in OutfitData.UNDER_GATE.keys():
		for o in OutfitData.outer_slots_of(str(gated)):
			if act.has(str(o)):
				owner[str(gated)] = str(o)
				break
	var order := []
	var members := {}
	for slot in act:
		var key := str(owner.get(slot, slot))
		if not members.has(key):
			members[key] = []
			order.append(key)
		members[key].append(slot)
	var out := []
	for k in order:
		out.append(members[k])
	return out

# 一组槽位的全部组合 → [暴露值, 反差值, 缺陷掩码]（已按门控算过）
func _group_combos(group: Array, true_app: Dictionary, acceptance: int) -> Array:
	var out := []
	_walk_combos(group, 0, true_app, acceptance, {}, out)
	return out

func _walk_combos(group: Array, i: int, true_app: Dictionary, acceptance: int,
		acc: Dictionary, out: Array) -> void:
	if i >= group.size():
		var eq := {}
		for g in group:
			eq[str(g)] = str((acc[str(g)] as Array)[4])
		var exp := 0
		var con := 0
		var cov := 0
		var k: int = OutfitData.contrast_per_exposure()
		for g in group:
			var s := str(g)
			var it: Array = acc[s]
			cov |= int(it[2])
			if not _counts_with(eq, s):
				continue        # 外衣不够露 → 这件内衣既不算暴露、也不算反差
			exp += int(it[0])
			# ★ 第四十九轮：反差现算 —— |这一件的暴露值 − 原貌那件的暴露值| × 系数。
			#   原貌这一槽位没值（空）时基线取 0（= 他没穿 / 没戴）。
			var base_e := 0
			var base_id := str(true_app.get(s, ""))
			if base_id != "":
				base_e = int(OutfitData.get_item(base_id).get("exposure", 0))
			con += absi(int(it[0]) - base_e) * k
		out.append([exp, con, cov])
		return
	var slot := str(group[i])
	for it in _slot_items[slot]:
		if int(it[3]) > acceptance:
			continue
		var nxt := acc.duplicate()
		nxt[slot] = it
		_walk_combos(group, i + 1, true_app, acceptance, nxt, out)

# 与 WardrobeModel._counts_with 同一口径：这一槽位在给定装备表下要不要计入
func _counts_with(eq: Dictionary, slot: String) -> bool:
	if not OutfitData.is_gated_slot(slot):
		return true
	for o in OutfitData.outer_slots_of(slot):
		var os := str(o)
		if not OutfitData.slot_enabled(os):
			continue
		var it := OutfitData.get_item(str(eq.get(os, "")))
		if it.is_empty() or OutfitData.is_bare(it):
			continue
		if OutfitData.see_through_kind(it) == "":
			return false
	return true

func _dp_optimum(true_app: Dictionary, acceptance: int, cap: int) -> int:
	var cur := []
	for e in cap + 1:
		cur.append([NEG, NEG, NEG, NEG])
	cur[0][0] = 0

	for group in _dp_groups():
		var combos: Array = _group_combos(group, true_app, acceptance)
		var nxt := []
		for e in cap + 1:
			nxt.append([NEG, NEG, NEG, NEG])
		for e in cap + 1:
			for cov in 4:
				var v: int = cur[e][cov]
				if v == NEG:
					continue
				for c in combos:
					var ne: int = e + int(c[0])
					if ne > cap:
						continue
					var nc: int = cov | int(c[2])
					var nv: int = v + int(c[1])
					if nv > nxt[ne][nc]:
						nxt[ne][nc] = nv
		cur = nxt

	var best := NEG
	for e in cap + 1:
		if cur[e][3] > best:
			best = cur[e][3]
	return -1 if best == NEG else best

# ============================================================
#  辅助
# ============================================================
func _has_defect(arr: Array, id: String) -> bool:
	for d in arr:
		if d["id"] == id:
			return true
	return false

# ★ 第三十一轮新算法：独立地从**数据**重算一遍反差，与被测的 total_contrast() 对照。
#
#   口径（用户口径）：**所有槽位**都算；数值 = |你穿的暴露度 − 原貌那件的暴露度| × 系数。
#   ★ 第四十九轮：从「只算上衣与下装」改成全槽位 —— 循环对象由写死的
#     `["top", "bottom"]` 换成 `m.equipped` 的全部键，并对多件槽位（纹身）
#     逐件累加（与模型 `_sum_now` 的口径一致）。
#   这里刻意不走模型内部函数，而是直接用 ITEMS 里的 exposure 现推 ——
#   否则就是「拿实现验证实现」，改了算法也照样通过。
func _expect_contrast(m: WardrobeModel) -> int:
	var w := OutfitData.contrast_per_exposure()
	var t := 0
	for slot in m.equipped:
		var ss := str(slot)
		if not m.counts_toward_totals(ss):
			continue
		var base_id := str(m.true_appearance.get(ss, ""))
		var base_e := 0
		if base_id != "":
			base_e = int(OutfitData.get_item(base_id).get("exposure", 0))
		var raw: Variant = m.equipped[ss]
		if typeof(raw) == TYPE_ARRAY:
			for id in (raw as Array):
				t += absi(int(OutfitData.get_item(str(id)).get("exposure", 0)) - base_e) * w
			continue
		t += absi(int(m.item_at(ss).get("exposure", 0)) - base_e) * w
	return t

func _sum_exposure(m: WardrobeModel) -> int:
	# 与 total_exposure() 同一口径：受门控的内衣内裤，露不出来就不计
	var t := 0
	for slot in m.equipped:
		if not m.counts_toward_totals(str(slot)):
			continue
		t += int(m.item_at(slot).get("exposure", 0))
	return t

func _try_equip(m: WardrobeModel, id: String) -> bool:
	return m.equip(OutfitData.get_item(id))

func _reasons_contain(ev: Dictionary, kw: String) -> bool:
	for r in ev.get("reasons", []):
		if str(r).contains(kw):
			return true
	return false

func _dict_eq(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if str(a[k]) != str(b.get(k, "")):
			return false
	return true

func _questions_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		# ★ 第二十九轮：题目换成了统一 schema（题面在 text）
		if str(a[i].get("card", "")) != str(b[i].get("card", "")):
			return false
		if str(a[i].get("text", a[i].get("q", ""))) != str(b[i].get("text", b[i].get("q", ""))):
			return false
	return true

# 抽出来的题是否「指向本局真实存在的东西」。
# ★ 第二十九轮重写：原来是按四类分别查各自字段（answer / leak / made_up…），
#   现在只认统一 schema —— 题面 + 选项 + 引用（card / fact）三类。
func _questions_resolve_arr(arr: Array) -> bool:
	for q in arr:
		var qd: Dictionary = q
		if str(qd.get("text", qd.get("q", ""))) == "":
			return false
		var opts: Array = qd.get("options", [])
		if opts.is_empty():
			return false
		for o in opts:
			var od: Dictionary = o
			# 「沉默」允许留空文本（那会用出厂那句）
			if str(od.get("text", "")) == "" and str(od.get("tone", "")) != "silence":
				return false
			if str(od.get("tone", "")) == "":
				return false
		var fid := str(qd.get("fact", ""))
		if fid != "" and DossierData.get_fact(fid).is_empty():
			return false
		var cid := str(qd.get("card", ""))
		if cid != "" and DossierData.get_card(cid).is_empty():
			return false
	return true

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

func _fact_questions(arr: Array) -> Array:
	var out := []
	for q in arr:
		if _q_kind(q as Dictionary) == "fact":
			out.append(q)
	return out

# 题目里有没有「复问 fact_id 这件事」的题，且数量正好 want 道
func _has_fact_recall(arr: Array, fact_id: String, want: int) -> bool:
	var n := 0
	for q in arr:
		var qd: Dictionary = q
		if _q_kind(qd) != "fact":
			continue
		if not bool(qd.get("recall", false)):
			continue
		if str(qd.get("fact", "")) == fact_id:
			n += 1
	return n == want

func _trait_ids_unique() -> bool:
	var seen := {}
	for t in ScenarioData.interrogator_traits():
		var id := str((t as Dictionary).get("id", ""))
		if seen.has(id):
			return false
		seen[id] = true
	return true

func _trait_lookup_ok() -> bool:
	for t in ScenarioData.interrogator_traits():
		var id := str((t as Dictionary).get("id", ""))
		if ScenarioData.get_interrogator_trait(id).is_empty():
			return false
	return true

func _companion_questions(arr: Array) -> Array:
	var out := []
	for q in arr:
		if _q_kind(q as Dictionary) == "companion":
			out.append(q)
	return out

func _blind_questions(arr: Array) -> Array:
	var out := []
	for q in arr:
		if _q_kind(q as Dictionary) == "blind":
			out.append(q)
	return out

func _card_questions(arr: Array) -> Array:
	var out := []
	for q in arr:
		if _q_kind(q as Dictionary) == "card":
			out.append(q)
	return out

func _app_signature() -> String:
	var s := ""
	for slot in OutfitData.SLOT_ORDER:
		s += RunData.true_item(slot) + "|"
	return s

func _zorder_sorted() -> bool:
	var prev := -1
	for slot in OutfitData.PREVIEW_ORDER:
		var z: int = int(OutfitData.SLOT_ZORDER.get(slot, -1))
		if z <= prev:
			return false
		prev = z
	return true

func _every_slot_has_items() -> bool:
	# 只看玩家能看到的槽位 —— 下架的槽位对外「一件都没有」，不算违规
	for slot in OutfitData.active_slots():
		if OutfitData.get_items_for_slot(slot).size() < 2:
			return false
	return true

func _every_slot_has_default() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		# ★ 第三十九轮：妙妙工具**不在原貌表里** —— 它是玩家手动揣的道具，
		#   默认值是「（不携带）」这个空件，由 `_equip_defaults()` 单独铺（见那里）。
		if OutfitData.is_manual_slot(slot):
			continue
		if not OutfitData.DEFAULT_LOADOUT.has(slot):
			return false
	return true

func _defaults_resolve() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		if OutfitData.is_manual_slot(slot):
			continue
		var it := OutfitData.get_item(OutfitData.DEFAULT_LOADOUT.get(slot, ""))
		if it.is_empty() or it["slot"] != slot:
			return false
	return true

func _ids_unique() -> bool:
	var seen := {}
	for it in OutfitData.ITEMS:
		if seen.has(it["id"]):
			return false
		seen[it["id"]] = true
	return true

func _slots_valid() -> bool:
	for it in OutfitData.ITEMS:
		if not OutfitData.SLOT_ORDER.has(it["slot"]):
			return false
	return true

func _pool_covers_all_slots() -> bool:
	for slot in OutfitData.auto_slots():
		if not OutfitData.TRUE_POOL.has(slot):
			print("      pool missing slot: ", slot)
			return false
	return true

func _pool_non_empty() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		# ★ 第三十九轮：妙妙工具不在原貌相关的表里（它是玩家手动揣的道具），跳过
		if OutfitData.is_manual_slot(slot):
			continue
		if (OutfitData.TRUE_POOL.get(slot, []) as Array).is_empty():
			return false
	return true

func _pool_items_resolve() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		for id in OutfitData.TRUE_POOL.get(slot, []):
			if OutfitData.get_item(str(id)).is_empty():
				print("      pool item missing: ", id)
				return false
	return true

func _pool_slots_match() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		for id in OutfitData.TRUE_POOL.get(slot, []):
			if str(OutfitData.get_item(str(id))["slot"]) != slot:
				print("      pool slot mismatch: ", id)
				return false
	return true

# ★ 第四十九轮：原来这里查的是「池内每件暴露值 ≤ 2」——
#   那条约束的**目的**是「原貌自己不能超第 1 关的暴露上限」（否则玩家连
#   「穿得和 A 一样」都做不到，情报台全中变成不可能）。
#   放开原貌池之后「≤ 2」不再成立，但目的没变 —— 所以改成**直接查目的**：
#   把「每个槽位取池内最高暴露」加起来，不超第 1 关上限。
#   ★ 用「每槽位取最大」是**保守上界**：实际抽取是每槽位各抽一件，
#     不可能比这个更大。
func _pool_within_first_cap() -> bool:
	var worst := 0
	for slot in OutfitData.SLOT_ORDER:
		var best := 0
		for id in OutfitData.TRUE_POOL.get(slot, []):
			best = maxi(best, int(OutfitData.get_item(str(id)).get("exposure", 0)))
		worst += best
	var cap: int = OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE)
	if worst > cap:
		print("      最坏情况原貌暴露 %d > 第 1 关上限 %d" % [worst, cap])
		return false
	return true

# 一套原貌的暴露总和（A 有多露）—— 用来验「A 逐轮变露」
func _true_total_exposure(ta: Dictionary) -> int:
	var t := 0
	for s in ta.keys():
		t += int(OutfitData.get_item(str(ta[s])).get("exposure", 0))
	return t

# 一组条目互不相同（比的是 slots，不比 name —— 名字人人不同，比了没意义）
func _all_distinct(list: Array) -> bool:
	if list.is_empty():
		return false
	var seen := {}
	for e in list:
		var key := str((e as Dictionary).get("slots", e))
		if seen.has(key):
			return false
		seen[key] = true
	return true

# ★ 第四十九轮新增：池里必须真的存在「中高暴露」候选。
#   这是**防回归**用的 —— 全槽位求和之所以不会退化成「暴露值 × 系数」，
#   全靠原貌也可能穿得露。以后谁把池子又收紧回「暴露 ≤ 2」，这条会立刻响。
func _pool_has_exposed_candidates() -> bool:
	var hits := 0
	for slot in OutfitData.SLOT_ORDER:
		for id in OutfitData.TRUE_POOL.get(slot, []):
			if int(OutfitData.get_item(str(id)).get("exposure", 0)) >= 5:
				hits += 1
	if hits < 3:
		print("      池里暴露 ≥ 5 的候选只有 %d 件（需要 ≥ 3）" % hits)
		return false
	return true

func _pool_has_desc() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		for id in OutfitData.TRUE_POOL.get(slot, []):
			if ScenarioData.desc_of(str(id)) == "":
				print("      missing ITEM_DESC: ", id)
				return false
	return true

func _tattoo_desc_ok() -> bool:
	# ★ 第三十五轮：纹身不在原貌候选池里，所以 _pool_has_desc 管不到它们 ——
	#   但玩家能穿，目击情报会用到描述（缺了就退化成「看不真切」）。
	#   这里把「除空件以外的纹身都要有描述」钉死。
	for it in OutfitData.ITEMS:
		if str(it["slot"]) != "tattoo" or str(it["id"]) == "tattoo_none":
			continue
		if ScenarioData.desc_of(str(it["id"])) == "":
			print("      missing ITEM_DESC: ", it["id"])
			return false
	return true

func _default_true_in_pool() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		# ★ 第三十九轮：妙妙工具不在原貌相关的表里（它是玩家手动揣的道具），跳过
		if OutfitData.is_manual_slot(slot):
			continue
		var id := str(OutfitData.TRUE_APPEARANCE.get(slot, ""))
		if not (OutfitData.TRUE_POOL.get(slot, []) as Array).has(id):
			print("      default true not in pool: ", slot, " -> ", id)
			return false
	return true

# ★ 第三十七轮：吊袜带整栏并入袜类 —— 原来那两件现在必须挂在 stockings 槽，
#   而且 garter_none（这一栏的空件）已经被删掉。
func _garter_items_moved_to_stockings() -> bool:
	var moved := 0
	for it in OutfitData.ITEMS:
		var id := str(it["id"])
		if id == "garter_none":
			print("      garter_none 应该已删除")
			return false
		if id.begins_with("garter_"):
			if str(it["slot"]) != "stockings":
				print("      %s 仍在 %s 槽" % [id, str(it["slot"])])
				return false
			moved += 1
	return moved == 2

func _desc_matches_pool() -> bool:
	# 候选池里的每一件都必须有描述；反过来，多余的描述不算错（便于以后扩池）
	for slot in OutfitData.SLOT_ORDER:
		for id in OutfitData.TRUE_POOL.get(slot, []):
			if not ScenarioData.ITEM_DESC.has(str(id)):
				return false
	return true

func _frame_covers_all_slots() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		# ★ 第三十九轮：妙妙工具不在原貌相关的表里（它是玩家手动揣的道具），跳过
		if OutfitData.is_manual_slot(slot):
			continue
		if not ScenarioData.CLUE_FRAME.has(slot):
			print("      CLUE_FRAME missing: ", slot)
			return false
	return true

func _sources_covers_all_slots() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		# ★ 第三十九轮：妙妙工具不在原貌相关的表里（它是玩家手动揣的道具），跳过
		if OutfitData.is_manual_slot(slot):
			continue
		if not ScenarioData.CLUE_SOURCES.has(slot):
			print("      CLUE_SOURCES missing: ", slot)
			return false
	return true

func _sources_enough() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		# ★ 第三十九轮：妙妙工具不在原貌相关的表里（它是玩家手动揣的道具），跳过
		if OutfitData.is_manual_slot(slot):
			continue
		if (ScenarioData.CLUE_SOURCES.get(slot, []) as Array).size() < 2:
			return false
	return true

func _bg_ids_unique() -> bool:
	var seen := {}
	for b in ScenarioData.BACKGROUNDS:
		if seen.has(b["id"]):
			return false
		seen[b["id"]] = true
	return true

func _bg_fields_ok() -> bool:
	for b in ScenarioData.enabled_backgrounds():
		# intro 是第十三轮新增的「开场介绍」—— 开场浮窗直接展示它
		for k in ["id", "name", "venue", "intro", "interrogator", "cover_role", "true_role", "true_name"]:
			if str(b.get(k, "")).length() < 2:
				print("      bg field bad: ", b.get("id", "?"), " / ", k)
				return false
		# ★ 第五十二轮：`levels` 从「必须非空」里拿掉 —— 空 = **回落全局那份**
		#   （`OutfitData.bg_levels()` 空 → 用 DEFAULT_LEVELS），这是运行时支持的语义；
		#   而且第五十二轮起每套背景的 `levels` 覆写就是空的（轮次名改成通用名字了）。
		for k in ["cards", "questions", "interference_lines"]:
			if (b.get(k, []) as Array).is_empty():
				print("      bg array empty: ", b.get("id", "?"), " / ", k)
				return false
	return true

func _count_owner(bg: Dictionary, owner: String) -> int:
	var n := 0
	for c in bg["cards"]:
		if str(c["owner"]) == owner:
			n += 1
	return n

func _bg_card_ids_unique(bg: Dictionary) -> bool:
	var seen := {}
	for c in bg["cards"]:
		if seen.has(c["id"]):
			return false
		seen[c["id"]] = true
	return true

# 这套背景的题目引用是否都成立。
# ★ 第二十九轮：题目改挂 card / fact 两个**可选**引用，所以只在填了的时候查存在性
#   （以前是「必须指向一张卡」，现在不挂卡就是盲区题 —— 那是合法设计）。
func _bg_questions_resolve(bg: Dictionary) -> bool:
	var card_ids := {}
	for c in bg["cards"]:
		card_ids[c["id"]] = true
	var fact_ids := {}
	for f in (bg.get("facts", []) as Array):
		fact_ids[f["id"]] = true
	for q in bg["questions"]:
		var qd: Dictionary = q
		var cid := str(qd.get("card", ""))
		if cid != "" and not card_ids.has(cid):
			print("      question points at missing card: ", cid)
			return false
		var fid := str(qd.get("fact", ""))
		if fid != "" and not fact_ids.has(fid):
			print("      question points at missing fact: ", fid)
			return false
	return true

# 每道题的选项是否都站得住。
# ★ 第二十九轮：从「每题必须有 bluff / evade 两段文本」改成
#   「每个选项的 tone 合法、除沉默外都有文本」。
func _bg_questions_options(bg: Dictionary) -> bool:
	var tones := ["correct", "leak", "version", "bluff", "evade", "silence", "made_up"]
	for q in bg["questions"]:
		var qd: Dictionary = q
		var opts: Array = qd.get("options", [])
		if opts.is_empty():
			return false
		for o in opts:
			var od: Dictionary = o
			var tn := str(od.get("tone", ""))
			if not tones.has(tn):
				return false
			if str(od.get("text", "")) == "" and tn != "silence":
				return false
		# ★ 第二十九轮：题面字段从 `q` 改叫 `text`
		if str(qd.get("text", qd.get("q", ""))).length() < 6:
			return false
	return true

func _req_increasing() -> bool:
	var prev := -1
	for lv in OutfitData.LEVELS:
		var r: int = int(lv["contrast_req"])
		if r <= prev:
			return false
		prev = r
	return true

func _cap_increasing() -> bool:
	var prev := -1
	for i in OutfitData.LEVELS.size():
		var acc := OutfitData.START_ACCEPTANCE
		for j in range(i):
			acc += int(OutfitData.LEVELS[j]["acceptance_gain"])
		var c := OutfitData.exposure_cap(acc)
		if c <= prev:
			return false
		prev = c
	return true

func _all_assets_exist(sub: String) -> bool:
	var root := DolDoll.root()
	for it in OutfitData.ITEMS:
		var p := "%s%s/%s.png" % [root, sub, it["id"]]
		if not ResourceLoader.exists(p):
			print("      missing: ", p)
			return false
	return true

# 小人素材（从图包烘焙）是否齐全：
#   · 每件物品都有 30×30 的卡片图标 —— 空件（不戴/素颜）也要有一枚，
#     否则那一排卡片会缺一块。
#   · 当前图包的图层表里每个非空件的图层文件都要真的存在。
#   ★ 路径一律走 DolDoll.root()，不要写死目录名 —— 换图包时测试才不会去
#     查一个不存在的目录，出现「假通过」。
func _doll_icons_complete() -> bool:
	var root := DolDoll.root()
	for it in OutfitData.ITEMS:
		if not ResourceLoader.exists(root + "icons/%s.png" % it["id"]):
			print("      missing icon: ", it["id"])
			return false
	for it in OutfitData.ITEMS:
		for L in DolDoll.layers_of(str(it["id"])):
			var p := root + str(L.get("file", ""))
			if not ResourceLoader.exists(p):
				print("      missing layer: ", p)
				return false
	return true

# ------------------------------------------------------------
#  手机 · 与 C 的短信（消息 App 的第二个界面）
#
#  和「与朋友」的区别：
#    · 与朋友 = 官方口径的唯一来源，所以**必须**逐关揭示 facts[i]。
#    · 与 C    = 他不给口径，只提醒你他一直在旁边 —— 所以**一条都不带** reveals。
#  这条「不带 reveals」是设计约束，不是巧合，所以专门断言它。
# ------------------------------------------------------------
func _test_companion_sms() -> void:
	print("\n-- 手机 · 与 C 的短信 --")
	var bad_count := 0
	var bad_level := 0
	var bad_fields := 0
	var bad_reveals := 0
	var dup_id := 0
	for bg in ScenarioData.enabled_backgrounds():
		var cs: Array = ScenarioData.companion_sms_of(bg)
		if cs.size() != OutfitData.MAX_LEVELS:
			bad_count += 1
			continue
		var seen := {}
		for i in cs.size():
			var s: Dictionary = cs[i]
			if int(s.get("level", -1)) != i:
				bad_level += 1
			if str(s.get("id", "")) == "" or str(s.get("contact", "")) == "" \
					or str(s.get("avatar", "")) == "" or (s.get("messages", []) as Array).is_empty():
				bad_fields += 1
			if not (s.get("reveals", []) as Array).is_empty():
				bad_reveals += 1
			var id := str(s.get("id", ""))
			if seen.has(id):
				dup_id += 1
			seen[id] = true
	_check("每套背景 4 条「与 C 的短信」", bad_count == 0)
	_check("每条 level 正好是 0/1/2/3", bad_level == 0)
	_check("每条都有 id / 联系人 / 头像 / 至少一句消息", bad_fields == 0)
	_check("「与 C 的短信」一条都不带 reveals（他不给口径）", bad_reveals == 0)
	_check("同一套背景里 id 不重复", dup_id == 0)

	# 逐关解锁
	var one_per_level := true
	for bg in ScenarioData.enabled_backgrounds():
		for li in OutfitData.MAX_LEVELS:
			if ScenarioData.companion_sms_for_level(bg, li).size() != li + 1:
				one_per_level = false
	_check("第 li 关能看到 li+1 条（一关解锁一条）", one_per_level)

	# 按 id 取
	var first_bg: Dictionary = ScenarioData.enabled_backgrounds()[0]
	var first_id := str((ScenarioData.companion_sms_of(first_bg)[0] as Dictionary).get("id", ""))
	_check("get_companion_sms 能按 id 取到",
		str(ScenarioData.get_companion_sms(first_bg, first_id).get("id", "")) == first_id)
	_check("取不到的 id 返回空字典",
		ScenarioData.get_companion_sms(first_bg, "no_such_sms").is_empty())

	# 与「与朋友」那组不共用 id
	var shared := 0
	for bg in ScenarioData.enabled_backgrounds():
		var a := {}
		for s in ScenarioData.sms_of(bg):
			a[str(s.get("id", ""))] = true
		for s in ScenarioData.companion_sms_of(bg):
			if a.has(str(s.get("id", ""))):
				shared += 1
	_check("「与 C」和「与朋友」的 id 不撞车", shared == 0)

	# 跨关：RunData / DossierData 门面
	ProfileData.reset_all()
	RunData.start_new_run(20261011)
	var seen_n: Array = []
	var mono := true
	for li in OutfitData.MAX_LEVELS:
		var n: int = RunData.companion_sms_threads().size()
		seen_n.append(n)
		if li > 0 and n <= int(seen_n[li - 1]):
			mono = false
		if li < OutfitData.MAX_LEVELS - 1:
			RunData.advance_level()
	_check("RunData.companion_sms_threads 随轮次增长", mono)
	_check("第 1 轮只解锁 1 条", int(seen_n[0]) == 1)
	# ★ 同上一处（`seen_n[3]` 越界 → 断言从未执行）—— 第五十三轮一起修掉
	_check("末轮解锁全部 %d 条" % OutfitData.MAX_LEVELS,
		int(seen_n[OutfitData.MAX_LEVELS - 1]) == OutfitData.MAX_LEVELS)
	_check("companion_sms_total 是全部条数",
		RunData.companion_sms_total() == OutfitData.MAX_LEVELS)
	_check("DossierData 门面与 RunData 一致",
		DossierData.companion_sms_count() == RunData.companion_sms_threads().size()
		and DossierData.companion_sms_total() == RunData.companion_sms_total())
	_check("锁着的条数 = 总数 - 已解锁",
		DossierData.companion_sms_locked_count()
			== DossierData.companion_sms_total() - DossierData.companion_sms_count())
	ProfileData.reset_all()

# ------------------------------------------------------------
#  手机 · 文案层（story.json 的 phone 段）
#
#  手机里所有会显示的字都从 phone 段读（用 tools/phone_editor.html 改）。
#  这里守两件事：
#    1. 每个字段都有内容 —— 空字段会让运行时静默退回出厂文案，等于改了白改。
#    2. 带占位符的字段，% 的个数和 PhoneDesk 里 _tf 传的参数个数一致 ——
#       对不上同样会静默退回出厂文案。
# ------------------------------------------------------------
func _test_phone_text() -> void:
	print("\n-- 手机 · 文案层（phone 段）--")
	var p: Dictionary = ScenarioData.PHONE
	_check("phone 段在（不是空的）", not p.is_empty())
	for k in ["shell", "messages", "memo", "album", "notes"]:
		_check("phone.%s 是字典" % k, p.get(k, null) is Dictionary)
	# ★ 第五十五轮：interrogator_sms 搬进每套背景了（见下面「与审问官」那几条断言）
	_check("phone 段里没有 interrogator_sms 了", not p.has("interrogator_sms"))

	# 取文案：命中 / 落空
	_check("phone_text 能取到 shell.time", ScenarioData.phone_text("shell.time") != "")
	_check("phone_text 取不到时回退 fallback",
		ScenarioData.phone_text("no.such.path", "FB") == "FB")
	_check("phone_text 走到半路不是字典也回退",
		ScenarioData.phone_text("shell.time.deeper", "FB") == "FB")

	# 与审问官的短信（★ 第五十五轮：从 phone 段搬进每套背景，和另外两组同构）
	_check("phone 段里不再有 interrogator_sms（改由每套背景提供）",
		not p.has("interrogator_sms"))
	var ibg: Dictionary = ScenarioData.get_background("border_post")
	var ith: Array = ScenarioData.interrogator_sms_of(ibg)
	_check("interrogator_sms_of(bg) 非空（实际 %d 条）" % ith.size(), ith.size() > 0)
	_check("第 1 轮只解锁 level 0 的那条（实际 %d 条）"
		% ScenarioData.interrogator_sms_for_level(ibg, 0).size(),
		ScenarioData.interrogator_sms_for_level(ibg, 0).size() == 1)
	_check("第 2 轮两条都解锁",
		ScenarioData.interrogator_sms_for_level(ibg, 1).size() == ith.size())
	_check("get_interrogator_sms 能按 id 取到",
		not ScenarioData.get_interrogator_sms(ibg, str((ith[0] as Dictionary).get("id", ""))).is_empty())

	# 每个**还在用**的文案字段都该有内容。
	# ★ 第十三轮停用了一批：notes 里旧的「官方口径对照表」那几条已经不再渲染，
	#   留下空串是刻意的（不动历史数据），所以把它们排除在外。
	var retired: Array = [
		"notes.hint", "notes.head_official", "notes.head_stated", "notes.unknown",
		"notes.no_facts", "notes.no_stated", "notes.mismatch",
	]
	var empty: Array = []
	for sec_name in ["shell", "messages", "memo", "album", "notes"]:
		var d: Dictionary = p.get(sec_name, {})
		for k in d:
			var path: String = sec_name + "." + str(k)
			if retired.has(path):
				continue
			if str(d[k]).strip_edges() == "":
				empty.append(path)
	_check("没有空文案" + ("" if empty.is_empty() else "（空：%s）" % ", ".join(empty)),
		empty.is_empty())
	# 新版备注（按轮次回放）的三条文案必须在
	_check("备注改用「按轮次回放」的三条文案",
		ScenarioData.phone_text("notes.head_round") != ""
		and ScenarioData.phone_text("notes.q_line") != ""
		and ScenarioData.phone_text("notes.a_line") != "")

	# 占位符个数必须和 PhoneDesk 里 _tf 传的参数个数一致
	var expect := {
		"messages.hint": 2, "messages.thread_title": 1,
		"messages.interrogator_row": 2,
		"memo.head_interrogator": 2, "memo.trait_line": 2,
		"memo.like_line": 1, "memo.hate_line": 1,
		"memo.cast_body": 11,
		# ★ 第十三轮删掉了备忘录的「第三条 · 这一轮」——内容整局不变，
		#   所以 memo.level_body / forced_item / forced_none / forced_sep 都不再使用。
		"notes.head_round": 1, "notes.q_line": 1, "notes.a_line": 1,
		# ★ 第四十三轮：一张照片可能同时拍到好几件 —— `cleared` 只带 1 个占位符
		#   （拼好的列表），每件的格式与分隔符另开两条（piece 2 个 / list_sep 0 个）。
		"album.hint": 2, "album.shot": 1, "album.cleared": 1,
		"album.cleared_head": 0, "album.piece": 2, "album.list_sep": 0,
		"album.wipe": 1,
	}
	var wrong: Array = []
	for path in expect:
		var got: int = _count_ph(ScenarioData.phone_text(path))
		if got != int(expect[path]):
			wrong.append("%s 有 %d 个占位符，PhoneDesk 要 %d 个" % [path, got, int(expect[path])])
	_check("每个带占位符的文案，% 个数都和 PhoneDesk 的 _tf 调用一致"
		+ ("" if wrong.is_empty() else "（%s）" % "; ".join(wrong)),
		wrong.is_empty())

	# 三个分组都要有标题 / 说明 / 空列表文案
	for g in ["interrogator", "companion", "friends"]:
		_check("messages.group_%s 标题在" % g,
			ScenarioData.phone_text("messages.group_" + g) != "")
		_check("messages.group_%s_hint 说明在" % g,
			ScenarioData.phone_text("messages.group_" + g + "_hint") != "")
		_check("messages.group_%s_empty 空列表文案在" % g,
			ScenarioData.phone_text("messages.group_" + g + "_empty") != "")

	# 与 C 的对话页有专门的提示；与审问官的对话页有尾注
	_check("与 C 的对话页提示在", ScenarioData.phone_text("messages.companion_thread_hint") != "")
	_check("与审问官对话页尾注在", ScenarioData.phone_text("messages.interrogator_tail") != "")

	# 备忘录第一条的「该怎么答」—— 盲区题唯一的依据
	_check("memo.howto_line 在", ScenarioData.phone_text("memo.howto_line") != "")
	_check("memo.howto_line 有 1 个占位符",
		_count_ph(ScenarioData.phone_text("memo.howto_line")) == 1)
	_check("DossierData.interrogator_hint() 有内容",
		DossierData.interrogator_hint().length() > 6)
	# 5 种性情的「该怎么答」都得写，否则盲区题在那一局就没依据了
	var no_hint := 0
	for tr in ScenarioData.INTERROGATOR_TRAITS:
		if ScenarioData.trait_hint(tr).length() < 6:
			no_hint += 1
	_check("5 种性情都带 hint（该怎么答）", no_hint == 0)

# ------------------------------------------------------------
#  盲区题（「完全没给信息的题」）
#
#  这是唯一一类**不指向任何卡 / 事实**的题 —— 考的就是「手里没底」。
#  数据层的断言就三件事：
#    1. 每套背景都配齐、字段齐全、id 不重复；
#    2. 一局 4 关抽到的**互不重复**（不然「完全没信息」就重复了）；
#    3. 它**不能**带 card / fact —— 带了就不叫「没给信息」了。
#  判定（靠审问官性情）在 TestRunner 里测，那边才跑得动真实盘问。
# ------------------------------------------------------------
func _test_blind_questions() -> void:
	print("\n-- 盲区题（完全没给信息的题）--")
	# ★ 第二十九轮：盲区题**不再是独立的一段**，而是「既不挂卡、也不挂事实」的题 ——
	#   从数据形状自然推出来，这也正是「不再分类」的意思。
	var bad_count := 0
	var bad_fields := 0
	var bad_id := 0
	for bg in ScenarioData.enabled_backgrounds():
		var arr: Array = _blind_of(bg)
		if arr.size() < OutfitData.MAX_LEVELS:
			bad_count += 1
			continue
		var seen := {}
		for q in arr:
			var qd: Dictionary = q
			if str(qd.get("id", "")) == "" or str(qd.get("text", "")) == "" \
					or str(qd.get("setup", "")) == "":
				bad_fields += 1
			var tones := []
			for o in (qd.get("options", []) as Array):
				tones.append(str((o as Dictionary).get("tone", "")))
			if not tones.has("bluff") or not tones.has("evade"):
				bad_fields += 1
			var id := str(qd.get("id", ""))
			if seen.has(id):
				bad_id += 1
			seen[id] = true
	_check("每套背景至少 2 条盲区题（第五十二轮：2 轮制，每轮 1 条）", bad_count == 0)
	_check("每条盲区题 id / 题面 / 说明 / 撒谎 / 回避 都齐全", bad_fields == 0)
	_check("同一套背景里 id 不重复", bad_id == 0)

	# 选项数量可变：有的盲区题不写「硬答」→ 就只有「撒谎 / 回避」两个选项
	var no_made_up := 0
	var with_made_up := 0
	for bg in ScenarioData.enabled_backgrounds():
		for q in _blind_of(bg):
			var has_mu := false
			for o in ((q as Dictionary).get("options", []) as Array):
				if str((o as Dictionary).get("tone", "")) == "made_up":
					has_mu = true
			if has_mu:
				with_made_up += 1
			else:
				no_made_up += 1
	# ★ 第五十二轮：删掉多余内容时，**唯一那条 2 选项的盲区题**（原 level 3、
	#   没写「硬答」的那条）跟着被删了 —— 所以现在每套背景剩的 2 条**都带「硬答」**。
	#   ★ 这条「2 选项」的代码路径因此不再被出厂数据覆盖（`_build_blind_options`
	#     仍支持它），这里如实断言成 0 条，别假装它还覆盖着。
	_check("出厂数据里已没有 2 选项的盲区题（那条随 level 3 一起删了）",
		no_made_up == 0)
	_check("每套背景剩的盲区题都带「硬答」（3 选项）",
		with_made_up == ScenarioData.enabled_backgrounds().size() * OutfitData.MAX_LEVELS)

	# 一局 4 关抽到的必须是 4 条不同的题（每轮第 i 条固定给第 i 关）
	ProfileData.reset_all()
	RunData.start_new_run(20261011)
	var qids := {}
	var miss := 0
	for li in OutfitData.MAX_LEVELS:
		var arr := _blind_questions(
			RunData.questions_for_level(li, Interrogation.QUESTIONS_PER_LEVEL))
		if arr.size() != 1:
			miss += 1
		else:
			var qid := str((arr[0] as Dictionary).get("id", ""))
			if qids.has(qid):
				miss += 1
			qids[qid] = true
		if li < OutfitData.MAX_LEVELS - 1:
			RunData.advance_level()
	_check("4 关每轮恰好 1 道盲区题，且 4 条互不重复", miss == 0)
	ProfileData.reset_all()

	# 选项的语义：只能是「硬编 / 撒谎 / 回避」三种 —— 盲区题没有「正确答案」
	var first_bg: Dictionary = ScenarioData.enabled_backgrounds()[0]
	var blind0: Array = _blind_of(first_bg)
	var q_first := {}
	for q in blind0:
		if int((q as Dictionary).get("level", -1)) == 0:
			q_first = q
			break
	if q_first.is_empty() and not blind0.is_empty():
		q_first = blind0[0]
	var tones0 := []
	for o in (q_first.get("options", []) as Array):
		tones0.append(str((o as Dictionary).get("tone", "")))
	var only_blind_tones := true
	for t in tones0:
		if not ["made_up", "bluff", "evade"].has(t):
			only_blind_tones = false
	_check("盲区题的选项只有「硬编 / 撒谎 / 回避」",
		only_blind_tones and tones0.has("bluff") and tones0.has("evade"))
	_check("盲区题的 setup 说明了「为什么你没底」",
		str(q_first.get("setup", "")).length() > 6)
	_check("盲区题没有「照实答 / 说漏嘴」这类选项（它没有正确答案）",
		not tones0.has("correct") and not tones0.has("leak") and not tones0.has("version"))

# 盲区题 = 既不挂卡、也不挂事实、也不是同行者问的那一批
func _blind_of(bg: Dictionary) -> Array:
	var out := []
	for q in (bg.get("questions", []) as Array):
		var qd: Dictionary = q
		if str(qd.get("card", "")) == "" and str(qd.get("fact", "")) == "" \
				and str(qd.get("speaker", "")) != "companion":
			out.append(qd)
	return out

func _count_ph(s: String) -> int:
	var n := 0
	var i := 0
	while i < s.length():
		if s[i] == "%":
			if i + 1 < s.length() and s[i + 1] == "%":
				i += 2
				continue
			n += 1
		i += 1
	return n

# ------------------------------------------------------------
#  本轮新增的辅助函数
# ------------------------------------------------------------
func _all_high_exposure(arr: Array) -> bool:
	for it in arr:
		if not OutfitData.is_high_exposure(it):
			return false
	return true

func _all_affordable(arr: Array, acceptance: int) -> bool:
	for it in arr:
		if not OutfitData.can_equip(it, acceptance):
			return false
	return true

func _pool_slot_count(arr: Array) -> int:
	var slots := {}
	for it in arr:
		slots[str(it.get("slot", ""))] = true
	return slots.size()

func _max_key(d: Dictionary) -> int:
	var m := 0
	for k in d:
		m = maxi(m, int(k))
	return m

func _arr_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true

# 同槽位里换一件「不是这件」的衣物
func _other_item_in_slot(slot: String, not_id: String) -> Dictionary:
	for it in OutfitData.get_items_for_slot(slot):
		if str(it["id"]) != not_id:
			return it
	return {}
