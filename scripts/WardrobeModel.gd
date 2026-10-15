class_name WardrobeModel
extends RefCounted

# ============================================================
#  换装系统运行时模型
#  负责：装备校验 / 暴露值上限 / 反差值判定 / 缺陷遮挡
#
#  多轮制之后有两处东西不再来自常量，而是「本局」的：
#    · true_appearance —— 本局随机出的 A 的原貌（RunData.true_appearance）
#    · levels          —— 本局 4 关的数值与名字（RunData.levels）
#  不传时退回 OutfitData 里的默认值，方便单元测试单独构造。
# ============================================================

signal changed

var data: Node                       # OutfitData 实例
# ★ 第三十六轮起，`equipped` 的值有两种形态：
#   · 单件槽位 → String（槽位 → 物品 id），和以前完全一样；
#   · 多件槽位（MULTI_SLOTS，目前只有 tattoo）→ Array[String]。
# 所以**不要**再直接 `str(equipped.get(slot, ""))` —— 多件槽位上那会得到
# `["a", "b"]` 这种字符串。一律走下面的 ids_at / id_at / set_ids / has_id。
var equipped: Dictionary = {}        # slot -> item id（多件槽位为 Array）
var acceptance: int = 0              # 接受度（每轮后提升）
var level_index: int = 0             # 当前轮次
var cleared_levels: int = 0
var true_appearance: Dictionary = {} # 本局 A 的原貌
var levels: Array = []               # 本局轮次表
var forced_items: Array = []         # 本轮强制装备的 item id（0 ~ 2 件，由 RunData 抽）
var forced_groups: Array = []        # 本轮的强制规则表（「几件选一件」/「固定一件」的自由组合）
# ★ 第二十七轮：被互斥「顶掉」的槽位顶掉之前穿的是什么 —— 玩家把成装脱下来时原样还回去。
#   （见 _apply_exclusive / _restore_exclusive）
var _exclusive_stash: Dictionary = {}

# ---------- 多件槽位的读写（第三十六轮）----------
# 把 equipped 里某个值「归一化」成一串 id —— String / Array / null 都能吃。
func _ids_of(v: Variant) -> Array:
	var out := []
	if v == null:
		return out
	if typeof(v) == TYPE_ARRAY:
		for x in (v as Array):
			var s := str(x)
			if s != "" and not out.has(s):
				out.append(s)
		return out
	var s1 := str(v)
	if s1 != "":
		out.append(s1)
	return out

# 这一槽位当前装着的全部 id（单件槽位 0 ~ 1 个，多件槽位 0 ~ 上限个）
func ids_at(slot: String) -> Array:
	return _ids_of(equipped.get(slot, null))

# 这一槽位的第一件（单件槽位的全部）
func id_at(slot: String) -> String:
	var a := ids_at(slot)
	return str(a[0]) if not a.is_empty() else ""

# 这件东西现在身上有没有（跨槽位查）
func has_id(item_id: String) -> bool:
	for s in equipped.keys():
		if ids_at(str(s)).has(item_id):
			return true
	return false

# 这一槽位里「实体件」（非空件）的 id —— 多件槽位的计数用
func solid_ids(slot: String) -> Array:
	var out := []
	for id in ids_at(slot):
		var it: Dictionary = data.get_item(str(id))
		if not it.is_empty() and not data.is_bare(it):
			out.append(str(id))
	return out

# 写入一槽位。单件槽位存 String（取第一件），多件槽位存 Array；空 → 擦掉这个键。
func set_ids(slot: String, ids: Array) -> void:
	var clean := []
	for x in ids:
		var s := str(x)
		if s != "" and not clean.has(s):
			clean.append(s)
	if clean.is_empty():
		equipped.erase(slot)
	elif data.is_multi_slot(slot):
		equipped[slot] = clean
	else:
		equipped[slot] = str(clean[0])

# 多件槽位的落定：去掉空件 → 超上限就顶掉最早那件 → 一件不剩就退回「（无）」空件。
func _settle_multi(slot: String, ids: Array) -> void:
	var solids := []
	for x in ids:
		var s := str(x)
		var it: Dictionary = data.get_item(s)
		if it.is_empty() or data.is_bare(it):
			continue
		if not solids.has(s):
			solids.append(s)
	var cap: int = data.max_equip(slot)
	while solids.size() > cap:
		solids.pop_front()
	if solids.is_empty():
		var bid: String = data.bare_id_of(slot)
		if bid != "":
			solids = [bid]
	set_ids(slot, solids)

func _init(outfit_data: Node, true_app: Dictionary = {}, levels_in: Array = []) -> void:
	data = outfit_data
	true_appearance = true_app if not true_app.is_empty() else data.TRUE_APPEARANCE
	levels = levels_in if not levels_in.is_empty() else data.levels()
	_equip_defaults()

# 切到另一关 / 另一局时重置装备与接受度
func reset_for_level(acceptance_in: int, level_index_in: int, true_app: Dictionary = {},
		forced_in: Array = [], groups_in: Array = []) -> void:
	if not true_app.is_empty():
		true_appearance = true_app
	acceptance = acceptance_in
	level_index = level_index_in
	cleared_levels = level_index_in
	forced_items = forced_in.duplicate()
	forced_groups = groups_in.duplicate()
	_equip_defaults()
	# 注意：**不**自动穿上强制装备。
	# 开局永远是「原封不动的 A」，强制装备得你自己在准备室里穿 ——
	# 没穿就点不了「进入盘问」（判定栏会红字写明原因）。
	# 这样既保住了「开局即原貌」这条教学不变量，也让强制要求变成一件要动手的事。
	changed.emit()

# ---------- 强制装备 ----------
# 本轮被硬性要求穿上的那几件。判定很直白：没穿 = 当场识破。
# （所以这不是「建议」，是硬约束 —— 但它同时也在帮你拉反差值。）
#
# ★ 第二十三轮：除了「必须穿这一件」，还支持「这几件里任选一件」（forced_groups）。
#   两种规则可以自由叠加，结构见 OutfitData.forced_groups_at：
#     {"pick": "all", "items": [id]}           这几件都要穿（一件 = 固定一件）
#     {"pick": "any", "items": [id1, id2, …]}  这几件里任选一件
func set_forced_items(ids: Array) -> void:
	forced_items = ids.duplicate()
	changed.emit()

# 规则表（RunData 在进关时灌进来）
func set_forced_groups(groups: Array) -> void:
	forced_groups = groups.duplicate()
	changed.emit()

func is_forced_id(item_id: String) -> bool:
	# 「任选一件」的组里，组内每一件都算「本轮指定」——
	# 卡片上标橙色、悬停写「本轮强制装备」才对，否则玩家不知道这是被指定的。
	for id in forced_items:
		if str(id) == item_id:
			return true
	for g in forced_groups:
		if ((g as Dictionary).get("items", []) as Array).has(item_id):
			return true
	return false

# 本轮强制装备的完整物品数据（给 UI 展示用）——
# 「任选一件」的组会把组内所有选项都列出来（它们都是合法答案）。
func forced_items_info() -> Array:
	var seen := {}
	var out := []
	for id in _forced_candidate_ids():
		if seen.has(id):
			continue
		seen[id] = true
		var it: Dictionary = data.get_item(str(id))
		if not it.is_empty():
			out.append(it)
	return out

func _forced_candidate_ids() -> Array:
	var out := []
	for id in forced_items:
		out.append(str(id))
	for g in forced_groups:
		for id in ((g as Dictionary).get("items", []) as Array):
			out.append(str(id))
	return out

# 某个槽位是否被强制占用（用于 UI 上锁）
#   all 组 → 锁死成那一件；
#   any 组 → 也返回组内第一件，调用方用 forced_allowed_ids() 拿到完整可选集。
func forced_for_slot(slot: String) -> Dictionary:
	for id in forced_items:
		var it: Dictionary = data.get_item(str(id))
		if not it.is_empty() and str(it.get("slot", "")) == slot:
			return it
	for g in forced_groups:
		for id in ((g as Dictionary).get("items", []) as Array):
			var it2: Dictionary = data.get_item(str(id))
			if not it2.is_empty() and str(it2.get("slot", "")) == slot:
				return it2
	return {}

func is_forced_slot(slot: String) -> bool:
	return not forced_for_slot(slot).is_empty()

