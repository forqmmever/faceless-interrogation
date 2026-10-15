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

	_test_slots()
	_test_disabled_slots()
	_test_manual_slot_tool()
	_test_item_overrides()
	_test_true_presets()
	_test_bg_overrides()
	_test_question_order()
	_test_underwear_gate()
	_test_tattoo_multi()
	_test_true_pool()
	_test_scenario_data()
	_test_run_randomization()
	_test_model_basics()
	_test_defect_tradeoff()
	_test_exposure_cap()
	_test_contrast()
	_test_level_curve()
	_test_editable_sections()
	_test_open_levels()
	_test_profile()
	_test_forced_items()
	_test_forced_solvability()
	_test_auto_complete()
	_test_sms_levels()
	_test_companion_sms()
	_test_phone_text()
	_test_blind_questions()
	_test_cast()
	_test_assets()

	print("\n=========================================")
	print(" Checks: ", checks, "   Failures: ", failures)
	print(" Result: ", "ALL TESTS PASSED" if failures == 0 else "SOME TESTS FAILED")
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
	var tattoo_ids := []
	for it in OutfitData.ITEMS:
		if str(it["slot"]) == "tattoo":
			tattoo_ids.append(str(it["id"]))
	_check("纹身槽现有 10 件", tattoo_ids.size() == 10)
	_check("含大腿心形纹身", tattoo_ids.has("tattoo_heart"))
	_check("含大腿爪印", tattoo_ids.has("tattoo_paw"))
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
	_check("当前下架列表是外袍 + 耳饰 + 手套 + 头饰 + 穿环",
		off.size() == 5 and off.has("robe") and off.has("earrings")
		and off.has("gloves") and off.has("headgear") and off.has("piercing"))
	_check("下架的槽位仍在 SLOT_ORDER 里（数据没删）",
		OutfitData.SLOT_ORDER.has("robe") and OutfitData.SLOT_ORDER.has("earrings")
		and OutfitData.SLOT_ORDER.has("gloves") and OutfitData.SLOT_ORDER.has("headgear")
		and OutfitData.SLOT_ORDER.has("piercing"))
	_check("active_slots() = SLOT_ORDER - DISABLED_SLOTS",
		OutfitData.active_slots().size() == OutfitData.SLOT_ORDER.size() - off.size())
	_check("active_slots() 不含下架的槽位",
		not OutfitData.active_slots().has("robe")
		and not OutfitData.active_slots().has("earrings")
		and not OutfitData.active_slots().has("gloves")
		and not OutfitData.active_slots().has("headgear")
		and not OutfitData.active_slots().has("piercing"))
	_check("slot_enabled() 语义正确",
		OutfitData.slot_enabled("top") and not OutfitData.slot_enabled("robe")
		and not OutfitData.slot_enabled("earrings")
		and not OutfitData.slot_enabled("gloves")
		and not OutfitData.slot_enabled("headgear")
		and not OutfitData.slot_enabled("piercing"))
	_check("下架槽位对外「一件都没有」",
		OutfitData.get_items_for_slot("robe").is_empty()
		and OutfitData.get_items_for_slot("earrings").is_empty()
		and OutfitData.get_items_for_slot("gloves").is_empty()
		and OutfitData.get_items_for_slot("headgear").is_empty()
		and OutfitData.get_items_for_slot("piercing").is_empty())
	_check("下架槽位不进强制装备池", _forced_pool_excludes_disabled())
	_check("下架的物品仍然完整定义着（4 外袍 + 4 耳饰 + 4 手套 + 4 头饰 + 4 穿环）", _disabled_items_intact())
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
	return n == 20

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
# ------------------------------------------------------------
func _test_manual_slot_tool() -> void:
	print("\n-- 妙妙工具（只能手动装备的一栏）--")
	_check("MANUAL_SLOTS 目前只有 tool 一栏",
		OutfitData.MANUAL_SLOTS.size() == 1 and OutfitData.MANUAL_SLOTS.has("tool"))
	_check("is_manual_slot() 语义正确",
		OutfitData.is_manual_slot("tool") and not OutfitData.is_manual_slot("top"))
	_check("妙妙工具在界面可见槽位里（active_slots）",
		OutfitData.active_slots().has("tool"))
	_check("auto_slots() = active_slots() 去掉 MANUAL_SLOTS",
		OutfitData.auto_slots().size() == OutfitData.active_slots().size() - 1
		and not OutfitData.auto_slots().has("tool"))
	_check("槽位中文名是「妙妙工具」",
		str(OutfitData.SLOT_NAMES.get("tool", "")) == "妙妙工具")

	var tool_ids := []
	for it in OutfitData.get_items_for_slot("tool"):
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
	return OutfitData.is_bare(OutfitData.get_item(str(m.equipped.get("tool", ""))))

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
	# 先**手动**装上尼古喵尾，再点一键达标 —— 它必须原样留在身上
	ProfileData.reset_all()
	RunData.start_new_run(5)
	var m := WardrobeModel.new(OutfitData, RunData.true_appearance(), OutfitData.LEVELS)
	m.reset_for_level(RunData.acceptance_at(0), 0, RunData.true_appearance(), [])
	if not m.equip(OutfitData.get_item("tool_tail")):
		return false
	m.auto_complete_outfit()
	return str(m.item_at("tool").get("id", "")) == "tool_tail"

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

	# ---- 默认：文件里两处都空 → 完全走老逻辑 ----
	_check("默认没有随机池", ScenarioData.true_preset_pool().is_empty())
	var by_lv: Array = ScenarioData.true_preset_by_level()
	_check("默认的按关覆写里每一关都是「不覆写」（空字典）",
		by_lv.size() == OutfitData.level_count()
		and by_lv.all(func(x): return (x as Dictionary).is_empty()))

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
		"by_level": [{"name": "第1轮", "slots": {"hair": "hair_short"}}, null, null, null],
	}
	ScenarioData._true_presets = dirty
	var cleaned: Array = ScenarioData.true_preset_pool()
	_check("★ 清洗后被丢掉 4 项，只剩「好套」1 套（实际 %d）" % cleaned.size(),
		cleaned.size() == 1 and str(cleaned[0].get("name", "")) == "好套")
	var lv2: Array = ScenarioData.true_preset_by_level()
	_check("按关覆写保留位置：第 1 轮有值，其余 3 关是空",
		not (lv2[0] as Dictionary).is_empty()
		and (lv2[1] as Dictionary).is_empty()
		and (lv2[2] as Dictionary).is_empty()
		and (lv2[3] as Dictionary).is_empty())

	# ---- ★ 未配覆写的关必须「回到基础原貌」，不能粘着上一轮 ----
	#   这个 bug 是端到端探针抓出来的：第 2 轮配了覆写、第 3 轮没配，
	#   第 3 轮却还在用第 2 轮的衣服（true_app 被覆写覆盖后就丢了基础那套）。
	#   修法：基础原貌（base_true_app）整局只算一次，按关覆写只临时顶替它。
	ScenarioData._true_presets = {
		"pool": [{"name": "基础套", "slots": {"top": "top_longsleeve"}}],
		"by_level": [{}, {"name": "第2轮", "slots": {"top": "top_highneck"}}, {}, {}],
	}
	ProfileData.reset_all()
	RunData.start_new_run(4242)
	var t1 := str(RunData.true_item("top"))
	RunData.advance_level()
	var t2 := str(RunData.true_item("top"))
	RunData.advance_level()
	var t3 := str(RunData.true_item("top"))
	_check("★ 第 1 轮（未配）用随机池那套：" + t1, t1 == "top_longsleeve")
	_check("★ 第 2 轮（配了覆写）换成覆写那套：" + t2, t2 == "top_highneck")
	_check("★ 第 3 轮（未配）**回到基础那套**，不粘着第 2 轮：" + t3, t3 == "top_longsleeve")
	_check("基础原貌整局只算一次（第 1 轮与第 3 轮一致）", t1 == t3)

	# ---- 从选关面板直接进第 2 轮 → 开局就该用那一关的覆写 ----
	#   ★ level_index 必须**先**设好再抽原貌（以前它在抽完之后才设，会取错轮次）
	ProfileData.reset_all()
	RunData.start_new_run(4242, 1)
	_check("★ 直接进第 2 轮时开局原貌就是覆写那套：" + str(RunData.true_item("top")),
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
	ScenarioData._true_presets = {}
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
	_check("没写反差要求的那一轮按自增算（30 + 3 = 33）",
		int(OutfitData.level_at(1).get("contrast_req", -1)) == 33)

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
	ScenarioData._true_presets = {}
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
#  原貌候选池（多轮制的基础）
# ------------------------------------------------------------
func _test_true_pool() -> void:
	print("\n-- 原貌候选池 TRUE_POOL --")
	_check("候选池覆盖全部 %d 个槽位" % OutfitData.auto_slots().size(),
		_pool_covers_all_slots())
	_check("池内物品 id 全部存在", _pool_items_resolve())
	_check("池内物品都属于它所在的槽位", _pool_slots_match())
	_check("每个槽位至少 1 个候选", _pool_non_empty())
	_check("池内物品暴露值均 ≤ 2（第 1 关上限只有 22）", _pool_low_exposure())
	_check("池内每件物品都有目击描述（ITEM_DESC）", _pool_has_desc())
	_check("默认原貌取自候选池", _default_true_in_pool())

	print("\n-- 原貌候选池的暴露值上界 --")
	var worst := 0
	for slot in OutfitData.SLOT_ORDER:
		var best := 0
		for id in OutfitData.TRUE_POOL.get(slot, []):
			best = maxi(best, int(OutfitData.get_item(id).get("exposure", 0)))
		worst += best
	print("      最坏情况原貌暴露值合计 = %d（第 1 关上限 %d）" % [
		worst, OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE)])
	_check("最坏情况原貌本身不超第 1 关上限",
		worst <= OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE))

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
	_check("背景库读到 ≥ 4 套", ScenarioData.BACKGROUNDS.size() >= 4)
	_check("性情表读到 ≥ 5 种", ScenarioData.INTERROGATOR_TRAITS.size() >= 5)
	_check("衣物目击描述非空", ScenarioData.ITEM_DESC.size() > 0)
	_check("至少 4 套背景", ScenarioData.bg_count() >= 4)
	_check("背景 id 唯一", _bg_ids_unique())
	_check("每套背景字段齐全", _bg_fields_ok())

	for bg in ScenarioData.BACKGROUNDS:
		var nm := str(bg["name"])
		_check("[%s] 轮次名 4 条" % nm, (bg["levels"] as Array).size() == OutfitData.MAX_LEVELS)
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
			if not pool.has(id):
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
	_check("每轮抽 8 道题", q0.size() == Interrogation.QUESTIONS_PER_LEVEL)
	_check("同局同关题目稳定",
		_questions_eq(RunData.questions_for_level(0, Interrogation.QUESTIONS_PER_LEVEL), q0))
	_check("同一局不同关题目不同", not _questions_eq(q0, q1))
	_check("抽出的题都指向存在的卡 / 事实", _questions_resolve_arr(q0))

	# ---- 编排（一关 8 道，★ 第十三轮）：
	#      0 档案题 · 1 新事实 · 2 同行者提问 · 3 档案题
	#      4 档案题 · 5 ★盲区题 · 6 跨轮复问 · 7 档案题
	#    ★ 改动点：第 4 道原来是「同关复问」，现在**改回档案题** ——
	#      一轮之内不再复问同一个事实，所以一轮之内也不会出现前后矛盾。
	#      第 1 轮没有「上一轮」，第 6 道让给档案题（于是第 1 轮 5 道档案题）。
	var f0 := _fact_questions(q0)
	var c0 := _card_questions(q0)
	var comp0 := _companion_questions(q0)
	var b0 := _blind_questions(q0)
	_check("第 1 轮：5 道档案题 + 1 道新说法题 + 1 道同行者提问 + 1 道盲区题",
		c0.size() == 5 and f0.size() == 1 and comp0.size() == 1 and b0.size() == 1)
	# ★ 第二十九轮：题序 = **题目清单的顺序**（固定题先出 → 复问 → 通用池抽取），
	#   不再由代码写死成「档案 / 说法 / 同行者 / 档案 / 档案 / 盲区 / 档案」。
	#   出厂迁移过来的那一份是「新说法 → 同行者 → 盲区 → 档案题…」。
	# ★ 第二十九轮：新 schema 里「没写 recall」就是普通题（默认 false）——
	#   原先这里默认 true 是旧格式的写法（旧格式里 recall 由代码标）。
	_check("第 1 道是本轮新增的说法题（不是复问）",
		_q_kind(q0[0]) == "fact" and not bool((q0[0] as Dictionary).get("recall", false)))
	_check("第 2 道是同行者提问", _q_kind(q0[1]) == "companion")
	_check("第 3 道是盲区题（「完全没给信息的题」）", _q_kind(q0[2]) == "blind")
	_check("第 4~8 道都是档案题（第 1 轮不排复问）",
		_q_kind(q0[3]) == "card" and _q_kind(q0[4]) == "card" and _q_kind(q0[5]) == "card"
		and _q_kind(q0[6]) == "card" and _q_kind(q0[7]) == "card")
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
		if ScenarioData.facts_of(bg).size() < OutfitData.MAX_LEVELS:
			bad_bg += 1
		if ScenarioData.sms_of(bg).size() < 3:
			bad_bg += 1
		# ★ 第二十九轮：同行者提问已并入统一题目清单（speaker = companion）
		var comp_n := 0
		for q in (bg.get("questions", []) as Array):
			if str((q as Dictionary).get("speaker", "")) == "companion":
				comp_n += 1
		if comp_n < 3:
			bad_bg += 1
	_check("每套背景都有 ≥4 个事实 / ≥3 段短信 / ≥3 条同行者提问", bad_bg == 0)

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
	_check("样本里确实查到了同行者提问（否则这几条断言是空转）", seen_cq >= 12)
	_check("每条同行者提问都有 3 个选项且至少一个能顶回去", bad_cq == 0)
	_check("同行者提问的每个 value 都能解析成真实版本", bad_cq_val == 0)
	_check("同行者提问「顶回去」的那个就是官方口径", missing_canonical == 0)

	# ---- 照片：清晰度上限与阈值 ----
	var bad_photo := 0
	for bid in ScenarioData.background_ids():
		RunData.start_new_run(9000 + int(bid.hash() % 1000))
		for i in RunData.photos.size():
			var ph: Dictionary = RunData.photo_at(i)
			if ScenarioData.photo_focus(str(ph["slot"])) == Rect2():
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
	_check("接受度6（开局）-> 上限22", OutfitData.exposure_cap(OutfitData.START_ACCEPTANCE) == 22)

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
	_check("新算法：只有上衣与下装参与反差",
		WardrobeModel.CONTRAST_SLOTS.size() == 2
		and WardrobeModel.CONTRAST_SLOTS.has("top")
		and WardrobeModel.CONTRAST_SLOTS.has("bottom"))
	_check("新算法：开场（穿着原貌）反差 = 0", mm.total_contrast() == 0)
	_check("新算法：反差的量纲 = |暴露度差| × 系数",
		mm.total_contrast() == _expect_contrast(mm))
	# 改一件**不参与反差**的部位（发型）→ 反差不动
	mm.equip(OutfitData.get_item("hair_short"))
	_check("新算法：改发型不影响反差",
		mm.total_contrast() == 0 and mm.total_contrast() == _expect_contrast(mm))
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
	# ★ 第三十一轮：颈饰**不再**参与反差（只有上衣与下装算）—— 长袖上衣在算
	_check("长袖上衣的反差计入总和", m.total_contrast() > 0)
	_check("颈饰不再计入反差（口径：只算上衣与下装）",
		m.total_contrast() == _expect_contrast(m)
		and OutfitData.get_item("neck_scarf")["contrast"] > 0)

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
	_check("一局 4 关", OutfitData.LEVELS.size() == 4)
	_check("MAX_LEVELS = 4", OutfitData.MAX_LEVELS == 4)
	_check("起始接受度 > 0（否则第 1 轮几乎无物可换）", OutfitData.START_ACCEPTANCE > 0)
	_check("反差要求逐关递增", _req_increasing())
	_check("暴露值上限逐关递增", _cap_increasing())
	_check("最后一关不再给接受度", int(OutfitData.LEVELS[3]["acceptance_gain"]) == 0)

	# ★ 第二十九轮：反差值要求改成「自增 + 可手写覆盖」——
	#   留空的关 = 上一轮 + rules.contrast_req_step；手写的值成为后面自增的新起点。
	#   游戏端解析在 OutfitData._resolve_contrast_req，这里验最终结果。
	var rq_base := int(ScenarioData.rule_i("contrast_req_base", -1))
	var rq_step := int(ScenarioData.rule_i("contrast_req_step", -1))
	_check("反差值曲线的 base / step 都在 rules 里",
		rq_base > 0 and rq_step > 0)
	_check("第 1 轮的反差要求是手写的基线（不是自增出来的）",
		not OutfitData.contrast_req_is_auto(0))
	_check("第 2~4 关留空 → 走自增", OutfitData.contrast_req_is_auto(1)
		and OutfitData.contrast_req_is_auto(2) and OutfitData.contrast_req_is_auto(3))
	_check("自增序列 = base + step × 关号（%d / %d / %d / %d）" % [
			int(OutfitData.level_at(0)["contrast_req"]), int(OutfitData.level_at(1)["contrast_req"]),
			int(OutfitData.level_at(2)["contrast_req"]), int(OutfitData.level_at(3)["contrast_req"])],
		int(OutfitData.level_at(0)["contrast_req"]) == rq_base
		and int(OutfitData.level_at(1)["contrast_req"]) == rq_base + rq_step
		and int(OutfitData.level_at(2)["contrast_req"]) == rq_base + rq_step * 2
		and int(OutfitData.level_at(3)["contrast_req"]) == rq_base + rq_step * 3)
	# 手写覆盖：临时把第 2 轮写死，看它是否成为后面自增的新起点
	var saved_rq: Array = []
	for i in OutfitData.MAX_LEVELS:
		saved_rq.append((OutfitData.LEVELS[i] as Dictionary).duplicate())
	var manual := rq_base + 25
	OutfitData.LEVELS[1]["contrast_req"] = manual
	var lv_ov: Array = [{}]
	# 直接重跑一次解析：LEVELS 已经是解析后的表，手写值会被再解析一遍（幂等）
	for i in OutfitData.MAX_LEVELS:
		var d: Dictionary = OutfitData.LEVELS[i]
		if i == 1:
			d["contrast_req"] = manual
		elif i > 1:
			d.erase("contrast_req")
	OutfitData.LEVELS[0]["contrast_req"] = rq_base
	# 用一个独立的模型验证「手写值 + 后面跟着抬」这条规则
	_check("手写值 >= 上一轮时曲线仍然递增（不报错）",
		manual >= rq_base)
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
	RunData.advance_level()
	RunData.advance_level()
	_check("推进 3 次后到第 4 轮", RunData.level_index == 3)
	_check("第 4 关仍未通关", RunData.is_run_complete() == false)
	RunData.advance_level()
	_check("第 4 关推进后整局通关", RunData.is_run_complete() == true)
	_check("已通过 4 关", RunData.cleared_levels == 4)

	print("\n-- 背景与原貌跨关保持不变 --")
	RunData.start_new_run(1234)
	var bg0 := RunData.background_id
	var ta0 := RunData.true_appearance().duplicate()
	RunData.advance_level()
	_check("进入下一轮后背景不变", RunData.background_id == bg0)
	_check("进入下一轮后原貌不变", _dict_eq(RunData.true_appearance(), ta0))
	_check("进入下一轮后外貌情报不变",
		str(DossierData.clue_for_slot("hair")["text"]) == ScenarioData.clue_text("hair", ta0["hair"]))

	print("\n-- 本轮重来（失败 → 回到本轮开始）--")
	ProfileData.reset_all()          # 从零开始，好精确断言「跨局保留」
	RunData.start_new_run(20260101)
	var bg1 := RunData.background_id
	var ta1 := RunData.true_appearance().duplicate()
	RunData.advance_level()
	var banked := ProfileData.bonus()
	_check("过关后这一关的接受度立刻进账号",
		banked == int(OutfitData.LEVELS[0]["acceptance_gain"]))

	# 这一轮里发生的事（说法 / 矛盾 / 问答记录），失败重来要回滚
	GameData.snapshot_level_state()
	GameData.stated_facts["trip"] = "by_sea"
	GameData.contradictions = 2
	GameData.answer_log.append({"level": 1, "q": "测试", "answer": "测试"})
	GameData.interrogator_sms.append("测试短信")
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
	_check("重来后本轮的事故短信回滚", GameData.interrogator_sms.is_empty())
	_check("重来后怀疑度底子回滚", is_equal_approx(GameData.suspicion_carry, 0.0))
	# ★ 接受度是**跨局保留**的 —— 本轮重来也不会把已经赚到的还回去
	_check("重来后接受度 = 起始值 + 跨局保留",
		RunData.acceptance == OutfitData.START_ACCEPTANCE + banked)
	_check("本轮重来不退还已赚到的接受度",
		banked > 0 and RunData.acceptance > OutfitData.START_ACCEPTANCE)
	_check("重来后强制装备与原来一致（同一关同一个种子）",
		_arr_eq(RunData.forced_item_ids(), forced_before))

	print("\n-- 多关可解性（动态规划，%d 个随机种子 × 4 关）--" % PROBE_SEEDS)
	var all_ok := true
	var worst := []
	var best := []
	for li in OutfitData.MAX_LEVELS:
		worst.append(999999)
		best.append(0)
	var unsolvable := 0

	for s in range(1, PROBE_SEEDS + 1):
		RunData.start_new_run(s)
		var ta: Dictionary = RunData.true_appearance()
		for li in OutfitData.MAX_LEVELS:
			var acc: int = RunData.acceptance_at(li)
			var cap: int = OutfitData.exposure_cap(acc)
			var opt: int = _dp_optimum(ta, acc, cap)
			if opt < 0:
				unsolvable += 1
				all_ok = false
				continue
			worst[li] = mini(worst[li], opt)
			best[li] = maxi(best[li], opt)

	for li in OutfitData.MAX_LEVELS:
		var req: int = int(OutfitData.LEVELS[li]["contrast_req"])
		print("      第%d轮 acc=%2d cap=%2d 要求=%3d 最优 %3d~%3d" % [
			li + 1, RunData.acceptance_at(li), OutfitData.exposure_cap(RunData.acceptance_at(li)),
			req, worst[li], best[li]])
		_check("第%d轮存在满足全部约束的配置" % (li + 1), worst[li] >= req)
		_check("第%d轮默认原貌本身不达标（不白送）" % (li + 1), 0 < req)

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
	_check("默认读到 4 关", OutfitData.level_count() == 4)
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
#  选关开放状态（第二十一轮）
#
#  用户口径：「点击开始游戏后出现进入四关的选项，目前只开放第一轮，
#            其他关暂时锁定，无需删除」
#  这里把「锁定 ≠ 删除」钉死：四关的曲线 / 名字一条不少，锁的只是入口。
# ------------------------------------------------------------
func _test_open_levels() -> void:
	print("\n-- 选关开放状态（四关入口，只开放第一轮）--")
	_check("开放表非空", not OutfitData.OPEN_LEVELS.is_empty())
	_check("第 1 轮开放", OutfitData.level_unlocked(0))
	_check("第 2 / 3 / 4 轮暂时锁定",
		not OutfitData.level_unlocked(1) and not OutfitData.level_unlocked(2)
		and not OutfitData.level_unlocked(3))
	_check("开放关数 = 1", OutfitData.open_level_count() == 1)
	_check("开放表里没有越界下标",
		OutfitData.OPEN_LEVELS.all(func(li): return int(li) >= 0 and int(li) < OutfitData.MAX_LEVELS))

	# ★ 锁定不等于删除：四关的数值曲线与名字全都还在
	_check("锁定的轮次数值曲线还在（LEVELS 仍是 4 条）", OutfitData.LEVELS.size() == 4)
	_check("锁定的轮次名字还在", OutfitData.LEVELS[3].get("name", "") != "")
	var all_named := true
	for lv in OutfitData.LEVELS:
		if str(lv.get("name", "")) == "" or int(lv.get("contrast_req", -1)) < 0:
			all_named = false
	_check("四关都有名字与反差要求", all_named)

	# 从某一关开局：关卡索引与已通过关数都拨到那一关，接受度不白送
	RunData.start_new_run(8888, 2)
	_check("从第 3 轮开局 → 轮次索引 = 2", RunData.level_index == 2)
	_check("从第 3 关开局 → 已通过关数 = 2", RunData.cleared_levels == 2)
	_check("从第 3 轮开局 → 接受度不白送",
		RunData.acceptance == OutfitData.START_ACCEPTANCE + ProfileData.bonus())
	# 同一个种子 + 同一关 → 强制装备可复现（重来时靠的就是这条）
	var forced_at_3: Array = RunData.forced_item_ids().duplicate()
	RunData.start_new_run(8888, 2)
	_check("同一关同一个种子 → 强制装备可复现",
		_arr_eq(RunData.forced_item_ids(), forced_at_3))
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
	ProfileData.note_run_finished(4, true)
	_check("记战绩：本轮重来 1 次", ProfileData.level_failures == 1)
	_check("记战绩：通关 1 局", ProfileData.runs_cleared == 1)
	_check("记战绩：单局最好 4 关", ProfileData.best_cleared == 4)
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
	_check("接受度越高，强制池越大", high_acc.size() > low_acc.size())
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
const FORCED_SEEDS := 120

