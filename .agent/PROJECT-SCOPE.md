# Project Scope: cf-minter

<!-- Locked 2026-09-09 by explicit user ratification ("lock it"). Phase 2 of the
     vision-first bootstrap (DECISION-0026). Vision input:
     .agent/REPORTS/project-brief.md (locked same session). -->

## Active milestone

**Milestone:** M2 — close the open ergonomics questions
**Ratified:** 2026-09-11, via walkthrough. M1 is complete (see PROJECT-STATE).

M2 was three rulings, not a build. Each was an open question the vision brief
left, and each is now answered:

1. **`cf-mint-token.sh` stays supported but stops being taught.** Every flag
   keeps working — nothing that calls it breaks — but the README no longer
   presents it as a way in. Measured at decision time: it exposes 17 flags and
   `cf-minter` reaches 8, so the dispatcher is a friendly surface over the
   common path, not a complete one. The README now says exactly that and points
   at `--help` for the other nine, rather than implying either that they don't
   exist or that the tool is a second front door.
2. **`profiles.conf` ships its seven as a declared starting set.** Not a
   catalogue of Cloudflare, and said so in both the README and the file's own
   header. No profiles were added: permission names resolve by a live catalogue
   read that `--dry-run` does not perform, so an unverified name cannot be
   checked offline, and guessing at vendor strings is the failure this project
   refuses by design.
3. **The repo ships as-is** — `.agent/` and `CLAUDE.md` included. Not a
   constraint violation (the constraint governs source, runtime strings and the
   README, all of which are clean). Revisit when the repo actually goes public;
   it is not public yet, so the question is premature.

**Definition of done:** all three rulings enacted in the README and
`profiles.conf`, suite green. **Met.**

**Next:** M3 — public-release readiness, not yet scoped. The gating facts, all
verified 2026-09-11: there is no git remote, no LICENSE, no CI, no install path
and no tag. Until those exist this project's own stated success test — "a
stranger goes from clone to a working scoped run in under a minute" — is not
merely unmet but impossible, since nobody can clone what is unpublished or
legally reuse what is unlicensed.

## Hard constraints

- **The secret never escapes.** Never printed (except the explicit
  `--mint-only`), never logged, never passed in argv (`ps` is world-readable),
  never written anywhere that outlives the mint beyond a 0600 temp file.
- **The burn is owed on every exit path**, including SIGINT. A run that leaked a
  live credential is not a green run — it exits non-zero and names the token.
- **No unasked-for reach.** A `zone` profile refuses to run without a
  `--zone`/`--zone-id`; an `account` profile refuses to be given one. And an
  **ambiguous permission name refuses rather than guessing**: Cloudflare
  publishes some groups twice under one name at both scopes, so a `--perm` that
  matches more than one names the conflict and prints the exact
  `@account`/`@zone` flag to disambiguate. Silently picking one would hand out
  reach at a scope nobody chose.
- **No hardcoded permission-group UUIDs.** Human permission names resolve by a
  live catalogue read at mint time; a renamed group fails the mint loudly.
- **No state file.** Staleness derives from the token's own name
  (`cfsr-<mint-epoch>-t<ttl-seconds>-<slug>`). Tokens outside that convention
  are never touched.
- **`profiles.conf` is the sole home of the profile set.** No code knows a
  profile by name; adding one is one edit and no code change.
- **Tests stay hermetic.** `curl` and `az` are PATH stubs; a full suite run
  mints nothing, uses nothing and deletes nothing.
- **Bash + `curl` + `jq`.** The runtime is ratified; changing it requires a new
  dated decision.
- **No tracking-surface vocabulary in the shipped tool.** No decision IDs,
  `.agent/` paths, or dotagent references in source comments, runtime strings,
  or the README.

## Out of scope

- **A Go / Node / Rust rewrite** — decided against 2026-09-09. Auditability of
  ~955 code lines is the property this tool sells hardest; a binary cannot be
  read before it is handed a credential that mints and deletes other
  credentials. Revisit if the codebase genuinely outgrows what a reader will
  audit.
- **Any provider but Cloudflare** — mint→use→burn is not being generalized to
  AWS/Azure/GitHub. Revisit if a second provider is actually needed, not
  speculatively.
- **A TUI / interactive-first experience** — ergonomics here means
  discoverability and low friction, not visual polish. A picker or colored
  output is admissible only where it removes real friction, never for its own
  sake.
- **Managing Cloudflare resources itself** — cf-minter hands a credential to a
  command; it does not deploy, edit DNS, or configure zones. That is the
  wrapped command's job, permanently.
- **Being a secret store** — `--minter-cmd` is the seam to yours. This is a
  boundary, not a deferral.
- **macOS / bash-3.2 compatibility as a constraint** — explicitly not a target
  and not a blocker.

## Criticality rubric

**Critical** (hard-stop, do not touch related work):

- anything touching the secret's lifetime or handling
- anything touching the burn's exit-path guarantee
- changing what a profile grants (its reach)
- weakening or removing any refusal
- removing or replacing existing bash code

**Material** (continue on parallel work, avoid downstream):

- the CLI surface shape — verbs, flag names, subcommand boundaries
- `profiles.conf`'s default profile set
- error and help wording

**Minor** (continue freely):

- code comments, README prose
- added tests
- output formatting