# 这个槽位被允许穿哪些（null = 不受限）。
#   · all 组 → 只有那一件；
#   · any 组 → 组内那几件；
#   · 没有规则表时（random / none 模式）→ forced_items 里的那几件同样锁死。
# 求解器（一键达标 / 可解性）靠它区分「可以自由换」与「被本轮锁住」——
# 漏掉最后那一条会让 DP 把锁死的槽位当成自由的，算出实际不成立的搭配。
func forced_allowed_ids(slot: String):
	var locked := ""
	var any_list := []
	for g in forced_groups:
		var gd: Dictionary = g
		var same_slot := []
		for id in (gd.get("items", []) as Array):
			var it: Dictionary = data.get_item(str(id))
			if not it.is_empty() and str(it.get("slot", "")) == slot:
				same_slot.append(str(id))
		if same_slot.is_empty():
			continue
		if str(gd.get("pick", "")) == data.PICK_ANY:
			any_list.append_array(same_slot)
		else:
			locked = str(same_slot[0])
	if locked != "":
		return [locked]
	if not any_list.is_empty():
		return any_list
	if forced_groups.is_empty():
		for id in forced_items:
			var it2: Dictionary = data.get_item(str(id))
			if not it2.is_empty() and str(it2.get("slot", "")) == slot:
				return [str(id)]
	return null

# 强制装备里还没满足的规则
#   · all 组：组内每一件都得穿着；
#   · any 组：组内**至少有一件**穿着。
func missing_forced() -> Array:
	var out := []
	for g in forced_groups:
		var gd: Dictionary = g
		var items: Array = gd.get("items", [])
		if items.is_empty():
			continue
		if str(gd.get("pick", "")) == data.PICK_ANY:
			var ok := false
			for id in items:
				var it: Dictionary = data.get_item(str(id))
				if it.is_empty():
					continue
				if has_id(str(id)):
					ok = true
					break
			if not ok:
				var first: Dictionary = data.get_item(str(items[0]))
				if not first.is_empty():
					out.append(first)
			continue
		for id in items:
			var it2: Dictionary = data.get_item(str(id))
			if it2.is_empty():
				continue
			if not has_id(str(id)):
				out.append(it2)
	# 没有规则表时（random / none 模式）退回老口径：forced_items 逐件检查
	if forced_groups.is_empty():
		for id in forced_items:
			var it3: Dictionary = data.get_item(str(id))
			if it3.is_empty():
				continue
			if not has_id(str(id)):
				out.append(it3)
	return out

# 还差什么 —— 一条规则一句人话
# （「这几件里任选一件：甲、乙」比罗列一堆物品名清楚得多）
func missing_forced_text() -> Array:
	var out := []
	for g in forced_groups:
		var gd: Dictionary = g
		var items: Array = gd.get("items", [])
		if items.is_empty():
			continue
		var names := []
		for id in items:
			names.append(str(data.get_item(str(id)).get("name", id)))
		if str(gd.get("pick", "")) == data.PICK_ANY:
			var ok := false
			for id in items:
				var it: Dictionary = data.get_item(str(id))
				if not it.is_empty() and has_id(str(id)):
					ok = true
					break
			if not ok:
				out.append("这几件里任选一件：" + "、".join(names))
			continue
		for id in items:
			var it2: Dictionary = data.get_item(str(id))
			if it2.is_empty():
				continue
			if not has_id(str(id)):
				out.append("必须穿：" + str(it2.get("name", id)))
	if forced_groups.is_empty():
		for it3 in missing_forced():
			out.append("必须穿：" + str((it3 as Dictionary).get("name", "")))
	return out

func forced_satisfied() -> bool:
	return missing_forced().is_empty()

# ---------- 初始化：套用显式的初始套装 ----------
# 开局就是 A 的原貌 —— 你还没来得及伪装自己
func _equip_defaults() -> void:
	equipped.clear()
	_exclusive_stash.clear()
	# 只铺「玩家能看到的槽位」—— 下架的槽位不进 equipped，
	# 这样暴露值 / 反差值 / 一致数 / 存档都不会多出一处
	for slot in data.active_slots():
		var s := str(slot)
		# ★ 第三十九轮：妙妙工具默认「不携带」。
		#   它是玩家**手动**揣上的道具（用户口径「只能手动装备」），
		#   默认送一件等于白给 —— 所以这里不走「取最朴素的那件」那套，
		#   直接落到这一栏的空件（`tool_none`「（不携带）」，由 `bare: true` 标出）。
		if data.is_manual_slot(s):
			var none_id: String = str(data.bare_id_of(s))
			if none_id != "":
				set_ids(s, [none_id])
			continue
		var ids := []
		for x in _ids_of(true_appearance.get(s, "")):
			var it: Dictionary = data.get_item(str(x))
			if not it.is_empty() and str(it.get("slot", "")) == s:
				ids.append(str(x))
		if ids.is_empty():
			# 兜底：该槽位取最朴素的物品
			var cheapest: Dictionary = data.cheapest_for_slot(s)
			if not cheapest.is_empty():
				ids = [str(cheapest["id"])]
		set_ids(s, ids)
	# ★ 第二十七轮：原貌也要过一遍互斥归一化。
	#   原貌是**逐槽位独立抽**的，理论上可能同时抽到「成装」与「上装 / 下装」——
	#   那是穿不到一起的组合。规则：**成装优先**（成装那一侧赢了就把上装 / 下装归零）。
	#   ★ 当前 TRUE_POOL 里 `dress` 只放空件，所以这段平时不触发，是纯防御。
	_normalize_exclusive()

# ★ 互斥归一化：把一份「可能自相矛盾」的装备表修成自洽的。
#   用在「从一张现成的装备表铺装备」的场合（原貌 / 存读档）——
#   这里的语义是「表里本来就该是自洽的，有冲突就按二分互斥的声明顺序裁决（左边优先）」。
#
#   ★ 注意二分互斥的语义：**同一组内部不互斥**。
#     `[["dress"], ["top", "bottom"]]` 只规定「成装 ↔ 上装 / 下装」，
#     上装与下装本身当然可以一起穿 —— 早先写成「组内只能留一个」的版本
#     会把「上衣 + 下装」这套完全正常的搭配也拆掉（开局原貌的上装下装被归零）。
func _normalize_exclusive() -> void:
	for g in data.EXCLUSIVE_GROUPS:
		var pair := g as Array
		var left := pair[0] as Array
		var right := pair[1] as Array
		var left_live := _any_solid(left)
		var right_live := _any_solid(right)
		if left_live and right_live:
			_blank_group(right)           # 两边都占着 → 左边赢（成装优先）
		elif left_live:
			_blank_group(right)
		elif right_live:
			_blank_group(left)

# 这一组里有没有「实体衣物」（非空件、非下架）
func _any_solid(slots: Array) -> bool:
	for s in slots:
		if not solid_ids(str(s)).is_empty():
			return true
	return false

# 把这一组全部换成各自的空件
func _blank_group(slots: Array) -> void:
	for s in slots:
		var ps := str(s)
		var bid: String = data.bare_id_of(ps)
		if bid != "":
			set_ids(ps, [bid])

# ★ 互斥执行：玩家主动装备 `slot` 之后，把它**对面那一组**脱掉。
#   语义与 _normalize_exclusive 不同 —— 这里是「**后装备的赢**」：
#   你刚穿上成装，就说明你不打算再穿刚才那件上衣了。
#
#   ★ 顶掉的槽位会记进 `_exclusive_stash`，玩家再把成装脱下来时原样还回去 ——
#     否则「穿成装 → 脱成装」之后上装与下装会一起空着（暴露值凭空 +18）。
func _apply_exclusive(slot: String) -> void:
	var peers: Array = data.exclusive_peers(slot)
	if peers.is_empty():
		return
	var it: Dictionary = item_at(slot)
	if it.is_empty() or data.is_bare(it):
		_restore_exclusive(peers)         # 装的是空件 → 把之前顶掉的还回去
		return
	for p in peers:
		var ps := str(p)
		var cur := id_at(ps)
		var cur_it: Dictionary = data.get_item(cur)
		if cur != "" and not cur_it.is_empty() and not data.is_bare(cur_it):
			_exclusive_stash[ps] = cur   # 先留个底
		var bid: String = data.bare_id_of(ps)
		if bid != "":
			set_ids(ps, [bid])

