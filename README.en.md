# Faceless: Disguise & Interrogation

A single-player text AVG with dress-up, built in Godot 4.3. One run is two rounds: one dress-up, one interrogation.

---

## Quick start

| Goal | Double-click |
|---|---|
| Play | `run_game.bat` |
| Run all tests | `run_tests.bat` |
| Edit story / numbers / copy | `open_story_editor.bat` |

Requires **Godot 4.3**. `run_game.bat` looks for a Godot binary in this order:
the `GODOT` environment variable, a `godot/` folder inside the project, then `godot` on `PATH`.

---

## Premise

The interrogator is **an old acquaintance of "A"**. You are A — a gang courier who now has to pass as "B", someone he has never met.

- He has collected a pile of **dossier fragments** about A. You got copies through an inside contact.
- From those fragments you piece together **how he remembers you** — which secrets he knows, what he thinks you look like — and then dress as the opposite.
- As B you must not say anything only A would know, and must not contradict yourself. He has a good memory and carries a notebook.
- A **companion (C)** travels with you. He knows you are A and that you are pretending to be B, but he neither helps nor exposes you.

| Marker | Who | Notes |
|---|---|---|
| **A** | True identity | You. The person the interrogator knows |
| **B** | Cover | The person you are playing. Must look as unlike A as possible |
| **C** | Companion | Knows the truth, is not on your side |
| **Interrogator** | The one being deceived | Knows A, has never seen B. Temperament is randomised per run |

In the game text the interrogator is called **男主** ("male lead") and the companion **男二**
("second male lead"); in the "Qiuqiu's New Toy" background the companion is a dog, written 男二（狗）.
Those strings live in `data/story.json` and can be edited at will. The A / B / C markers in code never change.

### Backgrounds

| Background | A's true identity | Interrogator | You play (B) | Companion (C) |
|---|---|---|---|---|
| Border outpost | Ring courier (Shen Tang) | Veteran of the post | Northern spice trader | Carter, Old Cui |
| Town waystation | Assassins' guild courier (Su Wan) | Waystation clerk | Wandering musician | Musician, A-Wu |
| Ducal residence | Court agent (Lu Qingwu) | House steward | Newly hired copyist | Copyist, Cheng Jiu |
| Harbour customs | Smuggler navigator (A-Yuan) | Customs inspector | Fishmonger from the west wharf | Sailor, A-Jiao |

Two backgrounds ship enabled — **Border outpost** and **Town waystation**. The other two are
marked as drafts (`enabled: false`): they are never rolled and never listed on the level select screen.

---

## How a run plays

```
Title screen → Level select (pick a background) → Wardrobe (dress up + check phone)
                                                  ↓
                                          Interrogation (6 questions)
                                                  ↓
                    ┌─────────────────────────────┴─────────────────────────────┐
              Passed (suspicion < 100)                              Failed (recognised / arrested / contradiction)
                    ↓                                                         ↓
              Round 2 (higher acceptance)                          Restart this round (back to wardrobe)
                    ↓
              Run complete → title screen
```

- A run = **one random background + one random true appearance + one random interrogator temperament**, **2 rounds**.
- Each round = one dress-up (wardrobe) + one interrogation.
- Failure only voids **the current round**. True appearance, messages already read, photos already
  cleaned, and acceptance all carry over. Only this round's outfit is redone.
- Acceptance earned each round is banked immediately (`user://profile.json`) and **kept globally**,
  even across retries.

---

## Round structure: the wardrobe

The screen has only two things: **dressing up** and **the phone**. Left side is a paper-doll preview
plus two gauges; right side is 12 visible slots, each with a section header and that body part's
garment cards. The phone is a floating panel opened from a button in the bottom-left corner.

```
┌──────────────┬──────────────────────────────────────────────────────┐
│ Outfit / True│  ▍Hair                        Current: Neat short    │
│  ┌────────┐  │  ┌───────────────┐ ┌───────────────┐ ┌─────────────┐ │
│  │  doll  │  │  │[img] Neat     │ │[img] Side braid│ │[img] Long  │ │
│  └────────┘  │  │ E ●○○○○○○     │ │ E ●○○○○○○     │ │      …      │ │
│  current …   │  └───────────────┘ └───────────────┘ └─────────────┘ │
│ ───────────  │  ▍Headwear                    Current: Wide hat     │
│ Exposure ●○○…│  … (12 slots, scroll down)                           │
│ ▓▓▓▓▓▼░░│░░  │                                                      │
│ 4 / 30       │                                                      │
│ Contrast ●○○…│                                                      │
│ ▓▓▓▼░░░░│░░  │                                                      │
│ 0 / 125      │                                                      │
├──────────────┴──────────────────────────────────────────────────────┤
│                                    [Phone]  [Auto-solve] [Enter >]   │
└─────────────────────────────────────────────────────────────────────┘
```

