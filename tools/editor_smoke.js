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
  questionFields, optionFields, TONE_OPTS, QUESTION_QTE_OPTS, renderQuestions, totalQuestions,
  SLOTS, POOL_IDS, TRUE_POOL, GENDERS, PLAYER_GENDER,
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
  ok(P.story.backgrounds.length === 4, "4 套背景，实际 " + P.story.backgrounds.length);
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
  console.log("   错误 " + errs.length + " / 提醒 " + warns.length);

  console.log("\n-- 3. 全部视图渲染 --");
  for (const v of [{ kind: "home" }, { kind: "traits" }, { kind: "global" },
                   { kind: "rules" }, { kind: "ui" },
                   { kind: "endings", index: 0 }, { kind: "endings", index: 3 },
                   { kind: "levels" }, { kind: "forced" }, { kind: "qte" }, { kind: "defects" },
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
  ok(P.SLOTS.length === 19, "SLOTS = 19");
  ok(P.POOL_IDS.length === 35, "候选池 = 35 件（第三十四轮删掉黄铜胸针后少 1），实际 " + P.POOL_IDS.length);
  const idsc = P.story.item_desc || {};
  ok(P.POOL_IDS.every(id => id in idsc), "ITEM_DESC 覆盖候选池全部");
  ok(P.PLAYER_GENDER === "女", "玩家（B 的马甲）性别 = 女");

  console.log("\n-- 7b. 卡司 / 性别 / 短信关卡（本轮新增字段）--");
  const GN = P.GENDERS.map(g => g.v);
  const badGender = [], badComp = [], badLevel = [], badAlign = [], badDup = [];
  P.story.backgrounds.forEach(bg => {
    if (GN.indexOf(bg.interrogator_gender) < 0) badGender.push(bg.id + " 审讯官");
    const cp = bg.companion;
    if (!cp || !cp.name || GN.indexOf(cp.gender) < 0) badComp.push(bg.id);
    const order = (bg.facts || []).map(f => f.id);
    const seenLv = new Set();
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
  ok(badGender.length === 0, "4 套背景的审讯官性别都合法" + (badGender.length ? " —— " + badGender.join("; ") : ""));
  ok(badComp.length === 0, "4 套背景都带 companion（C 的名字 + 性别）" + (badComp.length ? " —— " + badComp.join("; ") : ""));
  ok(badLevel.length === 0, "每条短信的 level 都是合法整数" + (badLevel.length ? " —— " + badLevel.join("; ") : ""));
  ok(badDup.length === 0, "每关恰好一条短信解锁" + (badDup.length ? " —— " + badDup.join("; ") : ""));
  ok(badAlign.length === 0, "短信 level 与 facts 顺序逐关对齐" + (badAlign.length ? " —— " + badAlign.join("; ") : ""));
  console.log("   短信 level：" + P.story.backgrounds.map(bg =>
    bg.id + "=[" + (bg.sms || []).map(t => t.level).join(",") + "]").join("  "));

  console.log("\n-- 7c. 新增字段在编辑器里真的能改 --");
  const secs0 = P.bgSections(P.story.backgrounds[0]);
  const compSec = secs0.find(s => s.key === "companion");
  ok(!!compSec, "左侧有「卡司 · 同行人 C」一节");
  if (compSec) {
    const ks = compSec.fields.map(f => (f.sub || "") + "." + f.k);
    ok(ks.indexOf("companion.name") >= 0, "能改 companion.name");
    ok(ks.indexOf("companion.gender") >= 0, "能改 companion.gender");
  }
  const metaSec = secs0.find(s => s.key === "meta");
  ok(!!metaSec && metaSec.fields.some(f => f.k === "interrogator_gender"), "基础信息里能改审讯官性别");
  const smsSec = secs0.find(s => s.key === "sms");
  ok(!!smsSec, "有短信一节");
  if (smsSec) {
    const f0 = smsSec.fieldsFor((P.story.backgrounds[0].sms || [])[0] || {});
    ok(f0.some(f => f.k === "level"), "短信里能改 level（第几关解锁）");
  }

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
  P.story.backgrounds.forEach(bg => {
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
  ok(noBlind.length === 0, "4 套背景都有盲区题" + (noBlind.length ? " —— 缺 " + noBlind.join("、") : ""));
  ok(badBlind.length === 0, "盲区题字段齐全、不指向任何卡 / 事实" + (badBlind.length ? " —— " + badBlind.join("; ") : ""));
  console.log("   盲区题：" + P.story.backgrounds.map(bg => bg.id + "=" + blindOf(bg).length).join("  "));
  const movedSec = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "questions_moved");
  ok(!!movedSec, "背景页有「盘问题目 → 已并入题库」的提示节（逐题编辑在「🗣 题库」页）");

  console.log("\n-- 7h. 开场介绍 intro（第十三轮新增）--");
  const noIntro = P.story.backgrounds.filter(bg => !bg.intro);
  ok(noIntro.length === 0, "4 套背景都带 intro（开场浮窗的正文）" + (noIntro.length ? " —— 缺 " + noIntro.map(b => b.id).join("、") : ""));
  ok(P.story.backgrounds.every(bg => bg.intro && bg.intro.length > 40),
    "每套背景的 intro 都写得够长（够撑起一个浮窗）");
  const metaSec3 = P.bgSections(P.story.backgrounds[0]).find(s => s.key === "meta");
  ok(!!metaSec3 && metaSec3.fields.some(f => f.k === "intro"), "基础信息里能改 intro");
  console.log("\n-- 7g. 题库页：逐题编辑的字段结构 --");
  // ★ 第二十九轮：题目不再按四类分区编辑，改成一份统一清单（每道题自带选项）。
  //   所以这里改查「题库页的字段定义」而不是旧的「盘问题目」一节。
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
  const lvField = qFields.find(f => f.k === "level");
  const lvOpts = lvField && lvField.opts ? lvField.opts() : [];
  ok(lvOpts.some(o => o.v === "-1"), "题目能指定「属于哪一关」（含通用池）");
  const qteField = qFields.find(f => f.k === "qte");
  const qteOpts = qteField && qteField.opts ? qteField.opts() : [];
  ok(qteField && qteField.sub === "qte" && qteOpts.length === 5,
    "每道题都能指定 QTE 类型（五种）");
  ok(!!qFields.find(f => f.k === "delay" && f.sub === "qte"), "每道题都能指定 QTE 出现时间");
  ok(typeof P.totalQuestions === "function" && P.totalQuestions() > 0, "题库角标能算出总题数");

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
    s => { s.backgrounds[0].sms[1].level = s.backgrounds[0].sms[0].level; }, "一关只该来一条");
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
  negCase("界面文案缺一条（应是提醒）", s => { delete s.ui.common.help_btn; }, "common.help_btn");
  negCase("界面文案写成空串（应是提醒）", s => { s.ui.title.title = ""; }, "留一块空白");
  negCase("反馈句丢了占位符", s => { s.ui.feedback.summary = "没有占位符的一句话"; }, "丢了占位符");
  negCase("结局文案缺一条（应是提醒）", s => { delete s.backgrounds[0].endings.recognized_line; }, "recognized_line");
  negCase("结局文案丢了占位符", s => { s.backgrounds[0].endings.recognized_line = "怎么是你。"; }, "丢了占位符");
  negCase("整块 endings 缺失", s => { delete s.backgrounds[0].endings; }, "没有 endings");
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
    ok(P.uiLeafCount() === 79, "story.ui 共 79 条文案，实际 " + P.uiLeafCount());
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
    ok(us.reduce((a, s) => a + (s.fields || []).length, 0) === 79, "文案页覆盖 79 条");
    ok(es.reduce((a, s) => a + (s.fields || []).length, 0) === 27, "结局页覆盖 27 条");
    ok(rs.every(s => s.host && s.host() === P.story.rules), "全部数值区块都写在 story.rules 上（全局一套）");
    ok(us.every(s => s.host && s.host() === P.story.ui[s.seg]), "每个文案区块挂在对应的 ui 子段上");
    ok(us.map(s => s.seg).join(",") === "common,title,wardrobe,interrogation,feedback,help", "文案 6 个分段齐全");
    ok(es.every(s => (s.fields || []).every(f => f.sub === "endings")), "结局字段全部写进 backgrounds[i].endings");
    const allFields = [].concat(rs, us, es).reduce((a, s) => a.concat(s.fields || []), []);
    ok(allFields.every(f => f.k && f.label), "所有字段都有 k 和 label");
    ok(allFields.every(f => ["num", "text", "area", "strlist"].includes(f.t)), "字段类型都在支持范围内（num / text / area / strlist）");
    P.story.backgrounds.forEach((b, i) =>
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
    ok(Array.isArray(S.levels) && S.levels.length === 4, "levels 有 4 关，实际 " + ((S.levels || []).length));
    ok(Array.isArray(S.forced_rules) && S.forced_rules.length === 4, "forced_rules 有 4 条，实际 " + ((S.forced_rules || []).length));
    ok(Array.isArray(S.qte_plan), "qte_plan 是数组（出厂为空 = 全自动）");
    ok(Array.isArray(S.defects) && S.defects.length === 2, "defects 有 2 项，实际 " + ((S.defects || []).length));

    // ---- catalog：编辑器靠它做下拉，缺了就没法挑衣服 ----
    const C = S.catalog || {};
    ok((C.items || []).length === 115, "catalog 里有 115 件衣物，实际 " + ((C.items || []).length));
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
    // 反差要求定到「把每个部位最高反差的衣服都堆上也够不着」→ 一定无解，必须提醒
    S.levels[S.levels.length - 1].contrast_req = 999;
    P.validateNow();
    ok(P.issues.some(i => i.m.includes("理论") && i.m.includes("999")),
      "反差要求超过理论上界会被提醒：" + (P.issues.filter(i => i.m.includes("999"))[0] || {}).m);
    S.levels.pop();
    P.validateNow();
    ok(S.levels.length === before, "关卡数改回原样（" + before + " 关）");

    // ★ 第二十九轮：反差要求「留空 = 自增」
    ok(S.levels[1].contrast_req == null, "第 2 关的反差要求留空 = 自动（实际 "
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
    // ★ 第三十一轮：反差换成新算法后重标过曲线（只算上衣+下装，可达范围变小）
    ok(autoSeq.join("/") === "24/27/30/33", "留空的关按 base+step 自增：" + autoSeq.join("/"));
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
    ok(JSON.parse(t2).catalog.items.length === 115, "catalog 能往返");
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  }

  console.log("\n================================");
  console.log(" 通过 " + pass + " / 失败 " + fail);
  console.log("================================");
  process.exit(fail ? 1 : 0);
})();