func _restore_exclusive(peers: Array) -> void:
	for p in peers:
		var ps := str(p)
		if not _exclusive_stash.has(ps):
			continue
		var back := str(_exclusive_stash[ps])
		_exclusive_stash.erase(ps)
		if not data.get_item(back).is_empty():
			equipped[ps] = back

# ---------- 查询 ----------
func item_at(slot: String) -> Dictionary:
	return data.get_item(id_at(slot))

# 这一槽位当前装着的全部物品（多件槽位会有多件；空件也在里面）
func items_at(slot: String) -> Array:
	var out := []
	for id in ids_at(slot):
		var it: Dictionary = data.get_item(str(id))
		if not it.is_empty():
			out.append(it)
	return out

func can_equip(item: Dictionary) -> bool:
	return data.can_equip(item, acceptance)

func equip(item: Dictionary) -> bool:
	if not can_equip(item):
		return false
	var slot := str(item["slot"])
	# ★ 第二十七轮补的一道闸：下架的槽位在**模型层**也不许装。
	#   以前只靠「界面不渲染下架槽位的卡片」来隔离（`get_items_for_slot` 返回空），
	#   但 `equip()` 是公开 API —— 传一件手套 / 外袍进来照样能装进 equipped，
	#   再被 `_counts_with`（非门控槽位一律返回 true）算进反差值。补上更干净。
	if not data.slot_enabled(slot):
		return false
	var id := str(item["id"])
	var it: Dictionary = data.get_item(id)
	if it.is_empty():
		return false
	# ★ 第三十六轮：多件槽位（纹身）—— 装上一件不是「替换」，而是「加一件」；
	#   满了（默认 2 件）就顶掉最早装上的那一件；装「（无）」= 全部卸掉。
	if data.is_multi_slot(slot):
		var keep := ids_at(slot)
		if data.is_bare(it):
			_settle_multi(slot, [])
		else:
			keep.append(id)
			_settle_multi(slot, keep)
		changed.emit()
		return true
	equipped[slot] = id
	_apply_exclusive(slot)
	changed.emit()
	return true

# ★ 第三十六轮：界面点卡片走这个 —— 单件槽位语义不变（再点一次是空操作），
#   多件槽位才是真正的「开关」：已装备的再点一次 = 脱下来。
func toggle(item: Dictionary) -> bool:
	var slot := str(item["slot"])
	var id := str(item["id"])
	if not data.is_multi_slot(slot):
		return equip(item)
	var cur := ids_at(slot)
	if not cur.has(id):
		return equip(item)
	if data.is_bare(data.get_item(id)):
		return false                       # 「（无）」本来就是空的，再点没意义
	var keep := []
	for x in cur:
		if str(x) != id:
			keep.append(str(x))
	_settle_multi(slot, keep)
	changed.emit()
	return true

func unequip(slot: String) -> void:
	equipped.erase(slot)
	changed.emit()

# ---------- 暴露值 ----------
# ★ 第二十二轮起，总和不再是一味相加 —— 内衣内裤挂了「曝光门控」：
#   穿在朴素外衣底下的内衣内裤，既不算暴露值、也不算反差值（见下）。
func total_exposure() -> int:
	return total_exposure_with({})

func total_exposure_with(override: Dictionary) -> int:
	return _sum_with(override, "exposure")

func exposure_cap() -> int:
	return data.exposure_cap(acceptance)

func is_over_cap() -> bool:
	return total_exposure() > exposure_cap()

# ============================================================
#  内衣内裤 / 纹身的「曝光门控」（第二十二轮起，第三十六轮扩到纹身）
#
#  用户口径：「内裤内衣的反差值和暴露值只有在**能够显示在人物身上**时才会计算，
#            如透明外衣能计算、直接外穿能计算、镂空开档能计算」
#  第三十六轮追加：「纹身与内衣内裤处理方法相同，不漏出来时，不计算暴露值反差度。」
#
#  判定的是「这一件到底看不看得见」，而不是「穿没穿外衣」。三条路：
#    ① 透明外衣  —— 外衣标了 "see": "sheer"（薄纱 / 蕾丝半透）
#    ② 镂空开档  —— 外衣标了 "see": "cutout"（开衩 / 超短 / 露腰）
#    ③ 直接外穿  —— 同侧外衣是空件（"bare"，例如「（不穿上衣）」）或压根没有
#  三条都不成立（盖得严严实实），这一件就既不算暴露值、也不算反差值。
#
#  ★ 暴露值与反差值**用同一条门控** —— 看不见就既没风险、也没意义。
#
#  ★ 开门人是**按件**给的（OutfitData.outer_slots_of_item）：
#    内衣内裤退回槽位级表（UNDER_GATE），纹身写在自己身上（不同部位不同遮盖）。
# ============================================================
# 这一件（当前装备的）是不是真的露在外面
func item_counts(slot: String, id: String) -> bool:
	return _item_counts(equipped, slot, id)

# 这一槽位的数值要不要计入总和（当前装备下）。界面与测试都走它。
# 多件槽位（纹身）：只要有**任意一件**露着就算「计入」。
func counts_toward_totals(slot: String) -> bool:
	return _counts_with(equipped, slot)

# 旧名（第二十二轮的叫法），保留给老调用点
func underwear_shown(slot: String) -> bool:
	return _counts_with(equipped, slot)

# 当前装备下，这一件「为什么看得见 / 为什么看不见」——
# 返回 "always"（不受门控）/ "sheer" / "cutout" / "bare" / "hidden"。界面文案用。
func item_visibility(slot: String, id: String) -> String:
	var it: Dictionary = data.get_item(id)
	if it.is_empty():
		return "hidden"
	var outers: Array = data.outer_slots_of_item(it)
	if outers.is_empty():
		return "always"
	# 从外往内找第一层「真的存在」的衣服 —— 它就是决定看得见看不见的那一层。
	# 找不到（每一层都是空件 / 下架）→ 直接外穿。
	for i in range(outers.size() - 1, -1, -1):
		var os := str(outers[i])
		if not data.slot_enabled(os):
			continue
		var oit: Dictionary = data.get_item(id_at(os))
		if oit.is_empty() or data.is_bare(oit):
			continue                              # 这一层等于没有
		var kind: String = data.see_through_kind(oit)
		return kind if kind != "" else "hidden"
	return "bare"

func underwear_visibility(slot: String) -> String:
	return item_visibility(slot, id_at(slot))

# 按「假想的装备表」判断某一槽位要不要计入 ——
# 换装界面判断「装上后会不会超上限」时，换的是上衣 / 下装会连带开关内衣（或纹身）的门控，
# 所以必须整套重算，不能只看被点的那一件。
#
# 判据：**上面没有任何一层把它挡住**。逐层从里往外看（bra → top → robe）：
#   · 下架的槽位不算一层（外袍现在就没在场上）；
#   · 空件（「（不穿上衣）」）等于这一层没有东西，不挡也不透；
#   · 标了 see 的那一层（透明 / 镂空）不挡；
#   · 其余（普通衣服）一律挡死 —— 里面再花哨也看不见。
# 一层都不剩 → 就是最外层，也就是用户说的「直接外穿」。
func _counts_with(eq: Dictionary, slot: String) -> bool:
	# ★ 这里刻意**不**走 `_ids_of()` —— 它是 DP 的最内层（每个候选搭配都要问好几遍），
	#   每次多分配一个数组会实打实地拖慢整套测试。单件槽位（绝大多数）直接走快路径。
	var v: Variant = eq.get(slot, null)
	if v == null:
		return false
	if typeof(v) == TYPE_ARRAY:
		for id in (v as Array):
			if _item_counts(eq, slot, str(id)):
				return true
		return false
	var s := str(v)
	return s != "" and _item_counts(eq, slot, s)

