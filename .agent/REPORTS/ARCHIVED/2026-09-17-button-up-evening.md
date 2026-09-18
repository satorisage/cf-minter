# Button-Up Report — cf-minter

GENERATED-BY: recipes/button-up-project.sh
**Date:** 2026-09-17
**Target:** `/Users/stephen/Projects/cf-minter`
**dotagent install:** `/Users/stephen/.dotagent`

Propagates dotagent conventions into the target project. The CLAUDE.md
refresh, the §2b report rotation, the §2d lanes rotation and the §3b
delivery fill are the mutations; §2g (harvest) and §2h (reap) propose
only; drift findings are advisory.

---

## 1. CLAUDE.md refresh

✓ Refreshed `/Users/stephen/Projects/cf-minter/CLAUDE.md` via publish/publish.sh — recorded shape kept (no pairings bundle; pairings resolve on demand via the dotagent MCP).
Pulls latest operating manual + principles + interaction style from
personal/ + the manual. Now: `<!-- GENERATED-BY: publish.sh on 2026-09-18T00:06:19Z [build: slim; include: no] -->`

---

## 2. drift-check findings

GENERATED-BY: drift-check/drift-check.sh
**Target:** `/Users/stephen/Projects/cf-minter/.agent`
**Date:** 2026-09-17
**Checks run:** 53

## ✓ assumption-shape-change

Clean.

## ✓ authority-surface

Clean.

## ✗ automation-state-drift (1 finding(s))

- no automation register declared (`.agent/AUTOMATION.md` absent) — optional per D-0135; a project opts in by writing one from the dotagent repo root's `AUTOMATION.template.md`. Not an error — this line exists so the absence is visible rather than silent (D-0122).

## ✓ branch-unintegrated

Clean.

## ✓ capability-unbounded

Clean.

## ✓ carry-forward-cap

Clean.

## ✓ checked-todo-accumulating

Clean.

## ✓ checkins-sync

Clean.

## ✓ claims-resolve

Clean.

## ✓ critical-item-aging

Clean.

## ✓ cross-repo-plan-migration

Clean.

## ✓ current-marker-stale

Clean.

## ✓ current-surface-stale

Clean.

## ✓ decision-revisit-due

Clean.

## ✓ decision-unconverged

Clean.

## ✓ depends-resolvable

Clean.

## ✓ dotagent-db-tracked

Clean.

## ✓ enforcement-cites-retired

Clean.

## ✓ engine-growth-unextracted

Clean.

## ✓ frontier-dead

Clean.

## ✓ githook-stale

Clean.

## ✓ intake-unpromoted

Clean.

## ✓ landed-not-pushed

Clean.

## ✓ live-field-usage

Clean.

## ✗ mcp-unregistered (1 finding(s))

- .agent/.bootstrap-stamp: MCP registration outcome UNKNOWN — the stamp carries no `mcp:` line (written before bootstrap recorded it, or by a phase that never reached registration). Register from inside the project: claude mcp add dotagent -- node <dotagent>/dist/cli.js --project-dir <project> — or re-run recipes/bootstrap-project.sh --publish, which records the outcome (dotagent L161).

## ✓ milestone-unbounded

Clean.

## ✓ pairing-polish-cadence

Clean.

## ✓ preflight-unanswered

Clean.

## ✓ proposed-decisions-stale

Clean.

## ✓ proposed-without-ratify-line

Clean.

## ✓ queued-items-expiry

Clean.

## ✓ report-without-disposition

Clean.

## ✗ reports-untriaged (1 finding(s))

- REPORTS/project-brief.md is 7d old and has no `## Triage` section; archive per dotagent D-0017

## ✓ retires-resolvable

Clean.

## ✓ roadmap-done-unmigrated

Clean.

## ✓ roadmap-grain

Clean.

## ✓ roadmap-id-collision

Clean.

## ✓ roadmap-task-grammar

Clean.

## ✓ roadmap-unreachable-task

Clean.

## ✓ ruling-unmarked

Clean.

## ✓ scope-inventory-drift

Clean.

