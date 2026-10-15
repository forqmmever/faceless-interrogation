extends Node

# ============================================================
#  一局（run）的状态与随机化
#
#  多轮制的核心：
#    · 每一局随机抽一套背景（ScenarioData.BACKGROUNDS）
#    · 每一局随机生成 A 的原貌（OutfitData.TRUE_POOL）
#    · 一局最多 4 关；盘问通过 → 进入下一关（背景与原貌不变、接受度提升）
#    · 任何一关失败 → **回到本轮开始**（第二十一轮）：
#      背景 / A 的原貌 / 情报 / 接受度全部不变，只把本轮里发生的事回滚。
#      见 retry_level() 与 GameData.snapshot_level_state()。
#
#  为什么原貌要随机：
#    固定原貌时，玩家背下「该改哪几处」就能通关，换装退化成背答案。
#    原貌一随机，每局都得重新读外貌情报、重新推导「他记忆里我长什么样」，
#    三值机制（暴露值 / 接受度 / 反差值）才真正每局都在起作用。
#
#  确定性：
#    start_new_run(seed) 传入固定种子时，背景与原貌完全可复现 —— 测试依赖这点。
# ============================================================

signal run_started
signal level_advanced
signal level_retried

# ---------- 当前局 ----------
var run_index: int = 0                 # 第几局（从 1 开始）
var seed_value: int = 0                # 本局随机种子
var background_id: String = ""
var true_app: Dictionary = {}          # slot -> item id（本局的 A）
var clues: Array = []                  # 本局的 18 条外貌情报（由原貌拼出来）

var level_index: int = 0               # 当前关卡（0 起）
var cleared_levels: int = 0            # 本局已通过的关卡数
var photos: Array = []                 # 本局手机相册里的照片
var interrogator_trait_id: String = "" # 本局审讯官的性情（审问者的情报）
var forced_items: Array = []           # 本关强制装备的 item id（0 ~ 2 件）

# 当前接受度 —— 派生值，不是自己攒的。
#   = 起始值 + 账号里跨局累积的加成（ProfileData.total_gain）
# 每通过一关就把那一关的 gain 存进 ProfileData，所以这里立刻反映出来；
# 就算这一轮失败、回到本轮开始重来，已经到手的部分也不会丢。
var acceptance: int:
	get:
		return OutfitData.START_ACCEPTANCE + ProfileData.bonus()

var _rng := RandomNumberGenerator.new()
var _bg: Dictionary = {}

func _ready() -> void:
	# 保证在 Main 调用 start_new_run 之前，任何查询都有合法数据可用
	if background_id == "":
		start_new_run(20261011)

# ============================================================
#  开一局
#
#  start_level：从第几关开始（0 起）。选关面板点「第 N 关」时传进来。
#  目前只开放第一关（OutfitData.OPEN_LEVELS），所以正常开局都是 0；
#  但从这一关开始意味着**前面几关的接受度加成不补** ——
#  开局接受度仍然只有「起始值 + 跨局累积」，这也是后三关暂时锁着的原因之一。
# ============================================================
func start_new_run(seed_in: int = -1, start_level: int = 0) -> void:
	run_index += 1

	if seed_in >= 0:
		seed_value = seed_in
	else:
		# 用系统毫秒 + 局数打散，避免同一毫秒内连开两局拿到同一个种子
		var t: int = int(Time.get_unix_time_from_system() * 1000.0)
		seed_value = (t ^ (run_index * 7919)) & 0x7FFFFFFF

	_rng.seed = seed_value

	var ids: Array = ScenarioData.background_ids()
	background_id = str(ids[_rng.randi() % ids.size()])
	_bg = ScenarioData.get_background(background_id)

	_roll_true_appearance()
	_build_clues()
	_roll_photos()
	# 性情最后抽 —— 放在这里才不会打乱上面「原貌 / 情报 / 相册」的随机序列，
	# 固定种子下的截图与测试因此保持完全可复现。
	_roll_interrogator_trait()

	level_index = clampi(start_level, 0, level_count() - 1)
	cleared_levels = level_index
	_roll_forced_items(level_index)

	GameData.reset_run_state()
	GameData.run_index = run_index
	GameData.run_seed = seed_value
	GameData.background_name = str(_bg.get("name", ""))
	GameData.acceptance = acceptance
	GameData.interrogator_trait = interrogator_trait_id
	GameData.interrogator_name = interrogator()
	GameData.companion_name = companion_name()

	run_started.emit()