# 单件的门控判定（第三十六轮拆出来的 —— 一个槽位里每件的可见性可以不一样）
func _item_counts(eq: Dictionary, slot: String, id: String) -> bool:
	# ★ 第二十七轮：被互斥组赢家顶掉的槽位，整件都不参与计算。
	#   互斥（EXCLUSIVE_GROUPS）执行时，落败的一方被换成「该槽位的空件」——
	#   而空件（`top_none` 暴露 9 / `bottom_none` 暴露 9 反差 8）本身是**高数值**的
	#   （它的语义是「这一层什么都不穿 → 内衣直接外穿」）。
	#   穿了一件成装却白吃下装空件的 9 点暴露、8 点反差，显然不对。
	#   所以这里补一道闸：同组已经有实体件了 → 被顶掉的那个槽位按 0 计。
	if _covered_by_exclusive(eq, slot):
		return false
	var it: Dictionary = data.get_item(id)
	if it.is_empty():
		return false
	var outers: Array = data.outer_slots_of_item(it)
	if outers.is_empty():
		return true                               # 不受门控 → 恒计入
	for o in outers:
		var os := str(o)
		if not data.slot_enabled(os):
			continue                              # 下架的槽位不算一层
		# 快路径：外层槽位永远是单件（top / bottom / dress / neckwear）
		var ov: Variant = eq.get(os, null)
		if ov == null:
			continue
		if typeof(ov) == TYPE_ARRAY:
			for oid in (ov as Array):
				var oit: Dictionary = data.get_item(str(oid))
				if oit.is_empty() or data.is_bare(oit):
					continue
				if data.see_through_kind(oit) == "":
					return false
			continue
		var oid2 := str(ov)
		if oid2 == "":
			continue
		var oit2: Dictionary = data.get_item(oid2)
		if oit2.is_empty() or data.is_bare(oit2):
			continue                              # 这一层等于没有 —— 不挡
		if data.see_through_kind(oit2) == "":
			return false                          # 这一层是普通衣服 → 挡住了
	return true

# 这一槽位是不是「被同组的另一件顶掉了」—— 是的话它整件都不算数。
#   判据：它所在的那一组互斥槽位里，有**别的**槽位装着实体衣物。
func _covered_by_exclusive(eq: Dictionary, slot: String) -> bool:
	for p in data.exclusive_peers(slot):
		for oid in _ids_of(eq.get(str(p), null)):
			var it: Dictionary = data.get_item(str(oid))
			if it.is_empty() or data.is_bare(it):
				continue
			return true
	return false

# 这几个槽位里有没有实体衣物（`_delta` 的短路判断用）
func _any_peer_solid(slots: Array) -> bool:
	for p in slots:
		if not solid_ids(str(p)).is_empty():
			return true
	return false

# 门控下这一槽位「实际算多少」—— 露不出来就是 0。单项读数用得上。
# 多件槽位：逐件过门控后求和。
func effective_stat(slot: String, field: String) -> int:
	var t := 0
	for id in ids_at(slot):
		if _item_counts(equipped, slot, str(id)):
			t += int(data.get_item(str(id)).get(field, 0))
	return t

# ---------- 反差值 ----------
# 语义：与「A 的原貌」的偏离程度。
# 只有与原貌不同的槽位才把该物品的 contrast 计入总和 ——
# 穿得和原貌一模一样时反差值为 0，意味着审讯官一眼就认出你。
# 第二十二轮起，受门控的内衣内裤还要额外过一道「露出来了吗」的关。
func _matches_true(slot: String) -> bool:
	return ids_at(slot) == _ids_of(true_appearance.get(slot, ""))

func total_contrast() -> int:
	return total_contrast_with({})

func total_contrast_with(override: Dictionary) -> int:
	return _sum_with(override, "contrast")

# 覆盖值的归一化：多件槽位传 Array，单件槽位传 String / 单元素 Array 都行
func _norm_val(v: Variant) -> Variant:
	if typeof(v) == TYPE_ARRAY:
		return (v as Array).duplicate()
	return str(v)

# 通用求和：把 override 套进当前装备，逐件累加某个字段。
#   ★ 这里刻意**不** duplicate 整个 equipped —— 换装界面的贪心/DP 会问几万遍，
#     复制一份 17 键的字典会把整个流程拖慢一个量级。改成「临时改、算完还原」。
func _sum_with(override: Dictionary, field: String) -> int:
	if override.is_empty():
		return _sum_now(field)
	var saved: Dictionary = {}
	for k in override:
		var ks := str(k)
		saved[ks] = equipped.get(ks, null)
		equipped[ks] = _norm_val(override[ks])
	var v := _sum_now(field)
	for k in saved:
		if saved[k] == null:
			equipped.erase(k)
		else:
			equipped[k] = saved[k]
	return v

func _sum_now(field: String) -> int:
	var t := 0
	for s in equipped.keys():
		var slot := str(s)
		var v: Variant = equipped[s]
		if typeof(v) == TYPE_ARRAY:
			for id in (v as Array):
				if _item_counts(equipped, slot, str(id)):
					t += _contrib(slot, str(id), field)
			continue
		var id2 := str(v)
		if id2 != "" and _item_counts(equipped, slot, id2):
			t += _contrib(slot, id2, field)
	return t

# 某一槽位当前实际计入多少（逐件过门控）—— `_delta` 的连带项用
func _slot_contrib(slot: String, field: String) -> int:
	var t := 0
	for id in ids_at(slot):
		if _item_counts(equipped, slot, str(id)):
			t += _contrib(slot, str(id), field)
	return t

# 单件的「门控后贡献」：露不出来就是 0
func _item_contrib(slot: String, id: String, field: String) -> int:
	if not _item_counts(equipped, slot, id):
		return 0
	return _contrib(slot, id, field)

# 单件的贡献（门控之外的部分）。
#
# ★★ 第三十一轮：反差值换算法（用户口径）。
#
#   改之前：逐槽位累加物品自己那个手填的 `contrast`（与原貌相同则记 0）。
#   改之后：**只算上衣与下装**，数值 = |你穿的暴露度 − 相册里记的那件的暴露度| × 系数。
#     · 相册记录的就是原貌（那几张「偷拍」拍的就是 A 平时的样子），
#       所以基线取 `true_appearance` —— 穿了与它相同的件，差为 0、自然不计反差，
#       正好对上「装备与相册记录相同则不记录反差值」这条口径。
#     · 暴露度差越大 = 你比他记得的样子露/捂得越多 = 越不像他。
#     · 只有上衣与下装参与：这两处是「一眼扫过去」最先看到的轮廓。
#
#   ★ 系数在 rules.contrast_per_exposure 里（默认 5）：暴露度差最大 9（下装「不穿」9 档），
#     两件加起来上限约 90，覆盖得住四关的 20/30/40/50。
func _contrib(slot: String, id: String, field: String) -> int:
	if id == "":
		return 0
	if field == "contrast":
		return _contrast_of(slot, id)
	return int(data.get_item(id).get(field, 0))

# 参与反差的槽位（用户口径：只影响上衣与下装）
const CONTRAST_SLOTS := ["top", "bottom"]

# 某槽位这件衣服贡献多少反差。不参与反差的槽位一律 0。
func _contrast_of(slot: String, id: String) -> int:
	if not CONTRAST_SLOTS.has(slot):
		return 0
	var base_id := str(true_appearance.get(slot, ""))
	var base_exp := 0
	if base_id != "":
		base_exp = int(data.get_item(base_id).get("exposure", 0))
	var now_exp := int(data.get_item(id).get("exposure", 0))
	return absi(now_exp - base_exp) * data.contrast_per_exposure()

# ============================================================
#  单槽位增量 —— 换一件衣服会让总和变多少
#
#  换装界面与求解器一次要问几万遍，所以不能每次去重算整个总和（17 个槽位）。
#  这里给出**精确**的增量，连带效应一起算：
#    · 自己那一件的贡献差；
#    · 若换的是外衣（top / bottom / robe），同侧内衣的可见性可能翻转 ——
#      翻转了就把它整件的贡献加进来或减出去。
# ============================================================
func exposure_delta(changed: String, new_id: String) -> int:
	return _delta(changed, new_id, "exposure")

func contrast_delta(changed: String, new_id: String) -> int:
	return _delta(changed, new_id, "contrast")

