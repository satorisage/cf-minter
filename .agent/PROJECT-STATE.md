# Project State

**Last updated:** 2026-10-01
**Active focus:** **v0.1.0 is released.** https://github.com/satorisage/cf-minter
is public, MIT-licensed, CI green on Linux and macOS. M1, M2 and M3 are all
complete, and the project's founding success test — a stranger goes from clone
to a working scoped run in under a minute — has been run from a fresh clone and
passes.

No milestone is active. There is no committed next milestone; the tool does what
it was built to do and is obtainable by anyone. Candidate work, none of it
urgent, is in §7. An unmilestoned ergonomics pass landed 2026-09-13/16, and the
first profile beyond the starting set on 2026-09-17, and three field-reported
front-door fixes on 2026-10-01 — see Current and Prior below.

<!-- History cap (D-0072): keep at most the current head + ~1 most-recent
     `**Prior YYYY-MM-DD —**` entry inline here. When you add a newer Prior
     entry, rotate the now-oldest one (and any `**Interstitial …**` paragraphs)
     to `.agent/PROJECT-STATE-HISTORY.md` (append-only, newest-first, NOT read
     at session start), and leave a one-line pointer to it. This keeps the
     per-session read cost from growing with project age. -->


---

## Current — 2026-10-01

**Three front-door bugs, found by an operator in the field, fixed (`4eb80e2`).**
A session using cf-minter elsewhere reported them; each was reproduced here
before it was fixed:

- **`doctor` ignored `--minter-cmd`** — it never read its arguments, so a
  minter supplied that way was reported as none. Its arguments now go, unread,
  to `cf-mint-token.sh --qualify-minter`, which owns minter resolution and
  refuses unknown flags. A first version parsed the flags in the dispatcher and
  tripped the existing guard that keeps `--minter-token-file` out of its code;
  the guard was kept and the design changed to fit it.
- **`run --help` omitted `--perm`** (and `--minter-token-file`), both in the
  README. Added, with `--perm` in both completions.
- **CRLF `profiles.conf` refused its own profile** — "unknown profile
  'cache-hygiene'. Did you mean 'cache-hygiene'?". Two readers of one format
  disagreed: `profile_names` stopped at whitespace, `load_profile` kept the CR.
  The loader now trims trailing whitespace from every line, so perm values no
  longer carry a CR into the catalogue lookup either.

Each has a regression test that fails on the prior code with the reported
symptom (5 failed there, verified). **226 assertions, up from 221; all green.**

**Drift triage (`43cf591`).** The dotagent L95 handoff was applied:
`.agent/LENS.md` is now the session-read core, and SCOPE's Overview moved into
it. `AGENT-SURFACES.txt` is gitignored rather than shipped, because the public
surface carries no tooling files. The brief got a Triage section and stays in
place; the stamp records `mcp: already-registered`; the automation register is
dismissed (opt-in, and CI is the only automation).

---

## Prior — 2026-09-17

**The first profile added since the starting set, and the level the engine
could not say.** Work on camping4you.net needed a token that could set cache
rules and purge the edge cache. Neither was expressible: Cloudflare's live
permission catalogue has a group named exactly `Cache Purge` with no Write/Read
form — its only level is Purge — and `level_suffix()` accepted only Edit and
Read. Two commits from that seat (`fd21d39`, `bfc041d`), verified here at
source:

- **`Purge` is a permission level.** `cf-mint-token.sh` maps it like Edit/Read;
  the existing catalogue fallback (name ends with the level, contains the base)
  resolves `Cache Purge:Purge` → `Cache Purge` with no resolver change. The
  refusal and `--perm` help name all three levels.
- **`cache-hygiene` profile**: `Cache Settings:Edit` + `Cache Purge:Purge` +
  `Zone:Read`, zone-scoped, 15m. The dashboard label "Cache Rules · Edit" is the
  API group `Cache Settings Write`; a live mint proved `Cache Rules:Edit`
  resolves to nothing, which is why the second commit exists. That live mint is
  the verification §7 said each new profile needs — the entry is retired below.

**Buttoning up found one defect the commits introduced.** `cf-minter profiles`
— the readout whose whole job is a profile's blast radius — rendered
`cache-hygiene` as "changes Cache Settings / reads Zone" and dropped the purge
permission, because `list_profiles` only knew two levels. Fixed: a `purges`
line, and a conservation test that walks every `perm:` in `profiles.conf` and
demands each appear on some reach line — the check the listing had lacked all
along, since with only Edit and Read in the file nothing could fall through.
Also added: `Cache Purge:Purge` resolving through the fallback against a
fixture that carries the real group, an unknown level refused offline naming
Purge, and README coverage of the level and the profile.