# ============================================================
#  续玩：从存档把「进行中的那一局」接回来
#
#  同一个种子 → 背景 / A 的原貌 / 外貌情报 / 相册 / 审讯官性情
#  全部原样复现（这几样都是确定性生成的，见上面 _level_rng 那套）。
#  再把关卡拨回存档记下的那一关，并重抽一次那一关的强制装备 ——
#  _roll_forced_items 也是确定性的，所以抽出来的还是当初那几件。
# ============================================================
func resume_run(seed_in: int, run_index_in: int, li: int, cleared: int) -> void:
	start_new_run(seed_in)
	run_index = maxi(1, run_index_in)
	level_index = clampi(li, 0, level_count() - 1)
	cleared_levels = maxi(0, cleared)
	_roll_forced_items(level_index)

	GameData.run_index = run_index
	GameData.level_index = level_index
	GameData.cleared_levels = cleared_levels
	GameData.acceptance = acceptance
	GameData.run_seed = seed_value
	GameData.background_name = str(_bg.get("name", ""))

# ============================================================
#  强制装备：每关的「必须穿什么」
#
#  ★ 第二十三轮改成读**每关的规则表**（OutfitData.forced_rules_at）：
#      "none"   —— 本关没有强制要求（第 1 关就是它）；
#      "random" —— 沿用旧的随机抽 0~2 件高暴露（出厂默认的后三关）；
#      "fixed"  —— 用编辑器里写死的规则，每条二选一：
#                    {"pick": "all", "items":[...]}  这几件都要穿（一件 = 固定一件）
#                    {"pick": "any", "items":[...]}  这几件里任选一件
#                  多条规则自由叠加。这是「用户可编辑」的那条路。
#
#  random 模式用独立的随机流（_forced_rng），免得抽装备把出题的随机序列打乱 ——
#  固定种子下的截图与测试因此保持完全可复现。
#
#  抽不到的情况（很常见，而且是设计的一部分）：
#    · 第一关（li == 0）**刻意不抽** —— 见下；
#    · 随机数是 0；
#    · 当前接受度穿不起任何高暴露衣物 → 池子空。
#  接受度越高，池子越大，被塞行头的概率越高 ——
#  这就是「跨局累积的接受度」在玩法上的第二个作用。
# ============================================================
var forced_groups: Array = []          # fixed 模式下的规则表（结构见 OutfitData.forced_groups_at）