## ✓ scoping-without-prior-art

Clean.

## ✓ sequence-conservation

Clean.

## ✓ session-read-oversize

Clean.

## ✓ stale-ephemeral-artifact

Clean.

## ✓ standing-duty-as-task

Clean.

## ✓ state-entry-points

Clean.

## ✓ state-prior-stack

Clean.

## ✓ tree-anchors-resolve

Clean.

## ✓ tree-coverage

Clean.

## ✓ ungoverned-surviving-feature

Clean.

## ✓ verification-undeclared

Clean.

## ✓ verified-stamp-stale

Clean.

---

**Summary:** 3 finding(s) across 53 check(s); 50 clean; 0 FAILED.

Advisory only — drift-check never modifies files. Triage findings by
hand or via `recipes/button-up-project.sh` for an adopting project.

---

## 2b. reports rotation

rotate-reports.sh: rotated 0 dispositioned report(s) to REPORTS/ARCHIVED/; 2 left at root (undispositioned or exempt).

---

## 2c. Critical-item aging — non-lumpable

**0 Minor/advisory finding(s).** Nothing foldable this sweep.

**0 Critical/OWNER-hand/ops-repair finding(s).** Nothing non-lumpable this sweep.


---

## 2d. Active lanes rotation

rotate-lanes.sh: `## … Active lanes` holds no entries — nothing to rotate.
rotate-lanes.sh: rotated 0, kept 0 open, 0 unkeyed.

---

## 2e. Rulings register

rulings-render: wrote /Users/stephen/Projects/cf-minter/.agent/RULINGS.md (0 ruling(s) recorded · ruling-unmarked: clean).

---

## 2f. Current-surface register (D-0122)

No register and no current-shaped files — none needed (legitimate empty state, D-0122).

---

## 2g. ROADMAP harvest — proposal (D-0125 part 2 / D-0072)

harvest-shipped.sh: no ROADMAP.md at /Users/stephen/Projects/cf-minter/.agent/ROADMAP.md — nothing to harvest from.
harvest-shipped.sh: harvested 0 (no board).

---

## 2h. Backlog reap — worksheet (D-0065 part 4 / D-0125 part 4)

**0 reap candidate(s)** (default DROP) · **0 working position(s)** due a verdict. Propose only — nothing written; apply by hand per the worksheet.

### Reap candidates (default = DROP)

None — every `## Backlog` item and `IDEAS/` file carries a
`revisit-when:`. Nothing to reap by default.

### Working positions (D-0123)

None — no Binding decision carries `Grade: working`. (Ungraded decisions
read as `invariant` — D-0123 part 6.)

---

To apply a confirmed drop:
- **Idea:** append a `Dropped — <reason>, 2026-09-17` note to the file, then
  `git mv .agent/IDEAS/<file> .agent/IDEAS/ARCHIVED/`.
- **Backlog item:** remove the task line from `## Backlog` and record it in a
  dropped-log / `## Shipped` note with the reason. (Git history is the archive.)

To KEEP instead: add a live `revisit-when:` (condition or by-date) to the
source item — it then survives the next reap.

To settle a working position: `held` re-states it (`decision-log amend … --revisit-when`),
`amend` revises it in place, `supersede` mints the ruling that replaces it.

---

## 3. decision-log audit

GENERATED-BY: decision-log/decision-log.sh audit
**Target:** `/Users/stephen/Projects/cf-minter/.agent/DECISIONS`
**Date:** 2026-09-17
**Files:** 0 decision file(s); 0 index row(s)

## ✓ Clean

All 0 Binding decision file(s) match index row(s) in title and filename.

---

## 3b. Delivery fill (pushed:)

No `ROADMAP.md` at `/Users/stephen/Projects/cf-minter/.agent/ROADMAP.md` — nothing to fill.

---

## 4. Pairings polish advisory

Pairing-polish cadence is a drift-check check (`pairing-polish-cadence`),
run as part of §2 above: any pairing selected in this project's
PROJECT-SCOPE.md that has not been polished within the quarterly (>90d)
cadence is flagged there. Detection lives in the engine; this recipe
only sequences it (per D-0019; recipe stays free of engine-grade work).