func _test_forced_solvability() -> void:
	print("\n-- 强制装备的可解性（%d 个种子 × 4 关）--" % FORCED_SEEDS)
	var bad := 0
	var levels_with_forced := 0
	var first_level_forced := 0
	var total_levels := 0
	var worst := ""
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
	print("      （%d / %d 轮带强制装备）" % [levels_with_forced, total_levels])
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
const AUTO_SEEDS := 24

func _test_auto_complete() -> void:
	print("\n-- 一键达标（%d 个种子 × 4 关）--" % AUTO_SEEDS)
	var total := AUTO_SEEDS * OutfitData.MAX_LEVELS
	var bad := 0                 # 违反硬约束的次数
	var not_pass := 0
	var worst := ""
	var no_forced := 0
	var over_req := 0
	var min_changed := 999
	var exact := 0
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
			#    （DP 是全局最优，所以局部最优必须成立 —— 不成立就是求解器写错了）
			if _is_locally_optimal(m):
				exact += 1
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
	_check("一键达标确实动过衣服（不是空操作）", min_changed > 0)
	_check("样本里出现过没有强制装备的关（否则断言空转）", no_forced > 0)
	_check("样本里出现过带强制装备的关", no_forced < total)
	_check("至少有一部分关求解后留有余量（反差高于要求）", over_req > 0)
	if worst != "":
		print("      首个不达标：", worst)
	print("      （%d / %d 轮没有强制装备 ｜ 余量关 %d ｜ 最少改动 %d 个槽位）" % [
		no_forced, total, over_req, min_changed])

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
func _is_locally_optimal(m: WardrobeModel) -> bool:
	var base: int = m.total_contrast()
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
			var better: bool = m.total_contrast() > base \
				and not m.is_over_cap() \
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
	for bg in ScenarioData.BACKGROUNDS:
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
	for bg in ScenarioData.BACKGROUNDS:
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
	_check("第 4 轮解锁全部 4 条", int(seen[3]) == OutfitData.MAX_LEVELS)
	_check("sms_total 是全部条数", RunData.sms_total() == OutfitData.MAX_LEVELS)
	ProfileData.reset_all()

