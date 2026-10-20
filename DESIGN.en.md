# Faceless: Design & Implementation

Data formats, the story editor, the art pipeline, tests, and known limitations.

> Gameplay and rules: [`README.en.md`](README.en.md). 中文版: [`DESIGN.md`](DESIGN.md)

---

## Question data schema

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
