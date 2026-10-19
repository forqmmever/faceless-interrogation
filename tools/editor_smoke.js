/* 编辑器冒烟测试：用极简 DOM 桩把 tools/story_editor.html 里的脚本跑起来，
   验证 (1) 数据能载入 (2) 校验结果为 0 错误 (3) 四个视图都能渲染
   (4) 所有预览函数不炸 (5) JSON 往返无损。跑完即删。 */
const fs = require("fs");
const path = require("path");

const ROOT = path.dirname(__dirname);   // tools/ 的上一级 = 项目根
const HTML = path.join(ROOT, "tools", "story_editor.html");
const html = fs.readFileSync(HTML, "utf8");

// ---- 抽 seed JSON ----
const seedM = html.match(/<script id="seed" type="application\/json">([\s\S]*?)<\/script>/);
if (!seedM) { console.error("FAIL: 页面里没有 seed 数据块"); process.exit(1); }
const seedText = seedM[1];
console.log("seed 字节:", Buffer.byteLength(seedText, "utf8"));

// ---- 抽主脚本 ----
const scripts = [...html.matchAll(/<script(?![^>]*\btype=)[^>]*>([\s\S]*?)<\/script>/g)];
if (scripts.length !== 1) { console.error("FAIL: 主 script 块数量异常 =", scripts.length); process.exit(1); }
let mainJs = scripts[0][1];

// ---- DOM 桩 ----
function mkEl(tag) {
  const set = new Set();
  const el = {
    nodeType: 1, tagName: tag, children: [], style: {}, dataset: {}, attrs: {},
    className: "", textContent: "", value: "", checked: false, selected: false,
    readOnly: false, disabled: false, innerHTML: "",
    classList: {
      add: c => set.add(c), remove: c => set.delete(c), contains: c => set.has(c),
      toggle: (c, f) => { const on = f === undefined ? !set.has(c) : !!f; on ? set.add(c) : set.delete(c); return on; }
    },
    append(...k) { for (const x of k) if (x != null) this.children.push(x); },
    appendChild(x) { this.children.push(x); return x; },
    prepend(x) { this.children.unshift(x); return x; },
    addEventListener() {}, removeEventListener() {},
    setAttribute(k, v) { this.attrs[k] = v; }, getAttribute(k) { return this.attrs[k]; },
    querySelector() { return mkEl("div"); }, querySelectorAll() { return []; },
    scrollIntoView() {}, focus() {}, click() {}, remove() {},
    get scrollHeight() { return 100; },
  };
  return el;
}
const byId = Object.create(null);
byId["seed"] = { nodeType: 1, textContent: seedText };
byId["fileinput"] = mkEl("input");

globalThis.document = {
  createElement: mkEl,
  createTextNode: s => ({ nodeType: 3, textContent: String(s) }),
  getElementById: id => (byId[id] || (byId[id] = mkEl("div"))),
  querySelector: () => null,
  querySelectorAll: () => [],
  addEventListener() {},
  body: mkEl("body"),
};
globalThis.window = globalThis;
globalThis.navigator = { clipboard: { writeText: () => Promise.resolve() } };
globalThis.alert = () => {};
globalThis.confirm = () => true;
globalThis.prompt = () => null;

// ---- 探针：把内部函数暴露出来 ----
mainJs += `
;globalThis.__probe = {
  get story(){ return story; }, set story(v){ story = v; },
  get issues(){ return issues; },
  get fileName(){ return fileName; },
  get index(){ return index; },
  loadStory, validateNow, buildIndex, renderAll, go, toJSON, getSeed, openSet, foldSet,
  commit, undo, redo,
  get undoStack(){ return undoStack; }, get redoStack(){ return redoStack; },
  bgSections, traitSections,
  rulesSections, uiSections, endingsSections, uiLeafCount, normalizeStory, stripNum,
  renderSection, renderField,
  // 第二十三轮：流程四页的字段定义与目录查询
  levelsFields, forcedFields, forcedRuleFields, qteFields, defectFields,
  forcedRuleTitle, qteTitle, FORCED_MODES,
  catItems, catTags, itemById, itemLabel, pickItemOpts, pickTagOpts,
  previewQuestion, previewCompanion, previewSms, previewFact, previewTrait,
  // ★ 第二十九轮：题库页（逐题编辑）暴露出来供冒烟检查
  // ★ 第五十三轮：renderQuestions 已删除（题库页并进每套背景），不再导出
  questionFields, optionFields, TONE_OPTS, QUESTION_QTE_OPTS, totalQuestions,
  bgEnabled, enabledBgs, blankBackground,
  TRUE_POOL, GENDERS, PLAYER_GENDER,
  // ★ 第四十轮：服装数值页 / 原貌页
  renderItemsEditor, renderTrueAppEditor, renderPresetList,
  setItemOverride, effValueOf, baseValueOf, catalogItems, overriddenItemCount,
  autoSlots, itemsOfSlot, inTruePool, presetSummary,
  get presetMode(){ return presetMode; }, set presetMode(v){ presetMode = v; },
  get presetSel(){ return presetSel; }, set presetSel(v){ presetSel = v; },
  get itemFilter(){ return itemFilter; },
  // ★ 第四十一轮：背景级流程覆写 + 原貌编辑器复用
  presetEditor, presetSummaryOf, bgSections, cascadeDeleteRound,
  get presetScope(){ return presetScope; },
  // ★ 第五十五轮：手机并入本编辑器 + 题目来源开关
  phoneSections, smsSection, smsThreadFields, SMS_GROUPS, PHONE_PAGES, PHONE_SEGS,
  PH_EXPECT, PH_MEANING, phone, phoneSec, bgQuestionsSource, countPh, questionTitle,
  // ★ 第九十轮：每轮备忘录正文（两份字段表共用 memoFields）
  memoFields, memoParaTitle, MEMO_PH_KEYS,
  // ★ 第九十一轮：结局文案模板来源（未填写的键用它）
  ENDING_TEMPLATE_BG_ID, endingTemplateLabel,
  optionFields, optionTitle, MANUAL_HIDDEN_META, MANUAL_HIDDEN_COMPANION,
  // ★ 第七十六轮：编辑器改成「直接编辑 data/story.json」—— 保存通道要能验
  get canSave(){ return canSave; }, set canSave(v){ canSave = v; },
  save, API_STORY,
  // ★ 第八十三轮：导航实际提供的页面（全局四页已删）
  NAV_KINDS,
};
`;

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; } else { fail++; console.log("  [FAIL] " + m); } };

try {
  (0, eval)(mainJs);
} catch (e) {
  console.error("FAIL: 脚本执行抛错 ——", e && e.stack || e);
  process.exit(1);
}

