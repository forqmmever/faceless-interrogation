# -*- coding: utf-8 -*-
"""
本作全部衣物 → AUfemale 美术资源的映射表。

用户口径：
  · 「参考 E:\\DOWNLOAD\\Degrees of Lewdity 下的换装系统的样式，将本游戏的系统替换那样的」
  · 「小人形象和服装也要改成一样」
  · 遇到「我们的某件衣服在 DoL 里没有对应款式」→ 挑最接近的款式
  · ★★ 第三十七轮：「现在和之后只使用 au 源的服装」——
    **所有服装一律取 AUfemale 图包**（E:/DOWNLOAD/AUfemale.imgpack_v0.9.3），
    不再从 DoL 官方图包里取衣物。DoL 那套图包（assets/dol + data/doll.json）
    整条链路已停掉，只剩 AU 一套。

每条映射的含义：
  our_id: [层1, 层2, ...]
  每一层 = dict(
    src   = ("clothes", "upper", "blouse")  # clothes/upper/blouse/<file>.png
            或 ("clothes", "upper", "blouse", "acc-full.png")   # 显式指定文件
            或 ("hair", "sides", "classic", "short")            # hair/sides/classic/short.png
            或 ("face", "default", "default", "eyes")           # face/default/default/eyes.png
    tint  = (r, g, b)      # None = 保持原图颜色（身体/头发已经是彩色）
    align = ("bbox_center", 60.0, 30.0)   # 把这张图的不透明部分中心挪到该点（DoL 的 128×128 坐标）
             None                          # 原样
    scale = 1.0            # 额外缩放
  )

★ align 坐标仍然按 **DoL 的 128×128 坐标系**写（头心 58,30），
  由 dol_prepare.transform() 换算到 AU 的 512×256 画布上。
  AU 的 128×128 帧里，人物大约是：头 y 19..41、身体 y 42..92，左右 x 47..69。

★ 文末的 AU_OVERRIDE 是「借用头部小件」那一小撮（耳饰 / 穿环 / 刺青）的专用参数
  —— DoL 没有这些槽位，只能挪用头部小件再把它的不透明中心搬到位。
"""

# ---------------- 基础层（小人本体）----------------
# 顺序 = 绘制顺序，数值是抄 DoL 的 ZIndices
BASE_LAYERS = [
    # DoL: basehead 5 → base 20 → 手臂 30/31.5 → 眼睛 30..35 → 嘴 40 → 头发 60 → 刘海 132 → 耳 132.5 → 眉 138
    {"name": "head",     "src": ("body", "base-head"),              "tint": None, "z": 5},
    {"name": "body",     "src": ("body", "base-classic"),           "tint": None, "z": 20},
    {"name": "leftarm",  "src": ("body", "left-arm-idle-classic"),  "tint": None, "z": 30},
    {"name": "rightarm", "src": ("body", "right-arm-idle-classic"), "tint": None, "z": 30.2},
    {"name": "eyes",     "src": ("face", "default", "default", "eyes"),    "tint": None, "z": 30.4},
    {"name": "sclera",   "src": ("face", "default", "default", "sclera"),  "tint": (0.99, 0.98, 0.97), "tint_mode": "mul", "z": 31},
    {"name": "iris",     "src": ("face", "default", "default", "iris"),    "tint": (0.30, 0.42, 0.36), "tint_mode": "mul", "z": 32},
    {"name": "eyelids",  "src": ("face", "default", "default", "eyelids"), "tint": None, "z": 34},
    {"name": "lashes",   "src": ("face", "default", "default", "lashes"),  "tint": (0.26, 0.19, 0.15), "tint_mode": "mul", "z": 35},
    {"name": "mouth",    "src": ("face", "default", "mouth-neutral"),      "tint": None, "z": 40},
    {"name": "ears",     "src": ("face", "default", "ears"),              "tint": None, "z": 132.5},
    {"name": "brow",     "src": ("face", "default", "default", "brow-mid"), "tint": (0.30, 0.22, 0.17), "tint_mode": "mul", "z": 138},
]

# 头发的三块（sides / fringe / back）由 hair 那四件决定，见 HAIR_STYLES
#
# ★★ 第三十七轮起只用 AU 一套（用户口径「只使用 au 源的服装」），
#    所以这里不再分图包 —— 只剩下面这一张 AU 表。
#
#    AU 自己重画的那批头发是**纯灰度蒙版**（实测饱和度 0.00），
#    必须在烘焙时乘上发色（tint），而且**只能用新几何 512×256 的款式**。
#
# ★★ AU 的坑：图包里同时留着 DoL 的旧款 —— 同名（`middlepart` / `twin braids`…）
#    但仍是 256×128、而且**还是 DoL 的红色**。所以这张表不能写成「候选列表」
#    （候选会先撞上旧款，一撞就中招），必须直接点名 AU 新几何的款式。

# AU 的发色：A 是同一个人，四款发型共用同一个发色（深棕）。
# gain 是给灰度蒙版的亮度增益 —— AU 的蒙版整体偏暗（实测亮度 38..207），
# 直接乘发色会发乌，先按 1.25 把灰度抬上来再乘。
HAIR_TINT_AU = (0.42, 0.30, 0.21)
HAIR_GAIN_AU = 1.25

# AU 的发型：款式全部点名「新几何 512×256 + 灰度蒙版」的那批
# （实测 sides 65 款里 51 款是新几何、fringe 60 款里约 34 款是新的；
#   点名时还避开了 `wavy braid` 这种「新几何但仍是 DoL 红」的漏网款）
HAIR_STYLES = {
    "hair_short": {"style": "neat",        "length": "short",
                   "fringe": "default",    "back": None,
                   "tint": HAIR_TINT_AU, "gain": HAIR_GAIN_AU},
    "hair_braid": {"style": "braid right", "length": "shoulder",
                   "fringe": "curtain",    "back": None,
                   "tint": HAIR_TINT_AU, "gain": HAIR_GAIN_AU},
    "hair_long":  {"style": "all down",    "length": "chest",
                   "fringe": "parted",     "back": "all down", "back_len": "thighs",
                   "tint": HAIR_TINT_AU, "gain": HAIR_GAIN_AU},
    "hair_up":    {"style": "messy bun",   "length": "navel",
                   "fringe": "parted",     "back": None,
                   "tint": HAIR_TINT_AU, "gain": HAIR_GAIN_AU},
}