**This phase does not judge you.** It lays out the numbers and nothing else — no pass/fail.
The verdict happens the moment the door opens in phase two.

### The three numbers

| Stat | Meaning | Rule |
|---|---|---|
| **Exposure** | How revealing a garment is | The sum across all equipped items **must not exceed the cap**; cap = `10 + acceptance × 2` |
| **Acceptance** | How far you are willing to go | Gates high-threshold items (hard requirement); rises each round |
| **Contrast** | How far you deviate from how he remembers you | Summed over all slots; **must be ≥ this round's requirement** or you are recognised on sight |

Shipped values for the two rounds:

| Round | Acceptance | Exposure cap | Contrast required |
|---|---|---|---|
| 1 | 10 | **30** | **125** |
| 2 | 19 | **48** | **150** |

### How contrast is computed

```
per-slot contrast = |your exposure − the true appearance's exposure| × 5
                  + (same exposure but a different garment) ? swap bonus : 0
```

- The **× 5 factor** is `rules.contrast_per_exposure`, editable.
- Swap bonus: **2** base, **12** for hair, **10** for makeup. Both conditions are required —
  the exposure must match **and** it must not be the true-appearance garment.
- **Wearing the true-appearance item scores 0**, whatever its exposure.
- Every **visible** slot counts (i.e. those that pass the underwear visibility gate).

Gauge scales are **absolute**: exposure 71, contrast 270. The threshold marks therefore land in
different places each round, so you can see the budget loosening at a glance.

### The two defects

The character carries two defects that cannot be removed:

| Defect | Tags that cover it |
|---|---|
| **Gang tattoo on the back of the right hand** | `long_sleeve` (2 tops) |
| **Slave brand on the side of the neck** | `high_collar` or `scarf` |

A's true appearance happens to be **one high-collared long-sleeve shirt covering both**.
To raise contrast you must take it off, and the covering duty shifts to the neckwear slot —
**hiding defects** and **not looking like yourself** are inherently opposed.

**If all coverings for a defect sit in a single slot, that slot is excluded from forced-equipment pools**
(`OutfitData.forced_locked_out_slots()`). Otherwise "forced to wear short sleeves" means the tattoo
is exposed *and* the top cannot be changed — an unwinnable round.

### Slots and garments

**19 slot definitions, 7 temporarily disabled, 12 visible to the player. 156 garments, 128 visible.**

| zorder | Slot | Garments | Status |
|---|---|---|---|
| 111 | `makeup` | 6 | visible |
| 121 | `accessory` | 6 | disabled |
| 131 | `piercing` | 4 | disabled |
| 141 | `tattoo` | 7 | visible (multi-slot, up to 2 at once) |
| 161 | `stockings` | 12 | visible |
| 171 | `panties` | 9 | visible |
| 191 | `bottom` | 21 | visible |
| 196 | `tool` | 2 | disabled (manual equip only) |
| 201 | `bra` | 7 | visible |
| 211 | `top` | 26 | visible |
| 216 | `dress` | 12 | visible |
| 221 | `gloves` | 4 | disabled |
| 225 | `shoes` | 8 | visible |
| 231 | `robe` | 4 | disabled |
| 241 | `neckwear` | 10 | visible |
| 251 | `hair` | 7 | visible |
| 261 | `earrings` | 4 | disabled |
| 271 | `glasses` | 3 | visible |
| 281 | `headgear` | 4 | disabled |

Disabling only affects **what the player sees**: the wardrobe omits the section, true appearance
never rolls it, the album never photographs it, forced pools never include it.
**No slot definitions, items, or art were deleted** — remove the id from `OutfitData.DISABLED_SLOTS`
and it comes back exactly as it was.

The `hair` slot has no "none" option (there is always hair), so the base body sprite carries no hair.
The z values in `data/doll_au.json` are what actually determine draw order; the table above is only
for reference.