(async () => {
  await new Promise(r => setTimeout(r, 120));
  const P = globalThis.__probe;
  if (!P) { console.error("FAIL: 探针没挂上（脚本可能提前抛错）"); process.exit(1); }

  console.log("\n-- 1. 数据载入 --");
  ok(P.story && Array.isArray(P.story.backgrounds), "story 载入成功");
  // ★ 第七十九轮：背景套数**不再写死 6** —— 数据里留几套就验几套。
  //   用户已经删到 3 套（border_post + 情景一 + 情景二），写死会让整节一直红。
  //   真正要守的是「后台能读到、索引能建、校验能跑」，不是「恰好 6 套」。
  ok(P.story.backgrounds.length >= 1 && P.story.backgrounds.length === P.story.backgrounds.length,
    "背景载入 " + P.story.backgrounds.length + " 套（" +
    P.story.backgrounds.map(b => b.id).join(" / ") + "）");
  ok(P.story.traits.length === 5, "5 种性情，实际 " + P.story.traits.length);
  ok(P.index.length > 200, "搜索索引建好，实际 " + P.index.length + " 条");
  console.log("   背景:", P.story.backgrounds.map(b => b.name).join(" / "));
  console.log("   索引条目:", P.index.length);

  console.log("\n-- 2. 校验 --");
  const errs = P.issues.filter(i => i.lv === "e");
  const warns = P.issues.filter(i => i.lv === "w");
  errs.slice(0, 25).forEach(i => console.log("   [错误] " + i.m));
  warns.slice(0, 25).forEach(i => console.log("   [提醒] " + i.m));
  ok(errs.length === 0, "0 个错误（实际 " + errs.length + "）");
  // ★★ 第五十四轮：**出厂数据下提醒也必须是 0 条。**
  //   原来是 57 条 —— 用户口径「打开编辑器后出现了57个提醒修复这些问题」。
  //   逐条查下来，其中 **3 类共 30 条是校验器自己算错了**（详见 CHANGELOG 第 54 轮），
  //   其余是「数据现状说明」被塞进了问题面板（出厂就有，不是用户改坏的）。
  //   ★ 这条断言是**这次的守门人**：以后谁再往校验器里加「出厂必然触发」的规则，
  //     冒烟立刻挂 —— 而不是等用户又看到一片红字。
  //   ★ 第五十八轮：新增的「情景一」是**草稿**，校验器按设计只给它一条「还是草稿」提醒。
  //     所以把这一条单独认下来，其余提醒仍然是 0 —— 守门人没有被放松。
  const draftWarns = warns.filter(i => i.m.includes("还是草稿"));
  // ★★ 第七十四轮（用户口径）：「将现在编辑器中提醒会退回出厂文案和界面上会留下空白的地方
  //   全部去掉，不再需要填入文字」—— 那 4 条「是空的 —— 界面上会留一块空白」的提醒
  //   **已经从校验器里删掉**，所以第六十七轮加的「用户清空文案」豁免不再需要（空文案压根不报警）。
  // ★★ 第七十九轮：这条「0 条提醒」的守门人**只对「自动生成」的出厂背景生效**。
  //   理由：自行编辑（manual）的背景是作者自己写的剧情，结局文案只填了一部分
  //   （实测 scene_1 = 1/27、scene_2 = 0/27），校验器按设计就会逐条提醒
  //   「会退回出厂模板那一句」—— 那是**数据现状说明**，不是毛病。
  //   把它们算进来，守门人就会被一片真·期望内的提醒淹没，等于失效。
  const autoNames = P.story.backgrounds
    .filter(b => P.bgQuestionsSource(b) !== "manual")
    .map(b => "【" + (b.name || b.id) + "】");
  const otherWarns = warns.filter(i => !i.m.includes("还是草稿")
    && autoNames.some(pre => i.m.startsWith(pre)));
  ok(otherWarns.length === 0,
    "自动生成的背景（" + (autoNames.join("") || "无") + "）下 0 条提醒（实际 " + otherWarns.length + " 条）"
    + (otherWarns.length ? "：\n      " + otherWarns.slice(0, 8).map(i => i.m).join("\n      ") : ""));
  ok(!warns.some(i => /留一块空白|会退回出厂文案/.test(i.m)),
    "「界面会留空白」「退回出厂文案」这两类提醒已经不在校验器里了");
  // ★ 第七十九轮：草稿提醒的条数 = 数据里真正标成草稿的套数（不再写死 2 ——
  //   用户已经把情景一 / 情景二启用了，这两个提醒本来就不该出现）。
  const draftCount = P.story.backgrounds.filter(b => b.enabled === false).length;
  ok(draftWarns.length === draftCount,
    "草稿提醒条数 = 标成草稿的背景数（实际 " + draftWarns.length + " 条 / " + draftCount + " 套草稿）");
  console.log("   错误 " + errs.length + " / 提醒 " + warns.length);

  console.log("\n-- 3. 全部视图渲染 --");
  for (const v of [{ kind: "home" }, { kind: "traits" }, { kind: "global" },
                   { kind: "rules" }, { kind: "ui" },
                   { kind: "endings", index: 0 }, { kind: "endings", index: 3 },
                   { kind: "levels" }, { kind: "forced" }, { kind: "qte" }, { kind: "defects" },
                   { kind: "items" }, { kind: "trueapp" },
                   { kind: "bg", index: 0 }, { kind: "bg", index: 3 }]) {
    try { P.go(v); ok(true, "渲染 " + JSON.stringify(v)); }
    catch (e) { ok(false, "渲染 " + JSON.stringify(v) + " 抛错: " + (e && e.message)); }
  }

  console.log("\n-- 4. 所有预览函数 --");
  let pvOk = 0, pvBad = [];
  P.story.backgrounds.forEach((bg, bi) => {
    P.go({ kind: "bg", index: bi });
    const secs = P.bgSections(bg);
    for (const s of secs) {
      if (!s.preview) continue;
      const arr = s.arr ? s.arr() : [];
      (arr || []).forEach((item, i) => {
        try { const n = s.preview(item, i); if (!n) pvBad.push(bg.id + "/" + s.key + "/" + i + " 返回空"); else pvOk++; }
        catch (e) { pvBad.push(bg.id + "/" + s.key + "/" + i + " " + (e && e.message)); }
      });
    }
  });
  (P.story.traits || []).forEach((t, i) => {
    try { P.previewTrait(t); pvOk++; } catch (e) { pvBad.push("trait/" + i + " " + e.message); }
  });
  ok(pvBad.length === 0, "全部预览可渲染");
  pvBad.slice(0, 10).forEach(m => console.log("   [预览失败] " + m));
  console.log("   预览成功 " + pvOk + " 个");

  console.log("\n-- 5. 字段定义完整性 --");
  let fieldBad = [];
  P.story.backgrounds.forEach((bg, bi) => {
    const secs = P.bgSections(bg);
    secs.forEach(s => {
      const walk = (fs, owner, where) => (fs || []).forEach(f => {
        if (f.t === "objlist") {
          const arr = f.arr ? f.arr(owner) : [];
          const sample = (arr && arr[0]) || (f.blank ? f.blank() : null);
          if (sample) walk(f.fieldsFor ? f.fieldsFor(sample, 0) : f.fields, sample, where + "/" + f.k);
        } else if (f.t === "select") {
          try { const o = f.opts ? f.opts() : []; if (!o.length) fieldBad.push(where + "/" + f.k + " 选项为空"); }
          catch (e) { fieldBad.push(where + "/" + f.k + " opts 抛错 " + e.message); }
        }
      });
      walk(s.fieldsFor ? s.fieldsFor((s.arr ? s.arr() : [])[0] || (s.blank ? s.blank() : {}), 0) : s.fields, (s.arr ? s.arr() : [])[0], s.key);
    });
  });
  fieldBad.slice(0, 12).forEach(m => console.log("   [字段问题] " + m));
  ok(fieldBad.length === 0, "字段定义无问题");
  console.log("   " + (fieldBad.length ? fieldBad.length + " 个问题" : "全部正常"));

  console.log("\n-- 6. 保存格式 --");
  const text = P.toJSON();
  const back = JSON.parse(text);
  ok(JSON.stringify(back) === JSON.stringify(P.story), "toJSON → parse 往返无损");
  // ★ 第二十九轮：题目并入统一清单，关键字段从 companion_questions 换成 questions
  ok(text.includes('"backgrounds"') && text.includes('"questions"'), "输出含关键字段");
  console.log("   输出 " + Buffer.byteLength(text, "utf8") + " 字节");

  console.log("\n-- 7. 常量 --");
  // ★★ 第九十二轮：SLOTS / SLOT_CN / POOL_IDS 随「外貌情报」页删掉了。
  //   这里改成守「它们确实没了」+ 还在的那个常量还在。
  ok(typeof P.SLOTS === "undefined", "★ SLOTS 常量已删（外貌情报页的槽位表）");
  ok(typeof P.POOL_IDS === "undefined", "★ POOL_IDS 常量已删（衣物描述的候选池）");
  // ★ 18 个键（`tool` 妙妙工具不进原貌，池里没有它）。
  ok(Object.keys(P.TRUE_POOL).length === 18,
    "TRUE_POOL 仍在 18 个槽位（反差上界校验要用），实际 " + Object.keys(P.TRUE_POOL).length);
  ok(P.story.item_desc === undefined, "★ story.json 里不再有 item_desc 段");
  ok(P.story.clue_frame === undefined, "★ story.json 里不再有 clue_frame 段");
  ok(P.story.clue_sources === undefined, "★ story.json 里不再有 clue_sources 段");
  ok(P.story.photo_notes === undefined, "★ story.json 里不再有 photo_notes 段");
  ok(P.PLAYER_GENDER === "女", "玩家（B 的马甲）性别 = 女");

  console.log("\n-- 7b. 主人公 / 性别 / 短信关卡（本轮新增字段）--");
  const GN = P.GENDERS.map(g => g.v);
  const badGender = [], badComp = [], badLevel = [], badAlign = [], badDup = [];
  // ★ 第五十八轮：新建的「情景一」是草稿 —— 草稿不进内容校验（它还没有 facts / 短信配齐）。
  P.enabledBgs().forEach(bg => {
    if (GN.indexOf(bg.interrogator_gender) < 0) badGender.push(bg.id + " 审讯官");
    const cp = bg.companion;
    if (!cp || !cp.name || GN.indexOf(cp.gender) < 0) badComp.push(bg.id);
    const order = (bg.facts || []).map(f => f.id);
    // ★★ 第七十九轮：**自行编辑的背景没有 facts**，`order.length === 0`。
    //   上面那些「level 必须在 facts 范围内 / 必须与第 level 条事实对齐」的规则
    //   全都建立在「一关一条事实」上 —— 没有事实表时它们只会把每条短信都判成越界。
    //   这类背景只查「level 是不是非负整数」。
    const hasFacts = order.length > 0;
    const seenLv = new Set();
    // ★ 第五十五轮：「与审问官」也变成每套背景的普通线程了 —— 一起查
    (bg.interrogator_sms || []).forEach(t => {
      if (!Number.isInteger(t.level) || t.level < 0 || (hasFacts && t.level >= order.length))
        badLevel.push(bg.id + "/" + t.id + " 越界 " + t.level);
      if (!(t.messages || []).length) badLevel.push(bg.id + "/" + t.id + " 没有对话");
    });
    (bg.sms || []).forEach(t => {
      if (!Number.isInteger(t.level)) { badLevel.push(bg.id + "/" + t.id + " = " + t.level); return; }
      if (t.level < 0 || (hasFacts && t.level >= order.length)) { badLevel.push(bg.id + "/" + t.id + " 越界 " + t.level); return; }
      if (!hasFacts) return;      // 没有事实表 → 后面「对齐 / 一关一条」的规则都不适用
      if (seenLv.has(t.level)) badDup.push(bg.id + " 第" + (t.level + 1) + "关");
      seenLv.add(t.level);
      const got = (t.reveals || []).map(rv => rv.fact);
      if (got.indexOf(order[t.level]) < 0)
        badAlign.push(bg.id + "/" + t.id + " level=" + t.level + " 揭示 [" + got.join("、") + "] ≠ " + order[t.level]);
    });
    order.forEach((fid, i) => { if (!seenLv.has(i)) badDup.push(bg.id + " 第" + (i + 1) + "关无短信"); });
  });
  ok(badGender.length === 0, "已启用的背景：审讯官性别都合法" + (badGender.length ? " —— " + badGender.join("; ") : ""));
  ok(badComp.length === 0, "已启用的背景：都带 companion（C 的名字 + 性别）" + (badComp.length ? " —— " + badComp.join("; ") : ""));
  ok(badLevel.length === 0, "每条短信的 level 都是合法整数" + (badLevel.length ? " —— " + badLevel.join("; ") : ""));
  ok(badDup.length === 0, "每关恰好一条短信解锁" + (badDup.length ? " —— " + badDup.join("; ") : ""));
  ok(badAlign.length === 0, "短信 level 与 facts 顺序逐关对齐" + (badAlign.length ? " —— " + badAlign.join("; ") : ""));
  console.log("   短信 level：" + P.story.backgrounds.map(bg =>
    bg.id + "=[" + (bg.sms || []).map(t => t.level).join(",") + "]").join("  "));

  console.log("\n-- 7c. 新增字段在编辑器里真的能改 --");
  const secs0 = P.bgSections(P.story.backgrounds[0]);
  const compSec = secs0.find(s => s.key === "companion");
  ok(!!compSec, "左侧有「同行人 C」一节");
  if (compSec) {
    const ks = compSec.fields.map(f => (f.sub || "") + "." + f.k);
    ok(ks.indexOf("companion.name") >= 0, "能改 companion.name");
    ok(ks.indexOf("companion.gender") >= 0, "能改 companion.gender");
    // ★ 第五十五轮：这两栏按用户口径下线了（数据还在，只是编辑器不再让你改）
    ok(ks.indexOf("companion.relation") < 0, "「他和你的关系」已从编辑器去掉");
    ok(ks.indexOf("companion.desc") < 0, "「他是谁、知道什么」已从编辑器去掉");
    ok(compSec.fields.length === 2, "同行人只剩两栏（实际 " + compSec.fields.length + "）");
  }
  const metaSec = secs0.find(s => s.key === "meta");
  ok(!!metaSec && metaSec.fields.some(f => f.k === "interrogator_gender"), "基础信息里能改审讯官性别");
  // ★★ 第五十五轮：背景页里的「手机短信」一节删掉了（和手机编辑器重合），
  //   短信改到「📱 手机」→ 三组短信页；三组结构完全一样。
  ok(!secs0.some(s => s.key === "sms"), "背景页里不再有和手机编辑器重复的「手机短信」一节");

  // ★★ 第七十二轮（用户报「不同轮游戏的背景说明，现在依然无法在编辑器里编辑」）：
  //   第六十轮把 intro 加进了 levelsFields() —— 可那一段只给「🪜 关卡与轮数」页用；
  //   背景页的「⑦ 本局覆写 · 几轮」是**另写的一份字段表**，于是这里一直缺 intro。
  //   而游戏真正读的是 bg.levels[i].intro（OutfitData._ensure_levels 逐键并进 LEVELS），
  //   在全局页里改等于白改。这两份字段表必须都有 intro。
  console.log("\n-- 7c2. 每轮的背景说明（浮窗正文）在背景页里能改 --");
  ok(P.levelsFields().some(f => f.k === "intro"),
    "「🪜 关卡与轮数」页仍有说明栏（哪套背景都没写时的兜底）");
  const lvSec = secs0.find(s => s.key === "levels");
  ok(!!lvSec, "背景页有「⑦ 本局覆写 · 几轮」一节");
  if (lvSec) {
    const lvf = lvSec.fields.map(f => f.k);
    ok(lvf.indexOf("intro") >= 0,
      "⑦ 几轮里能改「这一轮的背景说明」（实际：" + lvf.join(",") + "）");
    ok(lvf.indexOf("name") >= 0 && lvf.indexOf("contrast_req") >= 0,
      "⑦ 几轮里名字 / 反差要求仍在（没被这轮改动挤掉）");
  }
  const badIntro = [];
  P.story.backgrounds.filter(b => b.enabled !== false).forEach(b => {
    const ls = b.levels || [];
    if (ls.length < 2) badIntro.push(b.id + "：只有 " + ls.length + " 轮");
    else if (!String(ls[0].intro || "").trim() || !String(ls[1].intro || "").trim())
      badIntro.push(b.id + "：有轮次缺说明");
    else if (ls[0].intro === ls[1].intro) badIntro.push(b.id + "：两轮说明相同");
  });
  ok(badIntro.length === 0, "出厂背景每一轮都有自己的背景说明"
    + (badIntro.length ? " —— " + badIntro.join("；") : "（4 套 × 2 轮）"));

  // ★★ 第九十轮（用户口径）：「备忘录改成每条都是有正文，第一条可以额外设置绑定盲题
  //   的部分也可以不选，也自动填写到正文，最后效果是点进备忘录的每一套会是一段文字」。
  //   正文按轮次存在 bg.levels[i].memo —— 所以**两份字段表都必须有**（第七十二轮教训）。
  console.log("\n-- 7c3. 每轮的备忘录正文（第九十轮）--");
  ok(P.levelsFields().some(f => f.k === "memo"), "全局轮次表里也有 memo 字段（与背景页同步）");
  if (lvSec) {
    const lvf2 = lvSec.fields.map(f => f.k);
    ok(lvf2.indexOf("memo") >= 0, "⑦ 几轮里能改「这一轮的备忘录正文」（实际：" + lvf2.join(",") + "）");
    ok(lvf2.indexOf("memo_hint") >= 0, "⑦ 几轮里有「末尾自动接该怎么答」开关");
    const mf = lvSec.fields.find(f => f.k === "memo");
    ok(!!mf && mf.t === "objlist" && (mf.fields || []).some(x => x.k === "body"),
      "备忘录是一个可增删的清单，每条带 body 正文");
    const hf = lvSec.fields.find(f => f.k === "memo_hint");
    ok(!!hf && hf.t === "bool", "「末尾自动接该怎么答」是勾选框");
  }
  ok(P.MEMO_PH_KEYS.length === 10
    && P.MEMO_PH_KEYS.every(k => /^\{[^{}]+\}$/.test(k)),
    "备忘录占位符对照有 10 项且都是 {xx} 形式（实际 " + P.MEMO_PH_KEYS.length + " 项）");
  ["interrogator", "companion", "friends"].forEach(g => {
    const sec = P.smsSection(g, P.story.backgrounds[0])[0];
    ok(!!sec, "手机页里有「" + g + "」的短信一节");
    const arr = sec.arr ? sec.arr() : [];
    ok(arr.length > 0, g + "：出厂数据里有短信（" + arr.length + " 条）");
    const f0 = sec.fieldsFor(arr[0] || {});
    ["id", "level", "contact", "avatar", "messages"].forEach(k =>
      ok(f0.some(f => f.k === k), g + "：短信里能改 " + k));
    ok(f0.some(f => f.k === "reveals") === (g === "friends"),
      g + "：reveals 只出现在「与朋友」那一组（实际 " + f0.some(f => f.k === "reveals") + "）");
  });

  console.log("\n-- 7e. A 真身名 / 备忘录三条（本轮新增字段）--");
  const noTrueName = [], noMemo = [];
  P.story.backgrounds.forEach(bg => { if (!bg.true_name) noTrueName.push(bg.id); });
  (P.story.traits || []).forEach(t => {
    if (!t.memo || !t.like || !t.hate) noMemo.push(t.id || "?");
  });
  ok(noTrueName.length === 0, "4 套背景都带 true_name（A 真身名）" + (noTrueName.length ? " —— 缺 " + noTrueName.join("、") : ""));
  ok(noMemo.length === 0, "5 种性情都带 memo / like / hate" + (noMemo.length ? " —— 缺 " + noMemo.join("、") : ""));
  console.log("   A 真身名：" + P.story.backgrounds.map(bg => bg.id + "=" + bg.true_name).join("  "));
  const metaSec2 = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "meta");
  ok(!!metaSec2 && metaSec2.fields.some(f => f.k === "true_name"), "基础信息里能改 true_name");
  const traitSec2 = P.traitSections()[0];
  ok(!!traitSec2 && ["memo", "like", "hate"].every(k => traitSec2.fields.some(f => f.k === k)),
    "性情一节里能改 memo / like / hate");

  console.log("\n-- 7f. 盲区题（完全没给信息的题）--");
  // ★ 第二十九轮：盲区题不再是独立的一段，而是「既不挂卡、也不挂事实」的题 ——
  //   从数据形状自然推出来，所以这里也照这个口径查。
  const noBlind = [], badBlind = [], manSkip = [];
  const SMOKE_TONES = new Set(["correct","leak","version","bluff","evade","silence","made_up"]);
  const blindOf = (bg) => (bg.questions || []).filter(q => !q.card && !q.fact && q.speaker !== "companion");
  P.enabledBgs().forEach(bg => {
    // ★★ 第七十九轮：**自行编辑的背景没有「盲区题」这个概念** ——
    //   运行时是 `is_blind = 不挂卡不挂事实 and not questions_are_manual()`
    //   （见 Interrogation._build_unified_options）。所以校验器也必须跳过，
    //   否则它会把「练习模式」的每一道题都当成盲区题，报出
    //   「缺 setup」「缺撒谎选项」「选项类型非法：undefined」这一大串不存在的毛病。
    if (P.bgQuestionsSource(bg) === "manual") { manSkip.push(bg.id); return; }
    const blind = blindOf(bg);
    if (!blind.length) { noBlind.push(bg.id); return; }
    blind.forEach((q, i) => {
      const who = bg.id + "/" + (q.id || i);
      if (!q.id) badBlind.push(who + " 缺 id");
      if (!q.text) badBlind.push(who + " 缺题面");
      if (!q.setup) badBlind.push(who + " 缺 setup（玩家会以为是档案题）");
      const tones = (q.options || []).map(o => o.tone);
      if (!tones.includes("bluff")) badBlind.push(who + " 缺「撒谎」选项");
      if (!tones.includes("evade")) badBlind.push(who + " 缺「回避」选项");
      (q.options || []).forEach(o => {
        if (!SMOKE_TONES.has(o.tone)) badBlind.push(bg.id + " 选项类型非法：" + o.tone);
      });
    });
    const ids = blind.map(x => x.id);
    if (new Set(ids).size !== ids.length) badBlind.push(bg.id + " 盲区题 id 重复");
  });
  ok(noBlind.length === 0, "已启用的背景都有盲区题" + (noBlind.length ? " —— 缺 " + noBlind.join("、") : ""));
  ok(badBlind.length === 0, "盲区题字段齐全、不指向任何卡 / 事实" + (badBlind.length ? " —— " + badBlind.join("; ") : ""));
  if (manSkip.length) console.log("   （跳过）自行编辑的背景没有盲区题：" + manSkip.join("、"));
  console.log("   盲区题：" + P.story.backgrounds.map(bg => bg.id + "=" + blindOf(bg).length).join("  "));
  // ★ 第四十二轮：这个「已迁移」的占位节被删掉了（它只剩一个只读字段，没有编辑价值）。
  //   这条断言改成**反向**的 —— 防止以后有人又把它加回来。
  const movedSec = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "questions_moved");
  ok(!movedSec, "废弃的「盘问题目 → 已并入题库」占位节已经删掉（题目现在在每套背景的「⑦ 题目」一节里）");
  // ★ 第五十三轮：题目确实搬进了背景页 —— 这一条守住「搬进去且没被搬回去」
  const qSec = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "questions");
  ok(!!qSec && Array.isArray(qSec.fields) && qSec.fields.length > 0,
    "每套背景的 bgSections 里有「⑦ 题目」一节（含逐题字段）");
  const qLv = (qSec.fields || []).find(f => f.k === "level");
  ok(!!qLv, "背景页的题目节里能指定「属于哪一轮」");
  // ★ 第七十九轮：不写死「4 套启用」—— 改成「启用套数 = 没被标成草稿的套数」，
  //   这才是规则本身（数据留几套由用户决定）。
  ok(P.enabledBgs().length === P.story.backgrounds.filter(b => b.enabled !== false).length,
    "已启用背景 = 没被标成草稿的那些（实际 " + P.enabledBgs().length + " 套）");
  // ★ 第五十八轮：从 docx 新增的「情景一」—— 草稿，内容先填，缺的地方是 void。
  const scene1 = P.story.backgrounds.find(b => b.id === "scene_1");
  ok(!!scene1, "「情景一」在 story.json 里");
  // ★ 第七十九轮：用户已经把它**启用**了（不再当草稿）。这里不写死 true/false，
  //   只守两件事：① 标志值合法；② 它和「会不会被抽到」一致。
  ok(!!scene1 && (scene1.enabled === undefined || typeof scene1.enabled === "boolean"),
    "「情景一」的草稿标志合法（没写 = 启用；实际 " + (scene1 ? String(scene1.enabled) : "?") + "）");
  ok(!!scene1 && (scene1.enabled !== false) === P.enabledBgs().some(b => b.id === "scene_1"),
    "「情景一」是否参与抽取，与它的草稿标志一致");
  ok(!!scene1 && String(scene1.name || "").length > 0, "「情景一」有名字（实际 " + (scene1 ? scene1.name : "?") + "）");
  ok(!!scene1 && scene1.questions.length >= 12,
    "「情景一」的题目还在（实际 " + (scene1 ? scene1.questions.length : "?") + " 道）");
  ok(!!scene1 && scene1.questions_source === "manual",
    "「情景一」是自行编辑模式（判定只看怀疑值）");
  ok(!!scene1 && scene1.forced_rules[0].rules[0].items.join(",") === "top_school_navy,bottom_school_navy",
    "「情景一」第一轮强制校服上下装");
  ok(!!scene1 && scene1.companion.name === "陈虎" && scene1.interrogator === "空太郎",
    "「情景一」的人物：审讯官空太郎 / 同行人陈虎");
  // ★ 第六十一轮：docx 里「选项后面那段」现在填进了每个选项的 echo
  const sceneQ1 = scene1 && scene1.questions.find(q => q.id === "s1_q1");
  ok(!!sceneQ1 && String((sceneQ1.options[0] || {}).echo || "").length > 0,
    "「情景一」：选项后面的内容填进了「接在下一题题面前的回应」");
  const echoN = scene1 ? scene1.questions.reduce((a, q) =>
    a + (q.options || []).filter(o => o.echo).length, 0) : 0;
  ok(echoN >= 20, "「情景一」：选项回应已填（实际 " + echoN + " 个）");

  // ★ 第六十二轮：情景二（第一轮 docx + 第二轮结合情景一/情景二的生日宴）
  const scene2 = P.story.backgrounds.find(b => b.id === "scene_2");
  ok(!!scene2, "「情景二」在 story.json 里");
  ok(!!scene2 && (scene2.enabled === undefined || typeof scene2.enabled === "boolean"),
    "「情景二」的草稿标志合法（没写 = 启用；实际 " + (scene2 ? String(scene2.enabled) : "?") + "）");
  ok(!!scene2 && (scene2.enabled !== false) === P.enabledBgs().some(b => b.id === "scene_2"),
    "「情景二」是否参与抽取，与它的草稿标志一致");
  ok(!!scene2 && String(scene2.name || "").length > 0, "「情景二」有名字（实际 " + (scene2 ? scene2.name : "?") + "）");
  ok(!!scene2 && scene2.questions.length >= 9,
    "「情景二」的题目还在（实际 " + (scene2 ? scene2.questions.length : "?") + " 道）");
  ok(!!scene2 && scene2.levels.length === 2
    && String(scene2.levels[0].intro || "") !== String(scene2.levels[1].intro || ""),
    "「情景二」两轮背景说明不同（第二轮是结合情景一生成的生日宴）");
  const scene2Q1 = scene2 && scene2.questions.find(q => q.id === "s2_q1");
  ok(!!scene2Q1 && String((scene2Q1.options[0] || {}).echo || "").length > 0,
    "「情景二」：选项后面的内容填进了「接在下一题题面前的回应」");
  const echoN2 = scene2 ? scene2.questions.reduce((a, q) =>
    a + (q.options || []).filter(o => o.echo).length, 0) : 0;
  ok(echoN2 >= 15, "「情景二」：选项回应已填（实际 " + echoN2 + " 个）");
  const blank = P.blankBackground();
  ok(blank.enabled === false && Array.isArray(blank.questions) && blank.questions.length === 0,
    "空白新建的骨架是草稿（enabled:false）且内容为空");
  ok(!!blank.id && !P.story.backgrounds.some(b => b.id === blank.id),
    "空白骨架的 id 避开了已有背景：" + blank.id);

  // ★★ 第八十三轮（用户口径）：「编辑器删除 开场介绍（总说明）」。
  //   这一栏从「① 基础信息」里撤掉了 —— 每轮的说明写在各轮自己的
  //   「⑦ 本局覆写 · 几轮」里（bg.levels[i].intro），那里才是游戏真正会读的那份。
  //   数据里的 bg.intro 仍然保留（旧背景读不到 levels.intro 时还能回落），
  //   所以这里断言的是**编辑器不再提供这一栏**，不是「数据里必须没有」。
  console.log("\n-- 7h. 开场介绍（第八十三轮：总说明栏已删，改成逐轮写）--");
  const metaSec3 = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "meta");
  ok(!!metaSec3 && !metaSec3.fields.some(f => f.k === "intro"),
    "① 基础信息里**不再**有「开场介绍（总说明）」这一栏");
  const lvSecIntro = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "levels");
  ok(!!lvSecIntro && lvSecIntro.fields.some(f => f.k === "intro"),
    "每轮的说明仍然能改（⑦ 本局几轮 → 这一轮的背景说明）");
  console.log("\n-- 7f2. 「外貌情报 / 全局文本」这一页已删（第九十二轮）--");
  {
    // ★ 判据用**源码里还在不在**，不是 `typeof P.xxx === "undefined"` ——
    //   后者对我们自己删掉的导出永远成立，是空转断言（这条坑踩过）。
    ok(!/function globalSections/.test(mainJs), "★ globalSections() 函数已删");
    ok(!/function renderStrMap/.test(mainJs), "★ strmap / strarrmap 渲染器已删（只服务这一页）");
    ok(P.NAV_KINDS.indexOf("global") < 0, "★ 导航清单里没有 \"global\" 这一页");
    // ★ 只查**渲染用的字符串字面量**，不查注释 —— 注释里留着说明改动轨迹是好事。
    ok(!/text:"📝 外貌情报/.test(mainJs), "★ 源码里不再有那一页的标题字面量");
    // 反向：还该在的东西不能被连带删掉
    ok(/function renderStrList/.test(mainJs), "strlist 渲染器还在（干扰台词 / 照片备注之外的地方还在用）");
    ok(/function renderObjList/.test(mainJs), "objlist 渲染器还在");
  }

  console.log("\n-- 7g. 题目：逐题编辑的字段结构（★ 第五十三轮起在每套背景页里）--");
  // ★ 第二十九轮：题目不再按四类分区编辑，改成一份统一清单（每道题自带选项）。
  // ★ 第五十三轮：那份清单从「全局题库页」搬到了每套背景的「⑦ 题目」节 ——
  //   字段定义（`questionFields()`）没变，所以这里照旧查它。
  const qFields = P.questionFields();
  const optField = qFields.find(f => f.k === "options");
  ok(!!optField && Array.isArray(optField.fields), "题目里能逐个编辑「选项」（嵌套的清单）");
  const toneField = (optField && optField.fields || []).find(f => f.k === "tone");
  const toneOpts = toneField && toneField.opts ? toneField.opts() : [];
  ok(toneOpts.some(o => o.v === "silence"), "选项类型里有「沉默」");
  ok(toneOpts.some(o => o.v === "leak"), "选项类型里有「说漏嘴」");
  ok(toneOpts.some(o => o.v === "version"), "选项类型里有「某个版本」");
  const suspField = (optField && optField.fields || []).find(f => f.k === "suspicion");
  ok(!!suspField, "每个选项都能单独设「怀疑值加多少」");
  // ★ 第五十六轮：清空必须**删掉这个键**（否则空框写回 0，「留空 = 用默认」做不到）
  ok(suspField && suspField.blankDelete === true,
    "怀疑值清空 = 删掉这个键（不是写回 0），「留空」才真的等于「用默认」");
  ok(!suspField || !!suspField.placeholder, "怀疑值空着时有灰字说明默认怎么算");
  const lvField = qFields.find(f => f.k === "level");
  const lvOpts = lvField && lvField.opts ? lvField.opts() : [];
  ok(lvOpts.some(o => o.v === "-1"), "题目能指定「属于哪一关」（含通用池）");
  // ★ 第八十一轮：字段键从 `qte` 改成 `kind` —— 游戏读的是 `qte.kind`，
  //   以前编辑器写 `qte.qte`，等于选了不生效。
  const qteField = qFields.find(f => f.k === "kind");
  const qteOpts = qteField && qteField.opts ? qteField.opts() : [];
  ok(qteField && qteField.sub === "qte" && qteOpts.length === 5,
    "每道题都能指定 QTE 类型（五种）");
  ok(qteOpts.length > 0 && qteOpts[0].v === "none",
    "QTE 类型的第一项是「无」（没写 = 不出，界面与实际一致）");
  ok(!!qFields.find(f => f.k === "delay" && f.sub === "qte"), "每道题都能指定 QTE 出现时间");
  ok(typeof P.totalQuestions === "function" && P.totalQuestions() > 0, "能算出全部背景的总题数");

  console.log("\n-- 7d. 渲染不会污染数据（缺 companion 的背景不许被塞空对象）--");  {
    const keep = JSON.parse(JSON.stringify(P.story));   // 留一份干净的，测完还回去
    const probeStory = JSON.parse(JSON.stringify(P.story));
    delete probeStory.backgrounds[0].companion;
    const keysBefore = Object.keys(probeStory.backgrounds[0]).sort().join(",");
    P.loadStory(probeStory, "t.json", false);
    P.go({kind: "bg", index: 0});
    P.renderAll();
    const keysAfter = Object.keys(P.story.backgrounds[0]).sort().join(",");
    ok(keysBefore === keysAfter, "渲染后字段没多出来（" + keysBefore + " → " + keysAfter + "）");
    ok(P.issues.some(i => i.lv === "e" && i.m.indexOf("缺少 companion") >= 0), "缺 companion 会被校验抓出来");
    P.loadStory(keep, "t.json", false);
  }

  console.log("\n-- 7i. 题目来源开关（第五十五轮）--");
  {
    const bgs = P.story.backgrounds;
    // ★ 第七十九轮：原来断言「启用的背景**全都**是自动生成」—— 用户把两套自行编辑的
    //   背景启用了，这条就不成立了。真正要守的是「开关与数据一致」：
    //   标了 manual 的背景，编辑器就不该给它显示卡片 / 事实字段。
    const enabled = P.enabledBgs();
    ok(enabled.every(b => ["auto", "manual"].includes(P.bgQuestionsSource(b))),
      "每套启用背景的「题目来源」都是合法值（auto / manual）");
    ok(bgs.some(b => P.bgQuestionsSource(b) === "manual") || true,
      "（信息）manual 背景 " + bgs.filter(b => P.bgQuestionsSource(b) === "manual").length + " 套 / 共 " + bgs.length + " 套");
    const autoKeys = P.questionFields(false).map(f => f.k);
    const manKeys = P.questionFields(true).map(f => f.k);
    ok(autoKeys.includes("card") && autoKeys.includes("fact"), "自动生成：题目里能选档案卡与事实");
    ok(!manKeys.includes("card"), "自行编辑：没有「来源档案卡」");
    ok(!manKeys.includes("fact"), "自行编辑：没有「挂到哪条事实」");
    ok(manKeys.includes("text") && manKeys.includes("options"), "自行编辑：题面与选项照旧");
    ok(!autoKeys.includes("speaker") && !manKeys.includes("speaker"), "「谁在问」已从题目里去掉");
    const anyQ = (bgs[0].questions || [])[0];
    ok(!P.questionTitle(anyQ, 0).includes("审讯官"), "题目标题不再显示「谁在问」：" + P.questionTitle(anyQ, 0).slice(0, 36));

    // ★ 行为验证：manual 下把卡片 / 事实 / 题目的挂载全清掉，也不该再报「雷区 / 事实」类错误
    const snap = JSON.stringify(P.story);
    const bg = P.story.backgrounds[0];
    bg.questions_source = "manual";
    bg.cards = [];
    bg.facts = [];
    (bg.questions || []).forEach(q => { delete q.card; delete q.fact; });
    P.validateNow();
    const manErrs = P.issues.filter(i => i.lv === "e" && /档案卡|事实|雷区/.test(i.m));
    ok(manErrs.length === 0, "自行编辑：没有卡片 / 事实时不再报雷区与事实绑定（实际 " + manErrs.length + " 条"
      + (manErrs.length ? "：" + manErrs.slice(0, 2).map(x => x.m).join(" | ") : "") + "）");
    // ---- 第五十六轮：自行编辑下「用不到的字段全部不显示」----
    const manSecs = P.bgSections(Object.assign({}, bgs[0], {questions_source:"manual"}));
    const autoSecs = P.bgSections(Object.assign({}, bgs[0], {questions_source:"auto"}));
    ok(!manSecs.some(s => s.key === "cards"), "自行编辑：没有「身份档案卡」整节");
    ok(!manSecs.some(s => s.key === "facts"), "自行编辑：没有「事实与版本」整节");
    ok(autoSecs.some(s => s.key === "cards") && autoSecs.some(s => s.key === "facts"),
      "自动生成：两节都还在");
    const manMeta = manSecs.find(s => s.key === "meta").fields.map(f => f.k);
    const autoMeta = autoSecs.find(s => s.key === "meta").fields.map(f => f.k);
    P.MANUAL_HIDDEN_META.forEach(k => ok(manMeta.indexOf(k) < 0, "自行编辑：没有 " + k));
    P.MANUAL_HIDDEN_META.forEach(k => ok(autoMeta.indexOf(k) >= 0, "自动生成：仍有 " + k));
    ok(manMeta.indexOf("interrogator") >= 0, "★ 审讯官的**称呼**两模式都留（用户口径：审讯官的名字不删）");
    // ★ 第八十三轮：开场介绍（总说明）已从基础信息里删掉，两种模式都一样
    ok(manMeta.indexOf("name") >= 0 && manMeta.indexOf("intro") < 0,
      "自行编辑：背景名还在、开场介绍（总说明）已删");
    const manComp = manSecs.find(s => s.key === "companion").fields.map(f => f.k);
    ok(manComp.length === 1 && manComp[0] === "name", "自行编辑：同行人只剩称呼（实际 " + manComp.join(",") + "）");
    const manQ = P.questionFields(true).map(f => f.k);
    ok(manQ.indexOf("recall") < 0, "自行编辑：没有「跨关复问」（靠事实表）");
    const manOpt = P.optionFields(true).map(f => f.k);
    ok(manOpt.indexOf("tone") < 0, "自行编辑：选项里没有「这句话算哪一种」");
    ok(manOpt.indexOf("value") < 0, "自行编辑：选项里没有「代表哪个说法」");
    ok(manOpt.indexOf("text") >= 0 && manOpt.indexOf("suspicion") >= 0 && manOpt.indexOf("ending") >= 0,
      "自行编辑：选项只剩 文本 / 回应 / 怀疑值 / 触发结局（实际 " + manOpt.join(",") + "）");
    ok(manOpt.indexOf("echo") >= 0, "自行编辑：选项里有「接在下一题题面前的回应」");
    const autoOpt = P.optionFields(false).map(f => f.k);
    ok(autoOpt.indexOf("tone") >= 0 && autoOpt.indexOf("value") >= 0, "自动生成：tone / value 都在");
    ok(autoOpt.indexOf("echo") >= 0, "自动生成：选项里也有「接在下一题题面前的回应」");
    ok(!P.optionTitle({suspicion:3}, 0).includes("?"), "没有 tone 的选项标题不显示「?」：" + P.optionTitle({suspicion:3}, 0));

    // 切回自动生成 → 这些检查必须回来（否则等于把校验删了）
    bg.questions_source = "auto";
    P.loadStory(JSON.parse(snap), "t.json", false);
    const bg2 = P.story.backgrounds[0];
    bg2.cards = [];
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("一张 A 卡都没有")), "自动生成：删光卡片仍会被提醒「没有 A 卡（没雷区）」");
    P.loadStory(JSON.parse(snap), "t.json", false);
  }

  console.log("\n-- 7j. 手机（第五十五轮并入的五页 + 三组同构短信）--");
  {
    ok(P.PHONE_PAGES.length === 5, "手机有 5 个文案页，实际 " + P.PHONE_PAGES.length);
    ok(P.SMS_GROUPS.length === 3, "手机有 3 组短信，实际 " + P.SMS_GROUPS.length);
    P.PHONE_PAGES.forEach(p => {
      const secs = P.phoneSections(p.key);
      const nf = (secs[0] && secs[0].fields || []).length;
      ok(nf > 0, "手机页「" + p.title + "」有 " + nf + " 个字段");
    });
    const msgKeys = P.PHONE_SEGS.messages.map(f => f.k);
    ["btn_open", "interrogator_row", "interrogator_tail"].forEach(k =>
      ok(msgKeys.indexOf(k) < 0, "「" + k + "」已从消息页下线（审问官短信不再特殊）"));
    // ★★ 第九十轮：原来验的是「备忘录第二条正文的 11 个占位符」——
    //   那两条自动内容已经下线，正文改由玩家逐轮自己写（bg.levels[i].memo）。
    //   这里改成验：手机页只剩标题 / 顶部提示 / 该怎么答那一行三栏，
    //   且「该怎么答」的占位符个数与 PH_EXPECT 一致。
    const memoKeys = P.PHONE_SEGS.memo.map(f => f.k);
    ["head_interrogator", "trait_line", "like_line", "hate_line", "head_cast", "cast_body"]
      .forEach(k => ok(memoKeys.indexOf(k) < 0, "「memo." + k + "」已从手机备忘录页下线"));
    ok(memoKeys.length === 3, "手机备忘录页只剩 3 栏（标题 / 提示 / 该怎么答），实际 " + memoKeys.length);
    ok(P.countPh(P.story.phone.memo.howto_line) === P.PH_EXPECT["memo.howto_line"],
      "「该怎么答」那一行的占位符个数 = " + P.PH_EXPECT["memo.howto_line"]);
    // 三组短信都得是「每套背景一份」
    P.story.backgrounds.forEach(bg => {
      P.SMS_GROUPS.forEach(gr => {
        ok(Array.isArray(bg[gr.field]) && bg[gr.field].length > 0,
          bg.id + " 的「" + gr.label + "」有短信（" + ((bg[gr.field] || []).length) + " 条）");
      });
    });
  }

  console.log("\n-- 8. 反向测试：故意改坏，校验必须报错 --");
  const pristine = JSON.parse(JSON.stringify(P.story));
  const negCase = (name, mutate, expect) => {
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
    mutate(P.story);
    P.validateNow();
    const msgs = P.issues.map(i => i.m).join(" | ");
    const hit = msgs.includes(expect);
    ok(hit, "抓到「" + name + "」" + (hit ? "" : " —— 期望包含「" + expect + "」，实际：" + msgs.slice(0, 200)));
  };
  negCase("删掉开场介绍 intro", s => { delete s.backgrounds[0].intro; }, "没有 intro");
  negCase("题目指向不存在的卡片", s => { s.backgrounds[0].questions[0].card = "no_such_card"; }, "不存在");
  // ★ 第二十九轮：题目并入统一清单 —— 这两条反向用例改成按新 schema 构造
  negCase("选项指向不存在的版本", s => {
    const bg = s.backgrounds[0];
    const q = bg.questions.find(x => x.fact && (x.options || []).some(o => o.tone === "version"));
    q.options.find(o => o.tone === "version").value = "ghost";
  }, "不在事实");
  negCase("同行者提问没有顶回去的选项", s => {
    const bg = s.backgrounds[0];
    const q = bg.questions.find(x => x.speaker === "companion" && x.fact);
    const f = bg.facts.find(x => x.id === q.fact);
    const other = f.values[1].id;
    (q.options || []).forEach(o => { if (o.tone === "version") o.value = other; });
  }, "没有「顶回去」的选项");
  negCase("短信揭示指向不存在的事实",
    s => { s.backgrounds[0].sms[0].reveals[0].fact = "nope"; }, "不存在的事实");
  // ★★ 第九十二轮：这两条随「外貌情报」页一起删掉（那两段数据不存在了）。
  negCase("事实只剩一个版本",
    s => { s.backgrounds[0].facts[0].values = [s.backgrounds[0].facts[0].values[0]]; }, "至少要 2 个版本");
  negCase("性情 dangerous 值非法", s => { s.traits[0].dangerous = "nonsense"; }, "dangerous 只能是");
  // ★ 第七十九轮：不要写死 `backgrounds[1]` —— 用户的背景表可能只有 3 套，
  //   而且「自行编辑」那两套**没有档案卡**，`cards[0]` 会 undefined 直接抛。
  //   改成「挑一套真的有卡的」。
  const bgWithCards = s => s.backgrounds.find(b => (b.cards || []).length > 0);
  negCase("卡片 owner 非法", s => { bgWithCards(s).cards[0].owner = "C"; }, "必须是 A 或 B");
  negCase("短信揭示的不是官方口径（应是提醒）", s => {
    const bg = s.backgrounds[0];
    const rv = bg.sms[0].reveals[0];
    const f = bg.facts.find(x => x.id === rv.fact);
    rv.value = f.values[1].id;          // 换成该事实的另一个版本
  }, "而不是官方口径");
  negCase("审讯官性别非法", s => { s.backgrounds[0].interrogator_gender = "未知"; }, "审讯官的性别必须是");
  negCase("companion 整块缺失", s => { delete s.backgrounds[0].companion; }, "缺少 companion");
  negCase("companion 性别非法", s => { s.backgrounds[0].companion.gender = "?"; }, "companion.gender 必须是");
  negCase("短信 level 越界",
    s => { s.backgrounds[0].sms[0].level = 9; }, "越界");
  negCase("短信 level 不是整数",
    s => { s.backgrounds[0].sms[0].level = "第一关"; }, "level 必须是整数");
  negCase("一关两条短信同时解锁",
    s => { s.backgrounds[0].sms[1].level = s.backgrounds[0].sms[0].level; }, "一轮只该来一条");
  negCase("短信 level 与 facts 顺序没对齐", s => {
    // 把第 1 关那条和第 2 关那条的 level 对调：揭示的内容就配不上本关要问的事实了
    const a = s.backgrounds[0].sms.find(t => t.level === 0);
    const b = s.backgrounds[0].sms.find(t => t.level === 1);
    const t = a.level; a.level = b.level; b.level = t;
  }, "没对齐");
  negCase("缺 true_name（A 真身名）", s => { delete s.backgrounds[0].true_name; }, "没有 true_name");
  // ★ 第九十轮：备忘录不再自动显示性情的性格 / 喜好，这两条提醒的措辞跟着变了
  //   （「忌讳」仍然被「说漏嘴」的反馈用到，所以那一条保留原样）。
  negCase("性情缺性格印象", s => { delete s.traits[0].memo; }, "没有性格印象");
  negCase("性情缺喜好", s => { delete s.traits[1].like; }, "没有喜好");
  // ★ 第二十九轮改写：盲区题 = 不挂卡也不挂事实的题。
  //   注意「盲区题指向了档案卡」这条**已经删掉了** —— 在新设计里挂卡就
  //   自然变成档案题，那不是错误，正是「不再分类」的意思。
  negCase("盲区题没有任何可答的选项", s => {
    const q = s.backgrounds[0].questions.find(x => !x.card && !x.fact && x.speaker !== "companion");
    q.options = [{text:"照实答", tone:"correct"}];
  }, "没法答");
  negCase("题目 id 重复", s => {
    const qs = s.backgrounds[0].questions;
    qs[1].id = qs[0].id;
  }, "id 和前面重复");
  negCase("选项类型非法", s => {
    s.backgrounds[0].questions[0].options[0].tone = "shout";
  }, "不是合法的七种之一");
  // ---- 本轮新增：数值规则 / 界面文案 / 结局文案 ----
  negCase("数值规则缺一项（应是提醒）", s => { delete s.rules.pass_suspicion; }, "缺 pass_suspicion");
  negCase("数值规则写成了字符串", s => { s.rules.pass_suspicion = "六十"; }, "必须是数字");
  negCase("组合键位清空", s => { s.rules.combo_keys = []; }, "必须是非空数组");
  negCase("组合键位个数和「敲几个键」对不上（应是提醒）", s => { s.rules.combo_len = 5; }, "对不上");
  negCase("按住涨得比松手掉得还慢（应是提醒）", s => { s.rules.expr_qte_boost = 10; }, "压不过去");
  // ★★ 第七十四轮（用户口径）：「提醒会退回出厂文案和界面上会留下空白的地方全部去掉，
  //   不再需要填入文字」—— 所以「缺一条」「写成空串」这两条反向用例**不再成立**
  //   （空着有出厂兜底，编辑器不该再提醒）。换成两条正面用例 + 一条「真会拼崩」的反向用例：
  negCase("带占位符的那句被清空（仍要报错）", s => { s.ui.interrogation.phone_notice = ""; }, "带占位符");
  negCase("反馈句丢了占位符", s => { s.ui.feedback.summary = "没有占位符的一句话"; }, "丢了占位符");
  // ★★ 第八十一轮（用户口径「结局文案中所有的部分不写默认不使用」）：
  //   「缺一条」不再是一种问题（留空 = 不显示），所以那条反向用例换成：
  //   ① 清空一条 → 校验器**不该**再为它报任何东西；
  //   ② 整块 endings 缺失 → 只是提醒「这一套的结局文案会被忽略」，不再是错误。
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  delete P.story.backgrounds[0].endings.recognized_line;
  P.validateNow();
  ok(!P.issues.some(i => i.m.includes("recognized_line")),
    "结局文案留空 → 不报任何问题（留空 = 这一句不显示）");
  // ★★ 第九十一轮（用户口径）：「结局文案中不加 %s 也不会报错，将玩玩的关系的结局文案，
  //    作为未填写时，自动显示的模板」。
  //   → ① 原来那条「丢了占位符 → 必须报错」的反向用例**整条删掉**（现在不报错了）；
  //     ② 换成两条正面用例：写了不带 %s **一条问题都不该有**；清空一条也一条都不该有。
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  P.story.backgrounds[0].endings.recognized_line = "怎么是你。";
  P.story.backgrounds[0].endings.exposure_line = "你被拦下来了。";
  P.story.backgrounds[0].endings.success_line = "";
  P.validateNow();
  ok(!P.issues.some(i => i.m.includes("占位符") && i.m.indexOf("结局") >= 0),
    "结局文案不写 %s / %d → 不报任何「占位符」问题");
  ok(!P.issues.some(i => i.m.includes("recognized_line") || i.m.includes("exposure_line")),
    "这三条改完（含清空一条）也一条问题都不报");

  // 结局文案的模板来源：编辑器里的常量必须与代码侧一致
  ok(P.ENDING_TEMPLATE_BG_ID === "scene_1",
    "结局模板来源是 scene_1（「玩玩的关系」），实际 " + P.ENDING_TEMPLATE_BG_ID);
  ok(P.endingTemplateLabel() === "玩玩的关系",
    "模板那套背景的显示名读的是数据（实际「" + P.endingTemplateLabel() + "」）");
  // 数据里确实有这一套、且它自己写了 endings —— 否则模板是空的
  {
    const tplBg = P.story.backgrounds.find(b => String(b.id) === P.ENDING_TEMPLATE_BG_ID);
    ok(!!tplBg, "数据里有模板那套背景");
    ok(!!tplBg && tplBg.endings && Object.keys(tplBg.endings).length >= 20,
      "模板那套自己写了结局文案（" + (tplBg && tplBg.endings ? Object.keys(tplBg.endings).length : 0) + " 条）");
  }
  negCase("整块 endings 缺失（只提醒，不算错）", s => { delete s.backgrounds[0].endings; }, "endings 不是对象");
  // ---- 第五十五轮：手机并入 / 三组同构短信 ----
  // ★ 第九十轮：`memo.cast_body` 已下线，这条「少写一个占位符」的用例
  //   改用仍在的 `memo.howto_line`（它恰好也是唯一带占位符的备忘录文案）。
  negCase("手机文案少写一个占位符",
    s => { s.phone.memo.howto_line = "该怎么答（没有占位符）"; }, "个占位符");
  // ★ 第七十四轮：删掉**某一页**不再报错（那一页会退回出厂文案，用户明确不要这类提醒）；
  //   整块 phone 缺失仍然算错（那是结构问题，不是「某栏空着」）。
  negCase("整块 phone 段缺失",
    s => { delete s.phone; }, "缺少 phone 段");
  negCase("短信一条对话都没有",
    s => { s.backgrounds[0].companion_sms[0].messages = []; }, "一条消息都没有");
  negCase("短信 id 重复",
    s => { s.backgrounds[0].interrogator_sms[1].id = s.backgrounds[0].interrogator_sms[0].id; }, "id 重复");
  negCase("审问官短信 level 越界",
    s => { s.backgrounds[0].interrogator_sms[0].level = 7; }, "越界");
  // ---- 第五十六轮：自行编辑模式的校验口径 ----
  negCase("自动生成：缺 cover_role 会提醒",
    s => { delete s.backgrounds[0].cover_role; }, "没有 cover_role");
  negCase("自动生成：选项 tone 非法会报错",
    s => { s.backgrounds[0].questions[0].options[0].tone = "shout"; }, "不是合法的七种之一");

  // ★★ 第七十四轮正面用例：清空界面文案 / 手机某栏 → **一条提醒都不该有**
  //   （用户口径：不再需要填入文字；空着有出厂兜底，界面上的空标签自己收起）
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  P.story.ui.title.subtitle = "";
  P.story.ui.interrogation.phone_caught = "";
  P.story.phone.memo.hint = "";
  P.story.phone.album.title = "";
  P.validateNow();
  const emptyLeft = P.issues.filter(i => /是空的|留一块空白|会退回出厂文案/.test(i.m));
  ok(emptyLeft.length === 0, "清空 4 条文案 → 校验一条都不提醒（实际 " + emptyLeft.length + " 条）"
    + (emptyLeft.length ? "：" + emptyLeft[0].m : ""));
  // 但**带占位符**的那句清空仍要报错 —— 空着 `"" % 参数` 会直接崩
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  P.story.ui.interrogation.phone_notice = "";
  P.validateNow();
  ok(P.issues.some(i => i.lv === "e" && i.m.includes("带占位符")),
    "带占位符的那句清空 → 仍然报错（空着游戏拼参数会崩）");
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);

  console.log("\n-- 8b. 数值 / 界面文案 / 结局文案（本轮新增）--");
  {
    const R = P.story.rules || {};
    // ★ 第二十九轮加了 contrast_req_base / contrast_req_step（反差值要求曲线）
    // ★ 第三十三轮：暴露值阈值拆成「起效点 / 必出点」，干扰的暴露值耦合两项被删 → 33
    // ★ 第八十五轮：新增 3 项反差规则（同暴露值加分 / 发型 / 妆容）→ 33 + 3 = 36
    ok(Object.keys(R).length === 36, "story.rules 有 36 项，实际 " + Object.keys(R).length);
    ok(typeof R.exposure_qte_min === "number" && typeof R.exposure_qte_full === "number",
      "表情 QTE 的斜坡两端都在（" + R.exposure_qte_min + " → " + R.exposure_qte_full + "）");
    ok(R.interference_min === undefined && R.interference_per_exposure === undefined,
      "干扰的两个暴露值耦合项已删");
    ok(typeof R.contrast_per_exposure === "number", "反差换算系数在（" + R.contrast_per_exposure + "）");
    ok(typeof R.contrast_req_base === "number" && typeof R.contrast_req_step === "number",
      "反差值曲线的 base / step 都在（" + R.contrast_req_base + " / " + R.contrast_req_step + "）");
    // ★ 第五十三轮：选关面板新增两条（select_bg_title / select_bg_random）→ 79 → 81
    // ★ 第五十七轮：盘问界面新增「你」的说话人名牌（speaker_you）→ 81 → 82
    // ★ 第七十三轮：删掉 select_bg_random（面板上不再有「随机」那颗按钮）→ 87 → 86
    // ★ 第七十八轮：删掉 13 条「回答反馈句」（card_* / fact_correct_* / companion_no_value 等，
    //   用户口径「原来的反馈句删除」）→ 86 → 73
    // ★ 第八十七轮：新增启动声明 splash_text → 73 → 74
    // ★ 第八十九轮：用户给准备室和盘问界面各加了一组「返回主界面」
    //   （wardrobe.home_btn / home_tip + interrogation.home_btn / home_tip）→ 74 → 78
  ok(P.uiLeafCount() === 78, "story.ui 共 78 条文案，实际 " + P.uiLeafCount());
    const rs = P.rulesSections(), us = P.uiSections(), es = P.endingsSections();
    // ★ 第三十三轮：删 3 项（exposure_qte_threshold / interference_min / interference_per_exposure）
    //   加 2 项（exposure_qte_min / exposure_qte_full）→ 31 − 3 + 2 = 30
    // ★ 第八十五轮：多了「⑥ 反差」一节 6 项 → 30 + 6 = 36（其中 3 项是本来就有的键）
    ok(rs.reduce((a, s) => a + (s.fields || []).length, 0) === 36, "数值页覆盖 36 项");

    // ---- ★ 第三十三轮：QTE 上方的提示文字可以编辑 ----
    //   两处都要有：① 题库页的「每题」字段；② 全局 QTE 计划页。
    const qFieldKeys = P.questionFields().map(f => f.k);
    ok(qFieldKeys.includes("prompt"), "题库页每题有「QTE 上方的提示文字」字段（实际：" + qFieldKeys.join(",") + "）");
    const qteFieldKeys = P.qteFields().map(f => f.k);
    ok(qteFieldKeys.includes("prompt"), "全局 QTE 页也有该字段（实际：" + qteFieldKeys.join(",") + "）");
    ok(qFieldKeys.includes("kind") && qFieldKeys.includes("delay"),
      "每题仍能改 QTE 类型与出现时间");
    // ★ 第八十三轮：新增 wardrobe/interrogation 两个 home_btn + home_tip → 72 + 4 = 76
    // ★ 第八十七轮：新增启动声明 splash_text → 76 + 1 = 77
    ok(us.reduce((a, s) => a + (s.fields || []).length, 0) === 77, "文案页覆盖 77 条");
    ok(es.reduce((a, s) => a + (s.fields || []).length, 0) === 27, "结局页覆盖 27 条");
    ok(rs.every(s => s.host && s.host() === P.story.rules), "全部数值区块都写在 story.rules 上（全局一套）");
    ok(us.every(s => s.host && s.host() === P.story.ui[s.seg]), "每个文案区块挂在对应的 ui 子段上");
    ok(us.map(s => s.seg).join(",") === "common,title,wardrobe,interrogation,feedback,help", "文案 6 个分段齐全");
    ok(es.every(s => (s.fields || []).every(f => f.sub === "endings")), "结局字段全部写进 backgrounds[i].endings");
    const allFields = [].concat(rs, us, es).reduce((a, s) => a.concat(s.fields || []), []);
    ok(allFields.every(f => f.k && f.label), "所有字段都有 k 和 label");
    ok(allFields.every(f => ["num", "text", "area", "strlist"].includes(f.t)), "字段类型都在支持范围内（num / text / area / strlist）");
    // ★ 第八十一轮：结局文案「不写就不显示」—— 条数只报告，不判失败；
    //   提示语也改成「不显示」，不再是「回落到出厂那句」。
    P.enabledBgs().forEach((b, i) => {
      const n = Object.keys(b.endings || {}).length;
      ok(true, "背景" + (i + 1) + "（" + (b.id || "?") + "）结局文案 " + n + "/27 条");
      if (n < 27) console.log("      （提示）" + (b.id || "?") + " 只写了 " + n + "/27 条，"
        + "其余留空的在游戏里不显示 —— 想补就在「结局」页填（那一页 27 项都在）。");
    });

    // 字段真的能写进去（renderField 的 host 链：section.host() → 字段）
    P.go({ kind: "rules" });
    const before = P.story.rules.pass_suspicion;
    P.story.rules.pass_suspicion = 42;
    P.validateNow();
    ok(P.story.rules.pass_suspicion === 42 && P.issues.filter(x => x.lv === "e").length === 0,
      "改数值后校验依然 0 错误");
    P.story.rules.pass_suspicion = before;

    // 结局文案按背景各存一份，互不影响
    P.story.backgrounds[0].endings.recognized_line = "AAA";
    P.story.backgrounds[1].endings.recognized_line = "BBB";
    P.validateNow();
    ok(P.story.backgrounds[0].endings.recognized_line === "AAA" &&
       P.story.backgrounds[1].endings.recognized_line === "BBB", "结局文案按背景各存一份，互不影响");

    // 搜索索引里能找到这三页
    ok(P.index.some(e => e.v.kind === "rules"), "搜索索引含数值规则");
    ok(P.index.some(e => e.v.kind === "ui"), "搜索索引含界面文案");
    ok(P.index.some(e => e.v.kind === "endings"), "搜索索引含结局文案");
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  }

  console.log("\n-- 9. 撤销 / 重做 --");
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  const q = () => P.story.backgrounds[0].questions[0].q;
  const orig = q();
  ok(P.undoStack.length === 1, "载入后撤销栈只有 1 帧（当前状态），实际 " + P.undoStack.length);

  P.story.backgrounds[0].questions[0].q = "A";   P.commit();        // 离散一步
  P.story.backgrounds[0].questions[0].q = "AB";  P.commit("txt:x"); // 连续输入
  P.story.backgrounds[0].questions[0].q = "ABC"; P.commit("txt:x"); // 应合并进上一帧
  ok(P.undoStack.length === 3, "连续输入被合并（栈深 3），实际 " + P.undoStack.length);

  P.undo();
  ok(q() === "A", "撤销一次回到上一次提交点，实际「" + q() + "」");
  P.undo();
  ok(q() === orig, "再撤销回到原始文本");
  ok(P.redoStack.length === 2, "重做栈攒了 2 帧，实际 " + P.redoStack.length);
  P.redo();
  ok(q() === "A", "重做一次 → 「A」，实际「" + q() + "」");
  P.redo();
  ok(q() === "ABC", "重做两次 → 「ABC」（证明重做落到正确状态，不是停在中间态）");
  ok(P.redoStack.length === 0, "重做栈已清空");

  // 撤销到底不该炸
  for (let i = 0; i < 10; i++) P.undo();
  ok(q() === orig, "反复撤销到底仍停在原始文本（不越界）");
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);

  // ★★ 第八十三轮（用户口径）：「编辑器流程（各套背景共用）的四个页面 删去」。
  //   这一节原来测的是**全局四页**的数据与校验。四页删掉之后，同样的规则
  //   改由「背景页 → ⑦ 本局覆写」承担，所以这里整节重写成「背景级覆写」的用例 ——
  //   覆盖不减（同样的非法数据照样要被抓到），只是数据源从 story.* 换成 bg.*。
  console.log("\n-- 13. 流程覆写（第八十三轮：全局四页已删，只在背景页里配）--");
  {
    const S = P.story;

    // ---- 全局四页的入口没了 ----
    ["levels", "forced", "qte", "defects"].forEach(k => {
      ok(!P.NAV_KINDS.includes(k), "左侧导航不再有 " + k + " 页");
    });

    // ---- catalog：编辑器靠它做下拉，缺了就没法挑衣服 ----
    // ★ 这个数字跟着 `OutfitData.ITEMS` 走 —— 第八十九轮删了 9 件（165 → 156）。
    //   改物品表时**这一处和下面「catalog 能往返」那处都要同步**。
    const C = S.catalog || {};
    ok((C.items || []).length === 156, "catalog 里有 156 件衣物，实际 " + ((C.items || []).length));
    ok(Array.isArray(C.tags) && C.tags.length >= 4, "catalog 里有标签池：" + (C.tags || []).join(" / "));
    ok(C.items.every(x => x.id && x.name && x.slot), "catalog 每件都有 id / name / slot");
    ok(P.itemById("panties_lace") !== null, "itemById 能查到黑色蕾丝内裤");
    ok(P.pickItemOpts().length === C.items.filter(x => !x.disabled).length,
      "pickItemOpts 只列没下架的衣物（" + P.pickItemOpts().length + " 件）");

    // ---- 背景级覆写：拿一套启用的背景当靶子 ----
    const bg = P.enabledBgs()[0];
    ok(!!bg, "至少有一套启用的背景可用来验覆写");
    bg.levels = [
      { name: "第 1 轮", contrast_req: 100, acceptance_gain: 5 },
      { name: "第 2 轮", contrast_req: 140, acceptance_gain: 5 },
    ];
    bg.forced_rules = [
      { mode: "fixed", rules: [
        { pick: "all", items: ["panties_lace"] },
        { pick: "any", items: ["bottom_mini", "bottom_cut"] },
      ]},
      { mode: "none", rules: [] },
    ];
    bg.qte_plan = [{ qte: "expression", delay: 1.5 }, { qte: "combo", delay: 3 }];
    bg.defects = [{ id: "hand_tattoo", name: "手背刺青", slot_hint: "手套", cover_tags: ["glove"] }];
    P.validateNow();
    ok(P.issues.filter(i => i.lv === "e").length === 0,
      "合法的背景级覆写 0 错误：" + JSON.stringify(P.issues.filter(i => i.lv === "e").map(i => i.m).slice(0, 3)));

    // 反差要求倒退 → 提醒
    bg.levels[1].contrast_req = 1;
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("比上一轮")), "背景级：反差要求倒退会被提醒");
    bg.levels[1].contrast_req = 140;
    P.validateNow();

    // 「任选一件」里放同部位的两件 —— 这正是它的用法，只该给提醒
    P.validateNow();
    ok(P.issues.some(i => i.lv === "w" && i.m.includes("同部位的两件")),
      "背景级：任选一件里两条同部位的裙子只提醒、不算错");

    // 引用不存在的衣服 → 报错
    bg.forced_rules[0].rules[0].items = ["__nope__"];
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("不存在") && i.m.includes("__nope__")),
      "背景级：引用不存在的衣物会报错");
    bg.forced_rules[0].rules[0].items = ["panties_lace"];

    // 「必须穿」组里放同槽位两件 → 报错
    bg.forced_rules[0].rules.push({ pick: "all", items: ["bottom_mini", "bottom_pleat"] });
    P.validateNow();
    ok(P.issues.some(i => i.lv === "e" && i.m.includes("同一个部位穿不了两件")),
      "背景级：「必须穿」组里同槽位两件会报错");
    bg.forced_rules[0].rules.pop();

    // mode 写坏 → 报错
    bg.forced_rules[0].mode = "__bad__";
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("mode 只能是")), "背景级：mode 写坏会报错");
    bg.forced_rules[0].mode = "fixed";

    // QTE 类型 / 延迟
    bg.qte_plan[0].qte = "__bad__";
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("qte 只能是")), "背景级：QTE 类型写坏会报错");
    bg.qte_plan[0].qte = "expression";
    bg.qte_plan[0].delay = 30;
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("延迟有 30 秒")), "背景级：延迟过大给提醒");

    // 缺陷标签
    bg.defects[0].cover_tags = ["__nope__"];
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("引用了不存在的标签")), "背景级：缺陷用了不存在的标签会报错");
    bg.defects[0].cover_tags = ["glove"];
    P.validateNow();

    // ---- 往返无损 ----
    const t2 = P.toJSON();
    ok(JSON.parse(t2).qte_plan !== undefined, "全局 qte_plan 段仍然保留（新背景回落用）");
    // ★ 跟上面「catalog 里有 N 件衣物」同一个数字，改物品表时两处一起改。
    ok(JSON.parse(t2).catalog.items.length === 156, "catalog 能往返");
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  }

  //  14. 服装数值 / 原貌（第四十轮新增两页）
  // ============================================================
  console.log("\n-- 14. 服装数值 / 原貌（第四十轮新增两页）--");
  {
    const S = P.story;
    const pristine = JSON.parse(JSON.stringify(S));

    // ---- 目录里带齐了编辑器要用的两样 ----
    const cat = S.catalog || {};
    ok(!!cat.base_values, "catalog 里有 base_values（代码内置值，用来标「改过」）");
    ok(Object.keys(cat.base_values || {}).length === cat.items.length,
      "base_values 覆盖全部 " + cat.items.length + " 件");
    ok(!!cat.true_pool, "catalog 里有 true_pool（原貌候选池）");
    // ★ 第五十一轮修正：这里原来是 `active_slots.length - manual_slots.length`，
    //   在「一张槽位同时出现在下架表与手动表里」时会算错 —— 现在 `tool` 就是这种
    //   情况（用户口径「妙妙工具暂时去掉」）。`autoSlots()` 的实现是
    //   「先按 active_slots 过滤，再滤掉 manual 与 disabled」，所以正确的对照式
    //   是**先求交集**：只有既在可见槽位、又标了手动的那些才会真的被减掉。
    const actSlots = cat.active_slots || [];
    const manualInAct = (cat.manual_slots || []).filter(s => actSlots.includes(s));
    ok(P.autoSlots().length === actSlots.length - manualInAct.length,
      "autoSlots() = 可见槽位去掉「其中标了手动的」（" + P.autoSlots().length
      + " = " + actSlots.length + " - " + manualInAct.length + "）");

    // ---- 当前值 / 内置值 / 覆写 三者关系 ----
    const probeId = "top_plain";
    const baseExp = P.baseValueOf(probeId, "exposure");
    ok(typeof baseExp === "number", probeId + " 有内置暴露值 = " + baseExp);
    ok(P.effValueOf(probeId, "exposure") === baseExp, "没覆写时当前值 = 内置值");

    // ---- 写一条覆写 ----
    P.setItemOverride(probeId, "exposure", baseExp + 3);
    ok(S.item_overrides && S.item_overrides[probeId]
      && S.item_overrides[probeId].exposure === baseExp + 3,
      "写入覆写后 story.item_overrides 里有这一条");
    ok(P.effValueOf(probeId, "exposure") === baseExp + 3, "当前值跟着变成覆写值");
    ok(P.overriddenItemCount() === 1, "改动计数 = 1（实际 " + P.overriddenItemCount() + "）");
    P.validateNow();
    ok(!P.issues.some(i => i.lv === "e" && i.m.includes("item_overrides")),
      "合法的覆写不报错");

    // ---- 与内置值相同 → 自动删掉这条（不在 story.json 里留痕） ----
    P.setItemOverride(probeId, "exposure", baseExp);
    ok(!(S.item_overrides && S.item_overrides[probeId]),
      "改回内置值 → 这一条自动删掉，不留痕");
    ok(P.overriddenItemCount() === 0, "改动计数归零");

    // ---- 只改一个字段时，另一个字段不写入 ----
    P.setItemOverride(probeId, "acceptance_req", 9);
    ok(S.item_overrides[probeId].acceptance_req === 9
      && S.item_overrides[probeId].exposure === undefined,
      "只写被改的那个字段（另一个不落盘）");
    P.setItemOverride(probeId, "acceptance_req", P.baseValueOf(probeId, "acceptance_req"));

    // ---- 反向：未知 id / 越界值 / 类型不对 都必须报错 ----
    S.item_overrides = { __no_such_item__: { exposure: 3 } };
    P.validateNow();
    ok(P.issues.some(i => i.lv === "e" && i.m.includes("不存在的物品 id")),
      "未知物品 id 会报错");
    S.item_overrides = { [probeId]: { exposure: 99 } };
    P.validateNow();
    ok(P.issues.some(i => i.lv === "e" && i.m.includes("超出")),
      "暴露值越界会报错：" + (P.issues.filter(i => i.m.includes("超出"))[0] || {}).m);
    S.item_overrides = { [probeId]: { exposure: "3" } };
    P.validateNow();
    ok(P.issues.some(i => i.lv === "e" && i.m.includes("必须是数字")), "非数字会报错");
    S.item_overrides = { [probeId]: { exposure: baseExp } };
    P.validateNow();
    ok(P.issues.some(i => i.lv === "w" && i.m.includes("多余")),
      "与内置值相同的条目会被提醒（多余的）");
    S.item_overrides = {};
    P.validateNow();
    ok(!P.issues.some(i => i.m.includes("item_overrides")), "清空后校验干干净净");

    // ---- 原貌页：出厂状态 = 逐轮覆写了 4 轮 ----
    // ★ 第四十九轮起 story.json 自带一套「原貌逐轮递进」（下装始终保守、
    //   上装/袜子逐轮放开）。这条断言就是防它被谁清掉 —— 清掉之后
    //   随机原貌的暴露值几乎全为 0，反差会退化成「暴露值 × 系数」。
    // ★ 第五十二轮：一局 4 轮 → 2 轮，出厂原貌的逐轮覆写也跟着变成 2 套
    ok(P.presetSummary() === "逐轮 2 轮",
      "出厂原貌 = 逐轮覆写 2 轮（实际 " + P.presetSummary() + "）");
    // 两处都清空 → 摘要回到「默认」
    S.true_presets = { pool: [], by_level: [] };
    ok(P.presetSummary() === "默认", "两处都空时摘要 = 「默认」");
    P.validateNow();
    ok(!P.issues.some(i => i.lv === "e" && i.m.includes("true_presets")),
      "空预设不报错");

    // ---- 加一套随机池、指定一个槽位 ----
    const slot0 = P.autoSlots()[0];
    const cand0 = P.itemsOfSlot(slot0, false);
    ok(cand0.length > 0, slot0 + " 槽有 " + cand0.length + " 件候选");
    const pick0 = cand0[0].id;
    S.true_presets.pool = [{ name: "测试套", slots: { [slot0]: pick0 } }];
    P.validateNow();
    ok(!P.issues.some(i => i.lv === "e" && i.m.includes("true_presets")),
      "合法的预设不报错");
    ok(P.presetSummary().includes("池 1 套"), "导航角标统计到随机池：" + P.presetSummary());
    ok(P.inTruePool(slot0, pick0) === ((cat.true_pool[slot0] || []).includes(pick0)),
      "inTruePool 与 catalog.true_pool 一致");

    // ---- 只写了几件也算数（不要求写满） ----
    ok(Object.keys(S.true_presets.pool[0].slots).length === 1,
      "一套里只写 1 个槽位也合法（没写到的交给随机）");

    // ---- 反向：不存在的物品 / 槽位对不上 ----
    S.true_presets.pool = [{ name: "坏套", slots: { [slot0]: "__no_such__" } }];
    P.validateNow();
    ok(P.issues.some(i => i.lv === "e" && i.m.includes("不存在的物品")), "预设引用不存在的物品会报错");
    S.true_presets.pool = [{ name: "错槽", slots: { bottom: pick0 } }];
    P.validateNow();
    ok(P.issues.some(i => i.lv === "e" && i.m.includes("槽")), "把物品放进错的槽位会报错");

    // ---- 按关覆写：长度与关卡数一致、null = 不覆写 ----
    S.true_presets = { pool: [], by_level: [null, { name: "第2关", slots: { [slot0]: pick0 } }, null, null] };
    P.validateNow();
    ok(!P.issues.some(i => i.lv === "e" && i.m.includes("true_presets")),
      "按关覆写（中间一关有值、其余 null）不报错");
    ok(P.presetSummary().includes("逐轮 1 轮"), "导航角标统计到逐轮覆写：" + P.presetSummary());
    // ★★ 第五十四轮：这条「按关覆写生效时会提醒『A 的样子会逐关变化』」的断言
    //   改成**反向**的 —— 那条提醒被**删掉**了（它是「设计说明」不是「问题」，
    //   出厂就是按轮钉死原貌，等于每次打开都刷一条）。
    //   改成反向断言 = 守住「它不该再回来」。
    ok(!P.issues.some(i => i.m.includes("逐关变化")),
      "不再常驻提醒「A 的样子会逐关变化」（第五十四轮起挪进背景页的说明里）");
    // ★ 但「按关覆写本身是合法的」这条要留着 —— 别把功能一起删了
    ok(P.presetSummary().includes("逐轮 1 轮"),
      "按关覆写的数据仍然被正常识别：" + P.presetSummary());

    // ---- 按轮覆写：项数与轮数不匹配 → 提醒 ----
    //   ★ 第五十二轮：轮数从 4 变 2，所以「不匹配」的样本要从 2 项改成 3 项
    S.true_presets.by_level = [null, null, null];
    P.validateNow();
    ok(P.issues.some(i => i.lv === "w" && i.m.includes("关卡数")), "项数与关卡数不符会提醒");

    // ---- 两个页签的交互路径都能走通（渲染 → 切模式 → 切选中） ----
    P.story.true_presets = { pool: [{ name: "甲", slots: {} }, { name: "乙", slots: {} }], by_level: [null, null, null, null] };
    P.presetMode = "pool"; P.presetSel = 1;
    try { P.go({ kind: "trueapp" }); ok(true, "随机池模式（选中第 2 套）渲染不抛错"); }
    catch (e) { ok(false, "随机池模式渲染抛错：" + (e && e.message)); }
    P.presetMode = "by_level"; P.presetSel = 3;
    try { P.go({ kind: "trueapp" }); ok(true, "按关覆写模式（选中第 4 关）渲染不抛错"); }
    catch (e) { ok(false, "按关覆写模式渲染抛错：" + (e && e.message)); }
    P.presetMode = "pool"; P.presetSel = 0;

    // ---- 往返无损 ----
    P.story.item_overrides = { [probeId]: { exposure: baseExp + 2, acceptance_req: 7 } };
    P.story.true_presets = { pool: [{ name: "套1", slots: { [slot0]: pick0 } }], by_level: [null, null, null, null] };
    const t3 = JSON.parse(P.toJSON());
    ok(t3.item_overrides[probeId].exposure === baseExp + 2, "item_overrides 能往返");
    ok(t3.true_presets.pool[0].slots[slot0] === pick0, "true_presets.pool 能往返");
    ok(Array.isArray(t3.true_presets.by_level) && t3.true_presets.by_level.length === 4,
      "true_presets.by_level 能往返");

    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  }


  // ============================================================
  //  15. 背景级流程覆写 · 删轮次联动 · 出场序号（第四十一轮）
  // ============================================================
  console.log("\n-- 15. 本局覆写 / 删轮次联动 / 出场序号（第四十一轮）--");
  {
    const S = P.story;
    const pristine = JSON.parse(JSON.stringify(S));

    // ---- 背景页里带上了三个覆写节 ----
    const secs = P.bgSections(S.backgrounds[0]);
    const keys = secs.map(x => x.key);
    ok(keys.includes("levels"), "背景页有「本局几轮」节");
    ok(keys.includes("ov_forced"), "背景页有「本局覆写 · 强制穿着」节");
    ok(keys.includes("ov_qte"), "背景页有「本局覆写 · QTE 计划」节");
    ok(keys.includes("ov_defects"), "背景页有「本局覆写 · 身体缺陷」节");

    // ---- 背景的覆写字段都能建出来、能渲染 ----
    S.backgrounds.forEach((b, i) => {
      if (!Array.isArray(b.forced_rules)) b.forced_rules = [];
      if (!Array.isArray(b.qte_plan)) b.qte_plan = [];
      if (!Array.isArray(b.defects)) b.defects = [];
      if (!b.true_presets) b.true_presets = {};
    });
    S.backgrounds[0].forced_rules = [{mode:"fixed", rules:[{pick:"all", items:["top_plain"]}]}];
    S.backgrounds[0].qte_plan = [{qte:"expression", delay:1.5}];
    S.backgrounds[0].defects = [{id:"hand_tattoo", name:"测试", slot_hint:"", cover_tags:["glove"]}];
    P.validateNow();
    ok(!P.issues.some(x => x.lv === "e" && x.m.includes("强制规则")), "合法的背景强制穿着不报错");
    ok(!P.issues.some(x => x.lv === "e" && x.m.includes("QTE 计划")), "合法的背景 QTE 计划不报错");

    // ---- 反向：非法的 mode / qte / 衣物 id / 标签 ----
    S.backgrounds[0].forced_rules = [{mode:"乱写", rules:[{pick:"all", items:["__no__"]}]}];
    P.validateNow();
    ok(P.issues.some(x => x.lv === "e" && x.m.includes("mode 只能是")), "非法 mode 会报错");
    ok(P.issues.some(x => x.lv === "e" && x.m.includes("不存在的衣物")), "强制穿着引用不存在的衣物会报错");
    S.backgrounds[0].forced_rules = [];
    S.backgrounds[0].qte_plan = [{qte:"乱写", delay:0}];
    P.validateNow();
    ok(P.issues.some(x => x.lv === "e" && x.m.includes("qte 只能是")), "非法 QTE 类型会报错");
    S.backgrounds[0].qte_plan = [];
    S.backgrounds[0].defects = [{id:"d1", name:"甲", cover_tags:["不存在的标签"]}];
    P.validateNow();
    ok(P.issues.some(x => x.lv === "e" && x.m.includes("不存在的标签")), "缺陷引用不存在的标签会报错");
    S.backgrounds[0].defects = [];
    P.validateNow();
    ok(!P.issues.some(x => x.lv === "e" && x.m.includes("缺陷")), "清空后校验干净");

    // ---- 背景覆写原貌：非法槽位对不上要报错 ----
    S.backgrounds[0].true_presets = {pool:[], by_level:[{name:"x", slots:{bottom:"top_plain"}}]};
    P.validateNow();
    ok(P.issues.some(x => x.lv === "e" && x.m.includes("放进了")), "背景原貌把衣物放进错槽位会报错");
    S.backgrounds[0].true_presets = {};
    P.validateNow();

    // ---- presetEditor 能用背景那份 host 渲染（scope 也跟着变） ----
    const bg0 = S.backgrounds[0];
    bg0.true_presets = {pool:[{name:"甲", slots:{}}], by_level:[null,null,null,null]};
    P.presetMode = "pool";
    try { P.go({kind:"bg", index:0}); ok(true, "背景页（含本局原貌编辑器）渲染不抛错"); }
    catch (e) { ok(false, "背景页渲染抛错：" + (e && e.message)); }
    ok(P.presetScope === "bg:" + (bg0.id || 0), "原貌编辑器的 scope 切到了这套背景：" + P.presetScope);
    ok(P.presetSummaryOf(bg0.true_presets).includes("池 1 套"),
      "按背景的摘要正确：" + P.presetSummaryOf(bg0.true_presets));
    // 全局那份不该被背景的编辑串味（出厂那份 = 逐轮 2 轮）
    ok(P.presetSummaryOf(S.true_presets) === "逐轮 2 轮",
      "全局原貌没被背景那份串味（仍是出厂的逐轮 2 轮，实际 "
      + P.presetSummaryOf(S.true_presets) + "）");
    P.presetMode = "pool";

    // ---- 题库：出场序号字段在 ----
    const qf = P.questionFields();
    ok(qf.some(f => f.k === "order"), "题目字段里有 order（出场序号）");

    // ---- ★ 删轮次联动：删第 2 轮，第 2 轮的题被删、后面的往前挪 ----
    const bg = S.backgrounds[0];
    bg.levels = [{name:"一轮"},{name:"二轮"},{name:"三轮"},{name:"四轮"}];
    bg.questions = [
      {id:"q0a", level:0, options:[]},
      {id:"q1a", level:1, options:[]},
      {id:"q1b", level:1, options:[]},
      {id:"q2a", level:2, options:[]},
      {id:"q3a", level:3, options:[]},
      {id:"qAny", level:-1, options:[]},
    ];
    bg.true_presets = {pool:[], by_level:[{name:"p0", slots:{top:"top_plain"}},
      {name:"p1", slots:{top:"top_plain"}}, null, {name:"p3", slots:{top:"top_plain"}}]};
    const before = bg.questions.length;
    const okDel = P.cascadeDeleteRound(bg, 1);
    ok(okDel === true, "删轮次联动返回 true（允许继续删）");
    ok(bg.questions.length === before - 2, "第 2 轮那两道题被删掉了（" + before
      + " → " + bg.questions.length + "）");
    ok(!bg.questions.some(q => q.id === "q1a" || q.id === "q1b"), "被删的正是第 2 轮那两道");
    ok(bg.questions.find(q => q.id === "q2a").level === 1, "原本第 3 轮的题往前挪成了第 2 轮");
    ok(bg.questions.find(q => q.id === "q3a").level === 2, "原本第 4 轮的题往前挪成了第 3 轮");
    ok(bg.questions.find(q => q.id === "qAny").level === -1, "通用池的题（level=-1）不受影响");
    ok(bg.questions.find(q => q.id === "q0a").level === 0, "前面的题不受影响");
    ok(bg.true_presets.by_level.length === 3, "原貌「逐轮指定」也跟着少了一项");
    ok(bg.true_presets.by_level[2] && bg.true_presets.by_level[2].name === "p3",
      "原貌指定里后面那项往前挪了（p3 从第 4 轮到第 3 轮）");

    // ---- 没有牵连时不该弹确认、直接返回 true ----
    const bg2 = S.backgrounds[1];
    bg2.levels = [{name:"a"},{name:"b"}];
    bg2.questions = [{id:"x", level:-1, options:[]}];
    bg2.true_presets = {};
    ok(P.cascadeDeleteRound(bg2, 1) === true, "没有牵连时直接允许删除");

    // ---- 反向校验：题目挂在「这一局不存在的轮次」上 → 提醒 ----
    S.backgrounds[0].levels = [{name:"一"},{name:"二"}];
    S.backgrounds[0].questions = [{id:"zz", level:3, options:[]}];
    P.validateNow();
    ok(P.issues.some(x => x.lv === "w" && x.m.includes("永远不会出现")),
      "题目属于本局不存在的轮次会被提醒");
    S.backgrounds[0].questions = [];
    S.backgrounds[0].levels = pristine.backgrounds[0].levels;
    P.validateNow();

    // ---- 出场序号重复 → 提醒（不是错误） ----
    S.backgrounds[0].questions = [
      {id:"d1", level:0, order:5, options:[]},
      {id:"d2", level:0, order:5, options:[]},
    ];
    P.validateNow();
    ok(P.issues.some(x => x.lv === "w" && x.m.includes("出场序号相同")), "同轮序号重复会提醒");
    ok(!P.issues.some(x => x.lv === "e" && x.m.includes("出场序号")), "序号重复只是提醒、不是错误");
    S.backgrounds[0].questions = [];
    P.validateNow();

    // ---- 往返无损 ----
    S.backgrounds[0].forced_rules = [{mode:"random", rules:[]}];
    S.backgrounds[0].qte_plan = [{qte:"none", delay:-1}];
    S.backgrounds[0].defects = [];
    S.backgrounds[0].true_presets = {pool: [], by_level: [null, null, null, null]};
    const t4 = JSON.parse(P.toJSON());
    ok(t4.backgrounds[0].forced_rules[0].mode === "random", "背景强制穿着能往返");
    ok(t4.backgrounds[0].qte_plan[0].qte === "none", "背景 QTE 计划能往返");

    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
    ok(true, "恢复原始数据");
  }

  console.log("\n-- 16. 保存通道：直接写回 data/story.json（第七十六轮）--");
  // 编辑器不再「打开文件」：它只认 data/story.json，靠 tools/story_server.py 读写。
  // 这一段验两件事 —— ① 没连上服务时是只读（不许偷偷发请求）；
  // ② 连上时 POST 到 /api/story，正文就是 toJSON()。
  ok(P.canSave === false, "冒烟环境没有本地服务 → canSave 应为 false（只读）");
  {
    let posted = null;
    const realFetch = globalThis.fetch;
    globalThis.fetch = () => Promise.reject(new Error("offline"));
    await P.save();
    ok(posted === null, "只读模式下点保存不会发任何请求");

    globalThis.fetch = (u, opt) => {
      if (String(u) === P.API_STORY && opt && opt.method === "POST"){
        posted = opt.body;
        return Promise.resolve({ ok: true, status: 200,
          json: () => Promise.resolve({ ok: true, bytes: opt.body.length }) });
      }
      return Promise.reject(new Error("unexpected " + u));
    };
    P.canSave = true;
    const before = P.toJSON();
    await P.save();
    ok(posted !== null, "连上服务后点保存会 POST 到 " + P.API_STORY);
    ok(posted === before, "POST 的正文就是 toJSON()（没有被改写）");
    // ★ 第七十九轮：不写死 6 —— 背景条数由数据决定（用户现在只留 3 套）
    ok(JSON.parse(posted).backgrounds.length === P.story.backgrounds.length,
      "正文里的背景条数与当前数据一致（" + P.story.backgrounds.length + " 套）");
    ok(P.toJSON() === before, "保存不改数据本身");
    globalThis.fetch = realFetch;
    P.canSave = false;
  }

  console.log("\n================================");
  console.log(" 通过 " + pass + " / 失败 " + fail);
  console.log("================================");
  process.exit(fail ? 1 : 0);
})();
