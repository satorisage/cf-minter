# cf-minter

**One command gets you a Cloudflare credential that exists only while your job
runs.** Mint a scope-exact API token, hand it to a command, burn it on the way
out — success, failure, or Ctrl-C alike.

```bash
export CF_MINTER_TOKEN=…            # a credential with "User API Tokens:Edit"
./cf-minter run --profile dns-edit --zone example.com -- ./publish-records.sh
```

That mints a token carrying exactly `DNS:Edit` + `Zone:Read` on `example.com`,
with a 15-minute expiry, runs `./publish-records.sh` with the value in
`CLOUDFLARE_API_TOKEN` / `CF_SCOPED_TOKEN`, and deletes the token at Cloudflare
before it returns. The value is never printed, never logged, never written
anywhere but a 0600 temp file that does not outlive the mint.

## Start here

Run `./cf-minter` on its own and it tells you what it does. Then:

```bash
./cf-minter doctor                  # is curl/jq present, and does your credential qualify?
./cf-minter profiles                # what can I ask for, and what reach does each hand out?
./cf-minter run --profile dns-edit --zone example.com --dry-run -- ./publish-records.sh
```

`--dry-run` prints the exact plan — permissions, scope, TTL, and the API call
that would be made — with **zero network calls and no credential required**. It
is the safe way to see what a profile actually grants before you grant it.

## Commands

| command | what it does |
|---|---|
| `cf-minter run … -- <cmd>` | mint a scoped token, run `<cmd>` with it, burn it afterwards |
| `cf-minter mint …` | mint and print the value once, run nothing, do **not** burn — for hand-driven work. Only the TTL ends it |
| `cf-minter profiles` | list the named purposes and the reach each grants |
| `cf-minter list` | list your API tokens; `--stale` for runs whose burn failed |
| `cf-minter burn <id>` | revoke that token; `--stale` to sweep failed burns |
| `cf-minter doctor` | check `curl`, `jq`, and whether your minter credential qualifies |

Run `cf-minter <command> --help` for one command's own flags.

## What is underneath

`cf-minter` is a dispatcher. It holds no logic of its own — it never sees a
token value and never calls Cloudflare — and hands every command to one of two
tools:

| tool | what it owns |
|---|---|
| `cf-scoped-run.sh` | the **mint → use → burn** lifecycle, profiles, the burn trap, stale-token sweeping |
| `cf-mint-token.sh` | the credential itself: resolve names to ids, mint, **verify**, store, list, revoke, burn |

Both remain usable directly and their flags are unchanged, so existing call
sites keep working. `cf-minter run` is `cf-scoped-run.sh`; `cf-minter mint` is
`cf-scoped-run.sh --mint-only`; `cf-minter list` is `cf-mint-token.sh --list`,
and `cf-minter list --stale` is `cf-scoped-run.sh --list-stale`. The split is a
real module boundary — it is just no longer something you have to learn first.

## Flags for `run` and `mint`

| flag | meaning |
|---|---|
| `--profile <name>` | a named purpose from `profiles.conf`: its permissions, its zone-vs-account rule, its default TTL |
| `--zone <name>` | scope to this zone by name (resolved live to its id) — repeatable |
| `--zone-id <id>` | scope to this zone by id, no lookup — for automation that already holds the id |
| `--ttl <n>[s\|m\|h\|d]` | token lifetime; overrides the profile default. Cloudflare refuses the token past it even if the burn never runs |
| `--slug <label>` | trailing label in the token name (defaults to the profile name) so a stale token says what it was for |
| `--mint-only` | mint and print the value once, run nothing, do **not** burn — for hand-driven work. Only the TTL ends it |
| `--minter-cmd <cmd>` | shell command that prints the minter token — the hook for your own secret store |
| `--minter-token-file <p>` | read the minter from a file's first line |
| `--perm <Name:Level>` | ad-hoc permission instead of a profile, repeatable (e.g. `--perm DNS:Edit`). Append `@account` or `@zone` to disambiguate a name Cloudflare publishes at both scopes — see below |
| `--dry-run` | print exactly what would be minted and run; no network calls, nothing created |
| `--list-profiles` | print the profiles and their reach |
| `--list-stale` | list `cfsr-*` tokens past the TTL their own name declares — i.e. runs whose burn failed. Exit 1 if any |
| `--burn-stale` | revoke exactly those. Tokens not named `cfsr-*` are never touched |

Exit code: the wrapped command's own — except **1** when the mint failed (the
command never ran) or when the burn failed after a green command. A run that
leaked a live credential is not a green run.


## When one name means two permissions

Applies to `--perm` in both tools.

Cloudflare publishes a handful of permission groups **twice under one name**,
differing only in scope — `Access: Apps and Policies Write`, `Logs Read/Write`
and `Disable ESC Read/Write` each exist as both an account-scoped and a
zone-scoped group. Resolving by name alone cannot tell them apart, so cf-minter
refuses rather than guessing which one you meant:

```
FAIL  --perm 'Access: Apps and Policies:Edit' is ambiguous — 2 permission
      groups share the name 'Access: Apps and Policies Write':
    Access: Apps and Policies Write  [com.cloudflare.api.account]
    Access: Apps and Policies Write  [com.cloudflare.api.account.zone]
  Say which you mean by appending @account or @zone:
      --perm "Access: Apps and Policies:Edit@account"
      --perm "Access: Apps and Policies:Edit@zone"
```