func _roll_forced_items(li: int) -> void:
	forced_items = []
	forced_groups = []
	var entry := OutfitData.forced_rules_at(li)
	var mode := str(entry.get("mode", OutfitData.FORCED_MODE_RANDOM))

	if mode == OutfitData.FORCED_MODE_NONE:
		return
	# ★ 每局的第一关没有强制服装要求。
	#   开局就被人按着头穿某件衣服，玩家还没搞明白「反差 / 暴露 / 缺陷」
	#   这三件事是怎么回事，就先被罚了一次 —— 那不公平。
	#   先让他在第一关自由地改一遍，从第二关起才开始塞行头。
	if li <= 0:
		return

	if mode == OutfitData.FORCED_MODE_FIXED:
		_apply_fixed_forced(entry.get("rules", []))
		return

	var pool: Array = OutfitData.forced_pool(acceptance)
	if pool.is_empty():
		return
	var r := _forced_rng(li)
	var n: int = r.randi() % (OutfitData.FORCED_MAX + 1)   # 0 / 1 / 2
	if n <= 0:
		return

	# 洗牌后按槽位去重 —— 同一个槽位不可能被强制两件
	for i in range(pool.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t

	var used_slots := []
	for it in pool:
		if forced_items.size() >= n:
			break
		var slot := str(it.get("slot", ""))
		if used_slots.has(slot):
			continue
		# ★ 第三十七轮：互斥组里各挑一件 = 穿不到一起 = 本关死局。
		#   典型是「强制穿成装」+「强制穿下装」——成装一上身，下装就被清空，
		#   两条强制要求永远无法同时满足。这里按 EXCLUSIVE_GROUPS 互斥地筛一遍。
		var clash := false
		for peer in OutfitData.exclusive_peers(slot):
			if used_slots.has(str(peer)):
				clash = true
				break
		if clash:
			continue
		used_slots.append(slot)
		forced_items.append(str(it.get("id", "")))

# 把「写死的规则」落成强制装备。
#   all 组：每一件都进 forced_items，槽位锁死；
#   any 组：**默认替你穿上第一件穿得起的**，但槽位不锁死 ——
#           另外几件照样可选（选了就算满足要求，见 WardrobeModel.missing_forced）。
#           一件都穿不起时跳过这一组（不能因为编辑器写了件贵的就把玩家卡死）。
func _apply_fixed_forced(rules: Array) -> void:
	for r in rules:
		var rd: Dictionary = r
		var items: Array = rd.get("items", [])
		if items.is_empty():
			continue
		var pick := str(rd.get("pick", OutfitData.PICK_ALL))
		if pick == OutfitData.PICK_ANY:
			var group_items := []
			var chosen := ""
			for id in items:
				var it := OutfitData.get_item(str(id))
				if it.is_empty():
					continue
				group_items.append(str(id))
				if chosen == "" and OutfitData.can_equip(it, acceptance):
					chosen = str(id)
			if group_items.is_empty():
				continue
			forced_groups.append({"pick": OutfitData.PICK_ANY, "items": group_items})
			if chosen != "":
				forced_items.append(chosen)
			continue
		# all：全都得穿
		for id in items:
			var it2 := OutfitData.get_item(str(id))
			if it2.is_empty():
				continue
			forced_groups.append({"pick": OutfitData.PICK_ALL, "items": [str(id)]})
			if OutfitData.can_equip(it2, acceptance):
				forced_items.append(str(id))

func forced_item_ids() -> Array:
	return forced_items

func forced_groups_info() -> Array:
	return forced_groups

# 本关强制装备的完整说明（界面 / 覆盖层文案用）——
# 一条规则一句话，让人一眼看出「这条是必须穿哪件、那条是几件里挑一件」。
func forced_rule_lines() -> Array:
	var out := []
	for g in forced_groups:
		var gd: Dictionary = g
		var names := []
		for id in gd.get("items", []):
			names.append(str(OutfitData.get_item(str(id)).get("name", id)))
		if str(gd.get("pick", "")) == OutfitData.PICK_ANY:
			out.append("这几件里任选一件：" + "、".join(names))
		else:
			out.append("必须穿：" + "、".join(names))
	return out

func forced_items_info() -> Array:
	var out := []
	for id in forced_items:
		var it := OutfitData.get_item(str(id))
		if not it.is_empty():
			out.append(it)
	return out

func has_forced_items() -> bool:
	return not forced_items.is_empty()

# 每局随机给审讯官抽一种性情 —— 这就是「审问者的情报」里唯一能提前拿到的东西
func _roll_interrogator_trait() -> void:
	var ids: Array = ScenarioData.interrogator_trait_ids()
	if ids.is_empty():
		interrogator_trait_id = ""
		return
	interrogator_trait_id = str(ids[_rng.randi() % ids.size()])

# 每局随机生成 A 的原貌：每个槽位从候选池里抽一件
# （只抽玩家能看到的槽位 —— 下架的槽位不参与，否则会凭空多出一处对不上的原貌）
# ★ 第三十九轮：换成 `auto_slots()` —— 把「妙妙工具」也排掉。它是玩家手动揣的道具，
#   不是 A 的原貌；抽进去会让情报台问一句「他带着尼古喵尾吗」，那是说不通的。
func _roll_true_appearance() -> void:
	true_app = {}
	for slot in OutfitData.auto_slots():
		var pool: Array = OutfitData.TRUE_POOL.get(slot, [])
		if pool.is_empty():
			continue
		true_app[slot] = str(pool[_rng.randi() % pool.size()])
	# ★ 第二十七轮：互斥归一化 —— 成装与上装 / 下装三者只能有一个非空件。
	#   原貌是**逐槽位独立抽**的，不归一化就会出现「原貌既有吊带成装、又有高领长袖衬衫」，
	#   而这两件在装备层根本穿不到一起（见 OutfitData.EXCLUSIVE_GROUPS）。
	#   那会让两边说法打架：情报台 / 相册按 `true_app` 说「他记得你穿着高领长袖」，
	#   渲染 / 反差判定却按 `equipped`（成装赢了、上装被清空）—— 玩家会看到自相矛盾的一局。
	#   规则与 `WardrobeModel._normalize_exclusive()` 完全一致：按声明顺序取第一个非空件。
	#   注意这里**不消耗随机数**，所以抽签流不受影响。
	for g in OutfitData.EXCLUSIVE_GROUPS:
		var group := g as Array
		var occupied := ""
		for s in group:
			var slot := str(s)
			var it: Dictionary = OutfitData.get_item(str(true_app.get(slot, "")))
			if it.is_empty() or OutfitData.is_bare(it):
				continue
			if occupied == "":
				occupied = slot
			else:
				true_app[slot] = OutfitData.bare_id_of(slot)

# 按本局原貌现场拼出外貌情报（文案与来源都随局变化）
# ★ 第三十九轮：同样走 `auto_slots()` —— 妙妙工具不进情报（它是你自己的道具）。
func _build_clues() -> void:
	clues = []
	for slot in OutfitData.auto_slots():
		var item_id := true_item(slot)
		if item_id == "":
			continue
		var srcs: Array = ScenarioData.sources_of(slot)
		var src := str(srcs[_rng.randi() % srcs.size()])
		clues.append({
			"id": "clue_" + slot,
			"slot": slot,
			"source": src,
			"text": ScenarioData.clue_text(slot, item_id),
		})

# 本局手机相册：随机挑几个槽位，配上「拍糊了的照片」
# 每张照片有自己的起始清晰度与可擦次数 —— 有的擦两下就看清，有的一辈子看不清
func _roll_photos() -> void:
	photos = []
	# 下架的槽位不进相册 —— 否则会抽到一张「拍的是外袍」但画面上什么都没有的照片
	var pool: Array = []
	for s in ScenarioData.PHOTO_SLOTS:
		# ★ 第三十九轮：妙妙工具也不进相册（它是你的道具，不是「偷拍到的 A」）
		if OutfitData.slot_enabled(str(s)) and not OutfitData.is_manual_slot(str(s)):
			pool.append(s)
	# 洗牌
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t

	var n: int = mini(ScenarioData.PHOTO_COUNT, pool.size())
	for i in n:
		var slot := str(pool[i])
		var start := 0.10 + _rng.randf() * 0.45          # 0.10 ~ 0.55
		var wipes := 1 + _rng.randi() % 3                # 1 ~ 3 次
		var notes: Array = ScenarioData.PHOTO_NOTES
		photos.append({
			"index": i,
			"slot": slot,
			"note": str(notes[_rng.randi() % notes.size()]),
			"start_clarity": start,
			"max_wipes": wipes,
			# 擦满之后能到什么清晰度 —— 低于阈值就是一张废片
			"final_clarity": minf(1.0, start + float(wipes) * ScenarioData.PHOTO_WIPE_STEP),
			# 只存槽位名 —— 「偷拍 · 」那个前缀属于界面文案，由手机从
			# ScenarioData.PHONE["album"]["shot"] 里取，这样才改得动。
			"shot_slot": str(OutfitData.SLOT_NAMES.get(slot, slot)),
			# ★ 第三十一轮：这张照片属于上半身还是下半身（界面会把两段拼起来）
			"half": str(ScenarioData.PHOTO_HALF.get(slot, "")),
		})

# ============================================================
#  查询
# ============================================================
func background() -> Dictionary:
	if _bg.is_empty():
		_bg = ScenarioData.get_background(background_id)
	return _bg

func background_name() -> String:
	return str(background().get("name", ""))

func venue() -> String:
	return str(background().get("venue", ""))

func interrogator() -> String:
	return ScenarioData.interrogator_of(background())

# ---------------- 同行人 ----------------
# 他知道你是 A，也知道你在装 B。他不帮你、不当面揭穿 ——
# 他只在旁边把审讯官的目光往对的地方引（提问 = 正式题目，递话 = 可 QTE 打断）。
#
# 他的身份来自背景，和审讯官一样是**每局抽一次、跨关不重抽**。
func companion() -> Dictionary:
	return ScenarioData.companion_of(background())

func companion_name() -> String:
	return ScenarioData.companion_name_of(background())

func companion_relation() -> String:
	return ScenarioData.companion_relation_of(background())

func companion_desc() -> String:
	return ScenarioData.companion_desc_of(background())

func companion_gender() -> String:
	return ScenarioData.companion_gender_of(background())

# 审讯官（= A 的旧识，被欺骗的那个人）—— 男
func interrogator_gender() -> String:
	return ScenarioData.interrogator_gender_of(background())

# ---------------- 本局固定卡司 ----------------
# 「审讯官 / 同行人 / A / B 在一局之内不会变」这件事的唯一出处。
# 背景是每局抽一次、advance_level() 不碰它，所以这几个人跨关、跨题都是同一批。
#
# 命名口径（用户定的）：
#   A = 真身 —— 你本来的身份，审讯官认识的就是这个「A」
#   B = 马甲 —— 你现在装的这个人
#   C = 同行人 —— 知道你是 A、也知道你在装 B，但不站你这边
func cast() -> Dictionary:
	return {
		"background": background_name(),
		"venue": venue(),
		"interrogator": interrogator(),                 # A 的旧识（被欺骗的那个人）
		"interrogator_gender": interrogator_gender(),
		"trait": interrogator_trait_name(),
		"companion": companion_name(),                  # C
		"companion_relation": companion_relation(),
		"companion_gender": companion_gender(),
		"companion_desc": companion_desc(),
		"true_role": true_role(),      # A —— 你其实是
		"true_name": true_name(),      # A 的真身名字（只在被他认出来那一刻才被念出）
		"cover_role": cover_role(),    # B —— 你装成
		"player_gender": ScenarioData.PLAYER_GENDER,
	}

# 本局审讯官的性情（审问者的情报）—— 盘问时用来判断「撒谎 / 回避」的代价
func interrogator_trait() -> Dictionary:
	return ScenarioData.get_interrogator_trait(interrogator_trait_id)

func interrogator_trait_name() -> String:
	return str(interrogator_trait().get("name", ""))

func cover_role() -> String:
	return str(background().get("cover_role", ""))

func true_role() -> String:
	return str(background().get("true_role", ""))

# A 的真身名字 —— 平时不出现在任何地方。
# 唯一一次被念出来，是门开那一刻审讯官认出你的时候：「怎么是你，<这个名字>。」
func true_name() -> String:
	return ScenarioData.true_name_of(background())

# 本局 A 在某个槽位的样子
func true_item(slot: String) -> String:
	return str(true_app.get(slot, ""))

# 本局的完整原貌（slot -> item id）
func true_appearance() -> Dictionary:
	return true_app

# 本局的关卡表（数值曲线来自 OutfitData.LEVELS —— 现在可从 story.json 编辑；
# 名字与推导形象来自背景，背景写了就覆盖）
func levels() -> Array:
	var names: Array = background().get("levels", [])
	var out := []
	for i in OutfitData.level_count():
		var base: Dictionary = OutfitData.level_at(i)
		var entry := base.duplicate()
		if i < names.size():
			var n: Dictionary = names[i]
			entry["name"] = str(n.get("name", base["name"]))
			entry["derived_profile"] = str(n.get("derived_profile", base["derived_profile"]))
		out.append(entry)
	return out

func level_count() -> int:
	return OutfitData.level_count()

func level_number() -> int:
	return level_index + 1

func current_level() -> Dictionary:
	var lv := levels()
	return lv[mini(level_index, lv.size() - 1)]

func level_name() -> String:
	return str(current_level().get("name", ""))

# 「如果本局打到第 li 关，开局接受度会是多少」
#   = 起始值 + 跨局累积（ProfileData）+ 本局还没结算的那些关的 gain
#
# 不变式：acceptance_at(cleared_levels) == acceptance（当前值）。
# 因为已通过的关，gain 早就存进 ProfileData 了，这里不重复算。
func acceptance_at(li: int) -> int:
	var acc := acceptance
	var lv := levels()
	for i in range(cleared_levels, mini(li, lv.size())):
		acc += int(lv[i].get("acceptance_gain", 0))
	return acc

func exposure_cap_at(li: int) -> int:
	return OutfitData.exposure_cap(acceptance_at(li))

# ============================================================
#  关卡推进 / 结束
# ============================================================
func is_run_complete() -> bool:
	return level_index >= level_count()

# 本关通过 → 结算并推进到下一关（背景与原貌保持不变）
func advance_level() -> void:
	if is_run_complete():
		return
	var gain := int(current_level().get("acceptance_gain", 0))
	# ★ 全局保留：这一关赚到的接受度**立刻**进账号。
	#   这一轮就算失败、回到本轮开始重来，这部分也不会丢。
	ProfileData.add_gain(gain)
	cleared_levels += 1
	level_index += 1
	_roll_forced_items(level_index)      # 新的一关，重新抽强制装备
	GameData.level_index = level_index
	GameData.cleared_levels = cleared_levels
	GameData.acceptance = acceptance
	level_advanced.emit()

# 本局失败 → 回到**本轮开始**（第二十一轮）
#
#  ★ 旧规则是 fail_run()：任何一关失败 → 整局作废，重抽背景与原貌。
#    新规则只作废**这一轮** —— 他记忆里的那张脸没变，你已经查到的情报也还在，
#    要改的只是这一轮的打扮。所以这里**不重抽任何东西**，只把「本轮里发生的事」
#    回滚到进这一关那一刻（见 GameData.restore_level_snapshot）。
func retry_level() -> void:
	GameData.restore_level_snapshot()
	# 同一关、同一个种子 → 抽出来还是当初那几件；这一步只是把不变式写实
	_roll_forced_items(level_index)
	GameData.level_index = level_index
	GameData.cleared_levels = cleared_levels
	GameData.acceptance = acceptance
	level_retried.emit()

# ============================================================
#  按关出题
#
#  一关 8 道题，编排固定为：
#      0 档案题 · 1 新事实 · 2 同行者提问 · 3 档案题
#      4 新事实复问 · 5 档案题 · 6 旧事实复问 · 7 档案题
#
#  · 档案题 —— 考你知不知道「这是不是 B 该知道的事」。
#              A 卡（只有 A 才知道的事）照实答 = 当场说漏嘴；
#              B 卡照答才对得上档案。
#              题面本身就是线索，得当场判断。
#  · 新事实 —— 本关第一次问这个事实。你随口立下一种说法，它就成了你的「口径」。
#  · 同行者提问 —— **不是干扰，是正式的题目**，和审讯官的题走同一套判定。
#                  他刚听见你立下的说法，立刻抛出一个错误的版本试探你。
#                  顺着他说 = 跟自己的口径对不上 = 前后矛盾。
#  · 新事实复问 —— 同一关里，隔了两道题再问一遍同一个事实。
#                  刚说过的话都记不住，就没人信你是那个行商了。
#  · 旧事实复问 —— 复问**之前某一关**已经立过的那个说法。
#                  中间隔着整整一关、夹着档案题和同行者搅局 ——
#                  你要是记不住自己上次怎么说的，这里就会当场前后矛盾。
#                  第 1 关没有「上一关」，复问自己就成了同一道题，
#                  于是那一关多抽一道档案题补位（仍然是 8 道）。
#
#  事实表有 4 条、一局 4 关，正好：
#      第 1 关 → 新 f0 ｜ 同行者问 f0 ｜ 复问 f0 ｜ 档案题 ×5
#      第 2 关 → 新 f1 ｜ 同行者问 f1 ｜ 复问 f1 ｜ 复问 f0 ｜ 档案题 ×4
#      第 3 关 → 新 f2 ｜ 同行者问 f2 ｜ 复问 f2 ｜ 复问 f1 ｜ 档案题 ×4
#      第 4 关 → 新 f3 ｜ 同行者问 f3 ｜ 复问 f3 ｜ 复问 f2 ｜ 档案题 ×4
#  越往后，你身上背着的「口径」越多，说错一句的代价越大。
# ============================================================
func _level_rng(li: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value ^ ((li + 1) * 104729)
	return r

# 强制装备用独立随机流（见 _roll_forced_items）
func _forced_rng(li: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value ^ ((li + 1) * 40503) ^ 0x5F3759DF
	return r

# 复问挑哪条旧说法，也用独立随机流
func _recall_rng(li: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value ^ ((li + 1) * 22695477) ^ 0x2545F491
	return r

func facts() -> Array:
	return ScenarioData.facts_of(background())

func fact_for_level(li: int) -> Dictionary:
	var fs: Array = facts()
	if fs.is_empty():
		return {}
	return fs[li % fs.size()]

# 本关要复问的那个「旧说法」。
# 从**之前已经立过说法的那些事实**里确定性抽一个 ——
# 不是固定复问上一关，所以第 1 关立下的口径到第 4 关照样可能被翻出来。
# 越往后身上背的口径越多，说错一句的代价越大。
func recalled_fact_for_level(li: int) -> Dictionary:
	var fs: Array = facts()
	if fs.is_empty():
		return {}
	if li <= 0:
		return fs[0]
	var r := _recall_rng(li)
	return fs[r.randi() % mini(li, fs.size())]

# 本局当前关能看到的短信 —— 短信是**逐关解锁**的：
# 第 i 关解锁 level == i 的那一条，它正好揭示本关新要问的那个说法。
# 所以「本关该怎么说」，你得在准备室先把它读出来。
func sms_threads() -> Array:
	return ScenarioData.sms_for_level(background(), level_index)

# 本局一共几条短信（含还没解锁的）
func sms_total() -> int:
	return ScenarioData.sms_of(background()).size()

# 与 C 的短信 —— 同样逐关解锁，但它**不揭示任何口径**：
# C 知道你是 A，他发消息不是为了帮你，是让你记着他一直都在旁边。
func companion_sms_threads() -> Array:
	return ScenarioData.companion_sms_for_level(background(), level_index)

func companion_sms_total() -> int:
	return ScenarioData.companion_sms_of(background()).size()

func companion_questions() -> Array:
	return ScenarioData.companion_questions_of(background())

func companion_question_at(n: int) -> Dictionary:
	var arr: Array = companion_questions()
	if arr.is_empty():
		return {}
	return arr[n % arr.size()]

func photo_at(i: int) -> Dictionary:
	if i < 0 or i >= photos.size():
		return {}
	return photos[i]

# ============================================================
#  题目清单（★ 第二十九轮：从「编排代码」改成「数据驱动」）
#
#  改造前：题目不是清单，而是下面那段 42 行按固定位置拼出来的
#  （第 3 道固定同行者、第 6 道固定盲区、第 7 道固定跨关复问），
#  而且四类题目各有一套互不相同的结构，玩家改不动任何一道题。
#
#  改造后每套背景只留一份 `questions[]`，每题是一个自带全部属性的对象
#  （题面 / 选项 / 每个选项的语义与怀疑值 / QTE 类型与延迟 / 是否抖动 /
#    触发什么结局）。判定逻辑不再看「这道题属于哪一类」，只看**选项自己的
#  `tone`** —— 这就是用户口径里说的「不再给问题分类」。
#
#  出题规则（顺序 = 清单顺序，所以「排序」也是一种编辑手段）：
#    · `level == li`         → 本关固定题，按清单顺序出；
#    · `level == -1`（通用池）→ 用来把本关补足到 questions_per_level 道；
#    · 标了 `recall: true` 的通用题 → 优先按本关抽到的「旧说法」挑一道，
#      这样「跨关复问」仍然会发生，但复问谁、问什么改由数据决定。
#
#  ★ 每关到底出几道题 = 该关固定题数 + 从通用池补足到 questions_per_level。
#    所以想精确控制某关几道题，直接把题分配到那一关（改 level）即可。
#  ★ 旧格式（内置常量 ScenarioData.DEFAULT_BACKGROUNDS）仍然支持 ——
#    story.json 缺失时走下面那条老路径，出厂兜底照常工作。
# ============================================================
const QUESTIONS_SCHEMA_V1 := "faceless-questions-v1"
const QUESTION_LEVEL_ANY := -1

# 读出本套背景的题目清单（新格式）。
# 返回空数组 = 这套背景还是旧格式，调用方要走老路径。
func question_list() -> Array:
	var bg := background()
	if str(bg.get("questions_schema", "")) != QUESTIONS_SCHEMA_V1:
		return []
	return bg.get("questions", [])

func _questions_for_level_v1(bg: Dictionary, li: int, count: int) -> Array:
	var all: Array = bg.get("questions", [])
	if all.is_empty():
		return []
	var r := _level_rng(li)
	var fixed := []
	var pool := []
	var recalls := []
	for q in all:
		var d: Dictionary = q
		if str(d.get("id", "")) == "":
			continue
		var lv := int(d.get("level", QUESTION_LEVEL_ANY))
		if lv == li:
			fixed.append(d)
		elif lv == QUESTION_LEVEL_ANY:
			if bool(d.get("recall", false)):
				recalls.append(d)
			else:
				pool.append(d)

	var out := []
	for q in fixed:
		out.append((q as Dictionary).duplicate(true))

	# 跨关复问：第 1 关没有「上一关」，不排；其余关按本关抽到的旧说法挑对应的那道。
	if li > 0:
		var old_fid := str(recalled_fact_for_level(li).get("id", ""))
		var new_fid := str(fact_for_level(li).get("id", ""))
		if old_fid != "" and old_fid != new_fid:
			for q in recalls:
				if str((q as Dictionary).get("fact", "")) == old_fid:
					out.append((q as Dictionary).duplicate(true))
					break

	# 通用池补足到 count（洗牌后依次取，保证每关的抽样不同）
	if out.size() < count and not pool.is_empty():
		var idx := []
		for i in pool.size():
			idx.append(i)
		for i in range(idx.size() - 1, 0, -1):
			var j := r.randi() % (i + 1)
			var t = idx[i]
			idx[i] = idx[j]
			idx[j] = t
		for k in idx:
			if out.size() >= count:
				break
			out.append((pool[k] as Dictionary).duplicate(true))

	# 返回全部：固定题与复问如果已经凑够（或超过）count，就以**数据为准** ——
	# 用户显式把 8 道题都分配给了这一关，就不该再被全局的 count 砍掉。
	# 不够时才由通用池补足。所以「每关几道题」= 固定题数，不足则补到 count。
	return out

# 本关出题数：全局 rules 打底，每关可以用 levels[li].questions_per_level 覆盖。
func questions_per_level_of(li: int) -> int:
	var lv: Dictionary = level_at_index(li)
	var v := int(lv.get("questions_per_level", -1))
	if v > 0:
		return v
	return int(ScenarioData.rule_i("questions_per_level", 8))

func level_at_index(li: int) -> Dictionary:
	var ls: Array = levels()
	if li < 0 or li >= ls.size():
		return {}
	return ls[li]

func questions_for_level(li: int, count: int) -> Array:
	var bg := background()
	# ★ 新格式优先：只要这套背景带 schema 标记，就走数据驱动那条路。
	if not question_list().is_empty():
		return _questions_for_level_v1(bg, li, count)

	# ================= 以下为旧路径（内置常量兜底）=================
	var pool: Array = bg.get("questions", [])
	var r := _level_rng(li)

	var new_fact := fact_for_level(li)
	var old_fact := recalled_fact_for_level(li)
	# 第 1 关没有「上一关」，recalled 会落到自己身上 —— 那时不排「旧事实复问」
	var same: bool = old_fact.is_empty() \
		or str(old_fact.get("id", "")) == str(new_fact.get("id", ""))

	# 档案题要抽几道：正常情况下 4 道；第 1 关少一道复问，就多抽一道补位
	var n_cards: int = 5 if same else 4
	var cards := _pick_cards(pool, r, n_cards)

	# ★ 第十三轮编排调整：**一轮之内不再复问同一个事实**。
	#   原来第 4 道是「同关复问」（同一关里把第 1 道那个事实再问一遍）——
	#   那会让玩家在一轮之内就吃到「前后矛盾」，和「矛盾只跨轮发生」的规则冲突。
	#   现在第 4 道改回档案题，同一关里那个事实只问一次。
	#   第 6 道仍然是**跨关复问**（翻出前面几关立过的说法）——
	#   那才是唯一会构成「前后矛盾」的地方。
	var out: Array = []
	var ci := 0

	out = _push_q(out, _as_card_question(cards, ci))
	ci += 1
	out = _push_q(out, _make_fact_question(new_fact, 0, r, false))
	out = _push_q(out, _make_companion_question(str(new_fact.get("id", "")), r))
	out = _push_q(out, _as_card_question(cards, ci))
	ci += 1
	out = _push_q(out, _as_card_question(cards, ci))
	ci += 1
	# 第 6 道固定是盲区题 —— 档案题中间插一道「你手里完全没给信息的」，
	# 把节奏从「翻档案」打断一下，逼你回头看手机备忘录第一条。
	out = _push_q(out, _make_blind_question(li))
	# 第 7 道：跨关复问（第 1 关没有上一关，那道位置让给档案题）
	if not same:
		out = _push_q(out, _make_fact_question(old_fact, 1, r, true))
	out = _push_q(out, _as_card_question(cards, ci))
	ci += 1
	# 补足到 count（第 1 关多抽的那一道档案题在这里落地）
	while out.size() < count and ci < cards.size():
		out = _push_q(out, _as_card_question(cards, ci))
		ci += 1

	return out.slice(0, count)

# 档案题：从抽出来的题目里取第 idx 道，标上 kind=card
func _as_card_question(picked: Array, idx: int) -> Dictionary:
	if idx < 0 or idx >= picked.size():
		return {}
	var q: Dictionary = (picked[idx] as Dictionary).duplicate()
	q["kind"] = "card"
	return q

# ------------------------------------------------------------
#  盲区题 —— 「完全没给信息的题」
#
#  他问一件**档案里没有、短信里也没提**的事。题面不指向任何一张卡，
#  所以手里真的一点底都没有 —— 没有「内容上的正确答案」。
#
#  唯一的安全解是「按他的脾性选」（撒谎还是回避），
#  而这件事只能从手机备忘录第一条推出来。判定在 Interrogation 那边。
#
#  第 li 关固定用第 li 条：一局里不重复，也方便测试与复现。
# ------------------------------------------------------------
func _make_blind_question(li: int) -> Dictionary:
	var q := ScenarioData.blind_question_for_level(background(), li)
	if q.is_empty():
		return {}
	if str(q.get("q", "")) == "":
		return {}
	return {
		"kind": "blind",
		"id": str(q.get("id", "")),
		"q": str(q.get("q", "")),
		"setup": str(q.get("setup", "")),
		"made_up": str(q.get("made_up", "")),
		"bluff": str(q.get("bluff", "")),
		"evade": str(q.get("evade", "")),
	}

# 只把非空的题推进结果里 —— 内容缺字段时宁可少一道，也别塞一道空题
func _push_q(out: Array, q: Dictionary) -> Array:
	if not q.is_empty():
		out.append(q)
	return out

# 同行者提问：他自己的问法 + 三个回应，其中一个是错的版本。
# 结构和说法题一致（kind/options/value），所以盘问环节能用同一套口径判定处理它。
func _make_companion_question(fact_id: String, r: RandomNumberGenerator) -> Dictionary:
	var q := ScenarioData.companion_question_for(background(), fact_id)
	if q.is_empty():
		return {}
	var raw: Array = q.get("options", [])
	if raw.is_empty():
		return {}
	var opts := []
	for o in raw:
		opts.append({
			"text": str(o.get("text", "")),
			"delta": float(o.get("delta", 0.0)),
			"value": str(o.get("value", "")),
		})
	for i in range(opts.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t = opts[i]
		opts[i] = opts[j]
		opts[j] = t
	return {
		"kind": "companion",
		"fact": fact_id,
		"q": str(q.get("line", "")),
		"plant": str(q.get("plant", "")),
		"options": opts,
	}

func _pick_cards(pool: Array, r: RandomNumberGenerator, n: int) -> Array:
	var idx := []
	for i in pool.size():
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	var out := []
	for k in mini(n, idx.size()):
		out.append(pool[idx[k]])
	return out

# 事实题：问法二选一，选项 = 该事实的三个版本（打乱顺序）
# recall=true 时标记为「复问」—— 盘问环节会拿它跟玩家之前说过的说法比对
func _make_fact_question(fact: Dictionary, prompt_idx: int, r: RandomNumberGenerator,
		recall: bool = false) -> Dictionary:
	var prompts: Array = fact.get("prompts", [])
	var values: Array = fact.get("values", [])
	if prompts.is_empty() or values.is_empty():
		return {}
	var opts := []
	for v in values:
		opts.append({"id": str(v.get("id", "")), "label": str(v.get("label", ""))})
	for i in range(opts.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t = opts[i]
		opts[i] = opts[j]
		opts[j] = t
	return {
		"kind": "fact",
		"fact": str(fact.get("id", "")),
		"recall": recall,
		"q": str(prompts[prompt_idx % prompts.size()]),
		"options": opts,
	}

# ============================================================
#  一局摘要（给结果界面 / 调试用）
# ============================================================
func run_summary() -> String:
	return "第 %d 局 ｜ %s ｜ 已通过 %d/%d 关" % [
		run_index, background_name(), cleared_levels, level_count()]