# 我们每个槽位在小人身上的绘制层号（照 DoL 的 ZIndices 抄，robe 提到最外层）
SLOT_Z = {
    "hair":       60.0,
    "headgear":   149.0,
    "glasses":    145.0,
    "earrings":   146.0,
    "makeup":     45.0,
    "piercing":   139.0,
    "tattoo":     36.0,
    "neckwear":   103.0,
    "top":        95.0,
    # ★ 第二十六轮：整件式（连衣裙 / 晚礼服）单开一个槽位。
    #   z 只比 top 高 1 —— 它是**一整件**，上半截要盖住 top / bra，
    #   下半截要盖住 bottom / panties，所以只能整体压在它们之上。
    "dress":      96.0,
    "bra":        70.0,
    "gloves":     110.0,
    "accessory":  105.0,
    "bottom":     90.0,
    "panties":    67.0,
    "stockings":  66.6,
    "shoes":      85.0,
    "robe":       150.0,
    # ★ 第三十九轮：妙妙工具（挂在身后的那条尾巴）。
    #   z 取 92 —— 压在 `bottom`(90) 之上、`top`(95) 之下：尾巴从腰后翘出来，
    #   根部被下装压住、尾梢露在外面，这是最自然的一层。
    #   与 OutfitData.SLOT_ZORDER["tool"] = 196（WTS 参考值域里的同一位次）语义一致。
    "tool":       92.0,
}

# ---------------- 68 件衣物的映射 ----------------
# 色板走「旧世界的低饱和」：灰、褐、暗红、墨黑、米白、亚麻
IVORY = (0.86, 0.84, 0.78)
LINEN = (0.78, 0.74, 0.64)
GREY = (0.62, 0.63, 0.66)
DARKGREY = (0.34, 0.35, 0.39)
BLACK = (0.13, 0.13, 0.15)
NAVY = (0.20, 0.24, 0.36)
BROWN = (0.46, 0.34, 0.22)
DARKBROWN = (0.28, 0.20, 0.14)
LEATHER = (0.22, 0.18, 0.17)
WINE = (0.44, 0.15, 0.16)
GREEN = (0.28, 0.40, 0.30)
GOLD = (0.82, 0.68, 0.32)
SILVER = (0.76, 0.78, 0.82)

# 第二十四轮：两套校服的配色（藏青一套 / 墨绿一套，两套互相区别，
# 也都不等于现有 bottom_knee 那条褐色格子校裙）
NAVY = (0.24, 0.28, 0.42)          # 藏青（校裙）
NAVY_LIGHT = (0.34, 0.40, 0.56)     # 藏青（衬衫，比裙子亮一档）
NAVY_DARK = (0.16, 0.18, 0.26)      # 藏青（皮鞋，压暗）
GREEN_LIGHT = (0.38, 0.48, 0.42)    # 墨绿（衬衫）
GREEN_DARK = (0.26, 0.36, 0.30)     # 墨绿（校裙）
WHITE_SOCK = (0.93, 0.93, 0.91)     # 校服白袜
SAND = (0.84, 0.80, 0.70)           # 米色校服袜
SHOEBROWN = (0.40, 0.29, 0.19)      # 棕色校服皮鞋

# 第二十五轮：水手服 / 连衣裙 / 晚礼服 / 三套暴露装
WHITE = (0.95, 0.95, 0.93)          # 白色水手服（衬衫 + 裙同一色）
CREAM = (0.86, 0.84, 0.78)          # 连衣裙（米白）
PLUM = (0.34, 0.28, 0.34)           # 洛丽塔（暗紫灰）
DUSK = (0.22, 0.20, 0.25)           # 高开衩短裙（近黑）
ROSEWOOD = (0.50, 0.26, 0.30)       # 开胸上衣（暗玫红）

# 第二十六轮：刺青改用 AU 的 bodywriting 图案（不再借用头部小件）
INK = (0.18, 0.22, 0.28)            # 刺青墨色 —— 暗蓝黑，落在皮肤上像纹进去的

# 第二十八轮：从 AU 补的高暴露款
SHEER_NUDE = (0.90, 0.86, 0.84)     # 网纱透视上衣（近肤的薄纱色）
VINYL = (0.12, 0.12, 0.14)          # 漆皮迷你裙（近黑，带一点冷调）
QIPAO = (0.62, 0.16, 0.22)          # 开衩短旗袍（正红）
FISHNET = (0.16, 0.16, 0.18)        # 网眼超短裙
KNIT_ASH = (0.46, 0.46, 0.50)       # 紧身针织衫（灰）
KNIT_CREAM = (0.84, 0.81, 0.74)     # 高领军毛衣（米白）
SKIN_SILK = (0.86, 0.70, 0.66)      # 乳贴 / 微型比基尼（肤色绸）

# 第三十九轮：妙妙工具与平坦贞操笼
FUR_FOX = (0.66, 0.38, 0.19)        # 尼古喵尾（橙棕毛色 —— 源图是灰度蒙版，饱和度 0.00）
CHROME = (0.72, 0.75, 0.80)         # 平坦贞操笼（冷调金属，比 SILVER 稍暗一点）

# 第三十四轮：从 AU 补的 3 个妆容 + 3 个配饰
LIP_RED = (0.86, 0.12, 0.14)        # 烈焰红唇（正红；源图本身就是红的，乘一层压深）
BLUSH_PINK = (0.96, 0.56, 0.58)     # 绯色腮红（粉；源图 alpha 很低，乘完仍是薄薄一层）
FRECKLE_BROWN = (0.44, 0.30, 0.22)  # 点出来的雀斑（褐；源图近灰，乘一层上色）
PEWTER = (0.66, 0.68, 0.74)         # 银质心形吊坠（旧银，比 SILVER 压暗一档）

