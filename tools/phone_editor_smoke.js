/* 手机编辑器冒烟测试：用极简 DOM 桩把 tools/phone_editor.html 里的脚本跑起来，
   验证 (1) 数据能载入 (2) 校验为 0 错误 (3) 每个界面都能渲染
   (4) 所有预览函数不炸 (5) 文案段字段齐全、占位符个数对得上
   (6) 反向用例：改坏了必须报错 (7) 撤销 / 重做 (8) JSON 往返无损。
   跑完即删（这个文件本身不删，是常驻测试）。 */
const fs = require("fs");
const path = require("path");

const ROOT = path.dirname(__dirname);   // tools/ 的上一级 = 项目根
const HTML = path.join(ROOT, "tools", "phone_editor.html");
const html = fs.readFileSync(HTML, "utf8");

// ---- 抽 seed JSON ----
const seedM = html.match(/<script id="seed" type="application\/json">([\s\S]*?)<\/script>/);
if (!seedM) { console.error("FAIL: 页面里没有 seed 数据块"); process.exit(1); }
const seedText = seedM[1];
if (seedText.indexOf("__PHONE_JSON__") === 0) {
  console.error("FAIL: seed 还是占位符 —— 先跑 python tools/build_phone_editor.py");
  process.exit(1);
}
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
    readOnly: false, disabled: false, innerHTML: "", rows: 0, type: "",
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
globalThis.fetch = () => Promise.reject(new Error("no network in smoke test"));

