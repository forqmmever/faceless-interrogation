extends Node

# ============================================================
#  账号级存档（roguelite 元进度）
#
#  ★★ 第七十五轮（用户口径「暂时不使用接受度全局累计，改为每轮可用的暴露值不同」）：
#    这个文件的定位**降级**了 —— 从「影响玩法的元进度」变成「战绩账本」。
#      · `total_gain` 还在记（每过一轮加一笔），但它**不再回流到 `RunData.acceptance`**；
#        接受度现在按轮手写在 `story.json` 的 `levels[i].acceptance` 里。
#      · 换台机器、重开游戏、玩过多少局，第 1 轮的暴露上限都是同一个数。
#      · `bonus()` 保留是给**老存档 / 外部调用**兜底的，玩法里已经没人读它了。
#    真正的元进度只剩战绩（打过几局 / 通关几局 / 重来几次 / 单局最好）。
#
#  （下面这段是第七十五轮之前的口径，保留作历史：）
#    「每轮游戏获得的、用于解锁服装的数值，全局保留。」
#  也就是：接受度不再是每局清零的一次性资源，而是**跨局累积**的账号进度。
#  任何一关通过，那一关的 acceptance_gain 立刻存进这里；就算这一轮砸了、
#  回到本轮开始重来，甚至后面整局走不完，已经到手的部分也不会丢。
#
#  为什么必须落盘：
#    不存档的话「全局保留」只在这一个进程里成立，关掉游戏就没了 ——
#    而元进度的全部意义就在于「下次打开还在」。
#
#  存哪：user://profile.json
#    Windows 下实际是 %APPDATA%\Godot\app_userdata\<项目名>\profile.json
#
#  测试注意：
#    测试会读 user:// 里那份真实存档，导致断言随「玩家玩过几局」而变。
#    所以测试开头一律：
#        ProfileData.autosave_enabled = false
#        ProfileData.reset_all()
#    跑完再把 autosave_enabled 恢复（同一个进程里后面的用例还要用）。
# ============================================================

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 1

# ---------- 存档内容 ----------
var total_gain: int = 0        # 累计接受度加成 —— 「全局保留」的就是这个
var runs_played: int = 0       # 一共开过几局
var runs_cleared: int = 0      # 一共通关几局
var best_cleared: int = 0      # 单局最高通过关数（0 ~ 4）
var level_failures: int = 0    # 累计「本轮重来」次数（第二十一轮）

# ---------- 运行时开关 ----------
var autosave_enabled: bool = true    # 测试会关掉，避免污染真实存档
var loaded: bool = false

func _ready() -> void:
	load_profile()

# ============================================================
#  读写
# ============================================================
func load_profile() -> void:
	loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("profile.json 打不开，按新档处理")
		return
	var txt := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("profile.json 解析失败，按新档处理")
		return

	var d: Dictionary = parsed
	total_gain = maxi(0, int(d.get("total_gain", 0)))
	runs_played = maxi(0, int(d.get("runs_played", 0)))
	runs_cleared = maxi(0, int(d.get("runs_cleared", 0)))
	best_cleared = maxi(0, int(d.get("best_cleared", 0)))
	level_failures = maxi(0, int(d.get("level_failures", 0)))

func save_profile() -> void:
	if not autosave_enabled:
		return
	var d := {
		"version": SAVE_VERSION,
		"total_gain": total_gain,
		"runs_played": runs_played,
		"runs_cleared": runs_cleared,
		"best_cleared": best_cleared,
		"level_failures": level_failures,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("profile.json 写不进去（user:// 不可写？）")
		return
	f.store_string(JSON.stringify(d, "\t", false))
	f.close()

# ============================================================
#  写入接口
# ============================================================
# 一关通过 → 把那一关的接受度加成存进账号
func add_gain(n: int) -> void:
	if n <= 0:
		return
	total_gain += n
	save_profile()

# 一局结束（通关）→ 记一笔战绩
# ★ 第二十一轮起，失败**不算一局结束** —— 它只作废本轮，玩家会回到本轮准备室重来，
#   同一局还可能最终通关。所以失败走 note_level_failed()，不写进 runs_played，
#   否则「打过 N 局」会被同一次失败重复计数。
func note_run_finished(cleared: int, won: bool) -> void:
	runs_played += 1
	if won:
		runs_cleared += 1
	best_cleared = maxi(best_cleared, cleared)
	save_profile()

# 本轮失败 → 回准备室重来。只记一个「重来次数」，接受度一分不退。
func note_level_failed() -> void:
	level_failures += 1
	save_profile()

# 清档（测试用；游戏里也可以挂一个「重置进度」按钮）
func reset_all() -> void:
	total_gain = 0
	runs_played = 0
	runs_cleared = 0
	best_cleared = 0
	level_failures = 0
	save_profile()

# ============================================================
#  查询
# ============================================================
# 本局开局时「跨局带过来的」接受度加成
#  ★ 第七十五轮起**玩法里不再读它** —— 接受度改成逐轮手写（levels[i].acceptance）。
#    留着是为了老存档与外部调用的兼容，别在新代码里拿它算数值。
func bonus() -> int:
	return total_gain

# 有没有存过档（给 UI 判断要不要显示「继续上次进度」）
func has_progress() -> bool:
	return total_gain > 0 or runs_played > 0

func summary() -> String:
	return "累计接受度 +%d ｜ 通关 %d 局 ｜ 本轮重来 %d 次 ｜ 单局最好 %d/%d 关" % [
		total_gain, runs_cleared, level_failures, best_cleared, OutfitData.level_count()]