### Underwear visibility gate

`bra` and `panties` only count toward exposure and contrast **when the underwear is visible**.
Any one of three paths suffices:

| Path | Criterion | Marked on |
|---|---|---|
| 1. Sheer outer layer | Semi-transparent / gauze / lace | The outer garment carries `"see": "sheer"` |
| 2. Cut-out | Slit / ultra-short / cropped, visible through the opening | The outer garment carries `"see": "cutout"` |
| 3. Worn alone | The outer layer for that half is empty, so underwear *is* the outermost layer | The "none" item carries `"bare": true` |

The criterion is "**nothing above it covers it**", not "is there an outer garment" — because the
upper body has two layers:

| Combination | Result |
|---|---|
| High-collar long-sleeve shirt + lace bra | Covered |
| Sheer lace top + lace bra | **Counts** (shows through) |
| (No top) + lace bra | **Counts** (worn alone) |
| High-collar shirt + sheer robe | Covered (the **shirt** covers it) |
| Slip dress + lace bra | Covered (the dress's upper half covers it) |

The check skips disabled slots before looking at the remaining layers. The gate governs
**both exposure and contrast** — invisible underwear carries neither risk nor value.
Covered cards are dimmed in the UI, and hovering says the outer layer covers it.

The auto-solve solver treats "top + bra" and "bottom + panties" **as one group** —
an underwear item's contribution depends on the outer layer, so choosing them separately
would produce an "optimal" solution that does not hold.

### Auto-solve

A debug button in the bottom-right corner satisfies **all** outfit requirements at once:
forced equipment worn, exposure within cap, contrast met. It does not pick an outfit you would
want to wear; it only guarantees the check passes.

---

## Round structure: the interrogation

The interrogator is an old acquaintance of A, probing throughout.

### Recognised on sight

The door opens, he looks up — and sees A, not B.

If the wardrobe check failed (contrast too low / defect uncovered / over exposure cap / forced
equipment missing), he puts down the notebook and says the name you had hoped never to hear again:

```
The veteran at the post raises his head. His gaze stops on your face.
He looks for a long time — long enough that everyone nearby goes quiet.
Then he sets down the notebook and says the name you had hoped never to hear again —

"So it's you, Shen Tang."

· Contrast 7 < required 125
```

The round ends there. The result button reads "Restart this round".

### Six questions

Each round has **6 questions** (`rules.questions_per_level`, editable; a single round can override it
via `levels[].questions_per_level`).

Play order **is the order in the question bank** — drag to reorder in the editor's question tab.
The shipped set:

| Position | What | Source |
|---|---|---|
| 1 | A **new claim** question (asks about something new) | Pinned to this round |
| 2 | **Companion question** (attacks the claim you just made) | Pinned to this round |
| 3 | **Blind-spot question** (nothing in the dossier, nothing in the messages) | Pinned to this round |
| 4 | **Cross-round recall** (brings up a claim from an earlier round) | The pool question marked `recall` |
| 5–6 | Dossier questions | 2 drawn at random from the pool |

Round 1 has no previous round, so no recall is scheduled and that slot becomes a third dossier question.

**No contradiction can occur within a round** — each fact is asked at most once per round.
Contradictions only come from cross-round recall.

### Question data shape

Each background has a single `questions[]`; **every question is an object carrying all its own
attributes**. Judgement does not look at "what kind of question this is" — **it only looks at each
option's `tone`**.

| Field | Meaning |
|---|---|
| `id` | Question id, unique within a background |
| `level` | `-1` = shared pool, `0..N` = pinned to round N+1 |
| `speaker` | Who asks. If present in existing data it still applies; absent means the interrogator |
| `text` | The question text |
| `setup` | Optional context line (blind-spot questions use it to say "this is not in the dossier") |
| `card` | Optional dossier card. **If set, judgement follows the card's owner** |
| `fact` | Optional fact link, participates in cross-round consistency checks |
| `recall` | Optional: marks this as the question used for cross-round recall |
| `qte` | `{kind, delay}` — which QTE this question triggers, and after how many seconds |
| `options[]` | Candidate answers |

Each entry in `options[]`:

| Field | Meaning |
|---|---|
| `text` | Option text (may be empty when `tone: silence`, falling back to the generic line) |
| `echo` | Optional: the line shown above the *next* question. Empty = show `text`; filled = shown verbatim. The button label never changes |
| `tone` | **Semantic tag**; judgement reads only this (seven kinds) |
| `suspicion` | Suspicion added if chosen. **Empty = global default** (this is what makes temperament matter) |
| `value` | Only for `version` — which variant this is; cross-round comparison uses it |
| `ending` | Optional: `leak` ends the round immediately. Separate from `tone` |
| `shake` | Optional: screen shake strength when chosen |

The seven `tone` values:

| tone | Meaning | Cost |
|---|---|---|
| `correct` | Answer truthfully (B-card dossier, checks out) | `rules.correct_delta` (**0**) |
| `leak` | Slip up (something only A knows) | `rules.leak_delta` (**100** — immediate loss) |
| `version` | One variant of a factual question | Decided by the consistency check |
| `bluff` | Lie | Computed from the interrogator's temperament |
| `evade` | Deflect | Computed from the interrogator's temperament |
| `silence` | Say nothing | `rules.silence_delta` (**12**, temperament-independent) |
| `made_up` | Invent a detail (blind-spot question) | `rules.blind_made_up_delta` (**48**) |

**Manually authored backgrounds** (`questions_source = "manual"`) get no speaker nameplate and no
"You:" prefix — question text and echo display verbatim. Auto-generated backgrounds keep the nameplate.

### The four question types

**Dossier question** — tests "would B know this?". Judged by the card's owner (`card.owner`):

| Card owner | What the "answer directly" option becomes | Effect |
|---|---|---|
| **B card** (the cover dossier you fabricated) | Recite the dossier detail | Suspicion **0** |
| **A card** (only the true identity knows) | Blurt out A's truth | Suspicion **maxed → immediate exposure** |

Always 4 options: A. answer directly / B. improvise / C. deflect / D. silence.

**Claim question** — offers three variants. Any of them is acceptable; **there is no correct answer**.
Whichever you pick becomes your stated position, and you may not change it later.
Matching the official version in the messages costs nothing; contradicting it costs **+70**.

**Blind-spot question** — asks about something absent from the dossier and from the messages.
**There is no correct answer in terms of content.** It has 2–3 options (invent / lie / deflect), and
**the correct choice is whichever of "lie" and "deflect" is cheaper** — which depends entirely on
the interrogator's temperament. The answer is not in the dossier; it is in whether you thought
about *his* temperament.

**Companion question** — he inserts a formal question, offering a **wrong variant** to test you:

| Your response | Effect |
|---|---|
| Push back (restate your claim) | No change |
| Go along with it | Cost of that option |
| Do not engage | No change, not treated as a position |

★ **His question never counts as a contradiction within the round** — he only makes you bleed,
he does not convict you on the spot. Whatever you answer, the line goes into the notebook,
and his wrong variant **never** becomes your stated position.

### Interrogator temperament

Randomised per run. It sets how expensive "lie" and "deflect" are:

| Temperament | Description | Lie | Deflect |
|---|---|---|---|
| **Suspicious** | The smoother you talk, the more he doubles back | **+45** | +12 |
| **Slow** | Average memory, misses the cracks | **+6** | +10 |
| **Shrewd** | He does not threaten — he lets you trip yourself | +30 | +8 |
| **Impatient** | Hates circling; every dodge makes him tap his pen | +10 | **+32** |
| **Soft-hearted** | Years on the job, tired, does not want to press | +18 | **+6** |

**This information is registered by opening the memo app.** Once you have opened it, you are
considered to have "noted his temperament", and from then on the **dangerous option is marked red
with a ⚠**. If you never opened it, there is no hint at all.

### Expression QTE

A blue bar appears at the bottom of the screen for a **4-second window**. **Hold space** to push it
past the **80%** line.

```
trigger chance = (exposure − 10) / (60 − 10)     clamped to 0..1
```

| Exposure | Trigger chance |
|---|---|
| ≤ 10 | 0 — never |
| 30 | 0.40 |
| ≥ 60 | 1 — every question |

At current acceptance levels, wearing maximum exposure gives roughly **40% / 76%**.

Four rules:

| Rule | Description |
|---|---|
| **Delayed start** | Appears **3 seconds** after switching to a new question, so you can read it first |
| **Single phase** | Once per question; it ends when the question is answered |
| **Locks phone and options** | The phone is unusable during QTE, and options stay locked until you pass 80% |
| **No reflow** | The bar is an anchored overlay outside any layout, so it never pushes other buttons around |

| Result | Effect |
|---|---|
| Held | No change; brief shake (strength 3) |
| Failed | Suspicion **+48**; shake (strength 10) |

**Question 1 never triggers a QTE** (let the opening line land first).
Questions explicitly marked `qte: expression` still fire. A question with no `qte` is `none` —
which also suppresses the random whispered line.

### Companion interference

He also leans over and murmurs half a sentence to steer the interrogator's attention.
**Interval is a fixed 14 seconds**, independent of exposure.

| Kind | When | How to resist | Window |
|---|---|---|---|
| Single key | Most of the time | Press **space** | 2.6 s |
| Combo | 1 in **3** | Press **J → K → L** in order (a wrong key loses immediately) | 2.6 s |

- Interrupted → suspicion **−3**
- Failed / timed out / wrong combo key → suspicion **+36**

**Questions and interference are separate channels**: questions are formal entries in the sequence
and go through position judgement; interference is a pure QTE that only interrupts.
He uses both within the same round.

### Checking the phone mid-interrogation

A button sits in the bottom-left corner of the interrogation screen, in a fixed position.
Opening it overlays the phone while **the question and options remain clickable**
(the overlay does not consume mouse events). It closes automatically when you answer, and when
the next question loads.

There is a cost — he can see you:

| Pulls | Effect |
|---|---|
| 1st | He assumes you are adjusting your outfit; no penalty |
| **2nd onward** | Suspicion **+16 × pulls over the limit** (2nd +16, 3rd +32, 4th +48 …) |

The phone is locked while holding the expression QTE: the bar appearing closes the phone,
greys out the button and relabels it. It unlocks as soon as you finish.

### Suspicion and resolution

| Rule | Description |
|---|---|
| **Only rises within a round** | All negative deltas are clamped to zero. Answering correctly, staying consistent, interrupting the companion — these only write flavour text |
| **Decays between rounds** | Written to `suspicion_carry` at round end; entering the next round it is **× 0.5**, floored at **10** |
| **Starting value** | Round 1 starts at **20** |

**Resolution:**

| Condition | Result |
|---|---|
| Wardrobe check failed | Recognised on sight; round ends |
| Suspicion reaches **100** | Arrested on the spot |
| **2** contradictions accumulated | Exposed on the spot |
| 6 questions answered with suspicion **< 100** | Round passed; advance |
| Both rounds passed | Run complete; back to title screen |

Failing any round sends you **back to the start of that round** (its wardrobe), not to an earlier one.

---

## The phone

The wardrobe and the interrogation share one phone. Four apps:

| App | Content | Mechanic |
|---|---|---|
| **Messages** | Three threads: the interrogator / companion C / friends | **Only what you read counts**; unlocked per round (one new message each round) |
| **Album** | Photos of A taken by others | Blurry, glare, noise. Repeatedly **wipe the glare** to sharpen; 70% before you can make anything out. Some photos are duds that never become clear |
| **Memo** | This run's notebook, **written by the author per round** | One complete list per round, not cumulative. Supports `{true_name}` `{interrogator}` `{temperament}` `{companion}` placeholders |
| **Notes** | Q&A log accumulated per round | Empty in round 1; from round 2 on, every earlier round's questions and answers are laid out |

**The three message threads each do one job:**

| # | Sender | Contents | What reading does |
|---|---|---|---|
| 1 | The interrogator | Event messages. Normally **empty**, thread hidden | Tells you "he saw that"; reveals no official story |
| 2 | Companion C | Knows you are A, **gives you no story**, only reminds you he is always there | **Teaches 0 facts** — by design, not an oversight |
| 3 | Friends | **The only source of official stories** | Each reveals one "official story of B". Unread ones leave you guessing |

★ Why C's messages deliberately carry no facts: the core of the work is "A is alone in playing B".
If C also supplied facts, there would be a second source of correct answers. An assertion guards this.

**Memo**: each round you can write several paragraphs; in-game they join into one continuous text.
Each round can also tick "append the how-to-answer line" — that line comes from this round's
temperament. The memo may be entirely empty, and **blind-spot feedback does not depend on it**
(feedback reads the temperament table directly).

**Album**: photos are captured live by putting this run's true-appearance layers into a `SubViewport`,
so they always match the current true appearance. The glare effect is computed in a canvas_item
shader (blur + radial bloom + diagonal glare band + wash-out + grain).

---

## Data and files

### Layout

```
project.godot             Godot 4 config (7 autoloads)
run_game.bat              Launch the game
run_tests.bat             Run all tests
open_story_editor.bat     Open the editor (starts a local server)
data/
  story.json              All data: backgrounds / questions / options / numbers / copy / endings
  doll_au.json            Doll layer table (produced by tools/dol_prepare.py)
assets/dol_au/            Doll art (base / clothes / icons)
scenes/Main.tscn          Main scene (all UI built in code)
scripts/                  16 GDScript files
shaders/photo_blur.gdshader  Album photo blur / glare / wash-out / grain
tools/
  story_editor.html       Visual editor (single-file web page)
  story_server.py         Local server so the editor can read/write story.json (8765)
  build_story_editor.py   Embeds story.json into the editor as a built-in snapshot
  dol_map.py              Mapping of 156 garments onto the AU pack
  dol_prepare.py          Extract / tint / crop layers into assets/dol_au/
  DumpStory.tscn/.gd      Exports built-in constants to story.json (★ overwrites real data — use with care)
  editor_smoke.js         Editor smoke test
tests/
  WardrobeTest.tscn/.gd   Wardrobe + data-layer unit tests
  TestRunner.tscn/.gd     End-to-end tests
  Screenshot.tscn/.gd     Real-render screenshot script
screenshots/              Rendered screenshots + flow overview
CHANGELOG.md              Per-round change log
```

### Top-level structure of `data/story.json`

| Key | Contents | Merge semantics |
|---|---|---|
| `rules` | All numbers (question count, suspicion, QTE, interference, phone pulls …) | Per-key override |
| `ui` | UI copy | Per-key override |
| `phone` | Phone copy (shell / messages / memo / album / notes) | Per-key override |
| `levels` | Acceptance and contrast requirement per round | Whole-section replace |
| `forced_rules` | Forced equipment | Whole-section replace |
| `qte_plan` | QTE kind and delay by question index | Whole-section replace |
| `item_overrides` | Per-item stat overrides | Per-key override |
| `true_presets` | True-appearance pool (progressive per round) | Whole-section replace |
| `catalog` | Read-only catalogue for the editor (the game never reads it) | Whole-section replace |
| `backgrounds` | Four backgrounds (cards / facts / questions / messages / rounds / forced / QTE / defects) | Whole-section replace |
| `traits` | Interrogator temperament table | Whole-section replace |
| `endings` | Ending copy | Per-key override |

**Whole-section replace** means the section you write replaces the entire block; an empty dictionary
is ignored. **Per-key override** replaces only the keys you write.

If the file is missing, everything falls back to the `DEFAULT_*` constants in GDScript and the game
still runs.

### Garment data

`scripts/OutfitData.gd` is the **single source of truth**: slot definitions, all 156 item stats,
tags, true-appearance pools. Everything else is a derived snapshot:

| Derived artefact | When to regenerate |
|---|---|
| Layer z in `data/doll_au.json` | Re-run `tools/dol_prepare.py` after changing slots or items |
| `catalog` in `story.json` | Same, re-export |
| `TRUE_POOL` in `tools/story_editor.html` | **Edit by hand** (JS constant block) |
| `screenshots/_flow_overview.png` | Re-run `tools/flow_overview.py` |

---

## Story editor

`open_story_editor.bat` starts a local server (8765) and the editor **reads and writes**
`data/story.json` directly. Opening it over `file://` only reads the built-in snapshot and cannot save.

Left-hand navigation:

| Group | What you can edit |
|---|---|
| **Basics** | Numeric rules (question count / suspicion / contrast / QTE / interference …), UI copy, ending copy |
| **Background** | Per background: cards / facts / questions / messages / rounds / forced equipment / QTE plan / defects |
| **Question bank** | Every question's text, options, `tone`, cost, QTE; drag to reorder |
| **Phone** | Shell, message copy, memo format, album copy, notes copy |
| **Garments** | Item stats, true-appearance pool |
| **Validation** | Full check; **problems only, no explanations** |

**Manually authored mode** (`questions_source = "manual"`) collapses sections that are not used
(the data is untouched). Judgement switches to suspicion-only, no dossier cards or facts are built,
and blind-spot logic is skipped.

**The validation panel only lists problems.** Shipped data must be **0 errors, 0 warnings**.
A field with placeholders left empty is flagged red (`"" % args` would error). A field without
placeholders left empty is **not** a problem — it falls back to shipped copy.

After editing `story.json`, rebuild the editor's built-in snapshot (`build_story_editor.py`);
the smoke test reads that copy.

---

## Art assets

The doll is **not hand-drawn**. It is mapped garment-by-garment from an existing layered pack.
Only the **AUfemale** pack is used (a community redraw: taller figure, full legs).

### Layered canvas

Every layer is cropped to the **same 68×203 viewport** so the doll does not jump when you change
outfits. Tinting happens at build time, not at runtime (tinting is a per-pixel multiply and colours
are fixed).

### Pipeline

```
tools/dol_map.py (mapping table)
      ↓
tools/dol_prepare.py (extract / tint / crop)
      ↓
assets/dol_au/*.png  +  data/doll_au.json
      ↓
godot --headless --path . --import      ← skip this and Godot will not see the new images
```

### Texture resolution rules

Files in the pack are not always named `full.png`. Tried in this order, skipping fully transparent
candidates:

1. Filter out `-acc` / `_acc` variants (those are decoration layers, not the body of the garment)
2. `full.png`
3. `full*` (many items only ship `full-alt` / `full_gray` / `full-long`)
4. Anything containing `idle` (the doll always uses the standing arm pose)
5. Numeric names (`1.png`, `2.png` …)
6. Otherwise the first by name

### Hair

Hair (sides / fringe / back) ships as a **pure greyscale mask**. Recolouring must go through
`tint()`: result = hair colour × mask luminance, with a `gain` boost.

**Only name the redrawn AU geometry styles explicitly.** Never write a "candidate list" — the pack
still contains old styles with the same names (256×128, still red), and a candidate list hits those
first. Hard conditions: **geometry 512×256** and **saturation 0.00**. Both are required.

### Dresses

`dress` is a **two-layer composite** (`upper/<style>` + `lower/<style>`, upper drawn first).
Using only one layer yields a half-body garment. First thing to check when adding a dress:
are both layers present?

---

## Tests

Four suites. `run_tests.bat` runs them all.

| Suite | Coverage | Command |
|---|---|---|
| `WardrobeTest` | Wardrobe + data-layer unit tests | `godot --headless --path . res://tests/WardrobeTest.tscn` |
| `TestRunner` | End-to-end (full run flow) | `godot --headless --path . res://tests/TestRunner.tscn` |
| `editor_smoke.js` | Editor (including the 8 phone pages) | `node tools/editor_smoke.js` |
| `Screenshot` | Real-render screenshots | `godot --path . res://tests/Screenshot.tscn` (**not headless**) |

The first two print total elapsed time and the eight slowest sections — look at that when tuning
instead of guessing.

**Assertion counts change every round, so this file does not state them.** Run the suites, or check
the "test scale over time" table at the end of `CHANGELOG.md`.

**After a run, check three things:**

1. `Failures: 0`
2. Whether there is any `SCRIPT ERROR` — an error does not fail the suite, it silently removes that assertion
3. **Whether the total assertion count dropped unexpectedly**

---

## Screenshots

`screenshots/` is produced by `tests/Screenshot.tscn` with real rendering (not headless).
Files are numbered by flow (`00_title_screen` → `22_contradiction`); files prefixed with `_` are
tool output (flow overview, selection comparison sheets).

---

## Known limitations

- **Manual mode still obeys "6 questions per round."** Wanting "2 questions per run" requires
  changing the numeric rules or distributing questions per round.
- **`relation` / `desc` / `speaker` are no longer exposed in the editor but are still read at runtime.**
  Editing them currently means editing `story.json` directly.
- **No phone appearance preview.** To see it, run the game or look at the screenshots.
- **`index.html` is an early HTML5 prototype**, long out of sync with the Godot build. Neither
  deleted nor cleaned up.
- **`border_post` still carries 12 `cards`** (both enabled backgrounds are manually authored and
  have empty `cards`). Whether to clear them on export is undecided — they are kept so switching
  back to auto-generation still works.