ITEMS = {
    # ---- 发型（由 HAIR_STYLES 处理，这里只占位）----
    "hair_short": [], "hair_braid": [], "hair_long": [], "hair_up": [],

    # ---- 头饰 ----
    "head_none": [],
    "head_hat":  [{"src": ("clothes", "head", "fedora"),            "tint": BROWN}],
    "head_hood": [{"src": ("clothes", "head", "hoodie"),            "tint": DARKGREY}],
    "head_veil": [{"src": ("clothes", "head", "roseveil"),          "tint": BLACK}],

    # ---- 眼镜 ----
    "glasses_none": [],
    "glasses_round":   [{"src": ("clothes", "face", "round"),       "tint": GOLD}],
    # ★ 第二十七轮换血：删掉「单片金链眼镜」（monocle）与「黑色墨镜」（coolshades），
    #   从 AU 图包补两副新框 —— cateye（猫眼）/ square（方框）。
    #   三副都是 512×256 的 AU 几何 + 纯灰度蒙版（实测最大彩度 0），所以直接染色即可，
    #   不需要 align / scale 覆盖。
    "glasses_cateye":  [{"src": ("clothes", "face", "cateye"),      "tint": WINE}],
    "glasses_square":  [{"src": ("clothes", "face", "square"),      "tint": DARKGREY}],

    # ---- 耳饰（DoL 没有耳饰槽 —— 用头部小件的**位置搬移**顶替）----
    "ear_none": [],
    "ear_stud":    [{"src": ("clothes", "head", "goldhairpin"), "tint": SILVER,
                     "align": ("bbox_center", 48.0, 31.0)}],
    "ear_hoop":    [{"src": ("clothes", "head", "bunny earmuffs"), "tint": SILVER,
                     "alt": {"src": ("clothes", "head", "goldhairpin"), "tint": SILVER,
                             "align": ("bbox_center", 48.0, 31.0)}}],
    "ear_diamond": [{"src": ("clothes", "head", "fishhairpin"), "tint": GOLD, "scale": 1.2,
                     "align": ("bbox_center", 66.0, 33.0)}],

    # ---- 妆容 ----
    "makeup_none": [],
    "makeup_light": [{"src": ("face", "default", "default", "makeup", "eyeshadow"), "tint": (0.55, 0.42, 0.48), "z": 55.0}],
    "makeup_heavy": [{"src": ("face", "default", "default", "makeup", "eyeshadow"), "tint": (0.34, 0.26, 0.38), "z": 55.0},
                     {"src": ("face", "default", "default", "makeup", "mascara"),   "tint": BLACK, "z": 55.4},
                     {"src": ("face", "default", "lipstick-neutral"), "tint": WINE, "z": 56.0}],
    # ★★ 第三十四轮：按用户口径「从 au 中添加几个妆容」补的 3 件。
    #   三件都取 AU 图包**真实的面部图层**（不是借用别的东西顶替）：
    #     · 源图在 AU 里是 face/default/default/<件>.png；
    #     · DoL 原版少一层，写作 face/default/<件>.png —— 所以每条都带 `alt` 兜底。
    #   ★ 三张图都**已经落在正确的解剖位置上**，所以一律不给 align（给了反而会搬歪）。
    "makeup_lip":      [{"src": ("face", "default", "default", "lipstick-neutral"), "tint": LIP_RED,
                         "alt": {"src": ("face", "default", "lipstick-neutral"), "tint": LIP_RED}}],
    "makeup_blush":    [{"src": ("face", "default", "default", "blusher"), "tint": BLUSH_PINK,
                         "alt": {"src": ("face", "default", "blusher"), "tint": BLUSH_PINK}}],
    "makeup_freckles": [{"src": ("face", "default", "default", "freckles"), "tint": FRECKLE_BROWN,
                         "alt": {"src": ("face", "default", "freckles"), "tint": FRECKLE_BROWN}}],

    # ---- 穿环（同样靠位置搬移顶替）----
    "piercing_none": [],
    "piercing_multi": [{"src": ("clothes", "head", "goldhairpin"), "tint": SILVER, "scale": 0.7,
                        "align": ("bbox_center", 48.0, 29.0)},
                       {"src": ("clothes", "head", "goldhairpin"), "tint": SILVER, "scale": 0.7,
                        "align": ("bbox_center", 66.0, 29.0)},
                       {"src": ("clothes", "head", "goldhairpin"), "tint": SILVER, "scale": 0.7,
                        "align": ("bbox_center", 48.0, 32.0)}],
    "piercing_lip":   [{"src": ("clothes", "head", "goldhairpin"), "tint": BLACK, "scale": 0.8,
                        "align": ("bbox_center", 58.0, 39.0)}],
    "piercing_nose":  [{"src": ("clothes", "head", "goldhairpin"), "tint": SILVER, "scale": 0.7,
                        "align": ("bbox_center", 58.0, 35.0)}],

    # ---- 刺青 ----
    # ★★ 第三十七轮起只剩 AU 一套图包，下面这些 src/align 已经**不再被使用** ——
    #   刺青的实际烘焙参数全在文末的 AU_OVERRIDE（AU 自己的 bodywriting 图案）。
    #   这一组留着只为**占位**：`ITEMS` 里有没有这个 key、列表里有几个元素，
    #   决定了这件物品会不会被烘、烘几层，所以不能整条删掉。
    #   （历史：第二十六轮之前 AU 还没有专属参数时，这里存的是「借用头部小件 +
    #    位置搬移」那套顶替方案。）
    "tattoo_none": [],
    "tattoo_neck":  [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.28),
                      "scale": 3.0, "align": ("bbox_center", 57.0, 45.0)}],
    "tattoo_cheek": [{"src": ("clothes", "head", "hairclip"), "tint": (0.24, 0.26, 0.34),
                      "scale": 2.6, "align": ("bbox_center", 63.0, 30.0)}],
    "tattoo_thigh": [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.24),
                      "scale": 2.8, "align": ("bbox_center", 49.0, 66.0)}],
    # 第三十五轮补的两件（同上：这里只是占位，参数见 AU_OVERRIDE）
    "tattoo_heart": [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.26),
                      "scale": 3.2, "align": ("bbox_center", 49.0, 66.0)}],
    "tattoo_paw":   [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.26),
                      "scale": 2.6, "align": ("bbox_center", 51.0, 62.0)}],
    # ★ 第三十六轮补的四件刻字（bitch / free-use / slave / cum-rag）。
    #   可读的整字图案同样取自 AU 的 bodywriting，见下方 AU_OVERRIDE。
    "tattoo_bitch":   [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.26),
                        "scale": 3.0, "align": ("bbox_center", 49.0, 66.0)}],
    "tattoo_freeuse": [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.26),
                        "scale": 3.0, "align": ("bbox_center", 67.0, 66.0)}],
    "tattoo_slave":   [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.26),
                        "scale": 3.0, "align": ("bbox_center", 58.0, 52.0)}],
    "tattoo_cumrag":  [{"src": ("clothes", "head", "hairclip"), "tint": (0.22, 0.30, 0.26),
                        "scale": 3.0, "align": ("bbox_center", 58.0, 70.0)}],

    # ---- 颈饰 ----
    # ★ 第二十六轮核查结论：这三件的源图本来就是 AU 图包自己的 clothes/neck/*，
    #   没有一件退回 DoL —— `gothic choker` / `woolscarf` 在 AU 里没有同名款，
    #   由 `alt` 顶到 AU 的 `clothchoker` / `scarf`（**都是 AU 的图**）。
    #   本轮再按用户口径「增加几款项圈」补 5 件，同样全部取 AU 真实贴图。
    #   AU 全身像那一列的人物只有 40×145 px，脖子上的东西天然就小，
    #   括号里是它在 68 px 宽取景框里的实际像素尺寸，挑款时按它排的序。
    "neck_none": [],
    "neck_collar": [{"src": ("clothes", "neck", "collar"),          "tint": (0.42, 0.42, 0.46)}],   # 7×5
    "neck_scarf":  [{"src": ("clothes", "neck", "woolscarf"),       "tint": WINE,
                     "alt": {"src": ("clothes", "neck", "scarf"), "tint": WINE}}],                      # 34×46
    "neck_choker": [{"src": ("clothes", "neck", "gothic choker"),   "tint": LEATHER,
                     "alt": {"src": ("clothes", "neck", "clothchoker"), "tint": LEATHER}}],              # 7×5
    # —— 第二十六轮新增的 5 款项圈 ——
    # ★ tint 只对**灰度蒙版**有意义（结果 = 颜色 × 灰度）。AU 的 neck 目录里
    #   chaingold / freeuse / holypendant / cat 这几件**本来就是彩色的**，
    #   再乘一层颜色只会发乌，所以它们不给 tint。
    "neck_spiked":  [{"src": ("clothes", "neck", "spiked"),       "tint": LEATHER}],                     # 11×5 灰度
    "neck_ringed":  [{"src": ("clothes", "neck", "ringedcollar"), "tint": SILVER}],                      # 7×8  灰度
    "neck_lace":    [{"src": ("clothes", "neck", "lacechoker"),   "tint": (0.88, 0.86, 0.90)}],          # 21×15 灰度
    "neck_chain":   [{"src": ("clothes", "neck", "chaingold")}],                                         # 15×20 已彩色
    "neck_freeuse": [{"src": ("clothes", "neck", "freeuse")}],                                           # 10×13 已彩色

    # ---- 上衣 ----
    # ★ 「（不穿上衣）」：没有贴图，烘完只有一枚小灰杠图标（和其他 `_none` 一样）。
    #   它的作用是让「直接外穿」这条路成立 —— 这一层空着，内衣就是最外层。
    "top_none":      [],
    "top_highneck":  [{"src": ("clothes", "upper", "blouse"),                 "tint": IVORY}],
    "top_plain":     [{"src": ("clothes", "upper", "boxy"),                   "tint": LINEN}],
    "top_longsleeve":[{"src": ("clothes", "upper", "classic blouse"),         "tint": (0.52, 0.56, 0.52),
                       "alt": {"src": ("clothes", "upper", "sweater"), "tint": (0.52, 0.56, 0.52)}}],
    "top_sheer":     [{"src": ("clothes", "upper", "longsheershirt"),         "tint": (0.92, 0.92, 0.94),
                       "alt": {"src": ("clothes", "upper", "droparm"), "tint": (0.92, 0.92, 0.94)}}],
    "top_lace":      [{"src": ("clothes", "upper", "offshoulder lace top"),   "tint": (0.88, 0.86, 0.90),
                       "alt": {"src": ("clothes", "upper", "lacegown"), "tint": (0.88, 0.86, 0.90)}}],
    "top_corset":    [{"src": ("clothes", "upper", "leathertop"),             "tint": LEATHER}],
    # ★ 第二十二轮从 AU 补的 2 件「够露」的上衣 ——
    #   两个图包都有同名款（croptop / openshoulderscrop），所以映射统一，不用按包覆盖。
    "top_crop":        [{"src": ("clothes", "upper", "croptop"),              "tint": (0.72, 0.66, 0.62)}],
    "top_offshoulder": [{"src": ("clothes", "upper", "openshoulderscrop", "2.png"), "tint": (0.66, 0.58, 0.66)}],
    # ★ 第二十四轮从 AU 补的「两套校服」，每套 4 件（上衣 / 裙子 / 鞋 / 袜）：
    #   第一套裙长最短（classicschoolskirt，实测裙摆底边 y111，比 schoolskirt 的 y124 短 13 px）；
    #   第二套是普通及膝校裙（schoolskirt），两套颜色互不相同。
    #   源图在两个图包里都有同名款，所以映射统一、不用按包覆盖。
    "top_school_navy":  [{"src": ("clothes", "upper", "schoolblouse"), "tint": NAVY_LIGHT}],
    "top_school_green": [{"src": ("clothes", "upper", "schoolshirt"),  "tint": GREEN_LIGHT}],
    # ★ 第二十五轮：两套水手服的上衣（白色 / 藏青）——
    #   下装都是 AU 里唯一那条水手服裙 serafuku_dress，只是染色不同。
    "top_sailor_white": [{"src": ("clothes", "upper", "serafuku_new"), "tint": WHITE}],
    "top_sailor_navy":  [{"src": ("clothes", "upper", "serafuku"),     "tint": NAVY_LIGHT}],
    # ★ 第二十五轮补过 top_sundress / top_eveninggown 两件「上半层」，
    #   第二十六轮按用户口径「一整件衣服不能拆成上装和下装」把它们合并掉了 ——
    #   连衣裙与晚礼服现在是**整件式**，各自只有一件，见下方「整件式」段。
    # ★ 第二十五轮：三套「够露」的上衣（各配一件下装，见下方 bottom 段）
    "top_bustier":      [{"src": ("clothes", "upper", "slutler"),       "tint": BLACK}],
    "top_lolita":       [{"src": ("clothes", "upper", "skimpylolita"),  "tint": PLUM}],
    "top_keyhole":      [{"src": ("clothes", "upper", "keyhole"),       "tint": ROSEWOOD}],
    # ★★ 第二十八轮：三件「解死结」的上衣
    #   · 网纱取自 under-upper/mesh —— 那个目录里还混着 left-idle / right-idle /
    #     *-cover（单侧手臂层），resolve() 会挑到 left-idle；所以**显式点名 0.png**。
    #   · 紧身针织衫 / 高领军毛衣都有 full.png，直接写目录即可。
    "top_mesh":         [{"src": ("clothes", "under-upper", "mesh", "0.png"), "tint": SHEER_NUDE}],
    "top_virginkiller": [{"src": ("clothes", "upper", "virginkiller"),   "tint": KNIT_ASH}],
    "top_turtleneck":   [{"src": ("clothes", "upper", "turtleneckjumper"), "tint": KNIT_CREAM}],

    # ---- 内衣 ----
    "bra_plain": [{"src": ("clothes", "under-upper", "plainbra"),   "tint": (0.80, 0.78, 0.74)}],
    "bra_lace":  [{"src": ("clothes", "under-upper", "lacebra"),    "tint": BLACK}],
    "bra_none":  [],
    # ★★ 第二十八轮：两件高反差内衣。这两个目录**都没有 full.png**，
    #   而且 pasties 的候选名是 0-heart / 0-star / 2-heart…（同一图案的多个变体），
    #   所以两件都显式点名具体文件，别让 resolve() 去猜。
    "bra_microkini": [{"src": ("clothes", "under-upper", "microkini", "1.png"),  "tint": SKIN_SILK}],
    "bra_pasties":   [{"src": ("clothes", "under-upper", "pasties",   "0-star.png"), "tint": SKIN_SILK}],

    # ---- 手套 ----
    # ★ 手套的贴图是**按左右手分开**的（left-idle / right-idle），没有 full.png，
    #   所以要给两条 —— 只给一条的话小人只戴一只手。
    #   显式点出 idle 那张：目录里还有 cover（手臂遮胸）与 hold（握着东西）两种姿势。
    "gloves_none": [],
    "gloves_leather": [{"src": ("clothes", "hands", "longleathergloves", "left-idle"),  "tint": LEATHER},
                       {"src": ("clothes", "hands", "longleathergloves", "right-idle"), "tint": LEATHER}],
    "gloves_lace":    [{"src": ("clothes", "hands", "lacewarmers", "left-idle"),  "tint": (0.86, 0.84, 0.84)},
                       {"src": ("clothes", "hands", "lacewarmers", "right-idle"), "tint": (0.86, 0.84, 0.84)}],
    "gloves_oper":    [{"src": ("clothes", "hands", "armwarmers", "left-idle"),  "tint": (0.78, 0.78, 0.82)},
                       {"src": ("clothes", "hands", "armwarmers", "right-idle"), "tint": (0.78, 0.78, 0.82)}],

    # ---- 配饰 ----
    # ★★ 第三十四轮：用户口径「黄铜胸针去掉」→ `acc_brooch` **物品级删除**（整条撤掉，
    #   和上一轮撤掉眉钉 `piercing_brow` 是同一档处理）。同轮从 AU 补 3 件新的：
    #     · 三件都是 AU 图包自己那套贴图（`neck/lovelocket` / `legs/goldanklets` /
    #       `hands/goldshackles`），两套图包的路径一致，所以都不用 `alt`；
    #     · 位置也**本来就对**（吊坠在锁骨、脚链在脚踝、手铐垂在腕边），一律不给 align。
    #   ★ 染色：吊坠源图是纯灰（实测彩度 0.00）→ 乘一层旧银；
    #     脚链 / 手铐源图**本来就是金的**（彩度 0.67）→ 不给 tint，再乘一层只会发乌。
    "acc_none": [],
    "acc_locket": [{"src": ("clothes", "neck", "lovelocket"), "tint": PEWTER}],                    # 11×21 纯灰
    "acc_anklet": [{"src": ("clothes", "legs", "goldanklets")}],                                    # 29×8  已彩色
    "acc_shackle": [{"src": ("clothes", "hands", "goldshackles", "left-idle")},                     # 10×78 已彩色
                    {"src": ("clothes", "hands", "goldshackles", "right-idle")}],                   # 15×101
    "acc_belt":   [{"src": ("clothes", "lower", "chainbelt skirt", "acc"), "tint": LEATHER,
                    "alt": {"src": ("clothes", "lower", "belted"), "tint": LEATHER}}],

    # ---- 下装 ----
    # ★ 同上：「（不穿下装）」= 这一层空着，内裤直接外穿。
    "bottom_none":      [],
    "bottom_longskirt": [{"src": ("clothes", "lower", "longskirt"),          "tint": DARKGREY}],
    "bottom_trousers":  [{"src": ("clothes", "lower", "straight trousers"),  "tint": (0.36, 0.34, 0.30)}],
    "bottom_knee":      [{"src": ("clothes", "lower", "schoolskirtplaid"),   "tint": (0.40, 0.34, 0.30)}],
    "bottom_mini":      [{"src": ("clothes", "lower", "leatherminiskirt"),   "tint": LEATHER}],
    # ★ 第二十二轮从 AU 补的 2 件「够露」的下装（同样是两包都有同名款）
    "bottom_pleat":     [{"src": ("clothes", "lower", "micropleatedskirt"),  "tint": (0.38, 0.34, 0.42)}],
    "bottom_cut":       [{"src": ("clothes", "lower", "cutskirtshort"),      "tint": (0.30, 0.36, 0.34)}],
    # ★ 第二十四轮的两套校服裙：藏青那条是「裙长最短」的超短款，
    #   墨绿那条是普通及膝款（两条在 OutfitData 里走的门控不同 —— 超短的算 cutout）
    "bottom_school_navy":  [{"src": ("clothes", "lower", "classicschoolskirt"), "tint": NAVY}],
    "bottom_school_green": [{"src": ("clothes", "lower", "schoolskirt"),        "tint": GREEN_DARK}],
    # ★ 第二十五轮：两套水手服的裙（同一个源图 serafuku_dress，只换染色）
    "bottom_sailor_white": [{"src": ("clothes", "lower", "serafuku_dress"), "tint": WHITE}],
    "bottom_sailor_navy":  [{"src": ("clothes", "lower", "serafuku_dress"), "tint": NAVY}],
    # ★ 第二十六轮：三套暴露装的下装（皮短裤 / 高开衩短裙；洛丽塔短裙第二十七轮已删）
    "bottom_hotpants":     [{"src": ("clothes", "lower", "slutler"),      "tint": LEATHER}],
    "bottom_slit":         [{"src": ("clothes", "lower", "split"),        "tint": DUSK}],
    # ★★ 第二十八轮：三件高暴露下装（都有 full.png，直接写目录）
    "bottom_fishnet":      [{"src": ("clothes", "lower", "micropleatedskirt"), "tint": FISHNET}],
    "bottom_pvc":          [{"src": ("clothes", "lower", "leatherminiskirt"),  "tint": VINYL}],
    "bottom_qipao":        [{"src": ("clothes", "lower", "cheongsamshort"),    "tint": QIPAO}],

    # ---- 整件式（连衣裙 / 晚礼服）★ 第二十六轮新增的槽位 ----
    # 用户口径：「如果是一整件衣服 如晚礼服 不能分开成下装和上装 应该单开一个栏目」。
    # 所以连衣裙与晚礼服**各自只有一件**，把上、下两层贴图烘进同一张 PNG，
    # 走新的 `dress` 槽位（z 96，压在 top / bottom 之上）。
    # 好处不只是「栏目对了」—— 以前拆成两件时，两件各自独立参与暴露 / 反差 /
    # 上限的加总，玩家可以只穿晚礼服的上半截；合并之后它就是一整件，穿就是穿全套。
    "dress_none": [],
    "dress_sundress": [{"src": ("clothes", "upper", "sundress"),    "tint": CREAM},
                       {"src": ("clothes", "lower", "sundress"),    "tint": CREAM}],
    # ★ 晚礼服的下摆是**整包里唯一被取景框切到的图层**（烘 AU 时会打印
    #   「切 18 px  clothes/dress_eveninggown」）。原因是共用取景框只有 68 px 宽
    #   （x62..130），而 AU 这条舞会裙在全身像那一列里横跨 x44..139（95 px），
    #   左边 18 px 的裙摆外扩被裁掉了 —— 右边另有 9 px 被 130 的接缝挡掉。
    #   试过换成 `lower/ballgown`（正好 62..130，0 裁剪），但那是条**短蓬裙**，
    #   和「晚礼服」的语义对不上，所以宁可留这点裁边也要保住这条长裙。
    "dress_eveninggown": [{"src": ("clothes", "upper", "eveninggown"), "tint": WINE},
                          {"src": ("clothes", "lower", "eveninggown"), "tint": WINE}],

    # ---- 吊袜带（第三十七轮并入「袜类」，槽位 z 走 stockings = 66.6）----
    # garter_none 已随合并删除（袜类自己的空件是 stockings_none）。
    "garter_lace":  [{"src": ("clothes", "legs", "asymmetricalgarter"), "tint": (0.84, 0.82, 0.84),
                      "alt": {"src": ("clothes", "legs", "ribbonstockings"), "tint": (0.84, 0.82, 0.84)}}],
    "garter_black": [{"src": ("clothes", "legs", "harness garter stockings"), "tint": LEATHER,
                      "alt": {"src": ("clothes", "legs", "garterstockings"), "tint": LEATHER}}],

    # ---- 内裤 ----
    "panties_plain": [{"src": ("clothes", "under-lower", "classicplainpanties"), "tint": (0.82, 0.80, 0.76)}],
    # ★ 第二十五轮换源图：原来是 `gstring`（丁字裤）—— AU 那条是**高腰系带**画法，
    #   腰带比所有下装的腰线都高，穿上长裤 / 长裙也能从腰上方露出黑色带子
    #   （实测在 8 条下装下露出 11%~21% 的像素，看着像「内裤穿在裤子外面」）。
    #   DoL 原版那条没这毛病，所以只在 AU 侧炸 —— 换成 `lacepanties`（标准蕾丝内裤，
    #   两包都有，实测在各下装下露出 0%）后问题消失。
    "panties_lace":  [{"src": ("clothes", "under-lower", "lacepanties"),         "tint": BLACK}],
    # ★ 第二十六轮：按用户口径「增加暴露度高的内裤款式」补 4 件，全部取 AU 真实贴图。
    #   括号里是它在 68 px 宽取景框里的实际尺寸（AU 全身像列的人物只有 40×145 px）。
    #   门控照旧：内裤在 UNDER_GATE 里，下面被普通下装盖住时这几件一律不计入暴露 / 反差
    #   —— 想让它真的算数，就得配「（不穿下装）」或者标了 see 的下装。
    "panties_crotchless": [{"src": ("clothes", "under-lower", "crotchlesspanties"), "tint": BLACK}],      # 25×14 开裆
    "panties_micro":      [{"src": ("clothes", "under-lower", "highmicrokini"),     "tint": (0.62, 0.24, 0.32)}],  # 23×19 微型
    "panties_janties":    [{"src": ("clothes", "under-lower", "janties"),           "tint": (0.30, 0.34, 0.44)}],  # 27×18 牛仔丁字
    "panties_thong":      [{"src": ("clothes", "under-lower", "thong"),             "tint": BLACK}],      # 25×12 丁字
    "panties_none":  [],

    # ---- 袜子 ----
    "stockings_none":   [],
    "stockings_opaque": [{"src": ("clothes", "legs", "tights"),         "tint": (0.24, 0.24, 0.28)}],
    "stockings_thigh":  [{"src": ("clothes", "legs", "plainthighhighs"), "tint": (0.90, 0.90, 0.90)}],
    "stockings_net":    [{"src": ("clothes", "legs", "fishnetstockings"), "tint": BLACK}],
    # ★ 第二十四轮：两套校服的袜子（白色大腿袜 / 米色花边短袜）
    "stockings_school_navy":  [{"src": ("clothes", "legs", "plainthighhighs"), "tint": WHITE_SOCK}],
    "stockings_school_green": [{"src": ("clothes", "legs", "ruffled socks"),   "tint": SAND}],

    # ---- 鞋 ----
    "shoes_boots": [{"src": ("clothes", "feet", "highheelankleboots"), "tint": DARKBROWN,
                     "alt": {"src": ("clothes", "feet", "bootheels"), "tint": DARKBROWN}}],
    "shoes_heels": [{"src": ("clothes", "feet", "courtheels"),         "tint": BLACK}],
    # ★ 第二十四轮：两套校服的鞋（藏青校服皮鞋 / 棕色便鞋）
    "shoes_school_navy":  [{"src": ("clothes", "feet", "schoolshoes"), "tint": NAVY_DARK}],
    "shoes_school_green": [{"src": ("clothes", "feet", "loafers"),     "tint": SHOEBROWN}],

    # ---- 外袍 ----
    "robe_none": [],
    "robe_travel":  [{"src": ("clothes", "upper", "winterjacket"),        "tint": (0.34, 0.28, 0.22), "z": 150.0}],
    "robe_lace":    [{"src": ("clothes", "upper", "sheer lace pyjama"),   "tint": (0.90, 0.88, 0.90), "z": 150.0,
                      "alt": {"src": ("clothes", "upper", "bathrobe"), "tint": (0.90, 0.88, 0.90), "z": 150.0}}],
    "robe_leather": [{"src": ("clothes", "upper", "blackleather"),        "tint": BLACK, "z": 150.0}],

    # ================= ★★ 第三十七轮：按暴露度分档补的 35 件 =================
    # 用户口径：「补充各个暴露度层级的衣服，使数量尽量平衡」。
    #
    # 这一批**一条 `alt` 都不用写** —— 35 个款式在 AU 图包里全都存在（已逐个核过）。
    # 也**一条 `align` 都不用写** —— 它们不是「借头部小件搬位置」那一类，
    # 本身就是按身体画好的衣物图层，落在正确的层上即可。
    #
    # 分档（括号里是 exposure）：3 档 4 件 / 4 档 7 件 / 5 档 4 件 /
    # 7 档 4 件 / 8 档 6 件 / 9 档 10 件 —— 目标是让「1~9 每档 9~11 件」压平
    # （不含纹身那 9 件 @2，它们是同一个多件槽位）。

    # ---- 成装（8 件）----
    "dress_kimono":      [{"src": ("clothes", "upper", "kimonomini"),       "tint": NAVY_DARK}],
    "dress_maid":        [{"src": ("clothes", "upper", "maid"),             "tint": DARKGREY}],
    "dress_slip":        [{"src": ("clothes", "upper", "babydoll"),         "tint": CREAM}],
    "dress_nurse":       [{"src": ("clothes", "upper", "pinknurse"),        "tint": WHITE}],
    "dress_cheongsam":   [{"src": ("clothes", "upper", "cheongsamshort"),   "tint": QIPAO}],
    "dress_leather":     [{"src": ("clothes", "upper", "leatherdress"),     "tint": LEATHER}],
    "dress_swan":        [{"src": ("clothes", "upper", "swandress"),        "tint": WINE}],
    "dress_transparent": [{"src": ("clothes", "upper", "transparentnurse"), "tint": SKIN_SILK}],

    # ---- 上衣（8 件）----
    "top_tank":        [{"src": ("clothes", "upper", "tanktop"),        "tint": KNIT_ASH}],
    "top_tube":        [{"src": ("clothes", "upper", "tubetop"),        "tint": WINE}],
    "top_swim":        [{"src": ("clothes", "under-upper", "swimsuit"), "tint": NAVY}],
    "top_leathercrop": [{"src": ("clothes", "upper", "leathercroptop"), "tint": LEATHER}],
    "top_chain":       [{"src": ("clothes", "upper", "chain tunic"),    "tint": SILVER}],
    "top_graphiccrop": [{"src": ("clothes", "upper", "graphiccrop"),    "tint": BLACK}],
    # ★ 这两件是 9 档的「临时裹一下」：源图本身就是布，染成米白
    "top_towel":       [{"src": ("clothes", "upper", "towel"),          "tint": IVORY}],
    "top_bedsheet":    [{"src": ("clothes", "upper", "bedsheet"),       "tint": IVORY}],

    # ---- 下装（5 件）----
    "bottom_pencil":       [{"src": ("clothes", "lower", "pencillong"),    "tint": DARKGREY}],
    # jorts 源图本来就是彩色牛仔布，不再染色（tint=None → 保持原色）
    "bottom_shortshort":   [{"src": ("clothes", "lower", "jorts"),         "tint": None}],
    "bottom_leathershort": [{"src": ("clothes", "lower", "leathershorts"), "tint": LEATHER}],
    "bottom_chain":        [{"src": ("clothes", "lower", "chain tunic"),   "tint": SILVER}],
    "bottom_sarong":       [{"src": ("clothes", "lower", "sarong"),        "tint": GREEN}],

    # ---- 上内衣（4 件）----
    "bra_bikini":     [{"src": ("clothes", "under-upper", "classicbikini"),      "tint": WINE}],
    "bra_latex":      [{"src": ("clothes", "under-upper", "latexleotard"),       "tint": BLACK}],
    "bra_seethrough": [{"src": ("clothes", "under-upper", "seethroughswimsuit"), "tint": SKIN_SILK}],
    "bra_tape":       [{"src": ("clothes", "under-upper", "tape"),               "tint": IVORY}],

    # ---- 下内衣（6 件）----
    "panties_bikini":     [{"src": ("clothes", "under-lower", "classicbikini"),      "tint": WINE}],
    "panties_shibari":    [{"src": ("clothes", "under-lower", "shibari"),            "tint": DARKBROWN}],
    "panties_gstring":    [{"src": ("clothes", "under-lower", "gstring"),            "tint": BLACK}],
    "panties_loincloth":  [{"src": ("clothes", "under-lower", "loincloth"),          "tint": LINEN}],
    "panties_tieside":    [{"src": ("clothes", "under-lower", "tiesidebikini"),      "tint": SKIN_SILK}],
    "panties_seethrough": [{"src": ("clothes", "under-lower", "seethroughswimsuit"), "tint": SKIN_SILK}],
    # ★ 第三十九轮：从 AU 的 `clothes/genitals/` 引入（用户口径「引入平坦贞操笼放在下内衣」）。
    #   源图就是为「下体」画的，落点天然与 `under-lower/*` 同一高度
    #   （左列 bbox 91,89-118,101 —— gstring 是 88,84-121,106），所以**不需要 align 搬移**，
    #   直接取 `full.png` 那一帧、按取景框裁掉即可。
    #   四态（full / torn / tattered / frayed）在第三十八轮的清点里已实测**内容完全相同**，
    #   所以只取 full 一张。
    "panties_flatcage":   [{"src": ("clothes", "genitals", "flatchastitycage", "full"), "tint": CHROME}],

    # ---- 袜类（4 件）----
    "stockings_sheer":         [{"src": ("clothes", "legs", "sheer stockings"),   "tint": BLACK}],
    "stockings_fishnettights": [{"src": ("clothes", "legs", "fishnettights"),     "tint": FISHNET}],
    # ★ 8 档这件原本想用 `mismatched thighhighs`（左右腿图案不同），但那个源图
    #   在 AU 里**只画了一条腿**（烘出来 13 px 宽，正常袜类是 27~31 px）——
    #   换成 `chain leggings`：整条腿的网眼织法 + 一排金属环，两腿都在，正合「高暴露」。
    "stockings_chainnet":      [{"src": ("clothes", "legs", "chain leggings"),    "tint": FISHNET}],
    "stockings_sheerskin":     [{"src": ("clothes", "legs", "sheerleggings"),     "tint": SKIN_SILK}],

    # ---- 妙妙工具（第三十九轮新增的一栏，只能手动装备）----
    # 贴图取 AU `clothes/back/fox tail butt plug/back.png` —— 挂在身后的那条尾巴。
    # ★ 这一栏的贴图不需要 align / scale：源图本身就是「尾巴挂在身后」的构图
    #   （左列 bbox 36,40-116,107，从臀部一路向侧后方伸出去），
    #   而 AU 的 back 层本来就画在那个位置，照原样取帧即可。
    "tool_none": [],
    "tool_tail": [{"src": ("clothes", "back", "fox tail butt plug", "back"), "tint": FUR_FOX}],
}