func _delta(changed: String, new_id: String, field: String) -> int:
	var slot := str(changed)

	# ★ 第三十六轮：多件槽位（纹身）的增量 = 「这一件装上 / 脱下」的贡献差。
	#   它的可见性只取决于外面的衣服（top / bottom / dress），与同槽位另一件无关，
	#   所以不用整套重算。满员时是「顶掉最早那件」，被顶掉那件的贡献也要算进去。
	if data.is_multi_slot(slot):
		var cur := ids_at(slot)
		if cur.has(new_id):
			return -_item_contrib(slot, new_id, field)
		var nit: Dictionary = data.get_item(new_id)
		if not nit.is_empty() and data.is_bare(nit):
			var dt := 0                          # 「（无）」= 全部卸掉
			for id in cur:
				dt -= _item_contrib(slot, str(id), field)
			return dt
		var solids := solid_ids(slot)
		var dm := _item_contrib(slot, new_id, field)
		if solids.size() >= data.max_equip(slot):
			dm -= _item_contrib(slot, str(solids[0]), field)
		return dm

	var old_id := id_at(slot)

	# ★ 第二十七轮：互斥槽位的增量不能用「只改一个槽位」的算法 ——
	#   换上成装会把上装 / 下装一起清空（`_apply_exclusive`），
	#   那两件的贡献、以及它们各自的**内衣门控**都会跟着变。
	#
	#   ★ 但**只有在「对面那一组真的占着」时才需要整套重算** ——
	#     常见情况下成装是「（不穿成装）」、上装 / 下装各穿各的，
	#     换这三栏里任意一栏都不会波及对面，走下面的精确增量就够。
	#     不做这层短路的话，测试里的「局部最优」检查（每个槽位 × 每件候选都问一遍）
	#     会把整套重算调用上万次，WardrobeTest 从 1m30s 涨到 5m30s。
	var peers: Array = data.exclusive_peers(slot)
	if not peers.is_empty() and _any_peer_solid(peers):
		var ov := {slot: new_id}
		var it_new: Dictionary = data.get_item(new_id)
		if not (it_new.is_empty() or data.is_bare(it_new)):
			for p in peers:
				var bid: String = data.bare_id_of(str(p))
				if bid != "":
					ov[str(p)] = bid
		return _sum_with(ov, field) - _sum_now(field)

	var d := 0
	# ① 这一件自己：可见性取决于「外面那层」，与它自己换成哪件无关
	if _counts_with(equipped, slot):
		d = _contrib(slot, new_id, field) - _contrib(slot, old_id, field)

	# ② 连带：被它盖住 / 露出的那些内衣内裤、以及纹身（按件门控）
	var watch: Array = data.gate_dependents(slot)
	if watch.is_empty():
		return d

	# ★ 只在「这一槽位的可见性真的翻转了」时才重算它的贡献 ——
	#   `_delta` 是热路径（求解器要问几万遍），无条件重算会拖慢好几倍。
	var was := {}
	for gs in watch:
		var g0 := str(gs)
		was[g0] = {"on": _counts_with(equipped, g0), "c": _slot_contrib(g0, field)}
	var saved: Variant = equipped.get(slot, null)
	equipped[slot] = new_id
	for gs in watch:
		var g := str(gs)
		var st: Dictionary = was[g]
		var now: bool = _counts_with(equipped, g)
		if now == bool(st["on"]):
			continue
		d += _slot_contrib(g, field) if now else -int(st["c"])
	if saved == null:
		equipped.erase(slot)
	else:
		equipped[slot] = saved
	return d

# 换装界面判断「装上后会不会超上限」用这个（比整套重算便宜几十倍）
func exposure_after(changed: String, new_id: String) -> int:
	return total_exposure() + exposure_delta(changed, new_id)

# 仍与原貌一致的槽位（越少越安全）
# ★ 第三十九轮：走 `auto_slots()` —— 「妙妙工具」没有原貌，不计入这项统计
#   （所以它不影响反差值与任何数值判定的口径，见 OutfitData.MANUAL_SLOTS）。
func matching_slots() -> Array:
	var out := []
	for slot in data.auto_slots():
		if _matches_true(slot):
			out.append(slot)
	return out

# 已经改掉的槽位
func changed_slots() -> Array:
	var out := []
	for slot in data.auto_slots():
		if not _matches_true(slot):
			out.append(slot)
	return out

# 原貌相似度 0.0 ~ 1.0（越低越好认不出来）
func resemblance() -> float:
	var n: int = matching_slots().size()
	return float(n) / float(max(1, data.auto_slots().size()))

func contrast_requirement() -> int:
	return int(level_info().get("contrast_req", 0))

func level_info() -> Dictionary:
	if levels.is_empty():
		return {"contrast_req": 0, "acceptance_gain": 0, "name": "", "derived_profile": ""}
	return levels[clampi(level_index, 0, levels.size() - 1)]

func level_name() -> String:
	return str(level_info().get("name", ""))

func derived_profile() -> String:
	return str(level_info().get("derived_profile", ""))

func is_contrast_sufficient() -> bool:
	var c := total_contrast()
	var req := contrast_requirement()
	if data.CONTRAST_HIGHER_IS_SAFER:
		return c >= req
	return c <= req

# ---------- 缺陷遮挡 ----------
func covered_defect_ids() -> Array:
	var covered := []
	var tags := []
	for slot in equipped.keys():
		for it in items_at(str(slot)):
			for t in (it as Dictionary).get("tags", []):
				tags.append(t)

	for d in data.defects():
		var need: Array = d.get("cover_tags", [])
		var ok := false
		for tag in need:
			if tags.has(tag):
				ok = true
				break
		if ok:
			covered.append(d["id"])
	return covered

func exposed_defects() -> Array:
	var covered := covered_defect_ids()
	var out := []
	for d in data.defects():
		if not covered.has(d["id"]):
			out.append(d)
	return out

# ---------- 综合判定 ----------
# 返回 {verdict: "pass"/"instantly_exposed", reasons: [...]}
func evaluate() -> Dictionary:
	var reasons := []

	if is_over_cap():
		reasons.append("暴露值 %d 超出上限 %d" % [total_exposure(), exposure_cap()])

	var uncovered := exposed_defects()
	if uncovered.size() > 0:
		var names := []
		for d in uncovered:
			names.append(d["name"])
		reasons.append("缺陷未遮挡：" + ", ".join(names))

	if not is_contrast_sufficient():
		reasons.append("反差值 %d ＜ 要求 %d（仍有 %d 处与原貌一致）"
			% [total_contrast(), contrast_requirement(), matching_slots().size()])

	var missing_text := missing_forced_text()
	if missing_text.size() > 0:
		reasons.append("本轮强制装备没穿：" + "；".join(missing_text))

	return {
		"verdict": "pass" if reasons.is_empty() else "instantly_exposed",
		"reasons": reasons,
	}

