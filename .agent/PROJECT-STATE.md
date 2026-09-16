# Project State

**Last updated:** 2026-09-16
**Active focus:** **v0.1.0 is released.** https://github.com/satorisage/cf-minter
is public, MIT-licensed, CI green on Linux and macOS. M1, M2 and M3 are all
complete, and the project's founding success test — a stranger goes from clone
to a working scoped run in under a minute — has been run from a fresh clone and
passes.

No milestone is active. There is no committed next milestone; the tool does what
it was built to do and is obtainable by anyone. Candidate work, none of it
urgent, is in §7. An unmilestoned ergonomics pass landed 2026-09-13/16 — see
Current below.

<!-- History cap (D-0072): keep at most the current head + ~1 most-recent
     `**Prior YYYY-MM-DD —**` entry inline here. When you add a newer Prior
     entry, rotate the now-oldest one (and any `**Interstitial …**` paragraphs)
     to `.agent/PROJECT-STATE-HISTORY.md` (append-only, newest-first, NOT read
     at session start), and leave a one-line pointer to it. This keeps the
     per-session read cost from growing with project age. -->


---

## Current — 2026-09-16

**An ergonomics pass, inside the ratified position rather than against it.** The
owner asked for "wow factor," then sharpened it mid-walkthrough to flow —
completion and low friction, not visual polish. That is what `## Out of scope`
already defines ergonomics to mean, so the exclusion held and **no scope
amendment was made**. Four findings, all shipped:

- **Per-verb help.** `cf-minter run --help` had been emitting 105 lines, 104 of
  them the underlying script's commented header — sibling script names and
  test-only environment included. The front page advertises that exact command.
  Each verb now answers in the tool's own voice.
- **Shell completion, zsh and bash.** Fed by a new `--profile-names` emit from
  the tool that owns the profile format, so completion never becomes a second
  parser of `profiles.conf` and adding a profile stays one edit.
- **`profiles` leads with reach**, split into what a profile changes and what it
  only reads. Choosing a profile is choosing a blast radius.
- **A near-miss profile name is answered** with the nearest real one; the
  refusal still refuses.

**The completion shipped broken, and the tests could not see it.** They asserted
that the file parses and that `compinit` registers it. Both were true the whole
time, and both were derived from the same assumption the completion itself was
making — so they could only confirm the two agreed about what to ignore. TAB
produced a directory listing: `_arguments` reads the line from `words[1]`, so it
treated the dispatcher as the command and every verb as an unexpected argument.
Two more defects sat behind it — candidates collected in a pipeline, so the
subshell discarded them; specs passed as an expanded array rather than literal
arguments.

The replacement drives a real interactive zsh through a pseudo-terminal, presses
an actual TAB, and asserts the candidates — including that no filename appears
among them, this failure's signature. Verified to bite: reintroducing the bug
turns 9 passes into 7 failures.

**Then CI went red, which is the system working.** The completion suite had been
running on macOS only, because zsh is absent from the Ubuntu runner image
(checked against the manifests, not recalled). Adding it to the Linux leg
immediately surfaced a second failure: Debian's `/etc/zsh/zshrc` runs a bare
`compinit` before any `ZDOTDIR/.zshrc`, and on a host with a world-writable
directory on `fpath` — which a CI runner has — it aborts, taking the completion
system down before the completion under test loads. Fixed via Debian's own
documented `skip_global_compinit`. **CI green on both legs, with the completion
suite observed running on each** (run 35145910123).

The container check that preceded the red push ran as root in a clean image and
had neither a group-writable `fpath` entry nor Debian's zshrc, so it could not
have caught it. A check that does not reproduce the environment it claims to
cover is not evidence — the same lesson the test failure taught, one layer out.

**217 assertions, up from 183.** Untouched throughout: the burn trap, the
secret's path, what any profile grants, and the `curl` + `jq` runtime.

---

## Prior — 2026-09-11

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

<!-- Older entries (2026-09-10 and earlier) rotated to `.agent/PROJECT-STATE-HISTORY.md`
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

Nothing is owed. `main` is green on both CI legs and in sync with origin; no
milestone is active. Two dotagent-side items were raised 2026-09-16 and are the
owner's, not this project's: `mental-models` is past its polish cadence, and the
sweep reported `copy-truth` as a stale selected pairing when PROJECT-SCOPE.md
records it as considered and **not** selected.

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