// ---- 探针：把内部函数暴露出来 ----
mainJs += `
;globalThis.__probe = {
  get story(){ return story; }, set story(v){ story = v; },
  get issues(){ return issues; },
  get fileName(){ return fileName; },
  get view(){ return view; }, set view(v){ view = v; },
  get previewThread(){ return previewThread; }, set previewThread(v){ previewThread = v; },
  get previewBg(){ return previewBg; }, set previewBg(v){ previewBg = v; },
  get undoStack(){ return undoStack; }, get redoStack(){ return redoStack; },
  loadStory, validateNow, renderAll, go, toJSON, getSeed, openSet, foldSet,
  commit, undo, redo, snapshot, markDirty, buildNav, renderForm, renderPreview, renderStatus,
  buildPhone, listPreview, threadPreview, intrPreview,
  phone, sec, bgs, bgAt, threadsOf, factsOf, valueOpts,
  fmt, countPh, specPh, short, num,
  GROUPS, PHONE_FIELDS, PH_EXPECT, PH_MEANING,
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
  ok(!!P.story.phone && typeof P.story.phone === "object", "顶层有 phone 段");
  const PH = P.story.phone;
  ["shell", "messages", "memo", "album", "notes"].forEach(k =>
    ok(!!PH[k] && typeof PH[k] === "object", "phone." + k + " 存在"));
  ok(Array.isArray(PH.interrogator_sms) && PH.interrogator_sms.length > 0,
    "phone.interrogator_sms 有 " + (PH.interrogator_sms || []).length + " 条");
  console.log("   背景:", P.story.backgrounds.map(b => b.name).join(" / "));

  console.log("\n-- 2. 校验 --");
  const errs = P.issues.filter(i => i.lv === "e");
  const warns = P.issues.filter(i => i.lv === "w");
  errs.slice(0, 25).forEach(i => console.log("   [错误] " + i.m));
  warns.slice(0, 25).forEach(i => console.log("   [提醒] " + i.m));
  ok(errs.length === 0, "0 个错误（实际 " + errs.length + "）");
  ok(warns.length === 0, "0 个提醒（实际 " + warns.length + "）");
  console.log("   错误 " + errs.length + " / 提醒 " + warns.length);

  console.log("\n-- 3. 每个界面都能渲染 --");
  const views = [
    { kind: "home" }, { kind: "shell" }, { kind: "memo" }, { kind: "album" }, { kind: "notes" },
    { kind: "group", group: "interrogator", bg: 0 },
  ];
  P.bgs().forEach((b, i) => {
    views.push({ kind: "group", group: "companion", bg: i });
    views.push({ kind: "group", group: "friends", bg: i });
  });
  let viewBad = [];
  views.forEach(v => {
    try { P.go(v); if (!P.view) viewBad.push(JSON.stringify(v)); }
    catch (e) { viewBad.push(JSON.stringify(v) + " → " + (e && e.message)); }
  });
  ok(viewBad.length === 0, "全部 " + views.length + " 个界面可渲染" +
    (viewBad.length ? " —— " + viewBad.join("; ") : ""));
  console.log("   界面数:", views.length);

  console.log("\n-- 4. 所有预览函数 --");
  let pvOk = 0, pvBad = [];
  const tryPv = (label, fn) => {
    try { const n = fn(); if (!n) pvBad.push(label + " 返回空"); else pvOk++; }
    catch (e) { pvBad.push(label + " " + (e && e.message)); }
  };
  tryPv("home", () => { P.go({ kind: "home" }); return P.buildPhone(); });
  tryPv("shell", () => { P.go({ kind: "shell" }); return P.buildPhone(); });
  tryPv("memo", () => { P.go({ kind: "memo" }); return P.buildPhone(); });
  tryPv("album", () => { P.go({ kind: "album" }); return P.buildPhone(); });
  tryPv("notes", () => { P.go({ kind: "notes" }); return P.buildPhone(); });

  ["interrogator", "companion", "friends"].forEach(g => {
    P.bgs().forEach((bg, bi) => {
      tryPv(g + "/" + bg.id + "/列表", () => {
        P.go({ kind: "group", group: g, bg: bi });
        P.renderPreview();
        return P.listPreview(g, bi);
      });
      P.threadsOf(g, bi).forEach(t => {
        tryPv(g + "/" + bg.id + "/" + t.id, () => {
          P.go({ kind: "group", group: g, bg: bi });
          P.previewThread = String(t.id);
          P.renderPreview();
          return P.threadPreview(String(t.id), g, bi);
        });
      });
    });
  });
  tryPv("审问官对话页", () => {
    P.go({ kind: "group", group: "interrogator", bg: 0 });
    P.previewThread = "__interrogator__";
    P.renderPreview();
    return P.intrPreview();
  });
  ok(pvBad.length === 0, "全部预览可渲染");
  pvBad.slice(0, 10).forEach(m => console.log("   [预览失败] " + m));
  console.log("   预览成功 " + pvOk + " 个");

  console.log("\n-- 5. 文案段：字段齐全 + 占位符个数 --");
  const missField = [], badPh = [];
  Object.keys(P.PHONE_FIELDS).forEach(name => {
    const data = PH[name] || {};
    P.PHONE_FIELDS[name].forEach(f => {
      const v = data[f.k];
      if (v === undefined || v === null || v === "") missField.push(name + "." + f.k);
      const want = P.PH_EXPECT[name + "." + f.k];
      if (want !== undefined && P.countPh(v) !== want)
        badPh.push(name + "." + f.k + " 期望 " + want + " 个 %，实际 " + P.countPh(v));
    });
  });
  ok(missField.length === 0, "每个文案字段都非空" + (missField.length ? " —— 缺 " + missField.join("、") : ""));
  ok(badPh.length === 0, "每个占位符个数都对" + (badPh.length ? " —— " + badPh.join("; ") : ""));
  const nFields = Object.keys(P.PHONE_FIELDS).reduce((a, k) => a + P.PHONE_FIELDS[k].length, 0);
  console.log("   文案字段 " + nFields + " 个，其中带占位符 " + Object.keys(P.PH_EXPECT).length + " 个");
  // 盲区题唯一的依据：备忘录第一条最后那行「该怎么答」
  ok((P.PHONE_FIELDS.memo || []).some(f => f.k === "howto_line"),
    "备忘录一节里有「该怎么答」那一行");
  ok(P.PH_EXPECT["memo.howto_line"] === 1, "「该怎么答」声明了 1 个占位符");

  console.log("\n-- 5b. 占位符对照表覆盖了每个带占位符的字段 --");
  const noMeaning = [];
  Object.keys(P.PH_EXPECT).forEach(path => {
    const [secName, k] = path.split(".");
    const f = (P.PHONE_FIELDS[secName] || []).find(x => x.k === k);
    if (!f) noMeaning.push(path + "（字段定义里没有）");
    else {
      const want = P.PH_EXPECT[path];
      const hasMap = !!P.PH_MEANING[path];
      if (want >= 4 && !hasMap) noMeaning.push(path + "（占位符多但没有对照表）");
      if (hasMap && P.PH_MEANING[path].length !== want)
        noMeaning.push(path + "（对照表 " + P.PH_MEANING[path].length + " 项 ≠ " + want + " 个 %）");
    }
  });
  ok(noMeaning.length === 0, "对照表完整" + (noMeaning.length ? " —— " + noMeaning.join("; ") : ""));

  console.log("\n-- 5c. 分组标题已从手机界面删除（编辑器也不再改这些死字段）--");
  const msgFields = (P.PHONE_FIELDS.messages || []).map(f => f.k);
  ["group_interrogator", "group_companion", "group_friends",
   "group_interrogator_hint", "group_companion_hint", "group_friends_hint",
   "group_interrogator_empty", "group_companion_empty", "group_friends_empty",
   "companion_thread_hint"].forEach(k => {
    ok(msgFields.indexOf(k) < 0, "编辑器不再暴露死字段 " + k);
  });
  ok(P.GROUPS.length === 3, "GROUPS 正好三个分组（编辑器的导航页签，不是手机里的标题）");
  ok(P.GROUPS.map(g => g.key).join(",") === "interrogator,companion,friends",
    "分组顺序 = 审问官 / 同行的人 / 朋友");

  console.log("\n-- 5d. 备忘录「这一关」那一条已撤、备注改成按轮次回放 --");
  ok(msgFields.indexOf("head_level") < 0 && msgFields.indexOf("level_body") < 0
     && msgFields.indexOf("forced_item") < 0,
    "备忘录不再暴露「第三条 · 这一关」那几个字段（内容整局不变）");
  const nsFields = (P.PHONE_FIELDS.notes || []).map(f => f.k);
  ok(nsFields.indexOf("head_round") >= 0 && nsFields.indexOf("q_line") >= 0
     && nsFields.indexOf("a_line") >= 0,
    "备注改成「第 N 轮 / 他问 / 我答」三条");
  ["hint", "head_official", "head_stated", "unknown", "no_facts", "no_stated", "mismatch"]
    .forEach(k => ok(nsFields.indexOf(k) < 0, "备注里不再暴露旧字段 " + k));
  ok(!!PH.notes && !!PH.notes.head_round && !!PH.notes.q_line && !!PH.notes.a_line,
    "备注三条新文案在数据里都有值");

  console.log("\n-- 6. 短信数据 --");
  const badLevel = [], badDup = [], badId = [], badMsg = [], compReveals = [], badAlign = [];
  let nComp = 0, nFri = 0;
  P.bgs().forEach(bg => {
    const order = (bg.facts || []).map(f => f.id);
    const check = (arr, gk) => {
      const ids = new Set(), byLv = new Map();
      (arr || []).forEach(t => {
        if (!t.id) badId.push(bg.id + "/" + gk + " 缺 id");
        else if (ids.has(t.id)) badId.push(bg.id + "/" + gk + " id 重复 " + t.id);
        ids.add(t.id);
        if (!(t.messages || []).length) badMsg.push(bg.id + "/" + t.id + " 没有消息");
        if (!Number.isInteger(t.level)) badLevel.push(bg.id + "/" + t.id + " = " + t.level);
        else if (t.level < 0 || t.level > order.length - 1) badLevel.push(bg.id + "/" + t.id + " 越界 " + t.level);
        else {
          if (byLv.has(t.level)) badDup.push(bg.id + " 第" + (t.level + 1) + "关有两条" + gk);
          byLv.set(t.level, t.id);
        }
        if (gk === "companion" && (t.reveals || []).length) compReveals.push(bg.id + "/" + t.id);
      });
      order.forEach((fid, i) => { if (!byLv.has(i)) badDup.push(bg.id + " 第" + (i + 1) + "关没有" + gk + "短信"); });
      return arr || [];
    };
    nFri += check(bg.sms, "friends").length;
    nComp += check(bg.companion_sms, "companion").length;

    // 与朋友的那一组必须揭示本关的官方口径
    (bg.sms || []).forEach(t => {
      if (!Number.isInteger(t.level) || t.level < 0 || t.level >= order.length) return;
      const got = (t.reveals || []).map(rv => rv.fact);
      if (got.indexOf(order[t.level]) < 0)
        badAlign.push(bg.id + " 第" + (t.level + 1) + "关 揭示 [" + got.join("、") + "] ≠ " + order[t.level]);
    });
  });
  ok(badId.length === 0, "每条短信都有唯一 id" + (badId.length ? " —— " + badId.join("; ") : ""));
  ok(badMsg.length === 0, "每条短信都有消息" + (badMsg.length ? " —— " + badMsg.join("; ") : ""));
  ok(badLevel.length === 0, "level 都是合法整数且在范围内" + (badLevel.length ? " —— " + badLevel.join("; ") : ""));
  ok(badDup.length === 0, "每关恰好一条（两组各自）" + (badDup.length ? " —— " + badDup.join("; ") : ""));
  ok(compReveals.length === 0, "与 C 的短信都不带 reveals" + (compReveals.length ? " —— " + compReveals.join("、") : ""));
  ok(badAlign.length === 0, "与朋友的短信 level 与 facts 顺序逐关对齐" + (badAlign.length ? " —— " + badAlign.join("; ") : ""));
  console.log("   与审问官 " + PH.interrogator_sms.length + " 条 / 与同行的人 " + nComp + " 条 / 与朋友 " + nFri + " 条");

  console.log("\n-- 7. 保存格式 --");
  const text = P.toJSON();
  const back = JSON.parse(text);
  ok(JSON.stringify(back) === JSON.stringify(P.story), "toJSON → parse 往返无损");
  ok(text.includes('"phone"'), "输出含 phone 段");
  ok(text.includes('"companion_sms"'), "输出含 companion_sms");
  // ★ 第二十九轮：题目并入统一清单，关键字段从 companion_questions 换成 questions
  ok(text.includes('"backgrounds"') && text.includes('"questions"'),
    "输出里剧情文本还在（不是只写了手机那部分）");
  ok(text.endsWith("\n"), "输出以换行结尾");
  console.log("   输出 " + Buffer.byteLength(text, "utf8") + " 字节");

  console.log("\n-- 8. 渲染不污染数据 --");
  {
    const keep = JSON.parse(JSON.stringify(P.story));
    const before = JSON.stringify(P.story);
    views.forEach(v => { try { P.go(v); } catch (e) {} });
    P.renderAll();
    const after = JSON.stringify(P.story);
    ok(before === after, "把所有界面渲染一遍后，数据一字未改");
    P.loadStory(keep, "t.json", false);
  }

  console.log("\n-- 9. 反向测试：故意改坏，校验必须报错 --");
  const pristine = JSON.parse(JSON.stringify(P.story));
  const negCase = (name, mutate, expect, lv) => {
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
    mutate(P.story);
    P.validateNow();
    const hit = P.issues.some(i => (lv ? i.lv === lv : true) && i.m.includes(expect));
    ok(hit, "抓到「" + name + "」" + (hit ? "" : " —— 期望包含「" + expect + "」，实际：" +
      P.issues.map(i => "[" + i.lv + "]" + i.m).join(" | ").slice(0, 260)));
  };

  negCase("整段 phone 没了", s => { delete s.phone; }, "缺少 phone 段");
  negCase("shell 段没了", s => { delete s.phone.shell; }, "phone.shell 整段没了");
  negCase("文案占位符少写一个 %s",
    s => { s.phone.messages.hint = "已读 %d 条"; }, "需要 2 个占位符", "e");
  negCase("文案占位符多写一个",
    s => { s.phone.memo.like_line = "%s %s %s"; }, "需要 1 个占位符", "e");
  negCase("「该怎么答」那一行少写占位符",
    s => { s.phone.memo.howto_line = "该怎么答：看情况"; }, "需要 1 个占位符", "e");
  negCase("文案里写了不该有的 %s",
    s => { s.phone.album.dead = "底片救不回来 %s"; }, "不是模板", "w");
  negCase("状态栏里写了个真占位符",
    s => { s.phone.shell.signal = "4G %s"; }, "不是模板", "w");
  // 反过来：百分号不该被当成占位符
  {
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
    P.validateNow();
    ok(!P.issues.some(i => i.m.includes("shell.signal")),
      "状态栏的 🔋78% 不会被误报成占位符");
    P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  }
  negCase("文案字段被清空",
    s => { s.phone.notes.title = ""; }, "是空的", "w");
  negCase("与审问官的短信全删了",
    s => { s.phone.interrogator_sms = []; }, "interrogator_sms 是空的", "w");
  negCase("某套背景没有 companion_sms",
    s => { delete s.backgrounds[0].companion_sms; }, "没有 companion_sms", "w");
  negCase("短信线程缺 id",
    s => { delete s.backgrounds[0].companion_sms[0].id; }, "缺 id", "e");
  negCase("短信线程 id 重复",
    s => { s.backgrounds[0].companion_sms[1].id = s.backgrounds[0].companion_sms[0].id; }, "id 重复", "e");
  negCase("短信线程一条消息都没有",
    s => { s.backgrounds[0].companion_sms[0].messages = []; }, "一条消息都没有", "e");
  negCase("level 越界",
    s => { s.backgrounds[0].companion_sms[0].level = 9; }, "越界", "e");
  negCase("level 不是整数",
    s => { s.backgrounds[0].companion_sms[0].level = "第一关"; }, "必须是整数", "e");
  negCase("一关两条同时解锁",
    s => { s.backgrounds[0].companion_sms[1].level = s.backgrounds[0].companion_sms[0].level; }, "同时解锁", "w");
  negCase("某一关没有解锁短信",
    s => { s.backgrounds[0].companion_sms[0].level = 3; }, "没有解锁的短信", "w");
  negCase("与 C 的短信混进了 reveals",
    s => { s.backgrounds[0].companion_sms[0].reveals = [{ fact: "origin", value: "x" }]; },
    "带了 reveals", "w");
  negCase("与朋友的短信揭示指向不存在的事实",
    s => { s.backgrounds[0].sms[0].reveals[0].fact = "nope"; }, "指向了不存在的事实", "e");
  negCase("与朋友的短信揭示指向不存在的版本",
    s => { s.backgrounds[0].sms[0].reveals[0].value = "ghost"; }, "在事实", "e");
  negCase("与朋友的短信揭示的不是官方口径（应是提醒）", s => {
    const bg = s.backgrounds[0];
    const rv = bg.sms[0].reveals[0];
    const f = bg.facts.find(x => x.id === rv.fact);
    rv.value = f.values[1].id;
  }, "而不是官方口径", "w");
  negCase("与朋友的短信 level 与 facts 顺序没对齐", s => {
    const a = s.backgrounds[0].sms.find(t => t.level === 0);
    const b = s.backgrounds[0].sms.find(t => t.level === 1);
    const t = a.level; a.level = b.level; b.level = t;
  }, "没对齐", "e");
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);

  console.log("\n-- 10. 撤销 / 重做 --");
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  const q = () => P.story.phone.messages.title;
  const orig = q();
  ok(P.undoStack.length === 1, "载入后撤销栈只有 1 帧，实际 " + P.undoStack.length);

  P.story.phone.messages.title = "A";   P.commit();          // 离散一步
  P.story.phone.messages.title = "AB";  P.commit("txt:x");   // 连续输入
  P.story.phone.messages.title = "ABC"; P.commit("txt:x");   // 应合并进上一帧
  ok(P.undoStack.length === 3, "连续输入被合并（栈深 3），实际 " + P.undoStack.length);

  P.undo();
  ok(q() === "A", "撤销一次回到上一次提交点，实际「" + q() + "」");
  P.undo();
  ok(q() === orig, "再撤销回到原始文本");
  ok(P.redoStack.length === 2, "重做栈攒了 2 帧，实际 " + P.redoStack.length);
  P.redo();
  ok(q() === "A", "重做一次 → 「A」，实际「" + q() + "」");
  P.redo();
  ok(q() === "ABC", "重做两次 → 「ABC」（落到正确状态，不是中间态）");
  ok(P.redoStack.length === 0, "重做栈已清空");

  for (let i = 0; i < 10; i++) P.undo();
  ok(q() === orig, "反复撤销到底仍停在原始文本（不越界）");

  console.log("\n-- 11. 改一条短信 → 预览跟着变 --");
  P.loadStory(JSON.parse(JSON.stringify(pristine)), "t.json", false);
  P.go({ kind: "group", group: "companion", bg: 0 });
  const c0 = P.bgs()[0].companion_sms[0];
  const oldText = c0.messages[c0.messages.length - 1].text;
  c0.messages[c0.messages.length - 1].text = "【冒烟测试改过的句子】";
  P.renderPreview();
  P.previewThread = String(c0.id);
  const pv = P.threadPreview(String(c0.id), "companion", 0);
  const flat = JSON.stringify(pv.nodes.map(n => n.textContent || ""));
  ok(flat.includes("【冒烟测试改过的句子】"), "预览里能看到刚改的句子");
  c0.messages[c0.messages.length - 1].text = oldText;

  console.log("\n-- 12. fmt / countPh 小工具 --");
  ok(P.countPh("%s 和 %s") === 2, "countPh 数对了 2 个");
  ok(P.countPh("100%% 确定") === 0, "%% 不算占位符");
  ok(P.countPh("") === 0, "空串 0 个");
  ok(P.countPh("🔋78%") === 1, "孤零零的 % 也算一个（countPh 是宽松的）");
  ok(P.specPh("🔋78%") === 0, "但它不是占位符 —— specPh 认得出");
  ok(P.specPh("%s %d %f") === 3, "specPh 认得 %s %d %f");
  ok(P.fmt("%s 和 %s", ["甲", "乙"]) === "甲 和 乙",
    "fmt 正常替换（不是「甲s 和 乙s」）—— 实际「" + P.fmt("%s 和 %s", ["甲", "乙"]) + "」");
  ok(P.fmt("已读 %d / %d 条", [1, 5]) === "已读 1 / 5 条", "fmt 换掉 %d 连类型字母一起");
  ok(P.fmt("%s 和 %s", ["只有一个"]) === "%s 和 %s", "参数个数对不上时原样返回（不炸）");
  ok(P.fmt("%d%%", [5]) === "5%", "fmt 把 %% 还原成一个 % —— 实际「" + P.fmt("%d%%", [5]) + "」");
  ok(P.fmt("第 %d / %d 关 · %s\n反差值要求 %d ｜ 暴露值上限 %d\n强制装备：%s",
      [1, 4, "第一关", 20, 22, "朴素薄纱罩衫（暴露 7）"])
    === "第 1 / 4 关 · 第一关\n反差值要求 20 ｜ 暴露值上限 22\n强制装备：朴素薄纱罩衫（暴露 7）",
    "fmt 能正确渲染 memo.level_body 那 6 个占位符");
  ok(P.fmt("中文 + 符号 ✔ 也不影响替换：%s", ["✔"]) === "中文 + 符号 ✔ 也不影响替换：✔",
    "fmt 处理中文 + 特殊符号");

  console.log("\n================================");
  console.log(" 通过 " + pass + " / 失败 " + fail);
  console.log("================================");
  process.exit(fail ? 1 : 0);
})();