# ============================================================
#  测试用：一键满足本轮全部服装要求
#
#  要同时满足四条约束（全部来自 evaluate()）：
#    ① 本轮强制装备必须穿上（每轮随机 0~2 件高暴露衣物）
#    ② 暴露值 ≤ 上限
#    ③ 反差值 ≥ 本轮要求
#    ④ 身体缺陷全部遮住
#
#  做法：在「已用暴露值 × 已遮缺陷掩码」这个状态空间上跑一遍动态规划。
#    · 每个槽位只能选「当前接受度穿得起」的物品；
#    · 强制槽位锁死为本轮那一件；
#    · 价值 = 反差值（与原貌相同的槽位贡献 0，和 total_contrast() 同一口径），
#      同分时优先「改掉的部位更多」。
#  最后取「遮得最全 → 价值最高 → 暴露最低」的终态回溯出整套搭配 ——
#  因为状态里带了暴露值，这个解是**在约束下的最优解**，不是贪心近似。
#
#  ★ 第二十二轮：门控对必须**一起选**。
#    内衣内裤的暴露值与反差值要看同侧外衣够不够露（见 UNDER_GATE），
#    所以 bra 跟着 top、panties 跟着 bottom 合成一个决策 ——
#    否则 DP 会以为内衣的贡献是固定的，算出一套实际对不上的「最优解」。
#
#  这是**测试 / 调试**用的捷径，不是玩法的一部分：
#  它只是把玩家本来要自己算的那道题直接算完。
# ============================================================
func auto_complete_outfit() -> Dictionary:
	# ★ 第三十九轮：走 `auto_slots()` —— 「妙妙工具」不参与一键达标。
	#   用户口径「只能手动装备，调试计算反差值时请不要使用」：这一栏系统从不代劳，
	#   你点「一键达标」时它不会被穿上、也不会被脱下 —— 保持你手动设的那个状态。
	var slots: Array = data.auto_slots()
	var defects: Array = data.defects()
	var mask_n: int = 1 << defects.size()

	# ---- 分组：门控对（外衣 + 它里面的内衣）合成一组 ----
	var groups := dp_groups(slots)
	var max_total := 0
	for g in groups:
		max_total += int(g["worst_e"])

	# 状态空间只到「理论上穿得出」的上限 —— 接受度被刷得再大也不会把 DP 撑爆
	var cap: int = mini(exposure_cap(), max_total)
	var states: int = (cap + 1) * mask_n

	var dp := []
	dp.resize(states)
	dp.fill(-1)
	dp[0] = 0                                    # (暴露 0, 掩码 0) → 得分 0

	var par_state: Array = []                    # par_state[i][s] = 走到 s 时的上一状态
	var par_pick: Array = []                     # par_pick[i][s]  = 该组选中的候选下标

	for gi in groups.size():
		var opts: Array = groups[gi]["opts"]
		var ndp := []
		ndp.resize(states)
		ndp.fill(-1)
		var ps := []
		ps.resize(states)
		ps.fill(-1)
		var pp := []
		pp.resize(states)
		pp.fill(-1)

		for e in range(cap + 1):
			for m in mask_n:
				var s: int = e * mask_n + m
				var cur_v: int = dp[s]
				if cur_v < 0:
					continue
				for oi in opts.size():
					var opt: Dictionary = opts[oi]
					var ne: int = e + int(opt["exposure"])
					if ne > cap:
						continue
					var ns: int = ne * mask_n + (m | int(opt["mask"]))
					var nv: int = cur_v + int(opt["score"])
					if nv > ndp[ns]:
						ndp[ns] = nv
						ps[ns] = s
						pp[ns] = oi
		dp = ndp
		par_state.append(ps)
		par_pick.append(pp)

	# ---- 选终态：缺陷遮得最全 → 得分最高（反差优先）→ 暴露最低 ----
	var best_s := -1
	var best_cov := -1
	var best_con := -1
	var best_e := 1 << 30
	for e in range(cap + 1):
		for m in mask_n:
			var s: int = e * mask_n + m
			var v: int = dp[s]
			if v < 0:
				continue
			var cov: int = _bit_count(m)
			if cov > best_cov \
					or (cov == best_cov and v > best_con) \
					or (cov == best_cov and v == best_con and e < best_e):
				best_cov = cov
				best_con = v
				best_e = e
				best_s = s

	# ---- 回溯并穿上 ----
	# 注意：变量不能叫 `changed` —— 会遮蔽本类的 `signal changed`，
	# 后面那句 changed.emit() 就会变成「在 Array 上找 emit」而编译不过。
	var touched := []
	if best_s >= 0:
		var s := best_s
		for gi in range(groups.size() - 1, -1, -1):
			var oi: int = par_pick[gi][s]
			if oi < 0:
				break
			var pick: Dictionary = (groups[gi]["opts"] as Array)[oi]["pick"]
			for slot in pick.keys():
				var s2 := str(slot)
				# ★ 第三十六轮：多件槽位的 pick 值是 Array（0 ~ 上限件），
				#   单件槽位仍是 String —— 一律走 _ids_of / set_ids 落定。
				var ids := _ids_of(pick[slot])
				if ids != ids_at(s2):
					touched.append(s2)
				set_ids(s2, ids)
			s = par_state[gi][s]

	changed.emit()
	return _auto_report(touched)

# ------------------------------------------------------------
#  DP 分组：把「外衣 + 它里面那件内衣」并成一组
#
#  顺序沿用 active_slots()，组的键取这一块连通分量的代表，
#  位置就落在这一块里第一个出现的槽位（top 在 bra 前面、bottom 在 panties 前面）。
#
#  ★ 第二十六轮改成**连通分量**：以前是「每个受门控的槽位认它第一个在场上
#    的开门人」，在「一个门控槽位只有一个开门人」的前提下是对的
#    （bra←top、panties←bottom，robe 下架中）。
#    但新增的 `dress` **同时是 bra 与 panties 的开门人**，把
#    top / bra / dress / bottom / panties 串成了一整块 —— 只认一个主人就会
#    漏掉跨组影响（换 dress 会改变 bra 与 panties 算不算数，而它们分属不同的组），
#    DP 于是不再是精确解，测试里的「局部最优」「次级目标」两条会当场挂掉。
#    并成一个连通分量之后就又是精确的了。
#
#  ★ 第三十六轮：多件槽位（纹身）**不进**这张门控图 —— 它故意不在 UNDER_GATE 里，
#    所以天然自成一个单元素组。理由：纹身只影响暴露值、不影响反差值
#    （CONTRAST_SLOTS 只有 top / bottom），DP 的目标函数与它无关；
#    把它并进 top / bra / dress / bottom / panties 那一大块，光选项数就会
#    从两万五涨到上百万，直接跑不动。它的暴露值按**保守口径**计入
#    （见 _multi_option_of），所以解依旧不会超上限。
# ------------------------------------------------------------
func _gate_root(parent: Dictionary, x: String) -> String:
	while str(parent[x]) != x:
		parent[x] = parent[str(parent[x])]        # 路径压缩
		x = str(parent[x])
	return x

func dp_groups(slots: Array) -> Array:
	var parent := {}
	for slot in slots:
		parent[str(slot)] = str(slot)

	# 门控边：受门控的槽位 ↔ 它每一个「还在场上」的开门人
	for gated in data.UNDER_GATE.keys():
		var g := str(gated)
		if not parent.has(g):
			continue
		for o in data.outer_slots_of(g):
			var os := str(o)
			if not parent.has(os):
				continue
			var ra := _gate_root(parent, g)
			var rb := _gate_root(parent, os)
			if ra != rb:
				parent[ra] = rb

	var order := []
	var members := {}
	for slot in slots:
		var s := str(slot)
		var key := _gate_root(parent, s)
		if not members.has(key):
			members[key] = []
			order.append(key)
		members[key].append(s)

	var out := []
	for key in order:
		var group_slots: Array = members[key]
		var out_opts := _group_options(group_slots)
		var worst_e := 0
		for o in out_opts:
			worst_e = maxi(worst_e, int(o["exposure"]))
		out.append({"slots": group_slots, "opts": out_opts, "worst_e": worst_e})
	return out

# 一个组里所有可选项的组合（笛卡尔积）。
#   ★ 第二十三轮：被强制占用的槽位不再「只有一件」——
#     「固定一件」的组锁死那一件；「几件选一件」的组只放开组内那几件。
func _group_options(group_slots: Array) -> Array:
	# ★ 第三十六轮：多件槽位自成一组，选项是「0 ~ 上限件的各种组合」——
	#   不能走下面那套「每槽位选一件」的笛卡尔积。
	if group_slots.size() == 1 and data.is_multi_slot(str(group_slots[0])):
		return _multi_group_options(str(group_slots[0]))
	var lists := []
	for slot in group_slots:
		var s := str(slot)
		var allowed: Variant = forced_allowed_ids(s)
		if allowed != null:
			var list := []
			for id in (allowed as Array):
				var it: Dictionary = data.get_item(str(id))
				if not it.is_empty() and can_equip(it):
					list.append(it)
			if list.is_empty():
				# 组内的都没到接受度 → 退回当前那一件，保证这一组还有解
				var cur := item_at(s)
				if not cur.is_empty():
					list.append(cur)
				elif not allowed.is_empty():
					var it2: Dictionary = data.get_item(str((allowed as Array)[0]))
					if not it2.is_empty():
						list.append(it2)
			lists.append(list)
			continue
		var list2 := []
		for it in data.get_items_for_slot(s):
			if can_equip(it):
				list2.append(it)
		if list2.is_empty():
			# 一个都穿不起（理论上不会发生）→ 保留当前那一件，保证每个槽位都有解
			var cur2 := item_at(s)
			if not cur2.is_empty():
				list2.append(cur2)
		lists.append(list2)

	# ★ 第三十七轮：每个槽位先按「对 DP 而言等价的字段」去重（见 _dedupe_equivalent）
	for i in lists.size():
		lists[i] = _dedupe_equivalent(lists[i], str(group_slots[i]))

	var out := []
	# ★ 第三十七轮：整棵递归共用一份 `eq`（下去时改、回来时还原），
	#   不要再每个叶子 `equipped.duplicate()` 一次 —— 门控组的叶子有八千多个。
	var eq: Dictionary = equipped.duplicate()
	_walk_options(group_slots, lists, 0, {}, out, eq)
	return _prune_options(out)

