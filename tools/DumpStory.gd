extends Node

# ============================================================
#  把 ScenarioData 里的全部「文本数据」导出成 data/story.json
#
#  为什么要有这个脚本：
#    游戏跑起来时是从 data/story.json 读文本的（见 ScenarioData._load_story）。
#    但 story.json 本身得有个权威来源 —— 就是这份脚本。
#    以后如果你在 GDScript 里手改了常量、想同步回 JSON，跑一次它就行：
#
#      godot --headless --path <项目> res://tools/DumpStory.tscn
#
#  它导出的是 ScenarioData 的**当前值**（即 JSON 若存在则导出 JSON 的内容，
#  相当于「规范化 / 格式化」一遍）。
# ============================================================

const OUT_PATH := "res://data/story.json"

func _ready() -> void:
	# ★ 结局文案是**每套背景一份**（用户口径），但 GDScript 里只有一份出厂模板
	#   （DEFAULT_ENDINGS）。导出时给每套背景补上 "endings" —— 于是编辑器
	#   打开就能看到四份、各自独立地改。
	var bgs: Array = []
	for b in ScenarioData.BACKGROUNDS:
		var copy: Dictionary = (b as Dictionary).duplicate(true)
		copy["endings"] = ScenarioData.endings_of(b)
		bgs.append(copy)

	var out := {
		"$schema": "faceless-story-v1",
		"note": "本文件由 tools/DumpStory.gd 生成，可用 tools/story_editor.html（剧情 / 数值 / 文案 / 结局 / 关卡 / 强制穿着 / QTE 计划 / 缺陷）或 tools/phone_editor.html（手机界面 + 短信）编辑。游戏启动时从这里读；文件缺失会回退到 ScenarioData.gd / OutfitData.gd 里的内置常量。",
		"rules": ScenarioData.RULES,
		"ui": ScenarioData.UI,
		# ★ 第二十三轮新增的四段（都在编辑器里可改）：
		#   levels       —— 一局几关 + 每关数值（增删关卡就改这里）
		#   forced_rules —— 每关的强制服装规则（固定一件 / 几件选一件的自由组合）
		#   qte_plan     —— 每道题用哪种 QTE、几秒后出现
		#   defects      —— 身体缺陷与它的遮挡标签
		"levels": ScenarioData.LEVELS_EXPORT(),
		"forced_rules": ScenarioData.FORCED_RULES_EXPORT(),
		"qte_plan": ScenarioData.QTE_PLAN_EXPORT(),
		"defects": ScenarioData.DEFECTS_EXPORT(),
		# catalog 是**只读目录**（全部衣物 / 标签 / 槽位），
		# 给编辑器做下拉与勾选用 —— 游戏本身不读它。
		"catalog": ScenarioData.CATALOG_EXPORT(),
		"backgrounds": bgs,
		"traits": ScenarioData.INTERROGATOR_TRAITS,
		"item_desc": ScenarioData.ITEM_DESC,
		"clue_frame": ScenarioData.CLUE_FRAME,
		"clue_sources": ScenarioData.CLUE_SOURCES,
		"photo_notes": ScenarioData.PHOTO_NOTES,
		"phone": ScenarioData.PHONE,
	}

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("无法写入 %s（错误码 %d）" % [OUT_PATH, FileAccess.get_open_error()])
		get_tree().quit(1)
		return
	# sort_keys = false —— 保持 GDScript 里的书写顺序（id / name / venue …），
	# 否则 Godot 默认会按字母序重排，人读起来对不上源码。
	f.store_string(JSON.stringify(out, "\t", false))
	f.close()

	print("已导出 %s：%d 套背景 / %d 种性情 / %d 条衣物描述 / %d 项数值 / %d 段界面文案" % [
		OUT_PATH, bgs.size(),
		(out["traits"] as Array).size(),
		(out["item_desc"] as Dictionary).size(),
		(out["rules"] as Dictionary).size(),
		(out["ui"] as Dictionary).size(),
	])
	get_tree().quit(0)
