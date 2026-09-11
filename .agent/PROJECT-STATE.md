# Project State

**Last updated:** 2026-09-11
**Active focus:** **v0.1.0 is released.** https://github.com/satorisage/cf-minter
is public, MIT-licensed, CI green on Linux and macOS. M1, M2 and M3 are all
complete, and the project's founding success test — a stranger goes from clone
to a working scoped run in under a minute — has been run from a fresh clone and
passes.

No milestone is active. There is no committed next milestone; the tool does what
it was built to do and is obtainable by anyone. Candidate work, none of it
urgent, is in §7.

<!-- History cap (D-0072): keep at most the current head + ~1 most-recent
     `**Prior YYYY-MM-DD —**` entry inline here. When you add a newer Prior
     entry, rotate the now-oldest one (and any `**Interstitial …**` paragraphs)
     to `.agent/PROJECT-STATE-HISTORY.md` (append-only, newest-first, NOT read
     at session start), and leave a one-line pointer to it. This keeps the
     per-session read cost from growing with project age. -->


---

## Current — 2026-09-11

**M3 shipped: the tool became obtainable.** MIT licence; GitHub Actions running
the hermetic suite on `ubuntu-latest` and `macos-latest` (no secrets needed —
`curl` and `az` are PATH stubs, so a full run mints, uses and deletes nothing);
an Install section documenting clone + symlink; and the repo published, made
public and tagged `v0.1.0`.

Deliberately no `curl | bash` installer. A tool whose job is careful credential
handling should not open by asking the reader to pipe a remote script into their
shell — "read it before you trust it" is the actual pitch, and ~1000 lines of
auditable shell is what backs it.

**Verified as a stranger, not asserted:** cloned the public URL to a fresh
directory, symlinked the entry point onto `PATH`, and ran `doctor`, `profiles`,
`run --dry-run` and the full suite with no credential in the environment. All
correct; 183 assertions pass.

**Four real bugs were found across M1-M3, none of them findable by reading:**

| bug | how it surfaced |
|---|---|
| `--dry-run` required a credential, so the README's *first* command printed a plan with its permissions silently missing | running it the way a newcomer would |
| `cf()` aborted under `set -u` when no minter was set | only reachable once the first was fixed; caught by a new test, not by hand |
| a test read a file mode with BSD `stat` syntax; GNU `stat` rejects it but still prints to stdout, poisoning the capture | first time the suite ran outside macOS |
| a symlink on `PATH` broke the tool outright — `BASH_SOURCE[0]` is the link's path, so sibling tools were invisible | asking "can this go on PATH?" while writing the install docs |

The last two were found while *writing the release walkthrough*, because each
question carried a factual claim that could not be answered from memory. The
symlink bug would have been a first-five-minutes failure for every user who
installed it the normal way.

M2 preceded this and was three rulings rather than a build — see
PROJECT-SCOPE.md history. Its content: `cf-mint-token.sh` stays supported but
stops being taught, `profiles.conf` ships its seven as a declared starting set,
and the repo ships its own tracking.

---

## Prior — 2026-09-10

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
  operating manual permits). Both were reported upstream and subsequently fixed there; the
  handoff brief was ephemeral and is not kept here.
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

**No committed next milestone.** The tool is finished for its stated purpose
and is publicly obtainable. Candidates, all optional, are listed in §7.
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
| **All ratified design decisions** | `.agent/DECISIONS/` (one file per decision; index in `DECISIONS/README.md`) |
| **Open check-ins awaiting input** | `.agent/CHECKINS/` (at root; archived live in `CHECKINS/ARCHIVED/`) |
| **Generated audit / inspect / sweep reports** | `.agent/REPORTS/` (dispositioned ones archive to `REPORTS/ARCHIVED/`; tooling sweeps are local-only and untracked) |
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

What to do first when next session starts. 1-3 lines. Can be empty.

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

- **`profiles.conf` coverage.** Seven profiles ship. Cache purge, R2, Workers KV
  and Logpush have no profile. Deliberately not added: permission names resolve
  by a live catalogue read that `--dry-run` does not perform, so a name cannot
  be verified offline, and guessing at vendor strings is the failure this tool
  refuses by design. Each new profile needs one real mint to verify.
- **Homebrew tap.** The install is clone + symlink. A tap is the right second
  step *if* anyone asks; building one nobody has asked for is inventory.
- **`cf-minter` covers 8 of `cf-mint-token.sh`'s 17 flags.** By design — it
  covers the common path, and the README says so and points at `--help`. Worth
  revisiting only if the uncovered nine turn out to be reached for often.
- **No `CONTRIBUTING.md` or issue templates.** Add if the repo attracts any
  actual contributors; premature otherwise.