To polish a pairing flagged stale in §2:
```
/Users/stephen/.dotagent/polish-pairing/polish-pairing.sh --name <name> --out /tmp/<name>-pack.md
```
Then conduct the polish in a Claude session and save the revised draft
back to `/Users/stephen/.dotagent/pairings/<name>.md`.

---

## 5. Test surface

Not run — `/Users/stephen/Projects/cf-minter` has no discoverable test surface (no
`<tool>/test-*.sh` suites and no `dist/test/`). This is the normal
result for a project that does not use dotagent's own test conventions;
it is not a finding.

---

## 6. Retro digest — what recurred, where work stalled


## Lifecycle board (items × stage)
  0 tracked items — idea: 0  |  decision: 0  |  todo: 0  |  built: 0  |  done: 0

## Flow metrics
  cycle-time (todo→done): indeterminate (no determinate items)
  lead-time  (idea→done): indeterminate (no determinate items)
  throughput: 0 reached done
  worst stall stages: indeterminate (no datable per-stage dwell)

## What recurred
  thrash (files churned ≥ 3 commits, top 5 of 14):
    • README.md — 12 commits
    • .agent/PROJECT-STATE.md — 9 commits
    • cf-mint-token.sh — 7 commits
    • cf-scoped-run.sh — 6 commits
    • profiles.conf — 6 commits
  reverts: none detected
  re-decided surfaces: none (chains ≥ 2)
  recurring themes (top 1 of 1):
    • "minter" — 2 sources

Stamped `/Users/stephen/Projects/cf-minter/.agent/.retro-last` — the boot line carries this loop's age from here,
so a cadence that stops running says so on the line that is read first.
**This section is a prompt, not a report:** what recurred is only worth
computing if something changes because of it. A recurrence you decide to
accept gets said out loud (a dismissed-with-reason line), not left to
re-surface next session as though it were new.

---

## Next steps

1. Triage drift findings above (§2 + §3). Each finding is a
   candidate for an edit to the target project's `.agent/`
   surface — append `Triage` notes to stale reports, sync
   `PROJECT-STATE.md` §3 with `CHECKINS/`, update `§5b`
   queued items with by-date/trigger, etc. Per D-0017, D-0019.
2. If pairings were flagged (§4), polish them via
   `polish-pairing/` and update the pairing files in dotagent.
3. CLAUDE.md is now refreshed (unless `--no-publish` was given).
   The target project's next Claude session will see the latest
   operating manual + pairings.
4. Once triage is complete, append a `## Triage` section to this
   report and `mv` to `/Users/stephen/Projects/cf-minter/.agent/REPORTS/ARCHIVED/` per D-0017.

Per Principle 4, button-up-project.sh does not auto-fix drift —
findings are advisory; the human (or a Claude session inside the
target project) applies edits.

## Triage — 2026-09-17 (evening)

Session: landed the `web-analytics` profile (`ac05489`, then `9817ee8` adding
`Account Settings:Read`) — permission name re-verified against the Cloudflare
API reference, README row and count updated, `test/run-all.sh` green both
times, pushed. STATE Current extended; §7 count bumped to nine.
3 findings across 53 checks, 0 FAILED. All three dispositioned, unchanged from
the morning triage:

**1. `automation-state-drift` — no `.agent/AUTOMATION.md`. Dismissed, standing.**
Opt-in register (D-0135); the only automation is CI in
`.github/workflows/test.yml`.

**2. `mcp-unregistered` — stamp carries no `mcp:` line. Dismissed: stale stamp.**
The dotagent MCP was connected this session; registration exists. Re-stamps on
the next `bootstrap-project.sh --publish`.

**3. `reports-untriaged` — `project-brief.md`. Dismissed: not a findings
report.** The vision brief the §1 authority map points at, kept at root as the
bootstrap handoff artifact.

§5 "no discoverable test surface" is the recipe's convention: the project's own
runner `test/run-all.sh` was run in-session, all suites passed.