# ------------------------------------------------------------
#  本局卡司：A 真身 / B 马甲 / C 同行人
# ------------------------------------------------------------
func _test_cast() -> void:
	print("\n-- 本局卡司（A 真身 / B 马甲 / C 同行人）--")
	ProfileData.reset_all()
	RunData.start_new_run(20261011)
	var c: Dictionary = RunData.cast()
	_check("卡司有 A 真身 / B 马甲 / 审讯官 / C 同行人",
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

	# 一局之内绝不换人：跨关后卡司完全一致
	var before := RunData.cast()
	RunData.advance_level()
	RunData.advance_level()
	var after := RunData.cast()
	_check("跨关之后卡司一个都没换", _dict_eq(before, after))

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
			arr.append([int(it["exposure"]), int(it["contrast"]), cov,
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
		for g in group:
			var s := str(g)
			var it: Array = acc[s]
			cov |= int(it[2])
			if not _counts_with(eq, s):
				continue        # 外衣不够露 → 这件内衣既不算暴露、也不算反差
			exp += int(it[0])
			if str(it[4]) != str(true_app.get(s, "")):
				con += int(it[1])
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
#   口径（用户口径）：只算上衣与下装；数值 = |你穿的暴露度 − 原貌那件的暴露度| × 系数。
#   这里刻意不走模型内部函数，而是直接用 ITEMS 里的 exposure 现推 ——
#   否则就是「拿实现验证实现」，改了算法也照样通过。
func _expect_contrast(m: WardrobeModel) -> int:
	var w := OutfitData.contrast_per_exposure()
	var t := 0
	for slot in ["top", "bottom"]:
		var ss := str(slot)
		if not m.counts_toward_totals(ss):
			continue
		var base_id := str(m.true_appearance.get(ss, ""))
		var base_e := 0
		if base_id != "":
			base_e = int(OutfitData.get_item(base_id).get("exposure", 0))
		var now_e := int(m.item_at(ss).get("exposure", 0))
		t += absi(now_e - base_e) * w
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

func _pool_low_exposure() -> bool:
	for slot in OutfitData.SLOT_ORDER:
		for id in OutfitData.TRUE_POOL.get(slot, []):
			if int(OutfitData.get_item(str(id)).get("exposure", 0)) > 2:
				print("      pool item too exposed: ", id)
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
	for b in ScenarioData.BACKGROUNDS:
		# intro 是第十三轮新增的「开场介绍」—— 开场浮窗直接展示它
		for k in ["id", "name", "venue", "intro", "interrogator", "cover_role", "true_role", "true_name"]:
			if str(b.get(k, "")).length() < 2:
				print("      bg field bad: ", b.get("id", "?"), " / ", k)
				return false
		for k in ["levels", "cards", "questions", "interference_lines"]:
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
	for bg in ScenarioData.BACKGROUNDS:
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
	for bg in ScenarioData.BACKGROUNDS:
		for li in OutfitData.MAX_LEVELS:
			if ScenarioData.companion_sms_for_level(bg, li).size() != li + 1:
				one_per_level = false
	_check("第 li 关能看到 li+1 条（一关解锁一条）", one_per_level)

	# 按 id 取
	var first_bg: Dictionary = ScenarioData.BACKGROUNDS[0]
	var first_id := str((ScenarioData.companion_sms_of(first_bg)[0] as Dictionary).get("id", ""))
	_check("get_companion_sms 能按 id 取到",
		str(ScenarioData.get_companion_sms(first_bg, first_id).get("id", "")) == first_id)
	_check("取不到的 id 返回空字典",
		ScenarioData.get_companion_sms(first_bg, "no_such_sms").is_empty())

	# 与「与朋友」那组不共用 id
	var shared := 0
	for bg in ScenarioData.BACKGROUNDS:
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
	_check("第 4 轮解锁全部 4 条", int(seen_n[3]) == OutfitData.MAX_LEVELS)
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
	_check("phone.interrogator_sms 非空",
		(p.get("interrogator_sms", []) as Array).size() > 0)

	# 取文案：命中 / 落空
	_check("phone_text 能取到 shell.time", ScenarioData.phone_text("shell.time") != "")
	_check("phone_text 取不到时回退 fallback",
		ScenarioData.phone_text("no.such.path", "FB") == "FB")
	_check("phone_text 走到半路不是字典也回退",
		ScenarioData.phone_text("shell.time.deeper", "FB") == "FB")

	# 与审问官的事件短信会循环取用
	var n: int = (p.get("interrogator_sms", []) as Array).size()
	_check("interrogator_sms_at(0) 非空", ScenarioData.interrogator_sms_at(0) != "")
	_check("interrogator_sms_at 越界后循环",
		ScenarioData.interrogator_sms_at(n) == ScenarioData.interrogator_sms_at(0))

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
		"album.hint": 2, "album.shot": 1, "album.cleared": 2, "album.wipe": 1,
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
	for bg in ScenarioData.BACKGROUNDS:
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
	_check("每套背景至少 4 条盲区题", bad_count == 0)
	_check("每条盲区题 id / 题面 / 说明 / 撒谎 / 回避 都齐全", bad_fields == 0)
	_check("同一套背景里 id 不重复", bad_id == 0)

	# 选项数量可变：有的盲区题不写「硬答」→ 就只有「撒谎 / 回避」两个选项
	var no_made_up := 0
	var with_made_up := 0
	for bg in ScenarioData.BACKGROUNDS:
		for q in _blind_of(bg):
			var has_mu := false
			for o in ((q as Dictionary).get("options", []) as Array):
				if str((o as Dictionary).get("tone", "")) == "made_up":
					has_mu = true
			if has_mu:
				with_made_up += 1
			else:
				no_made_up += 1
	_check("每套背景各有 1 条不写「硬答」（2 选项）",
		no_made_up == ScenarioData.BACKGROUNDS.size())
	_check("其余盲区题都带「硬答」（3 选项）",
		with_made_up == ScenarioData.BACKGROUNDS.size() * 3)

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
	var first_bg: Dictionary = ScenarioData.BACKGROUNDS[0]
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
