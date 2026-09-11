# Project State

**Last updated:** 2026-09-10
**Active focus:** M1 (the `cf-minter` dispatcher + ergonomics pass) is **complete
and verified** — all five definition-of-done items demonstrated, 180 assertions
green. The project is between milestones; M2 has not been scoped. The three
ergonomics questions the brief left open are now two, since the dispatcher
settled the surface: whether `cf-mint-token.sh`'s flag surface stays as a
compatibility layer, and whether `profiles.conf` ships the right defaults for a
stranger.

<!-- History cap (D-0072): keep at most the current head + ~1 most-recent
     `**Prior YYYY-MM-DD —**` entry inline here. When you add a newer Prior
     entry, rotate the now-oldest one (and any `**Interstitial …**` paragraphs)
     to `.agent/PROJECT-STATE-HISTORY.md` (append-only, newest-first, NOT read
     at session start), and leave a one-line pointer to it. This keeps the
     per-session read cost from growing with project age. -->


---

## Current — 2026-09-10

**M1 shipped.** `cf-minter` is now a single verb-first entry point —
`run` / `mint` / `profiles` / `list` / `burn` / `doctor` — over the two tools,
which are unchanged and still usable directly. Definition of done, each
demonstrated rather than reported:

| DoD item | evidence |
|---|---|
| `extract-standalone-runner` landed | `main` contains `3e44147`; branch deleted |
| bare `cf-minter` explains itself | prints a COMMANDS block; asserted in suite |
| six verbs exist and route | `test/cf-minter.test.sh`, 21 assertions |
| every refusal names the fix | 62 refusals audited; 5 terse ones given remedies (`8ed2b77`) |
| suite green incl. SIGINT burn | 180 assertions, `ALL SUITES PASSED` |
| README rewritten | `8896df2`; every command in it was executed first |

**Two defects found and fixed while building it,** both in the cold-operator
path the scope's under-a-minute test depends on:

1. `--dry-run` required a minter credential — so the very first command the
   README tells a newcomer to run printed a plan with its permissions silently
   missing (measured: 0 of 2 `would resolve permission` lines without a minter,
   2 with). The mint tool refused before resolving them and exited; the wrapper
   carried on and reported "dry run complete". Fixed in `d10a66b` by scoping the
   precondition to the real path — the same shape the `curl` check four lines
   below already had. The live mint and live revoke still refuse by name, now
   asserted.
2. `cf()` defaulted its bearer to `$CF_MINTER_TOKEN`, which aborts under
   `set -u` when no minter is set. Only reachable once (1) was fixed; caught by
   the new test, not by hand.

**Architecture note:** the dispatcher holds no logic — no token value, no
network call — and two guards in its suite assert it stays that way, each
paired with a vacuity check so a detector that stops detecting fails loudly
instead of reporting clean.

**Open, not blocking:**
- `mental-models` pairing is 106d past its quarterly polish cadence (its content
  is sound; the cadence is the finding). Polish belongs in the dotagent repo.
- Two dotagent engine findings were handed off, not fixed here:
  `pairing-polish-cadence` counts documented non-selections as selections, and
  the retro digest crashes on a project with no `ROADMAP.md` (which the
  operating manual permits). Brief at `/tmp/dotagent-pairings-handoff.md`.
- ~~The bootstrap's generated interview packs are committed and stale.~~
  **Resolved 2026-09-11.** The governing rule predates the whole exchange:
  **D-0017 part 3, Binding since 2026-05-27** — prompt-packs are ephemeral,
  reproducible from their engines, and "do not get archived", because `REPORTS/`
  is the findings inbox and a generated input sitting there is permanent fake
  open work. Verified at source. `bootstrap-project.sh` was the outlier for
  three and a half months, because the rule was enforced by memory alone; the
  dotagent seat has now made the violation unrepresentable (packs write to
  `$XDG_CACHE_HOME/dotagent/bootstrap/<project>/`). So the 228KB removed here
  was a standing violation, not an open question. They regenerate on demand:
  `propose.sh` now emits 89 pairings against the **86** frozen in the deleted
  copy, which is the staleness the finding was about.

### Bootstrap provenance

Recorded in `.agent/.bootstrap-stamp` (the canonical home, per the engine's
D-0017 fix). This project predates that mechanism, so the stamp was
reconstructed rather than emitted — every field measured, none assumed:

- `dotagent: 968eb42` — recovered from `~/.dotagent`'s `release` reflog, which
  shows that commit as HEAD from 2026-09-07 14:59 to 2026-09-09 18:29; the
  bootstrap ran 14:24-14:54 on 09-09, inside that window. Confirmed by
  comparing `968eb42`'s `pairings/` tree against the pairing list in the
  now-deleted pack (recoverable at `a26eedd`): identical, 86 for 86.
- `pairings-available: 86` — not 87 as first supposed. `pull-based-deployment`
  reached dev on 09-08 but had not been promoted to `release`, and the
  bootstrap reads the release checkout.
- `pairings-list-sha: 9e43c9f76c67` — computed by the stamp writer's own
  method, validated by reproducing today's `5fd2e6dc6613` with the same steps.

**Next session:** no milestone is active. M2 needs scoping — the natural
candidates are the two remaining ergonomics questions above, or public-release
readiness (LICENSE, CI running the hermetic suite, a documented install path),
which the scope names as the project's purpose but which nothing has started.
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
| **Unratified ideas** | `.agent/IDEAS/` — one file per idea, archived alongside once ratified (per D-0028). Created on demand; absent in this project so far. |
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
