# Project Brief — cf-minter

<!-- Locked 2026-09-09 by explicit user ratification ("lockit"). Phase 0 of the
     vision-first bootstrap (DECISION-0026). Existing-repo bootstrap: the
     interview was grounded in the code (D-0034), not a blank slate. -->

## Vision

cf-minter is a **public, standalone tool** that makes a Cloudflare credential
exist *only while your job runs* — mint a scope-exact API token, hand it to a
command, burn it on the way out on success, failure, or Ctrl-C alike.

Success is a stranger cloning the repo, exporting `CF_MINTER_TOKEN`, running
`--dry-run`, and understanding exactly what would be created — in under a
minute, with no internal or dotagent references anywhere on the surface.

On top of correctness: **it must not be a pain to use.**

### Ergonomics as a first-class goal

"Enjoyably user friendly" means **ergonomics, not polish**. Concretely:

- the commands make sense and read the way you'd guess them;
- it's obvious how to run one without going back to the README;
- help text answers the question you actually have;
- defaults are the thing you almost always wanted;
- when something is wrong, the error names what to do about it.

This is discoverability and low friction. It is **not** visual polish. Colors,
tables, and an interactive profile picker are optional *means*, justified only
where they remove real friction — never pursued for their own sake.

## Platforms & stack

**Bash**, with `curl` + `jq` as runtime dependencies. Cloudflare's REST API is
the only backend.

Deliberately **not** Go, Node, or Rust. This was reconsidered explicitly during
this interview and re-affirmed: at **955 code lines across 44 functions in three
files** (`cf-mint-token.sh` 596, `cf-scoped-run.sh` 291, `lib/cf-retry.sh` 68),
a reader can audit the whole tool before trusting it with a credential that can
mint and delete other credentials. That auditability is the property this tool
sells hardest, and no runtime change may trade it away without a ratified
decision. (The "76KB of bash has outgrown auditability" argument that initially
favoured a Go rewrite was measured wrong — the files are ~40% comments.)

macOS / bash-3.2 compatibility is **not** a constraint.

## User-facing surface

**CLI only** — programmatic, no GUI, no physical surface.

Today: two entry points, `cf-mint-token.sh` (the credential itself) and
`cf-scoped-run.sh` (the mint → use → burn lifecycle).

Going forward: a single verb-first `cf-minter` dispatcher —
`run` / `mint` / `profiles` / `list` / `burn` / `doctor` — with the two-script
split demoted to an **internal module boundary** rather than something a user
must learn. This is the main ergonomics move: one thing to install, one thing to
learn, verbs you can guess.

## Personas / roles & domain-term glossary

### Personas

- **The cold operator** — running one scoped Cloudflare job by hand, has never
  seen the tool. Wants `--dry-run` and `--mint-only`, and wants to see the reach
  they are handing out *before* they hand it out. The primary persona; the
  under-a-minute success test is theirs.
- **The vault-backed automation user** — pipes a secret store in through
  `--minter-cmd` (1Password, HashiCorp Vault, AWS Secrets Manager, Azure Key
  Vault). Cares about exit codes and stale sweeping.

Both are first-class. There is no third CI-specific persona; CI is served as a
case of the automation user.

### Roles & dual-role users

No dual-role split — one person can be both personas on different days, and
nothing they need changes when they switch hats. No axis to preserve here.

### Domain-term glossary

- **Minter** — the *privileged* credential carrying `User API Tokens:Edit`,
  which can create and delete tokens. Qualified **by measurement** (`GET
  /user/tokens/permission_groups` succeeds), never by what it is named.
- **Minted token** / **scoped token** — the *ephemeral* credential handed to the
  wrapped command in `CLOUDFLARE_API_TOKEN` / `CF_SCOPED_TOKEN`.
- ⚠️ **OVERLOADED: "token."** Minter and minted token are two different things
  with opposite privilege levels and opposite lifetimes. This is the most
  confusable term in the project, and it is an **ergonomics hazard** as much as a
  documentation one — surfaces must never say bare "token" where the reader
  could resolve it either way.
- **Profile** — a named purpose in `profiles.conf`: its permissions, its
  zone-vs-account rule, its default TTL. `profiles.conf` is the only place a
  profile is defined; no code knows one by name.
- **Stale** — a `cfsr-*` token past the TTL its own name declares, i.e. a run
  whose burn failed. Tokens outside that naming convention are never touched.

## Methodology

Committed:

- **One home per fact.** `profiles.conf` is the sole definition of the profile
  set; adding a profile is one edit and no code change.
- **No hardcoded permission-group UUIDs.** Human permission names resolve to
  UUIDs by a **live catalogue read at mint time**, so a group Cloudflare renamed
  fails the mint loudly (listing what does exist) instead of silently granting
  the wrong thing.
- **No state file.** Staleness is derived from the token's own name
  (`cfsr-<mint-epoch>-t<ttl-seconds>-<slug>`), so there is nothing that can drift
  out of sync with Cloudflare.
- **Named refusals at the boundary** over downstream wheel-spin — an unknown
  profile, a missing minter, a zone flag on an account profile each fail by name.
- **Hermetic tests.** `curl` and `az` are PATH stubs; a full `test/run-all.sh`
  run mints nothing, uses nothing, and deletes nothing.

Not committed to: TDD as a ritual, any packaging/release framework, any
cross-provider abstraction (Cloudflare is the only backend and the pattern is not
being generalized).

## Constraints

**Hard — the secret never escapes.** Ratified as the binding constraint:

- never printed (except the explicit `--mint-only` path), never logged;
- never passed in argv (`ps` is world-readable);
- never written anywhere that outlives the mint beyond a 0600 temp file;
- the **burn is owed on every exit path**, including SIGINT;
- a run that leaked a live credential **is not a green run** — it exits non-zero
  and says so, naming the token.

**Also binding — no unasked-for reach.** A `zone` profile refuses to run without
a `--zone`/`--zone-id`; an `account` profile refuses to be given one. Neither may
quietly hand out reach nobody asked for.

**Not constraints:** macOS/bash-3.2 support; preserving `cf-mint-token.sh`'s
current flag surface (open question, see Gaps).

## Expertise needed

- Cloudflare's API token / permission-group model and its API's failure shapes.
- Defensive bash: traps, quoting, subshell secret handling, exit-path discipline.
- Credential-lifecycle security reasoning (blast radius, TTL vs revocation,
  residue sweeping).
- **CLI ergonomics** — surface design, help text, error messages. Now a
  first-class demand, not a nice-to-have.

## Gaps / unknowns

All three are **ergonomics questions, not architecture ones**:

1. Whether `cf-mint-token.sh`'s existing flag surface stays as a compatibility
   layer under the new `cf-minter` dispatcher, or is retired.
2. Whether `profiles.conf` ships with the right default profile set for a
   stranger, or is currently tuned to the author's own use.
3. How `doctor` presents a failed minter qualification.

## Standing authorization note

The bash implementation — `cf-mint-token.sh`, `cf-scoped-run.sh`,
`lib/cf-retry.sh`, and the `test/` suite — **is staying.** Nothing in this brief
authorizes deleting or replacing any of it (Principle 18).