# ------------------------------------------------------------
#  每槽位「等价项」去重（第三十七轮）
#
#  为什么要有这一步：
#    门控组（top / bra / bottom / dress / panties）的选项是**笛卡尔积**。
#    第三十七轮把 top 19→27、bra 5→9、bottom 18→23、panties 5→11、dress 3→11
#    之后，积从 8.6k 涨到 **62,469**；生成这些选项要调 6 万多次
#    `_counts_with` / `_score_of`，实测「一键达标」要 7~8 秒。
#    `_prune_options` 只能剪**最终结果**，剪不掉生成过程本身。
#
#  为什么能去重（① 完全等价）：
#    DP 从一个候选件身上只会读到这几件事 ——
#      · 暴露值（可见时计入）
#      · `tags`（折算缺陷掩码）
#      · `see` / `gate`（决定**别的槽位**露不露）
#      · 是不是空件 `bare`（决定互斥判定）
#      · 是不是 A 的原貌那一件（「已经不是原貌」那 1 分）
#    这六项全同的两件，对 DP 而言完全等价 —— 只留一件就够，
#    求出来的搭配数值一模一样。
#    （反差值只跟 `exposure` 有关，已含在键里；槽位是同一个，所以
#      「是不是 CONTRAST_SLOTS」这一项不必进键。）
#
#  为什么还能再剪（② 帕累托支配）：
#    ① 只吃掉「一模一样」的，剩下的仍然要参与笛卡尔积。实测 ① 之后
#    top / bra / bottom / dress / panties 的积还有四万多，生成一遍仍要几百毫秒。
#    但「对其他槽位的影响」一致（`gate` / `see` / `bare` 相同）的两件里，
#    如果一件**暴露更低、遮缺陷更全、反差更高、更不像原貌**全都占优，
#    那另一件永远不可能出现在最优解里 —— 直接丢掉。
#    这里不取近似：只要有一项严格更差才允许丢，且必须在同一 `beh` 组内比。
#
#  ★ 被强制占用的槽位不会出错：`_group_options` 已经先把候选缩到
#    `forced_allowed_ids()` 里那几件，所以留下来的任何一件都是合规的。
# ------------------------------------------------------------
func _dedupe_equivalent(items: Array, slot: String) -> Array:
	if items.size() <= 1:
		return items
	var true_id := str(true_appearance.get(slot, ""))
	# ---- ① 完全等价去重 ----
	# 键一律用**归一化后**的字段（`_defect_mask_of` 而不是 `tags` 原文、
	# `outer_slots_of_item` 而不是 `gate` 原文）—— 否则「tags 顺序不同」
	# 或「gate 显式写 vs 回落」这种写法差异会漏过 ①，
	# 进到 ② 里又因为语义确实相同而互相判定为被支配，**两边都被删掉**，
	# 整个槽位的候选列表清空 → 那一组无解 → 一键达标返回「什么都不改」。
	var seen := {}
	var out := []
	for it in items:
		var d: Dictionary = it
		var key := "%d|%d|%s|%s|%d|%d" % [
			int(d.get("exposure", 0)),
			_defect_mask_of(d),
			data.see_through_kind(d),
			str(data.outer_slots_of_item(d)),
			int(1 if data.is_bare(d) else 0),
			int(1 if str(d.get("id", "")) == true_id else 0),
		]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(d)
	if out.size() <= 1:
		return out

	# ---- ② 帕累托剪枝（同槽位内，行为一致的那一组里比） ----
	var prof := []
	for d in out:
		var it: Dictionary = d
		var iid := str(it.get("id", ""))
		prof.append({
			"it": it,
			"exp": int(it.get("exposure", 0)),        # 越低越好
			"mask": _defect_mask_of(it),              # 位越多越好
			"con": _contrast_of(slot, iid),           # 反差越高越好
			"own": 0 if iid == true_id else 1,        # 1 = 已经不是原貌，更好
			"beh": "%s|%s|%d" % [                     # 对其他槽位的影响
				str(data.outer_slots_of_item(it)),
				data.see_through_kind(it),
				1 if data.is_bare(it) else 0,
			],
		})
	var keep := []
	for i in prof.size():
		var a: Dictionary = prof[i]
		var dominated := false
		for j in prof.size():
			if i == j:
				continue
			var b: Dictionary = prof[j]
			if str(b["beh"]) != str(a["beh"]):
				continue
			if int(b["exp"]) > int(a["exp"]) \
					or (int(b["mask"]) | int(a["mask"])) != int(b["mask"]) \
					or int(b["con"]) < int(a["con"]) \
					or int(b["own"]) < int(a["own"]):
				continue                          # b 至少有一项更差 → 不构成支配
			# 四项全同（理论上 ① 已经拦掉）→ 只让序号小的赢，绝不互删
			if int(b["exp"]) == int(a["exp"]) \
					and int(b["mask"]) == int(a["mask"]) \
					and int(b["con"]) == int(a["con"]) \
					and int(b["own"]) == int(a["own"]) \
					and j > i:
				continue
			dominated = true
			break
		if not dominated:
			keep.append(a["it"])
	return keep

# ------------------------------------------------------------
#  选项剪枝（第三十七轮）
#
#  为什么要有这一步：
#    `_group_options` 对「门控组」（top / bra / bottom / dress / panties）
#    算的是**笛卡尔积**。第三十七轮补了 35 件衣物之后，这个积从 8.6k 涨到
#    **62,469**，而 DP 的内层循环是「状态数 × 选项数」——
#    实测「一键达标」从 0.2 秒涨到 **7~8 秒**（62,469 选项 × 约 124 个状态）。
#    这不是理论担忧，是探针量出来的（`tools/PerfProbe.tscn`，用完已删）。
#
#  为什么能剪：
#    DP 只从每个选项里读三个数 —— **暴露值 / 缺陷掩码 / 得分**。
#    · 两个选项若 (暴露值, 掩码) 完全相同，DP 只会用得分高的那一个；
#    · 若 A 的 暴露值 ≤ B、掩码 ⊇ B、得分 ≥ B（且至少一项更优），
#      那么任何「用 B」的解换成 A 之后暴露更低、遮得更全、得分更高 ——
#      B 永远不可能出现在最优解里。
#    所以只留**帕累托前沿**，DP 的解一模一样。
#
#  效果：62,469 → 一百上下（去重后至多 (cap+1) × 掩码数），
#        DP 内层循环少三个数量级，「一键达标」回到毫秒级。
# ------------------------------------------------------------
func _prune_options(opts: Array) -> Array:
	# ① 同 (暴露值, 掩码) 只留得分最高的那一个
	var best := {}
	for o in opts:
		var k := int(o["exposure"]) * 100000 + int(o["mask"])
		var cur: Variant = best.get(k)
		if cur == null or int(o["score"]) > int((cur as Dictionary)["score"]):
			best[k] = o
	var uniq: Array = best.values()
	if uniq.size() <= 1:
		return uniq
	# ② 帕累托剪枝：被支配的选项直接丢掉
	var keep: Array = []
	for i in uniq.size():
		var a: Dictionary = uniq[i]
		var dominated := false
		for j in uniq.size():
			if i == j:
				continue
			var b: Dictionary = uniq[j]
			if int(b["exposure"]) <= int(a["exposure"]) \
					and (int(b["mask"]) | int(a["mask"])) == int(b["mask"]) \
					and int(b["score"]) >= int(a["score"]):
				# ① 已经去过重，所以这里 b 与 a 至少有一项真的更优
				dominated = true
				break
		if not dominated:
			keep.append(a)
	return keep

