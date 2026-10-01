---
captured: 2026-09-19
status: spent
spent-by: the cf-minter commit that adds .agent/LENS.md (2026-10-01)
from: dotagent L230 (report-file drop, D-0080 — nothing else in this repo was touched)
---

> **For this seat, on boot:** apply the handoff below in your own worktree, then
> disposition this report (applied / dismissed-with-reason) and move it to
> `REPORTS/ARCHIVED/`. Until then it is open work.


# L95 handoff — LENS.md is the session-read core (apply in your own seat)

**From:** dotagent L95 (2026-09-18). **To:** the seat of any adopting repo.
Foreign governance is handoff-only (D-0080): dotagent edited nothing here; this
is a prompt your own agent applies, in your own worktree, under your own rubric.

## What changed in dotagent (the premise — verify it at source before acting)

The *role* "session-read core" moved from `PROJECT-SCOPE.md`'s head to
`.agent/LENS.md`. Content did **not** move: hard constraints, out-of-scope,
the criticality rubric, check-in mode and `## Verification` stay in SCOPE as
**boundaries** (D-0144 enumerates them there; D-0145 holds LENS to one screen).
Session start is now DIRECTION → LENS → SCOPE down to `## Reference`.

Verify in your dotagent install (`$DOTAGENT_HOME`, normally `~/.dotagent`):
- `publish/CLAUDE-OPERATING-MANUAL-SLIM.md` session-start steps 1–3 name
  DIRECTION, LENS, then SCOPE's boundaries.
- `LENS.template.md` exists at the install root.
- `drift-check/checks/scope-inventory-drift.sh` reads SCOPE ∪ LENS.
- `recipes/governance-load.sh` `boot_surface` lists a `LENS` row.

If any of those is absent, the release has not been promoted yet — stop and
say so; do not apply this handoff against a manual that still says otherwise.

## Apply — one worktree, one commit, your own rubric

1. **Create `.agent/LENS.md` if you have none.** Copy
   `$DOTAGENT_HOME/LENS.template.md` → `.agent/LENS.md`, set `restated:` to
   today, fill §1–§2 from what the project *is* (your `DIRECTION.md`
   destination and your SCOPE's former `## Overview`, if it still carries one,
   are the inputs). §6's conservation table names every top-level directory.
   One screen. If you already have a LENS, only re-read it against §1 of the
   template and bump `restated:` if it moved.
2. **Declare it `class: current` in your own register.** `<repo>/AGENT-SURFACES.txt`
   (create it if absent — same shape as the install's; the `class: current`
   class is read from the project half only, D-0145):
   `LENS.md          # class: current  accounts-for: */  — what <project> is; the session-read core`
   Do not declare `DIRECTION.md` unless it exists — a declared-but-absent
   current surface is a finding by `current-surface-stale.sh`'s own rule.
3. **Strip vision from SCOPE (D-0144), keep boundaries.** If your
   `PROJECT-SCOPE.md` still carries `## Overview` / target-state prose, move it
   into LENS §1 (description) or DIRECTION (destination) and delete it from
   SCOPE. Leave hard constraints, out-of-scope, rubric, check-in mode,
   verification, pairings and the `## Reference` tail where they are. Add the
   two-line pointer comment at the top of SCOPE naming LENS as the session-read
   core (copy it from dotagent's own `.agent/PROJECT-SCOPE.md` head).
4. **Re-publish your project `CLAUDE.md`** only if it is a `slim`/`full` build
   (the marker on line 1 says); a `pointer` build reads the global and needs
   nothing. Match the recorded build mode — a bare `--force` resets to
   slim/no-pairings.
5. **Run the checks** and read what they print (not the exit code):
   `$DOTAGENT_HOME/drift-check/drift-check.sh --target <repo> --material`
   `$DOTAGENT_HOME/drift-check/checks/current-surface-stale.sh <repo>/.agent`
   `$DOTAGENT_HOME/recipes/governance-load.sh measure --target <repo>` — the
   boot line now carries a `LENS` row; absent is a row, not silence.
6. **Track it.** Board one ROADMAP task citing this handoff, close it in the
   same commit, and disposition this file (fixed-now) — it is a handoff, so it
   retires: set `status: spent` with a forward-pointer to your commit, or
   delete it once applied.

## What this is NOT asking you to do

- Not to move hard constraints / out-of-scope into LENS. Those are boundaries
  and D-0144 keeps them in SCOPE. The one open question dotagent named for
  itself — SCOPE `## Out of scope` vs LENS §7 "Scope, graded" being one axis in
  two places — is *not* ruled; if it bites you, file it as your own decision
  or check-in, do not resolve it by deleting either.
- Not to edit `~/.claude/CLAUDE.md` or promote dotagent — the dotagent seat
  does that at its gate.

---

## Disposition (2026-09-18, dotagent seat)

- queued: **L230** — apply to each adopting repo from its own seat (D-0080); the handoff text above is the prompt. Release gate met: `~/.dotagent` at `35aa6dd` carries `LENS.template.md` and the migrated manual.

## Disposition (2026-10-01, cf-minter seat)

- **fixed-now — applied.** Premise verified at `~/.dotagent`: `LENS.template.md`
  exists, the slim manual's session-start step names LENS, and
  `scope-inventory-drift.sh` reads LENS. Steps:
  1. `.agent/LENS.md` created from the template, `restated: 2026-10-01`; §6
     names every top-level surface.
  2. `AGENT-SURFACES.txt` declares `LENS.md` `class: current accounts-for: */`.
     **Deviation, named:** it is gitignored, like `CLAUDE.md`. This repo is
     public, and its scope keeps tooling files off the cloned surface.
     DIRECTION.md is not declared: it does not exist.
  3. SCOPE's `## Overview` was moved into LENS §1 and deleted from SCOPE. The
     boundaries were left in place, and the pointer comment was added at
     SCOPE's head.
  4. Re-publish skipped: the project `CLAUDE.md` is a pointer build.
  5. Checks run; results are in the commit.
  6. No ROADMAP task was boarded: this project has no ROADMAP.md. Its
     candidate work lives in PROJECT-STATE §7. This disposition is the record.
