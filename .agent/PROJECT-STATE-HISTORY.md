# Project State — history

<!-- Rotated out of PROJECT-STATE.md by the history cap (D-0072): the current
     head plus roughly one Prior entry stay inline there; older entries land
     here. Append-only, newest-first. NOT read at session start. -->

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

