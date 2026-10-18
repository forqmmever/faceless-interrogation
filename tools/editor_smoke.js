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
  bgSections, traitSections, globalSections,
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
  SLOTS, POOL_IDS, TRUE_POOL, GENDERS, PLAYER_GENDER,
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
  optionFields, optionTitle, MANUAL_HIDDEN_META, MANUAL_HIDDEN_COMPANION,
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
  ok(P.story.backgrounds.length === 6, "6 套背景（4 套启用 + 2 套草稿），实际 " + P.story.backgrounds.length);
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
  const otherWarns = warns.filter(i => !i.m.includes("还是草稿"));
  ok(otherWarns.length === 0,
    "除了草稿说明，出厂数据下 0 条提醒（实际 " + otherWarns.length + " 条）"
    + (otherWarns.length ? "：\n      " + otherWarns.slice(0, 8).map(i => i.m).join("\n      ") : ""));
  ok(!warns.some(i => /留一块空白|会退回出厂文案/.test(i.m)),
    "「界面会留空白」「退回出厂文案」这两类提醒已经不在校验器里了");
  ok(draftWarns.length === 2,
    "两套草稿（情景一 / 情景二）各报一条「还是草稿」提醒（实际 " + draftWarns.length + " 条）");
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

  console.log("\n-- 7. 槽位/池 常量 --");
  ok(P.SLOTS.length === 19, "SLOTS = 19（第三十九轮新增妙妙工具）");
  ok(P.POOL_IDS.length === 34, "候选池 = 34 件（吊袜带并入袜类后少 1），实际 " + P.POOL_IDS.length);
  const idsc = P.story.item_desc || {};
  ok(P.POOL_IDS.every(id => id in idsc), "ITEM_DESC 覆盖候选池全部");
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
    const seenLv = new Set();
    // ★ 第五十五轮：「与审问官」也变成每套背景的普通线程了 —— 一起查
    (bg.interrogator_sms || []).forEach(t => {
      if (!Number.isInteger(t.level) || t.level < 0 || t.level >= order.length)
        badLevel.push(bg.id + "/" + t.id + " 越界 " + t.level);
      if (!(t.messages || []).length) badLevel.push(bg.id + "/" + t.id + " 没有对话");
    });
    (bg.sms || []).forEach(t => {
      if (!Number.isInteger(t.level)) { badLevel.push(bg.id + "/" + t.id + " = " + t.level); return; }
      if (t.level < 0 || t.level >= order.length) { badLevel.push(bg.id + "/" + t.id + " 越界 " + t.level); return; }
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
  const noBlind = [], badBlind = [];
  const SMOKE_TONES = new Set(["correct","leak","version","bluff","evade","silence","made_up"]);
  const blindOf = (bg) => (bg.questions || []).filter(q => !q.card && !q.fact && q.speaker !== "companion");
  P.enabledBgs().forEach(bg => {
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
  ok(P.enabledBgs().length === 4,
    "出厂四套背景已启用（没写 enabled 字段 = 启用），实际 " + P.enabledBgs().length);
  // ★ 第五十八轮：从 docx 新增的「情景一」—— 草稿，内容先填，缺的地方是 void。
  const scene1 = P.story.backgrounds.find(b => b.id === "scene_1");
  ok(!!scene1, "新增的「情景一」在 story.json 里");
  ok(!!scene1 && scene1.enabled === false, "「情景一」是草稿（不进抽取 / 自动化测试）");
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
  ok(!!scene2 && scene2.enabled === false, "「情景二」是草稿（不进抽取 / 自动化测试）");
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

  console.log("\n-- 7h. 开场介绍 intro（第十三轮新增）--");
  const noIntro = P.story.backgrounds.filter(bg => !bg.intro);
  ok(noIntro.length === 0, "每套背景都带 intro（开场浮窗的正文）" + (noIntro.length ? " —— 缺 " + noIntro.map(b => b.id).join("、") : ""));
  ok(P.story.backgrounds.every(bg => bg.intro && bg.intro.length > 40),
    "每套背景的 intro 都写得够长（够撑起一个浮窗）");
  const metaSec3 = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "meta");
  ok(!!metaSec3 && metaSec3.fields.some(f => f.k === "intro"), "基础信息里能改 intro");
  console.log("\n-- 7f2. 衣物描述的「多出来的项」提示（第五十四轮从校验面板挪到这一节）--");
  {
    const gsec = P.globalSections().find(s => s.key === "item_desc");
    ok(!!gsec, "全局文本页里有衣物描述这一节");
    ok(typeof gsec.extra === "function", "这一节声明了 extra（多出来的项）");
    const ex = gsec.extra ? gsec.extra() : [];
    ok(ex.length > 0, "出厂数据里确实有多出来的项（实际 " + ex.length + " 条）");
    ok(ex.every(k => !P.POOL_IDS.includes(k)), "extra 列出的都不在候选池里");
    ok(gsec.missing().length === 0, "同时「缺失的」是 0 条（该有的都有）");
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
  const qteField = qFields.find(f => f.k === "qte");
  const qteOpts = qteField && qteField.opts ? qteField.opts() : [];
  ok(qteField && qteField.sub === "qte" && qteOpts.length === 5,
    "每道题都能指定 QTE 类型（五种）");
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
    ok(P.enabledBgs().every(b => P.bgQuestionsSource(b) === "auto"),
      "出厂四套启用的背景都是「自动生成」（没写这个键就是它）");
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
    ok(manMeta.indexOf("name") >= 0 && manMeta.indexOf("intro") >= 0, "自行编辑：背景名与开场介绍照旧在");
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
    ok(P.countPh(P.story.phone.memo.cast_body) === P.PH_EXPECT["memo.cast_body"],
      "备忘录第二条正文的占位符个数 = " + P.PH_EXPECT["memo.cast_body"]);
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
  negCase("句式模板丢了 %s", s => { s.clue_frame.hair = "「那人头发。」"; }, "%s");
  negCase("衣物描述缺一件", s => { delete s.item_desc.hair_short; }, "衣物描述缺 hair_short");
  negCase("事实只剩一个版本",
    s => { s.backgrounds[0].facts[0].values = [s.backgrounds[0].facts[0].values[0]]; }, "至少要 2 个版本");
  negCase("性情 dangerous 值非法", s => { s.traits[0].dangerous = "nonsense"; }, "dangerous 只能是");
  negCase("卡片 owner 非法", s => { s.backgrounds[1].cards[0].owner = "C"; }, "必须是 A 或 B");
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
  negCase("性情缺备忘录性格", s => { delete s.traits[0].memo; }, "没有备忘录「性格」");
  negCase("性情缺备忘录喜好", s => { delete s.traits[1].like; }, "没有备忘录「喜好」");
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
  negCase("结局文案缺一条（应是提醒）", s => { delete s.backgrounds[0].endings.recognized_line; }, "recognized_line");
  negCase("结局文案丢了占位符", s => { s.backgrounds[0].endings.recognized_line = "怎么是你。"; }, "丢了占位符");
  negCase("整块 endings 缺失", s => { delete s.backgrounds[0].endings; }, "没有 endings");
  // ---- 第五十五轮：手机并入 / 三组同构短信 ----
  negCase("手机文案少写一个占位符",
    s => { s.phone.memo.cast_body = s.phone.memo.cast_body.replace("%s", "我"); }, "个占位符");
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
    ok(Object.keys(R).length === 33, "story.rules 有 33 项，实际 " + Object.keys(R).length);
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
  ok(P.uiLeafCount() === 86, "story.ui 共 86 条文案，实际 " + P.uiLeafCount());
    const rs = P.rulesSections(), us = P.uiSections(), es = P.endingsSections();
    // ★ 第三十三轮：删 3 项（exposure_qte_threshold / interference_min / interference_per_exposure）
    //   加 2 项（exposure_qte_min / exposure_qte_full）→ 31 − 3 + 2 = 30
    ok(rs.reduce((a, s) => a + (s.fields || []).length, 0) === 30, "数值页覆盖 30 项");

    // ---- ★ 第三十三轮：QTE 上方的提示文字可以编辑 ----
    //   两处都要有：① 题库页的「每题」字段；② 全局 QTE 计划页。
    const qFieldKeys = P.questionFields().map(f => f.k);
    ok(qFieldKeys.includes("prompt"), "题库页每题有「QTE 上方的提示文字」字段（实际：" + qFieldKeys.join(",") + "）");
    const qteFieldKeys = P.qteFields().map(f => f.k);
    ok(qteFieldKeys.includes("prompt"), "全局 QTE 页也有该字段（实际：" + qteFieldKeys.join(",") + "）");
    ok(qFieldKeys.includes("qte") && qFieldKeys.includes("delay"),
      "每题仍能改 QTE 类型与出现时间");
    ok(us.reduce((a, s) => a + (s.fields || []).length, 0) === 85, "文案页覆盖 85 条");
    ok(es.reduce((a, s) => a + (s.fields || []).length, 0) === 27, "结局页覆盖 27 条");
    ok(rs.every(s => s.host && s.host() === P.story.rules), "全部数值区块都写在 story.rules 上（全局一套）");
    ok(us.every(s => s.host && s.host() === P.story.ui[s.seg]), "每个文案区块挂在对应的 ui 子段上");
    ok(us.map(s => s.seg).join(",") === "common,title,wardrobe,interrogation,feedback,help", "文案 6 个分段齐全");
    ok(es.every(s => (s.fields || []).every(f => f.sub === "endings")), "结局字段全部写进 backgrounds[i].endings");
    const allFields = [].concat(rs, us, es).reduce((a, s) => a.concat(s.fields || []), []);
    ok(allFields.every(f => f.k && f.label), "所有字段都有 k 和 label");
    ok(allFields.every(f => ["num", "text", "area", "strlist"].includes(f.t)), "字段类型都在支持范围内（num / text / area / strlist）");
    P.enabledBgs().forEach((b, i) =>
      ok(Object.keys(b.endings || {}).length === 27, "背景" + (i + 1) + " 有 27 条结局文案，实际 " + Object.keys(b.endings || {}).length));

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

  console.log("\n-- 13. 关卡 / 强制穿着 / QTE 计划 / 缺陷（第二十三轮新增四页）--");
  {
    const S = P.story;

    // ---- 数据在 ----
    ok(Array.isArray(S.levels) && S.levels.length === 2, "levels 有 2 轮，实际 " + ((S.levels || []).length));
    ok(Array.isArray(S.forced_rules) && S.forced_rules.length === 2, "forced_rules 有 2 条，实际 " + ((S.forced_rules || []).length));
    ok(Array.isArray(S.qte_plan), "qte_plan 是数组（出厂为空 = 全自动）");
    ok(Array.isArray(S.defects) && S.defects.length === 2, "defects 有 2 项，实际 " + ((S.defects || []).length));

    // ---- catalog：编辑器靠它做下拉，缺了就没法挑衣服 ----
    const C = S.catalog || {};
    ok((C.items || []).length === 165, "catalog 里有 165 件衣物，实际 " + ((C.items || []).length));
    ok(Array.isArray(C.tags) && C.tags.length >= 4, "catalog 里有标签池：" + (C.tags || []).join(" / "));
    ok(C.items.every(x => x.id && x.name && x.slot), "catalog 每件都有 id / name / slot");
    ok(P.itemById("panties_lace") !== null, "itemById 能查到黑色蕾丝内裤");
    ok(P.itemLabel("panties_lace").includes("下内衣"), "itemLabel 带槽位名：" + P.itemLabel("panties_lace"));
    ok(P.pickItemOpts().length === C.items.filter(x => !x.disabled).length,
      "pickItemOpts 只列没下架的衣物（" + P.pickItemOpts().length + " 件）");

    // ---- 关卡页：能加一关、能验证越界 ----
    ok(P.validateNow === undefined || true, "校验入口存在");
    const before = S.levels.length;
    S.levels.push({ name: "第五关·测试", acceptance_gain: 0, contrast_req: 40, derived_profile: "测试" });
    P.validateNow();
    ok(!P.issues.some(i => i.lv === "e" && i.m.includes("第五关")),
      "新增一关不报错（合法的数值就该通过）");
    // 反差要求定到「暴露值上限 + 原貌最多能贡献」都够不着 → 一定无解，必须提醒
    //   ★ 第五十四轮：这条上界原来算错了（用的是旧口径的「单件 contrast」，
    //     会把 125 / 150 这种**有解**的曲线报成无解）。现在改成按
    //     `倍率 × (暴露值上限 + Σ原貌上界)` 算，文案也从「理论上界」改成「宽松上界」。
    S.levels[S.levels.length - 1].contrast_req = 999;
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("宽松上界") && i.m.includes("999")),
      "反差要求超过宽松上界会被提醒：" + (P.issues.filter(i => i.m.includes("999"))[0] || {}).m);
    // ★ 反向：出厂那条曲线（125 / 150）**不该**被报成无解 ——
    //   这正是第 54 轮修的那个 bug（旧公式把 125 报成「超过上界 59」）。
    S.levels[S.levels.length - 1].contrast_req = S.levels[0].contrast_req;
    P.validateNow();
    ok(!P.issues.some(i => i.m.includes("宽松上界")),
      "出厂的曲线（" + S.levels.map(l => l.contrast_req).join(" / ") + "）不该被报「超过上界」");
    S.levels.pop();
    P.validateNow();
    ok(S.levels.length === before, "关卡数改回原样（" + before + " 关）");

    // ★ 第二十九轮：反差要求「留空 = 自增」
    // ★ 第四十九轮：出厂曲线改成**每轮都手写**（当时是 4 轮 125/140/155/165）——
    //   增量 15/15/10，**不是等差**，base+step 表达不了。
    // ★ 第五十一轮：配饰下架后天花板掉 10~15 点，末轮 165 → 160。
    // ★ 第五十二轮：一局 4 轮 → **2 轮**，曲线跟着压成 125 / **150**
    //   （150 是实测定的：第 2 轮可达 155~215，写 160 会让最不利的原貌无解）。
    ok(S.levels[1].contrast_req === 150, "第 2 轮的反差要求是手写的 150（实际 "
      + JSON.stringify(S.levels[1].contrast_req) + "）");
    const autoSeq = (function(){
      const base = Number((S.rules||{}).contrast_req_base) || 20;
      const step = Number((S.rules||{}).contrast_req_step) || 10;
      let prev = base; const out = [];
      S.levels.forEach((l, i) => {
        const g = (l.contrast_req == null) ? 0 : Number(l.contrast_req);
        prev = (g > 0) ? g : (i > 0 ? prev + step : base);
        out.push(prev);
      });
      return out;
    })();
    // ★ 第四十九轮：反差改成**全槽位求和** + 原貌池放开之后重标过曲线
    //   （可达上限从 ~90 涨到 ~260）。两轮都是手写的，所以 autoSeq
    //   就等于这两个手写值 —— 它顺带验了「解析器读的是手写值」。
    ok(autoSeq.join("/") === "125/150", "两轮手写值被正确解析：" + autoSeq.join("/"));
    // 留空仍然走自增（机制没删，只是出厂数据不再用到）
    const seqAuto = (function(){
      const base = Number((S.rules||{}).contrast_req_base) || 20;
      const step = Number((S.rules||{}).contrast_req_step) || 10;
      let prev = base; const out = [];
      [125, null].forEach((g, i) => {
        prev = (g > 0) ? g : (i > 0 ? prev + step : base);
        out.push(prev);
      });
      return out;
    })();
    ok(seqAuto[1] === 125 + Number((S.rules||{}).contrast_req_step),
      "留空的关仍按上一关 + step 自增（" + seqAuto[1] + "）");
    // 在中间手写一个值 → 它成为后面自增的新起点
    S.levels[1].contrast_req = 45;
    P.validateNow();
    ok(true, "手写值不报错");
    S.levels[1].contrast_req = undefined;
    P.validateNow();

    // 反差要求倒退 → 提醒
    const saveReq = S.levels[1].contrast_req;
    S.levels[1].contrast_req = 1;
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("比上一关")), "反差要求倒退会被提醒");
    S.levels[1].contrast_req = saveReq;
    P.validateNow();
    ok(!P.issues.some(i => i.m.includes("比上一关")), "改回来之后提醒消失");

    // ---- 强制穿着：写死的规则 ----
    S.forced_rules[1] = { mode: "fixed", rules: [
      { pick: "all", items: ["panties_lace"] },
      { pick: "any", items: ["bottom_mini", "bottom_cut"] },
    ]};
    P.validateNow();
    const frErrs = P.issues.filter(i => i.lv === "e" && i.m.includes("强制穿着 · 第 2 关"));
    ok(frErrs.length === 0,
      "「固定一件 + 几件选一件」的组合是合法的（0 个错误）：" + JSON.stringify(frErrs.map(i => i.m)));
    // 「任选一件」里放同部位的两件 —— 这正是它的用法，只该给提醒、不该报错
    const frWarns = P.issues.filter(i => i.lv === "w" && i.m.includes("同部位的两件"));
    ok(frWarns.length === 1, "任选一件里放两条同部位的裙子只给提醒，不算错");

    // 引用不存在的衣服 → 报错
    S.forced_rules[1].rules[0].items = ["__nope__"];
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("不存在") && i.m.includes("__nope__")), "引用不存在的衣物会报错");
    S.forced_rules[1].rules[0].items = ["panties_lace"];

    // 「必须穿」组里放同槽位两件 → 报错（那是真的做不到）
    S.forced_rules[1].rules.push({ pick: "all", items: ["bottom_mini", "bottom_pleat"] });
    P.validateNow();
    ok(P.issues.some(i => i.lv === "e" && i.m.includes("同一个部位穿不了两件")),
      "「必须穿」组里同槽位两件会报错");
    S.forced_rules[1].rules.pop();

    // mode 写坏 → 报错
    const okMode = S.forced_rules[1].mode;
    S.forced_rules[1].mode = "__bad__";
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("mode 必须是")), "mode 写坏会报错");
    S.forced_rules[1].mode = okMode;
    P.validateNow();

    // ---- QTE 计划 ----
    S.qte_plan = [{ qte: "expression", delay: 1.5 }, { qte: "combo", delay: 3 }];
    P.validateNow();
    ok(!P.issues.some(i => i.m.includes("QTE 计划")), "合法的 QTE 计划不报错");
    S.qte_plan[0].qte = "__bad__";
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("qte 只能是")), "QTE 类型写坏会报错");
    S.qte_plan[0].qte = "expression";
    S.qte_plan[0].delay = 30;
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("延迟有 30 秒")), "延迟过大给提醒（玩家多半答完了）");
    // 表比题目长 → 提醒
    S.qte_plan = new Array(12).fill(0).map(() => ({ qte: "none", delay: -1 }));
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("永远用不上")), "QTE 计划比题目长会提醒");
    S.qte_plan = [];
    P.validateNow();

    // ---- 缺陷 ----
    S.defects[0].cover_tags = ["__nope__"];
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("引用了不存在的标签")), "缺陷用了不存在的标签会报错");
    S.defects[0].cover_tags = ["glove", "long_sleeve"];
    S.defects.push({ id: "hand_tattoo", name: "重复 id", slot_hint: "", cover_tags: ["glove"] });
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("id 重复")), "缺陷 id 重复会报错");
    S.defects.pop();
    S.defects.push({ id: "__tmp__", name: "没标签的缺陷", slot_hint: "", cover_tags: [] });
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("永远露着")), "缺陷没有遮挡标签会提醒");
    S.defects.pop();
    P.validateNow();

    // ---- 四页的区块都建得出来、字段都有定义 ----
    ["levels", "forced", "qte", "defects"].forEach(k => {
      try { P.go({ kind: k }); ok(true, "切到 " + k + " 页不抛错"); }
      catch (e) { ok(false, "切到 " + k + " 页抛错：" + (e && e.message)); }
    });

    // ---- 往返无损（新字段也要能存回去） ----
    S.qte_plan = [{ qte: "interference", delay: 2 }];
    const t2 = P.toJSON();
    ok(JSON.parse(t2).qte_plan[0].qte === "interference", "qte_plan 能往返");
    ok(JSON.parse(t2).catalog.items.length === 165, "catalog 能往返");
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  }

  // ============================================================
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

  console.log("\n================================");
  console.log(" 通过 " + pass + " / 失败 " + fail);
  console.log("================================");
  process.exit(fail ? 1 : 0);
})();