# ---------------- 借用头部小件的覆盖参数（AU）----------------
# 只有「借用头部小件 + 位置搬移」这一套（耳饰 / 穿环 / 刺青）需要这里的参数。
# 原因：这些槽位在 DoL 里根本不存在，只能挪用一个头部小件再把它搬到耳朵 / 眉骨 / 唇边；
# 而 AU 重画后同一个源件宽了 6 倍多，照搬旧 scale 会直接糊满整张脸 ——
#   goldhairpin  DoL 6×6  → AU 8×10
#   fishhairpin  DoL 8×7  → AU 15×15
#   hairclip     DoL 4×4  → AU 26×8   ← 是一条横排发夹
# 所以 AU 这边换成窄的 goldhairpin，并按「结果宽度对齐 DoL」重算 scale：
#   AU scale = DoL 结果宽 / AU 源宽
AU_OVERRIDE = {
    # ---- 刺青：改用 AU 自己的 bodywriting 图案（第二十六轮）----
    # AU 的 bodywriting 是**真正画在身上的图案**，而且每张图已经落在正确的
    # 身体位置上（forehead / left-cheek / left-shoulder / left-thigh / pubic /
    # breasts-0..6），所以 AU 这边不再需要「借用头部小件 + 搬移」那套顶替。
    #
    # ★ align 坐标按 DoL 头心 (58,30) 写，由 transform() 换算到各图包；
    #   下面这几个数是从 AU 画布上图案的 bbox 中心**反算回 DoL 坐标系**得到的：
    #       x_dol = (cx - 106) / 1.5 + 58        y_dol = (cy - 30.5) / 1.5 + 30
    #   （106 / 30.5 / 1.5 见 dol_prepare.PACKS['au']）
    #
    #     图案                  AU 画布 bbox          尺寸   中心 → DoL align
    #     flower/left-shoulder  (113, 54, 121, 64)    8×10   (117.0, 59.0) → (65.33, 49.00)
    #     star/left-cheek       (108, 40, 113, 45)    5×5    (110.5, 42.5) → (61.00, 38.00)
    #     flower/left-thigh     (108, 114, 118, 124)  10×10  (113.0, 119.0) → (62.67, 89.00)
    #
    # ★★ scale 要**除以 1.5** —— transform() 里 s = scale × align_scale，
    #   而 align_scale（au）= 1.5 是给「从 DoL 几何借来的贴图」用的。
    #   bodywriting **本来就是 AU 几何**，再乘一遍就等于平白放大 1.5 倍。
    #   第二十六轮初版就是踩了这个坑：`scale: 1.333` → 实际 s = 2.0，
    #   图案被撑成 2 倍之后有一大半悬在身体轮廓之外
    #   （用身体掩膜量过：颈侧只有 65%、颊 76%、大腿 81% 落在皮肤上）。
    #
    #   s = 1.0 / 1.5 / 1.5 这几个值也不是随手取的 —— 用「仍然 100% 落在
    #   身体掩膜上」当约束扫过一遍（transform 是对**已裁到左列**的图做缩放，
    #   再按 bbox 重新居中，所以位置恒定、只有尺寸变）：
    #     颈侧 flower/left-shoulder：s=1.00 → 100%（8×10）｜ s=1.25 → 87% ｜ s=2.0 → 65%
    #     颊   star/left-cheek     ：s=1.50 → 100%（7×8）｜ s=2.0 → 70%
    #     大腿 flower/left-thigh   ：s=1.50 → 96%（15×15）｜ s=2.0 → 81%
    #   颈侧取 1.0（原生尺寸，肩窝那块皮肤窄，再大就出轮廓）；
    #   颊 / 大腿取 1.5（仍是 96~100%，比原生大一档、看得清）。
    "tattoo_neck":  {"src": ("bodywriting", "flower", "left-shoulder"), "tint": INK,
                     "scale": 0.6667, "align": ("bbox_center", 65.33, 49.00)},
    "tattoo_cheek": {"src": ("bodywriting", "star", "left-cheek"), "tint": INK,
                     "scale": 1.0000, "align": ("bbox_center", 61.00, 38.00)},
    "tattoo_thigh": {"src": ("bodywriting", "flower", "left-thigh"), "tint": INK,
                     "scale": 1.0000, "align": ("bbox_center", 62.67, 89.00)},
    # ★ 第三十五轮补的两件，都取 AU 的 left-thigh：
    #   heart     源图 14×78（一串小心形沿腿而下）→ s=0.70 得 10×55，正好收在大腿上；
    #   paw print 源图只有 5×5（全位置都是 5×5）→ s=4.0 得 20×20 才看得清爪形。
    #   align 由源图 bbox 中心反算：ax=(cx−106)/1.5+58、ay=(cy−30.5)/1.5+30。
    "tattoo_heart": {"src": ("bodywriting", "heart", "left-thigh"), "tint": INK,
                     "scale": 0.4667, "align": ("bbox_center", 61.33, 99.00)},
    "tattoo_paw":   {"src": ("bodywriting", "paw print", "left-thigh"), "tint": INK,
                     "scale": 2.6667, "align": ("bbox_center", 61.00, 83.33)},
    # ★ 第三十六轮补的四件刻字，取 AU 的 `bodywriting/text/<词>/<位置>`。
    #   这一组和上面几件**不一样**：AU 的 text 贴图是**按部位画好的整字**
    #   （不是小图案），所以位置和尺寸都沿用图包自己的落点 ——
    #   s=1.0 即原生尺寸，只要把 bbox 中心搬到它本来待的地方。
    #   反算公式同上：ax=(cx−106)/1.5+58、ay=(cy−30.5)/1.5+30。
    #   · bitch    左大腿竖排 7×39 → 缩到 0.72（5×28）才不越过膝盖
    #   · free-use 右大腿竖排 8×17 → 放大 1.6（13×27）才看得清
    #   · slave    胸口横排 19×5  → 放大 1.4（27×7）
    #   · cum-rag  下腹横排 13×11 → 放大 1.4（18×15）
    #   四件分占四个位置，正好对上「可同时装备 2 件」的搭配空间。
    "tattoo_bitch":   {"src": ("bodywriting", "text", "bitch", "left-thigh"), "tint": INK,
                       "scale": 0.4800, "align": ("bbox_center", 61.67, 84.33)},
    "tattoo_freeuse": {"src": ("bodywriting", "text", "free-use", "right-thigh"), "tint": INK,
                       "scale": 1.0667, "align": ("bbox_center", 52.00, 85.33)},
    "tattoo_slave":   {"src": ("bodywriting", "text", "slave", "breasts"), "tint": INK,
                       "scale": 0.9333, "align": ("bbox_center", 57.00, 53.67)},
    "tattoo_cumrag":  {"src": ("bodywriting", "text", "cum-rag", "pubic"), "tint": INK,
                       "scale": 0.9333, "align": ("bbox_center", 57.00, 78.00)},
    # ★ 位置说明：AU 的 bodywriting **没有 neck 这个位置**（只有 forehead /
    #   left·right-cheek / left·right-shoulder / left·right-thigh / breasts-0..6 /
    #   pubic），所以「颈侧刺青」只能落在最近的左肩。已在 README 记为已知取舍。

    # ---- 穿环：AU **没有**穿环资源 ----
    # 全包搜过 piercing / ring / stud / barbell / septum / hoop，只搜到一个
    # 拿在手里的道具戒指，没有可用的穿环贴图 —— 所以只能继续借用头部小件顶替。
    # 这里把剩下 3 件全部列出来：它们还在用「按 DoL 的 6×6 算出来的 scale」，
    # 到 AU（goldhairpin 是 8×10）会放大过头、发糊。
    # AU scale 的算法：s = DoL 结果宽 / AU 源宽 = (6 × 原 scale) / 8。
    #   DoL 原 scale：multi 0.7 → 4.2/8 = 0.525；lip 0.8 → 4.8/8 = 0.600；
    #                 nose 0.7 → 4.2/8 = 0.525。
    # ★ 第二十七轮：原来第 4 件是 `piercing_brow`（眉钉），用户口径「眉钉去掉」
    #   已删 —— 它是唯一必须换源的一件（AU 的 hairclip 是 26×8 的**横排发夹**，
    #   照搬 DoL 的 4×4 会直接糊满整张脸），剩下三件本来就用 goldhairpin，无此问题。
    "piercing_multi": {"scale": 0.525},
    "piercing_lip":   {"scale": 0.600},
    "piercing_nose":  {"scale": 0.525},

    # DoL 是 fishhairpin 8×7 × 1.2 = 9.6 宽 → AU 用 goldhairpin 8 宽 → 9.6/8
    # （耳饰槽位第二十五轮已下架，留着是为了将来恢复时不用再改）
    "ear_diamond":   {"src": ("clothes", "head", "goldhairpin"), "scale": 1.20,
                      "align": ("bbox_center", 66.0, 33.0)},
}

# ---------------- 发型表 ----------------
# 第三十七轮起只有 AU 一套，所以不再需要「按图包挑表」这一层
# （原来这里是 PACK_HAIR = {'dol': HAIR_STYLES, 'au': HAIR_STYLES_AU}）。
# 烘焙脚本直接用上面的 HAIR_STYLES。