## Default check-in mode

Hybrid, per the operating manual.

## Verification

- **After a change:** `bash test/run-all.sh`
- **Before landing:** `bash test/run-all.sh`
- **Not run by hand:** none — there is no expensive tier. The full suite is
  hermetic (no network), 59 tests, and runs in seconds, so it *is* the cheap
  command.

## Reference — durable scope, NOT read at session start

## Overview

cf-minter is a public, standalone bash tool that makes a Cloudflare credential
exist only while your job runs — mint a scope-exact API token, hand it to a
command, burn it on the way out on success, failure, or Ctrl-C alike. It is for
anyone who needs Cloudflare access inside a script without leaving a long-lived
token lying around. Success is a stranger going from clone to a working scoped
run in under a minute.

## Pairings

- `cloudflare-security` — owns scoped API-token management and the honest blast
  radius of a Cloudflare credential; the reasoning behind why scope-exact and
  short-lived beats standing
- `enforcement-surfaces` — owns the refusals and preflights the tool is built
  from, and the discipline of proving each rather than asserting it
- `mental-models` — owns discoverability, guessable verbs, and resolving the
  `token` overload; the discipline behind the M1 surface redesign

(`copy-truth` was considered and not selected.)

## Principles, in priority order

1. **The secret never escapes.** Above everything else. A convenience that puts
   it at risk is not a convenience.
2. **Refuse by name at the boundary.** Never wheel-spin, never run on a
   placeholder, never hand out partial or unasked-for reach.
3. **Auditability is the product.** Readable bash beats a faster or prettier
   binary, because the reader must trust this tool with a credential that can
   mint and delete other credentials.
4. **One home per fact.** `profiles.conf` for profiles; the token's own name for
   staleness; the live catalogue for permission-group UUIDs.
5. **The cold operator is the primary reader.** If the surface needs the README
   to be usable, the surface is wrong.
6. **Nothing that can silently go stale.** No cached UUIDs, no state file, no
   second copy of a fact.

## Capabilities currently in scope

### Credential lifecycle
- Mint a scope-exact Cloudflare API token with an explicit TTL
- Verify a minted token before handing it out
- Store a minted value to a 0600 temp file that does not outlive the mint
- Revoke / burn a token by name or id
- Burn on every exit path, including SIGINT

### Profiles
- Named purposes resolved from `profiles.conf` (permissions, zone/account rule,
  default TTL, `why`)
- Zone-vs-account scope refusals
- `--list-profiles` / ad-hoc `--perm`
- **`--perm Name:Level@account` / `@zone` scope hint** — optional, needed only
  where Cloudflare publishes one name at both scopes (e.g. `Access: Apps and
  Policies`, `Logs`, `Disable ESC`). An unhinted ambiguous name refuses and
  names the flag to add; a hint that matches nothing reports what the name
  actually offers. `profiles.conf` inherits this for free — `perm:` values are
  passed verbatim to `--perm` with no format validation of their own.

### The run wrapper
- mint → run wrapped command → burn, with the value in `CLOUDFLARE_API_TOKEN`
  and `CF_SCOPED_TOKEN`
- `--dry-run` (zero network calls)
- `--mint-only` (print once, do not burn; TTL is what ends it)
- exit-code propagation, with mint/burn failure forcing non-zero

### Minter credential resolution
- `CF_MINTER_TOKEN` → `--minter-cmd` → `--minter-token-file` → Azure Key Vault
- `--qualify-minter` — qualification by measurement, never by name

### Residue
- `--list-stale` (exit 1 if any) and `--burn-stale`, derived from token names

### Planned but not yet specified (preserve, do not extend)
- **`cf-mint-token.sh`'s current flag surface as a compatibility layer.**
  Whether it survives under the new dispatcher is an open M1 question; it is
  preserved meanwhile.

## Removal review

Anything in the codebase that does not map to a capability above is a **review
trigger, not a delete warrant** (Principle 18). The default for unmapped surface
is stop and surface. The bash implementation — `cf-mint-token.sh`,
`cf-scoped-run.sh`, `lib/cf-retry.sh`, and the `test/` suite — is **explicitly
preserved**; nothing in this scope authorizes deleting any of it.

## Project-specific glossary

- **Minter**: the *privileged* credential carrying `User API Tokens:Edit`, which
  can create and delete tokens. Qualified by measurement (`GET
  /user/tokens/permission_groups` succeeds), never by what it is named.
- **Minted token** / **scoped token**: the *ephemeral* credential handed to the
  wrapped command in `CLOUDFLARE_API_TOKEN` / `CF_SCOPED_TOKEN`.
- ⚠️ **"token" is overloaded.** The two above have opposite privilege levels and
  opposite lifetimes. No user-facing surface may say bare "token" where the
  reader could resolve it either way.
- **Profile**: a named purpose in `profiles.conf` — its permissions, its
  zone-vs-account rule, its default TTL.
- **Stale**: a `cfsr-*` token past the TTL its own name declares, i.e. a run
  whose burn failed.
- **Scope hint**: the optional `@account` / `@zone` suffix on a `--perm` spec,
  disambiguating a permission-group name Cloudflare publishes at both scopes.
  Distinct from a *profile's* `scope:` key, which governs whether the run may
  name a zone at all — two different senses of "scope" that must not be
  collapsed.