**221 assertions, up from 217; all green.** Untouched: the burn trap, the
secret's path, and the reach of every pre-existing profile. Nine profiles ship;
"seven as a declared starting set" (M2) was a count, not a cap — the ruling was
that the set is declared and extended one verified edit at a time, which this is.

---

<!-- Older entries (2026-09-16 and earlier) rotated to `.agent/PROJECT-STATE-HISTORY.md`
     by the history cap, D-0072. Not read at session start. -->


## 1. Authority surface — where to look for X

Single map of canonical tracking surfaces. **Start here** when you don't
know which file to open. List every tracked file or directory, canonical
or extension. If it's not in this table, the dashboard and tooling don't
know about it.

| You want to know... | Look in |
|---|---|
| **Scope, principles, hard constraints, criticality rubric** | `.agent/PROJECT-SCOPE.md` |
| **Current state, in-flight work, next session plan** | `.agent/PROJECT-STATE.md` (this file) |
| **All ratified design decisions** | `.agent/DECISIONS/` (one file per decision; index in `DECISIONS/README.md`) |
| **Open check-ins awaiting input** | `.agent/CHECKINS/` (at root; archived live in `CHECKINS/ARCHIVED/`) |
| **Generated audit / inspect / sweep reports** | `.agent/REPORTS/` (dispositioned ones archive to `REPORTS/ARCHIVED/`; tooling sweeps are local-only and untracked) |
| **What the project is, right now (session-read core)** | `.agent/LENS.md` |
| **The vision this was built from** | `.agent/REPORTS/project-brief.md` |
| **What the corpus looked like at bootstrap** | `.agent/.bootstrap-stamp` |

This project does not use a ROADMAP/TODO work-structure tree — it is small
enough that the milestone and its done-when live in `PROJECT-SCOPE.md`
directly. Rows for those surfaces are therefore absent rather than empty.

---

## 2. Active milestone

**Milestone:** none. M3 closed 2026-09-11 with the `v0.1.0` release.
**Active blockers:** none.

This project does not use `ROADMAP.md`; the closed milestones and their
done-when lists are in `PROJECT-SCOPE.md` (`## Active milestone`, rewritten per
milestone) and summarised in §6 below.

---

## 2a. Active lanes

none — no work in flight.

---

## 3. Open check-ins

none — no questions awaiting input.

---

## 5. Next session

Nothing is owed. `main` is green (226 assertions) and in sync with origin; no
milestone is active.

Drift at 2026-10-01: 1 material finding, dismissed — `automation-state-drift`
(opt-in register; CI in `.github/workflows/test.yml` is the only automation).
The core-budget advisory from the push hook (22 KB `load: always` core, no
`core-budget:` declared) is not adopted: nothing is refused without it.

---

<!-- Optional sections below — add as your project needs.
     The dashboard renders any section it finds; canonical sections
     (1-5) are guaranteed to exist. -->

## 6. Milestones

- **M1** (2026-09-10) — one entry point. `cf-minter` dispatches six verbs
  (`run` / `mint` / `profiles` / `list` / `burn` / `doctor`) over the two tools,
  which were not modified. Closed.
- **M2** (2026-09-11) — the open ergonomics questions answered. Three rulings,
  no code: `cf-mint-token.sh` supported but not taught; `profiles.conf` ships
  its seven as a declared starting set; the repo ships its own tracking. Closed.
- **M3** (2026-09-11) — obtainable. MIT, CI on two platforms, documented
  install, public repo, `v0.1.0` tagged. Closed.

## 7. Candidate work — none committed, none urgent

The tool is finished for its stated purpose. These are noted so they are not
rediscovered, not because anything is owed:

- **`profiles.conf` coverage.** Nine profiles ship. R2, Workers KV and Logpush
  have no profile. Deliberately not added: permission names resolve by a live
  catalogue read that `--dry-run` does not perform, so a name cannot be verified
  offline, and guessing at vendor strings is the failure this tool refuses by
  design. Each new profile needs one real mint to verify — `cache-hygiene`
  (2026-09-17) is the worked example: its first guess, `Cache Rules:Edit`, was a
  dashboard label and resolved to nothing.
- **Homebrew tap.** The install is clone + symlink. A tap is the right second
  step *if* anyone asks; building one nobody has asked for is inventory.
- **`cf-minter` covers 8 of `cf-mint-token.sh`'s 17 flags.** By design — it
  covers the common path, and the README says so and points at `--help`. Worth
  revisiting only if the uncovered nine turn out to be reached for often.
- **No `CONTRIBUTING.md` or issue templates.** Add if the repo attracts any
  actual contributors; premature otherwise.