func _walk_options(group_slots: Array, lists: Array, i: int,
		acc: Dictionary, out: Array, eq: Dictionary) -> void:
	if i >= group_slots.size():
		out.append(_option_of(group_slots, acc, eq))
		return
	var slot := str(group_slots[i])
	for it in lists[i]:
		# ★ 第二十七轮：互斥剪枝 —— 成装与上装 / 下装三者只能有一个非空件。
		#   同一组里已经放了一件实体衣物，这一件又是实体 → 这个组合直接不成立，
		#   剪掉。不剪的话 DP 会算出「成装 + 长裤」这种搭配，选中之后
		#   `_apply_exclusive` 一执行就与 DP 的账对不上了。
		if _exclusive_conflict(acc, slot, it):
			continue
		var nxt := acc.duplicate()
		nxt[slot] = it
		# eq 只在「往下走」这段时间里带这一件，回来时还原
		var prev: Variant = eq.get(slot, null)
		eq[slot] = str((it as Dictionary).get("id", ""))
		_walk_options(group_slots, lists, i + 1, nxt, out, eq)
		eq[slot] = prev

# ------------------------------------------------------------
#  多件槽位（纹身）的 DP 选项
#
#  选项 = 「从这一槽位里挑 0 ~ 上限件」的所有组合（含空组合）。
#  每件的暴露值按**保守口径**计入（当作它露在外面）——
#  真实判定只会更小（外衣盖住 → 0），所以 DP 解在真实判定下一定不超上限。
#  反差值照旧走 _score_of：纹身不在 CONTRAST_SLOTS 里，所以恒为 0，
#  DP 只会为了「已经不是原貌」那 1 分去挑纹身，绝不会白吃暴露值。
# ------------------------------------------------------------
func _multi_group_options(slot: String) -> Array:
	var cands := []
	for it in data.get_items_for_slot(slot):
		if not data.is_bare(it) and can_equip(it):
			cands.append(it)
	# 被强制占用时只放开允许的那几件
	var allowed: Variant = forced_allowed_ids(slot)
	if allowed != null:
		var keep := []
		for it in cands:
			if (allowed as Array).has(str((it as Dictionary)["id"])):
				keep.append(it)
		cands = keep

	var bare_id: String = data.bare_id_of(slot)
	var cap: int = data.max_equip(slot)
	# 子集枚举：subsets 里的每一项是「已选物品的数组」
	var subsets := [[]]
	for it in cands:
		var add := []
		for sub in subsets:
			var arr: Array = sub
			if arr.size() < cap:
				var ns: Array = arr.duplicate()
				ns.append(it)
				add.append(ns)
		subsets.append_array(add)

	var out := []
	for sub in subsets:
		var ids := []
		for it in (sub as Array):
			ids.append(str((it as Dictionary)["id"]))
		if ids.is_empty() and bare_id != "":
			ids = [bare_id]                    # 「一件不穿」= 那一槽位的空件
		out.append(_multi_option_of(slot, ids, sub))
	return out

func _multi_option_of(slot: String, ids: Array, items: Array) -> Dictionary:
	var eq: Dictionary = equipped.duplicate()
	eq[slot] = ids
	# ★ 第三十七轮：可见性对这一个组合里的每一件都是同一个值，算一次就够
	var counts := _counts_with(eq, slot)
	var exp := 0
	var score := 0
	var mask := 0
	for x in items:
		var it: Dictionary = x
		mask |= _defect_mask_of(it)
		exp += int(it.get("exposure", 0))      # ★ 保守口径：按「露着」计
		score += _score_of_known(slot, it, counts)
	var pick := {}
	pick[slot] = ids
	return {"pick": pick, "exposure": exp, "score": score, "mask": mask}

# 把这一件放进这一槽位，会不会跟已经选好的同组槽位撞车
func _exclusive_conflict(acc: Dictionary, slot: String, it: Dictionary) -> bool:
	if data.exclusive_peers(slot).is_empty():
		return false
	if data.is_bare(it):
		return false                      # 空件不占位，永远不冲突
	for p in data.exclusive_peers(slot):
		var ps := str(p)
		if not acc.has(ps):
			continue
		var other: Dictionary = acc[ps]
		if other.is_empty() or data.is_bare(other):
			continue
		return true                       # 组里已经有非空件了
	return false

# 把一组「选好的物品」折算成 DP 要的四个数：
# 暴露值（◎ 已按门控算过）/ 得分 / 缺陷掩码 / 实际选了哪些 id
#   ★ 第三十七轮：`eq` 由调用方（`_walk_options`）在递归里维护，这里只读；
#     而且 `_counts_with` 只问一次、结果同时喂给暴露值与得分 ——
#     门控组的叶子有八千多个，每个叶子少一半的 `_counts_with` 调用。
func _option_of(group_slots: Array, picks: Dictionary, eq: Dictionary) -> Dictionary:
	var idmap := {}
	for slot in group_slots:
		var s := str(slot)
		idmap[s] = str((picks[s] as Dictionary).get("id", ""))

	var exp := 0
	var score := 0
	var mask := 0
	for slot in group_slots:
		var s := str(slot)
		var it: Dictionary = picks[s]
		mask |= _defect_mask_of(it)
		var counts := _counts_with(eq, s)
		if counts:
			exp += int(it.get("exposure", 0))
		score += _score_of_known(s, it, counts)
	return {"pick": idmap, "exposure": exp, "score": score, "mask": mask}

# 与 `_score_of` 同一口径，但可见性由调用方算好传进来（少一次 `_counts_with`）
func _score_of_known(slot: String, it: Dictionary, counts: bool) -> int:
	var con := 0
	if counts:
		con = _contrast_in_slot(slot, it)
	var s: int = con * 256
	if str(it.get("id", "")) != str(true_appearance.get(slot, "")):
		s += 1
	return s

func _auto_report(touched: Array) -> Dictionary:
	var uncovered := exposed_defects()
	var missing := missing_forced()
	var rep := {
		"changed": touched,
		"contrast": total_contrast(),
		"contrast_req": contrast_requirement(),
		"exposure": total_exposure(),
		"exposure_cap": exposure_cap(),
		"uncovered": uncovered,
		"missing_forced": missing,
		"matching": matching_slots().size(),
	}
	rep["ok"] = uncovered.is_empty() and not is_over_cap() \
		and is_contrast_sufficient() and missing.is_empty()
	return rep

# 一件衣物能遮住哪些缺陷（位掩码，下标与 data.defects() 一一对应）
func _defect_mask_of(it: Dictionary) -> int:
	var m := 0
	var tags: Array = it.get("tags", [])
	var defects: Array = data.defects()
	for di in defects.size():
		var need: Array = (defects[di] as Dictionary).get("cover_tags", [])
		for tag in need:
			if tags.has(tag):
				m |= 1 << di
				break
	return m

# 某槽位换上这件衣物能贡献多少反差 —— 口径与 total_contrast() 一致：
# 与 A 的原貌相同的那一件贡献 0（穿成他记忆里的样子 = 没有反差）。
# ★ 第三十一轮：口径换成 `_contrast_of` —— DP / 贪心 / 界面三处必须同口径，
#   否则一键达标求出来的解和右侧量表显示的反差对不上。
func _contrast_in_slot(slot: String, it: Dictionary) -> int:
	return _contrast_of(slot, str(it.get("id", "")))

# DP 里用的每槽位得分：高 8 位放反差，最低位放「已经不是原貌」的加分。
# 这样求解会**先**把反差顶到最高，再在同分下尽量少留「与原貌一致」的槽位 ——
# 否则一键达标可能留下一两个没改的部位，看着像没生效。
#
# ★ 第二十二轮：受门控的内衣内裤露不出来时**反差记 0**（它拉不开差距），
#   但「已经不是原貌」那 1 分照给 —— `matching_slots()` 的数法没变，
#   两项必须同口径，否则「同反差下也不该有可改的部位」这条不变量会破。
func _score_of(slot: String, it: Dictionary, eq: Dictionary) -> int:
	var con := 0
	if _counts_with(eq, slot):
		con = _contrast_in_slot(slot, it)
	var s: int = con * 256
	if str(it.get("id", "")) != str(true_appearance.get(slot, "")):
		s += 1
	return s

# 当前装备下某槽位的得分（外部只读用途）
func score_in_slot(slot: String, it: Dictionary) -> int:
	return _score_of(slot, it, equipped)

func _bit_count(m: int) -> int:
	var n := 0
	while m > 0:
		n += m & 1
		m >>= 1
	return n

# ---------- 轮次推进 ----------
func clear_level() -> void:
	cleared_levels += 1
	acceptance += int(level_info().get("acceptance_gain", 0))
	if level_index < levels.size() - 1:
		level_index += 1
	changed.emit()
