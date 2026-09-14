# cf-minter — flow ergonomics audit

**Date:** 2026-09-13. **Status:** undispositioned (findings need a call each).
**Framing:** the owner asked for "glamour in the sense of ergonomics — zsh
autocomplete and similar, to make it flowy." This is **inside** ratified scope,
not against it: `PROJECT-SCOPE.md ## Out of scope` rules out visual polish while
defining ergonomics as "discoverability and low friction" — which is the axis
here. No scope amendment is required for anything below.

## Method

Run at source on 2026-09-13, not read from the README: bare `cf-minter`,
`profiles`, `doctor` (exit 1), `run --dry-run`, `<verb> --help` for all six
verbs, and three refusal paths (unknown profile, zone profile without zone,
account profile with zone).

## What is already good (and must not be "improved")

- **Refusals name the fix and the blast radius.** `run --profile dns-edit
  --dry-run` → "profile 'dns-edit' is zone-scoped and no zone was named — pass
  --zone <name> or --zone-id <id>. Minting its permissions with no zone would
  hand the command reach over every zone the account owns." Nothing to add.
- **`--dry-run` is already the narrated plan** a glamour brief would ask for:
  resolution steps, computed expiry, the literal policy JSON, the POST that
  would be made with the minter token explicitly noted as never shown.
- **`doctor` exits 1 when not ready** — the exit code is an API and it is honest.

## Findings, ranked by flow-per-risk

### F1 — `<verb> --help` prints the source comment header (Material)

`cf-minter run --help` emits **105 lines, 104 of them starting with `#`** — the
raw script header of `cf-scoped-run.sh`. Same for `mint --help` and
`profiles --help`. The front door explicitly advertises this path ("HELP ON ONE
COMMAND — cf-minter <command> --help"), and it leads to commented source that
names sibling scripts and internal test-only env (`CF_MINT_TOKEN_SCRIPT
(tests)`). Two verbs are fine: `doctor --help` is one clean line; `burn --help`
errors usefully.

Fix: author per-verb help in cf-minter's own voice, matching the top-level
help's shape. Pure wording/Minor-Material, zero runtime risk, no new dependency.

### F2 — no shell completion at all (Minor, new file)

Nothing in the repo defines completion (`grep` for compdef/complete -F: none).
Every profile name, verb and flag is typed from memory or from a `profiles` call
in another pane. This is the single largest friction source and the owner's
explicit ask.

Design point that matters: completion must not become a **second parser** of
`profiles.conf` (hard constraint: it is the sole home of the profile set;
Principle 7: one fact, one place). The tool should emit a machine-readable
profile list that the completion consumes — `cf-scoped-run.sh` already has
`list_profiles()` (line 214) and a `list-profiles` dispatch (line 491) to build
on. Completion then stays a thin consumer, and adding a profile remains one edit.

Scope: verbs, per-verb flags, profile names (live from the tool), token ids for
`burn` (needs network — gate it or omit), `--ttl` suggestions.

### F3 — `profiles` shows permissions, not reach (Material)

Seven profiles print as flat text; reach is implied by permission strings. A
profile IS a blast radius. A reach column (zone vs account, read vs edit) is
information design, not decoration — admissible under the exclusion's own
"removes real friction" clause. Note `zone-harden`'s `why:` is a paragraph that
wraps badly at 7 permissions.

### F4 — unknown profile lists candidates but does not suggest (Minor)

`--profile nope` lists all seven. A nearest-match hint ("did you mean
'dns-edit'?") is a few lines of bash and no new dependency.

## Constraints respected by all four

None touches the secret's lifetime, the burn trap, signal handling, terminal
state during a wrapped command, or what a profile grants. No runtime dependency
beyond curl + jq. All remain hermetically testable. F1/F3/F4 are output-only;
F2 adds a file the tool does not source at runtime.

## Disposition — 2026-09-13

Owner reframed the brief mid-walkthrough: "glamour in the sense of ergonomics
like zsh autocomplete… make it flowy." That moved the work inside ratified
scope; the scope conflict I opened with dissolved and **no amendment was made
or needed**. Owner then ordered all four built on `main`.

| finding | disposition | evidence |
|---|---|---|
| F1 per-verb help | **fixed** | `cf-minter:verb_help()`; six verbs assert prose-not-comments |
| F2 completion | **fixed** | `completions/_cf-minter`, `completions/cf-minter.bash`, fed by `cf-scoped-run.sh --profile-names` |
| F3 reach-sorted profiles | **fixed** | `cf-scoped-run.sh:list_profiles()` + `perms_at()` |
| F4 did-you-mean | **fixed** | `cf-scoped-run.sh:nearest_profile()`, 6 lines |

Suite: **208 assertions, 0 failed** (was 183). Nothing touched the burn trap,
the secret path, what any profile grants, or the runtime dependency set.

One pre-existing guard was repaired rather than worked around: the dispatcher's
"never touches a credential" check strips help heredocs before reading code, and
knew only the `USAGE` delimiter — the new per-verb `H` blocks made legitimate
help text (which must name `CLOUDFLARE_API_TOKEN`) read as code. The stripper
now covers both. The suite's own planted-violation self-check still passes, so
the guard was not blunted.

**Honest bound on the zsh evidence.** The bash completion is exercised
end-to-end — driven through `COMPREPLY` the way the shell drives it, including
the deferral after `--`. The zsh file is verified to parse under `zsh -n` and to
load under `compinit`, and the data it consumes is asserted; a true interactive
`zpty` capture of its candidate list was attempted and did not produce output
under `zsh -f`, so **zsh completion is not proven by an interactive capture** —
it wants one manual TAB to confirm.
