# The Lens — what cf-minter is, right now

restated: 2026-10-01

<!-- The SESSION-READ CORE of this project (dotagent L95). Read every session,
     before PROJECT-SCOPE.md. `class: current`: it must be TRUE RIGHT NOW —
     bump `restated:` whenever the project moves. ONE SCREEN. Boundaries (hard
     constraints, out-of-scope, rubric, check-in mode, verification) stay in
     PROJECT-SCOPE.md. There is no DIRECTION.md: no next milestone is committed. -->

## What this file is, and the two rules that keep it true

This is cf-minter explaining itself to a reader with no context. Everything in
the repo is accounted for by §6, or named there as unaccounted.

## 1. What cf-minter is

**A public, standalone bash tool that makes a Cloudflare credential exist only
while your job runs** — mint a scope-exact API token, hand it to a command, burn
it on the way out on success, failure, or Ctrl-C alike. It is for anyone who
needs Cloudflare access inside a script without leaving a long-lived token lying
around. Success is a stranger going from clone to a working scoped run in under
a minute.

Two engines and a front door: `cf-mint-token.sh` owns the credential itself
(resolve the minter, mint, verify, list, revoke); `cf-scoped-run.sh` owns the
mint → use → burn lifecycle, the named profiles and the stale sweep;
`cf-minter` is a pure dispatcher over both that holds no credential knowledge.
`profiles.conf` is the one home of the named purposes.

## 2. What it does

- **Scoped runs.** `cf-minter run --profile <name> --zone <z> -- <cmd>` mints,
  runs, and burns; the command's exit code is preserved, and a failed burn
  turns a green run red.
- **Previews.** `--dry-run` shows permissions, zone, expiry and the exact
  request without touching the network or needing a minter.
- **Clean-up.** `list --stale` / `burn --stale` find and revoke leftovers from
  runs whose burn failed, touching only `cfsr-*` tokens past their declared life.
- **Setup check.** `cf-minter doctor` checks curl, jq, and whether the minter
  credential actually qualifies (measured against the API, not guessed).

## 3. How it got here

**It was** a pair of scripts inside an ops repo. **That produced** v0.1.0
(2026-09-17): public on GitHub, MIT, CI green on Linux and macOS, the founding
success test passed from a fresh clone. **What it cost** — the front door
lagged the engines: on 2026-10-01 an operator found `doctor` ignoring
`--minter-cmd`, `run --help` omitting `--perm`, and CRLF profiles refused by
their own name (all fixed, `4eb80e2`). **Nothing is being reframed.**

## 4. What is in flight, right now

- **Nothing committed.** No active milestone. Candidate work, none urgent, is
  PROJECT-STATE.md §7: more profiles (each verified by one real mint), a
  Homebrew tap if asked for, front-door coverage of the remaining engine flags.

## 5. What this file deliberately does not do

It does not name an endpoint, and it does not hold boundaries — those are
PROJECT-SCOPE.md's.

## 6. What it is made of — the conservation run

| surface | what it serves |
|---|---|
| `cf-minter`, `cf-*.sh`, `profiles.conf` (root) | the front door, the two engines, and the profile set (§1) |
| `lib/` | `cf-retry.sh`: retry wrapper for Cloudflare's eventually-consistent auth edge, sourced by the mint engine |
| `completions/` | bash and zsh completion for `cf-minter`; reads profiles via `profiles --names`, never the file |
| `test/` | the hermetic suites — one per tool plus a pty-driven zsh completion test; `run-all.sh` is the runner |
| `.github/` | CI: `test.yml` runs the suite on ubuntu and macos, no secrets |
| `.agent/` | project tracking — scope, state, brief, rulings; published, by ruling, as the tool's reasoning |

**Unaccounted for:** none.

## 7. Scope, graded

**In scope — v1 (shipped)**
- Mint / run / burn, profiles, stale sweep, doctor, completions, dry-run.

**In scope — after v1**
- New profiles, one verified edit at a time — each needs a real mint, because
  names resolve against Cloudflare's live catalogue.

**Out of scope — for now, not forever**
- A non-bash rewrite — revisit if the code outgrows what a reader will audit.
- Providers other than Cloudflare — revisit if a second is actually needed.
- A Homebrew tap — revisit when someone asks.

**Out of scope — entirely**
- Managing Cloudflare resources, and being a secret store: cf-minter hands a
  credential to a command, and `--minter-cmd` is the seam to your own store.
