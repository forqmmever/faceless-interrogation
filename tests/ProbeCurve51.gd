extends Node

# ============================================================
#  第五十一轮：复核反差曲线 —— 用**真实求解器**量余量
#
#  ★ 为什么不用 WardrobeTest 里那份 `_dp_optimum`：
#    它**没有缺陷掩码**（只按 4 位覆盖位算），会高估可达值。
#    第四十九轮实测过差距：`_dp_optimum` 报 175/265/250/250，
#    而真实 `auto_complete_outfit()`（DP + 缺陷掩码）只有 165/225/195/195。
#    标定曲线必须按真实求解器来 —— 这份探针走的就是 `auto_complete_outfit()`。
#
#  ★ 本轮为什么必须复核：
#    「去掉配饰一栏」把 `accessory` 整栏从**全槽位求和**里拿掉了
#    （槽位 14 → 12），还删了 4 件物品（含两件 9 档）。
#    第 49 轮标定的 125/140/155/165 是按「配饰栏还在」时量出来的。
#
#  临时探针，用完即删。
# ============================================================
const SEEDS := 150

func _ready() -> void:
	_run()
	get_tree().quit()

func _run() -> void:
	var reqs := []
	for li in OutfitData.MAX_LEVELS:
		reqs.append(int(OutfitData.LEVELS[li]["contrast_req"]))

	var worst := []          # 每轮最差的可达反差
	var best := []
	var worst_seed := []
	var vals := []           # 每轮全部数值（算中位数）
	var fails := []          # [seed, li, con, req, exp, cap, forced]
	for li in OutfitData.MAX_LEVELS:
		worst.append(999999)
		best.append(0)
		worst_seed.append(-1)
		vals.append([])

	print("=== 第五十一轮曲线复核：真实求解器 × %d 种子 × %d 轮 ===" % [
		SEEDS, OutfitData.MAX_LEVELS])
	print("   起始接受度 %d ｜ 通过对比：槽位 %d 个（配饰已下架）" % [
		OutfitData.START_ACCEPTANCE, OutfitData.auto_slots().size()])

	for s in range(1, SEEDS + 1):
		# 跨局保留的接受度加成必须每局清一次（否则量的是「打了 N 局」的口径）
		ProfileData.reset_all()
		RunData.start_new_run(100000 + s)
		for li in OutfitData.MAX_LEVELS:
			var ta: Dictionary = RunData.true_appearance()
			var acc: int = RunData.acceptance_at(li)
			var cap: int = OutfitData.exposure_cap(acc)
			var m := WardrobeModel.new(OutfitData, ta, OutfitData.LEVELS)
			m.reset_for_level(acc, li, ta,
				RunData.forced_item_ids(), RunData.forced_groups_info())
			m.auto_complete_outfit()
			var con: int = m.total_contrast()
			var exp: int = m.total_exposure()
			vals[li].append(con)
			if con < reqs[li] and fails.size() < 8:
				fails.append([s, li + 1, con, reqs[li], exp, cap, RunData.forced_item_ids()])
			if con < worst[li]:
				worst[li] = con
				worst_seed[li] = s
			if con > best[li]:
				best[li] = con
			if li < OutfitData.MAX_LEVELS - 1:
				RunData.advance_level()
		if s % 25 == 0:
			print("   …已跑 %d / %d 个种子" % [s, SEEDS])

	print("")
	print("%-4s %-4s %-5s %-6s %-16s %-7s %-8s %s" % [
		"轮", "acc", "cap", "要求", "可达 min~max", "中位", "最差余量", "达不到的种子数"])
	var fail_by_level := {}
	for f in fails:
		var k := int(f[1])
		fail_by_level[k] = int(fail_by_level.get(k, 0)) + 1
	# 全量统计（fails 只留了前 8 条，这里重跑一遍计数：靠 vals 比要求）
	for li in OutfitData.MAX_LEVELS:
		var n_fail := 0
		for v in vals[li]:
			if int(v) < reqs[li]:
				n_fail += 1
		var arr: Array = vals[li].duplicate()
		arr.sort()
		var med: int = int(arr[arr.size() / 2])
		print("%-4d %-4d %-5d %-6d %-16s %-7d %-8s %d / %d" % [
			li + 1, RunData.acceptance_at(li), OutfitData.exposure_cap(RunData.acceptance_at(li)),
			reqs[li], "%d ~ %d" % [worst[li], best[li]], med,
			"%+d" % (worst[li] - reqs[li]), n_fail, SEEDS])

	print("")
	if fails.is_empty():
		print("★ 结论：%d 个种子 × %d 轮全部达标，最差余量 %s" % [
			SEEDS, OutfitData.MAX_LEVELS,
			str(Array(worst).map(func(w): return "%+d" % (int(w) - 0)))])
	else:
		print("★ 达不到要求的样本（最多列 8 条）：")
		for f in fails:
			print("   seed=%d 第%d轮 反差=%d < 要求=%d ｜ 暴露=%d/%d ｜ 强制=%s" % [
				f[0], f[1], f[2], f[3], f[4], f[5], str(f[6])])
	print("")
	print("逐轮最差样本的种子号（标定时要看它为什么低）：")
	for li in OutfitData.MAX_LEVELS:
		print("   第%d轮 最差 %d ← seed=%d" % [li + 1, worst[li], worst_seed[li]])
