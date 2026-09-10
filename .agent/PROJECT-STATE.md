# Project State

**Last updated:** YYYY-MM-DD
**Active focus:** [1-3 sentences. What's actively in-flight right now.
The first thing you'd want to know about this project today.]

<!-- History cap (D-0072): keep at most the current head + ~1 most-recent
     `**Prior YYYY-MM-DD —**` entry inline here. When you add a newer Prior
     entry, rotate the now-oldest one (and any `**Interstitial …**` paragraphs)
     to `.agent/PROJECT-STATE-HISTORY.md` (append-only, newest-first, NOT read
     at session start), and leave a one-line pointer to it. This keeps the
     per-session read cost from growing with project age. -->

---

## 1. Authority surface — where to look for X

Single map of canonical tracking surfaces. **Start here** when you don't
know which file to open. List every tracked file or directory, canonical
or extension. If it's not in this table, the dashboard and tooling don't
know about it.

| You want to know... | Look in |
|---|---|
| **Scope, principles, hard constraints, criticality rubric** | `.agent/PROJECT-SCOPE.md` |
| **Current state, in-flight work, next session plan** | `.agent/PROJECT-STATE.md` (this file) |
| **Rotated state narrative (prior/interstitial history)** | `.agent/PROJECT-STATE-HISTORY.md` (append-only; **not read at session start**, per D-0072; present once the inline Prior stack first rotates) |
| **All ratified design decisions** | `.agent/DECISIONS/` (one file per decision; index in `DECISIONS/README.md`) |
| **Open check-ins awaiting input** | `.agent/CHECKINS/` (at root; archived live in `CHECKINS/ARCHIVED/`) |
| **Generated audit / inspect / sweep reports** | `.agent/REPORTS/` |
| **Ratified work-structure (milestone→task tree, depends-edges)** | `.agent/ROADMAP.md` (canonical when present; Active/Loose/Intake/Backlog + a pointer to shipped history, per D-0050/D-0093) |
| **Work a lane found but nobody has sequenced yet** | `.agent/ROADMAP.md` `## Intake` (the admission inbox; renders to no part of TODO.md until the seat promotes it, per D-0093) |
| **Shipped milestone history** | `.agent/ROADMAP-SHIPPED.md` (append-only `## Shipped` blocks; **not read at session start**, per D-0072; the renderer still reads it for done-resolution) |
| **Committed work ready now (derived frontier)** | `.agent/TODO.md` (generated from ROADMAP by `roadmap-render.sh`; never hand-edited) |
| **How an in-flight task is going (live lane narration)** | `.agent/PROJECT-STATE.md` §2a "Active lanes" (this file; one block per open task, keyed by its qualified ROADMAP task id, per D-0092) |
| **Unratified ideas** | `.agent/IDEAS/` (one file per idea, with `ARCHIVED/`, per D-0028) |
| **[Extension: add rows for project-specific tracked surfaces]** | `.agent/[RESEARCH/ / NOTES/ / SPECS/ / etc.]` |

Extensions only "exist" in the tracking system if they appear in this
table. The dashboard reads this table to know what to render.

---

## 2. Active milestone

**Active = ROADMAP `## Active`** → see `.agent/ROADMAP.md` (if the project
uses ROADMAP). One-line pointer only: name the active milestone and its
ready/blocked frontier. Per-task DoD (`done-when:`) and progress live in
ROADMAP — do **not** duplicate the DoD checklist here (D-0050 dissolved the
old lockstep-with-SCOPE mandate, a Principle-7 violation).

**Milestone:** [M<n> — short title; pointer to ROADMAP]
**Active blockers:** [list, or "none"]

(Projects not using ROADMAP may keep a short DoD list here instead.)

---

## 2a. Active lanes

Live narration for work **in flight right now** — one `###` block per open
task, keyed by the **qualified ROADMAP task id** (`M30.T2`, `L8`): the same
identity `TODO.md` renders at the head of each frontier line (D-0091), so the
lane and the line you picked it from are the same address.

An entry **references** its task by id and never restates it (Principle 7,
one fact one place). The ROADMAP task line owns *what the work is*; the lane
entry owns *how it is going* — what the lane found, what it corrected at
source, what is still open. That split is what keeps frontier lines
scannable; without it the narration lands in the task line and the board
stops being pick-one-legible (D-0092).

```
### M<n>.T<k>
- YYYY-MM-DD — what this lane found / corrected at source / left open
- YYYY-MM-DD — the next thing worth knowing before picking the task back up
```

**Write:** whenever a live task produces a fact the next person needs and the
task line is not the place for it. `drift-check/checks/roadmap-grain.sh
--extract <task-id>` does the move mechanically for a line that has already
bloated.

**Retire:** delete the block when its task closes. Entries are transient by
construction — the durable residue has already landed in the task's
`— done: <ref>` tail or the milestone's `**Done:**` line (D-0055), so a lane
block outliving its task is duplication, not history.

none.

---

## 3. Open check-ins

(Files at the root of `.agent/CHECKINS/` that are not yet archived.
Each represents a question awaiting your input.)

- `<date>-<slug>.md` — [one-line summary]

Or: "none" if no active check-ins.

---

## 4. (Dissolved per D-0050)

Cross-session deferred work no longer lives in a narrated §4 thread. Route
it by kind: deferred-but-committed → a `## Backlog` task in `.agent/ROADMAP.md`
(naming its trigger); unratified → `.agent/IDEAS/`; decided-but-unbuilt → a
`DECISION`. (Projects not using ROADMAP may retain a §4 list.)

---

## 5. Next session

What to do first when next session starts. 1-3 lines. Can be empty.

---

<!-- Optional sections below — add as your project needs.
     The dashboard renders any section it finds; canonical sections
     (1-5) are guaranteed to exist. -->

## 6. Recent milestones (one-liner index, optional)

If the project uses ROADMAP, shipped-milestone history lives in ROADMAP
`## Shipped` (D-0050) — don't duplicate it here. Otherwise:

- **M[N]** ([YYYY-MM-DD]) — [one-line summary]. [Closed / in-progress.]

## 7. Known issues / current debt (optional)

[Carry-forward issues that aren't blockers but are tracked.]
