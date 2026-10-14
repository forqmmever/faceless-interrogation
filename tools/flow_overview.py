"""把 screenshots/ 下的阶段截图拼成一张总览图，便于快速通读流程。

输出：screenshots/_flow_overview.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(os.path.dirname(HERE), "screenshots")


def _load_font(size: int = 15):
    """PIL 自带的位图字体画不出中文（会整行空白），所以显式找一个中文字体。"""
    cands = [
        r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\msyhl.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
        r"C:\Windows\Fonts\simsun.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for c in cands:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, size)
            except Exception:
                continue
    return ImageFont.load_default()


FONT = _load_font(15)

# (文件名, 说明)
PANELS = [
    ("00_title_screen.png",           "0. 开始界面 · 开始游戏 / 继续游戏 / 退出游戏（没有进行中的一局 → 「继续游戏」是灰的）"),
    ("00a_level_select.png",          "0a. ★ 选关面板 · 点「开始游戏」后先出这一层 —— 四关入口都在，目前只开放第一关；其余三关锁定但没删除"),
    ("00b_title_continue.png",        "0b. 开始界面 · 有存档时 —— 「继续游戏」亮起，摘要写明停在第几关的准备室"),
    ("00c_intro_popup.png",           "0c. ★ 开场介绍浮窗 · 开局自动弹出，讲清「这是哪儿 / 你是谁 / 谁在对面 / 谁在旁边」（正文可用编辑器改）"),
    ("00d_help_wardrobe.png",         "0d. ★ 阶段一 · 玩法说明（手机未开）—— 讲四处：卡片墙 / 数值量表 / 换装预览 / 手机。方框 + 编号 + 短箭头"),
    ("00e_help_phone.png",            "0e. ★ 阶段一 · 玩法说明（手机已开）—— 同样一个按钮，手机拿在手里时改成逐个讲消息 / 相册 / 备忘录 / 备注"),
    ("01_briefing_start.png",         "1. ★ 准备室开局 · DoL 风格：左＝分层小人 + 两条量表（七点色阶 + 渐变刻度 + 阈值刻线），右＝17 个槽位的衣物卡片墙（外袍暂时下架，30×30 图标放 2 倍）；第一关没有强制服装要求"),
    ("01b_briefing_bottom.png",       "1b. ★ 准备室滚到底 —— 卡片墙最后一段分区是「鞋履」；外袍整段消失（暂时下架，数据与贴图一件没删）"),
    ("01c_gate_hidden.png",           "1c. ★ 内衣门控·藏起来 —— 高领衬衫 + 蕾丝内衣：内衣卡片的两行点阵压暗、暴露值与反差值都不算它"),
    ("01d_gate_shown.png",            "1d. ★ 内衣门控·透出来 —— 只把上衣换成半透蕾丝：内衣立刻计入（三条路：透明外衣 / 镂空开档 / 直接外穿）"),
    ("01e_forced_fixed.png",          "1e. ★ 强制穿着 · 固定一件 + 几件选一件（编辑器里写死的规则表）—— 判定栏逐条写出还差哪一条"),
    ("01f_forced_satisfied.png",      "1f. ★ 强制穿着 · 穿上之后 —— 「任选一件」里挑哪一件都算满足"),
    ("03_phone_memo.png",             "3. 手机 · 备忘录（第一条：审问者是什么人 —— 性情 / 喜好 / 忌讳 / 该怎么答）"),
    ("04_phone_messages.png",         "4. 手机浮层 · 点左下角按钮弹出（整屏压暗、点遮罩收起）—— 消息列表不再写「与审问官」这类分组标题；短信逐关解锁，未读带 ●"),
    ("05_phone_thread.png",           "5. 手机 · 与朋友的一段对话 —— 读完才知道「B 该怎么说」（官方口径的唯一来源）"),
    ("05b_phone_companion_sms.png",   "5b. 手机 · 与 C 的短信 —— 他不给口径，只提醒你他一直都在旁边（读完学到 0 条）"),
    ("06_phone_album.png",            "6. 手机 · 相册（糊、反光、噪点；照片尺寸固定，切到相册不会把手机撑大）"),
    ("07_phone_album_cleared.png",    "7. 手机 · 擦掉反光后 —— 看清了一处原貌"),
    ("08a_phone_notes_round1.png",    "8a. ★ 手机 · 备注（第一轮）—— 整页空着，连说明文字都没有（用户口径：第一轮为空）"),
    ("08_phone_notes.png",            "8. ★ 手机 · 备注（第二轮起）—— 按轮次回放：上一轮他问过什么、你怎么答的，都在这儿"),
    ("09_phone_interrogator_sms.png", "9. 盘问里掏手机超过 3 次 → 收到审问者本人的短信（红框那条）"),
    ("10_peek_partial.png",           "10. 只拼到 6 处原貌时按 👁 —— 只能看见残缺的「A」"),
    ("11_briefing_done.png",          "11. 情报整理完 + 换装完成 · 强制装备已穿齐，伪装成立"),
    ("11b_auto_complete.png",         "11b. 测试按钮「🧪 一键达标」—— 先打回原貌，再一键补齐强制件 / 缺陷 / 反差 / 暴露"),
    ("12_overcap.png",                "12. 判定栏只摊数字、不下结论（暴露值超上限，门开了才见分晓）"),
    ("13_interrogation.png",          "13. 盘问开局 · 本关 8 题（左下角「掏出手机」按钮在选项左边；右栏的同行者信息已删）"),
    ("13b_help_interrogation.png",    "13b. ★ 阶段二 · 玩法说明 —— 怀疑度 / 题面 / 反馈 / 掏出手机 / 选项 / 两种提示条，逐处圈出来讲"),
    ("14_phone_in_interrogation.png", "14. 盘问中掏出手机 —— 左边答题、右边查档，选完答案自动收回"),
    ("15_fact_question.png",          "15. 说法题 —— 你选的版本会被他记下来（跨关不许改口）"),
    ("16_companion_question.png",     "16. 同行者提问 —— 他抛一个错的版本来试你（判定与审讯官一致）"),
    ("16b_blind_question.png",        "16b. 盲区题 —— 档案里没有、短信里也没提；选项数量可变（带「硬答」3 个，不带只有 2 个）"),
    ("16c_blind_feedback.png",        "16c. 盲区题选完 —— 反馈无论对错都把备忘录第一条摆出来（这一题的正解只能从它推）"),
    ("17_bluff_warning.png",          "17. 读过审问者情报 → 「撒谎」项亮起 ⚠（他多疑）"),
    ("18_companion_interference.png", "18. 同行者递话 · 单键干扰 —— 2.6 秒内按空格打断（窗口从 1.6 秒放宽，频率也从 2.5 秒放宽到 6 秒）"),
    ("18b_combo_interference.png",    "18b. 组合干扰 · 每 3 次里出 1 次 —— 依次敲 J → K → L 才截得断（敲错当场判负）"),
    ("19_expression_qte.png",         "19. 表情 QTE（切题后延迟 2.5 秒才出现、单阶段、答完即结束；期间照常答题与掏手机）"),
    ("20_leak_exposed.png",           "20. 说漏嘴 → 身份暴露结局"),
    ("21_recognized_on_sight.png",    "21. 一眼认出 —— 阶段一不判定；门一开他说「怎么是你，沈棠。」本轮当场结束"),
    ("22_contradiction.png",          "22. 前后矛盾 → 当场识破（本局前几轮说过的话都算数）"),
    ("23_level_cleared.png",          "23. 结果覆盖层 · 本关通过 → 进入下一关（这一关的接受度立刻进账号）"),
    ("24_run_cleared.png",            "24. 结果覆盖层 · 整局通关（4/4 关）"),
    ("25_run_failed.png",             "25. 结果覆盖层 · 失败 → 回到本轮开始（同一局 · 同一关；已赚的接受度不退）"),
]

COLS = 3
THUMB_W = 430
PAD = 14
CAP_H = 26
BG = (18, 20, 24)
CAP_FG = (232, 236, 242)


def _wrap(text: str, max_w: int, max_lines: int = 3):
    """按像素宽度折行。

    中文没有空格，不能靠 split() 断行 —— 得逐字累加量宽度。
    （踩过的坑：说明文字一长就横向溢出，压到右边那一格的截图上。）
    """
    lines = []
    cur = ""
    for ch in text:
        trial = cur + ch
        if FONT.getlength(trial) <= max_w or cur == "":
            cur = trial
        else:
            lines.append(cur)
            cur = ch
            if len(lines) >= max_lines:
                break
    if cur and len(lines) < max_lines:
        lines.append(cur)
    if len(lines) == max_lines and FONT.getlength(lines[-1]) > max_w - 12:
        # 最后一行塞不下时打个省略号，别硬挤
        lines[-1] = lines[-1][:-1] + "…"
    return lines


def main() -> None:
    loaded = []
    for name, cap in PANELS:
        path = os.path.join(SHOTS, name)
        if not os.path.exists(path):
            print("  missing:", path)
            continue
        im = Image.open(path).convert("RGB")
        ratio = THUMB_W / im.width
        im = im.resize((THUMB_W, int(im.height * ratio)), Image.LANCZOS)
        loaded.append((im, _wrap(cap, THUMB_W - 4)))

    if not loaded:
        print("nothing to compose")
        return

    line_h = FONT.size + 5
    rows = (len(loaded) + COLS - 1) // COLS
    cap_h = max(len(c) for _, c in loaded) * line_h + 8
    cell_h = max(im.height for im, _ in loaded) + cap_h
    W = COLS * THUMB_W + (COLS + 1) * PAD
    H = rows * cell_h + (rows + 1) * PAD

    sheet = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(sheet)

    for i, (im, cap_lines) in enumerate(loaded):
        r, c = divmod(i, COLS)
        x = PAD + c * (THUMB_W + PAD)
        y = PAD + r * (cell_h + PAD)
        sheet.paste(im, (x, y))
        draw.rectangle([x, y, x + THUMB_W - 1, y + im.height - 1], outline=(58, 64, 74))
        for li, line in enumerate(cap_lines):
            draw.text((x + 2, y + im.height + 6 + li * line_h), line, fill=CAP_FG, font=FONT)

    out = os.path.join(SHOTS, "_flow_overview.png")
    sheet.save(out)
    print("  saved", out, sheet.size)


if __name__ == "__main__":
    main()