Do what it says:

```bash
CF_MINTER_TOKEN=… ./cf-mint-token.sh --name glpi-provision \
  --perm "Access: Apps and Policies:Edit@account" \
  --perm "DNS:Edit" --zone example.com
```

The hint is **optional** — unique names need none, and a redundant but correct
one is accepted. A hint no candidate satisfies is reported as such, with the
scopes that name *does* offer, rather than as a generic "no such group".

## Profiles

Profiles live in `profiles.conf`. That file is the only place a profile is
defined; no code knows one by name.

| profile | permissions | scope | ttl |
|---|---|---|---|
| `dns-edit` | `DNS:Edit`, `Zone:Read` | zone | 15m |
| `dns-read` | `DNS:Read`, `Zone:Read` | zone | 15m |
| `zone-settings` | `Zone Settings:Edit`, `Zone:Read` | zone | 15m |
| `zone-harden` | `DNS:Edit`, `Zone Settings:Edit`, `Zone WAF:Edit`, `Firewall Services:Edit`, `SSL and Certificates:Edit`, `Analytics:Read` | zone | 30m |
| `certs` | `SSL and Certificates:Edit` | zone | 15m |
| `pages-deploy` | `Pages:Edit`, `Pages:Read` | account | 30m |
| `workers-deploy` | `Workers Scripts:Edit` | account | 30m |

A **zone** profile refuses to run without a `--zone`/`--zone-id`; an **account**
profile refuses to be given one. Both would otherwise hand out reach nobody
asked for.

### Adding a profile

One edit, no code:

```
profile: logs-read
perm: Logs:Read
perm: Zone:Read
scope: zone
ttl: 10m
why: pull Logpush job state for one zone
```

Permission names are the human names from Cloudflare's token editor
(`Name:Edit` / `Name:Read`); they are resolved to permission-group UUIDs by a
**live catalogue read** at mint time, so nothing here goes stale silently — a
name Cloudflare no longer uses fails the mint loudly, listing the groups that do
exist. Point at a different file with `CF_PROFILES_FILE=/path/to/profiles.conf`.

## The minter credential

Creating and deleting tokens is itself privileged: you need a credential
carrying **User API Tokens:Edit** (a normal scoped token can do neither).
Resolved in this precedence, and never accepted as a command-line argument —
argv is world-readable in `ps`:

1. `CF_MINTER_TOKEN=<value>` in the environment
2. `--minter-cmd '<command that prints the token>'` (or `CF_MINTER_CMD`)
3. `--minter-token-file <path>`
4. `CF_MINTER_VAULT_SECRET` + `OPS_VAULT_NAME` — an optional Azure Key Vault
   convenience, using whatever vault and secret name you name

### Wiring your own vault

`--minter-cmd` is the seam: any command that prints the token on stdout.

```bash
# 1Password
./cf-minter run --minter-cmd 'op read op://Infra/cf-minter/credential' \
  --profile dns-edit --zone example.com -- ./publish-records.sh

# HashiCorp Vault
./cf-minter run --minter-cmd 'vault kv get -field=token secret/cloudflare/minter' \
  --profile certs --zone example.com -- ./issue-origin-cert.sh

# AWS Secrets Manager
./cf-minter run --minter-cmd 'aws secretsmanager get-secret-value --secret-id cf-minter --query SecretString --output text' \
  --profile pages-deploy -- npx wrangler pages deploy ./dist

# Azure Key Vault
./cf-minter run --minter-cmd 'az keyvault secret show --vault-name my-vault --name cf-minter-token --query value -o tsv' \
  --profile zone-settings --zone example.com -- ./flip-tls-setting.sh
```

If the fetch command fails, the run fails and says so with the command's own
error — it is never treated as "no token configured".

### Is this credential actually a minter?

Ask by measurement, never by what it is named:

```bash
CF_MINTER_TOKEN=… ./cf-minter doctor
```

A credential qualifies iff `GET /user/tokens/permission_groups` succeeds. A
token with plenty of DNS or zone reach but not that group fails here — and would
have failed halfway through a mint instead.

## What the wrapped command sees

`CLOUDFLARE_API_TOKEN` and `CF_SCOPED_TOKEN`, both set to the minted value, in
the environment only. Nothing else changes. A command that already reads
`CLOUDFLARE_API_TOKEN` (wrangler, terraform's Cloudflare provider, flarectl,
most `curl` snippets) needs no adaptation at all.

## When a burn fails

The burn is owed on every exit path, but the network can refuse. When it does,
the run says so loudly with the token's name and exits non-zero — and the token
is still bounded by its TTL. Sweep the residue afterwards:

```bash
./cf-minter list --stale            # exit 1 if any run's burn failed
./cf-minter burn --stale            # revoke exactly those
```

Staleness is read back out of the token's own name
(`cfsr-<mint-epoch>-t<ttl-seconds>-<slug>`), so there is no state file to drift,
and tokens outside that convention are never touched.

## Requirements

`curl` and `jq`. `az` only if you use the optional Key Vault path. Bash 3.2+
(macOS stock bash is fine).

## Tests

Hermetic — `curl` and `az` are PATH stubs, so a full run mints nothing, uses
nothing and deletes nothing:

```bash
bash test/run-all.sh
```

Covered: the mint/verify/store gate, TTL and value-file handling, profile
resolution and scope refusals, minter precedence and named refusals, and the
burn on success, on command failure, and on SIGINT.
