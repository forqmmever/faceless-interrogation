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
		# ★ 第四十一轮：每套背景的「本局流程配置」覆写（关卡轮数 / 强制穿着 /
		#   QTE 计划 / 身体缺陷 / 原貌）单独保留为独立键 ——
		#   不写就是空，运行时回退到全局那份。
		var ov := ScenarioData.BG_OVERRIDES_EXPORT(b)
		copy["levels"] = ov["levels"]
		copy["forced_rules"] = ov["forced_rules"]
		copy["qte_plan"] = ov["qte_plan"]
		copy["defects"] = ov["defects"]
		copy["true_presets"] = ov["true_presets"]
		bgs.append(copy)

	var out := {
		"$schema": "faceless-story-v1",
		# ★ 第七十一轮：原来这里写「手机界面与短信另见 tools/phone_editor.html」——
		#   那个文件第 55 轮就并进 story_editor.html 了（左侧「📱 手机」组），改掉免得误导。
		"note": "本文件由 tools/DumpStory.gd 生成，可用 tools/story_editor.html 编辑：剧情（背景 / 题库 / 短信 / 文案 / 结局）、手机界面（备忘录 / 短信 / 相册 / 桌面）、玩法数值、服装数值、原貌，以及每局（按背景）的轮数 / 强制穿着 / QTE 计划 / 身体缺陷覆写。游戏启动时从这里读；文件缺失会回退到 ScenarioData.gd / OutfitData.gd 里的内置常量。",
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
		# ★ 第四十轮新增的两段（都在 story_editor 里可改）：
		#   item_overrides —— 服装数值覆写：{物品 id: {exposure, acceptance_req}}
		#                     只写「改过的那几件」，没写的用代码内置值。
		#   true_presets   —— 原貌预设：{pool: [整套...], by_level: [每关一套...]}
		#                     pool 非空 = 开局从这些整套里随机抽一套（而不是逐槽位乱抽）；
		#                     by_level[i] 非空 = 第 i 关强制换成这一套。
		#                     两处都空 = 完全走原来的随机逻辑（默认就是这个）。
		"item_overrides": ScenarioData.ITEM_OVERRIDES_EXPORT(),
		"true_presets": ScenarioData.TRUE_PRESETS_EXPORT(),
		# catalog 是**只读目录**（全部衣物 / 标签 / 槽位 / 原貌池），
		# 给编辑器做下拉与勾选用 —— 游戏本身不读它。
		# ★ 第四十轮起里面多带两样供编辑器用：
		#   true_pool —— 每槽位的原貌候选（编辑器做「符合原貌」提示与一键套用）
		#   base_values —— 每件的**代码内置**数值（编辑器要显示「改了什么」）
		"catalog": ScenarioData.CATALOG_EXPORT(),
		"backgrounds": bgs,
		"traits": ScenarioData.INTERROGATOR_TRAITS,
		# ★ 第九十二轮：item_desc / clue_frame / clue_sources / photo_notes 四段
		#   随「外貌情报」一起删掉，不再导出。
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

	print("已导出 %s：%d 套背景 / %d 种性情 / %d 项数值 / %d 段界面文案" % [
		OUT_PATH, bgs.size(),
		(out["traits"] as Array).size(),
		(out["rules"] as Dictionary).size(),
		(out["ui"] as Dictionary).size(),
	])
	get_tree().quit(0)
