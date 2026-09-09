# cf-minter

**One command gets you a Cloudflare credential that exists only while your job
runs.** Mint a scope-exact API token, hand it to a command, burn it on the way
out — success, failure, or Ctrl-C alike.

```bash
export CF_MINTER_TOKEN=…            # a credential with "User API Tokens:Edit"
./cf-scoped-run.sh --profile dns-edit --zone example.com -- ./publish-records.sh
```

That mints a token carrying exactly `DNS:Edit` + `Zone:Read` on `example.com`,
with a 15-minute expiry, runs `./publish-records.sh` with the value in
`CLOUDFLARE_API_TOKEN` / `CF_SCOPED_TOKEN`, and deletes the token at Cloudflare
before it returns. The value is never printed, never logged, never written
anywhere but a 0600 temp file that does not outlive the mint.

Start with `--dry-run` to see the exact plan (permissions, scope, TTL) with zero
network calls, and `--list-profiles` to see what you can ask for.

## The two tools

| tool | what it owns |
|---|---|
| `cf-scoped-run.sh` | the **mint → use → burn** lifecycle, profiles, the burn trap, stale-token sweeping |
| `cf-mint-token.sh` | the credential itself: resolve names to ids, mint, **verify**, store, list, revoke, burn |

`cf-mint-token.sh` is unchanged as an entry point — every existing call site
(`--name/--perm/--zone/--zone-id/--ttl/--value-file/--vault-secret/--list/--revoke/--burn/--dry-run`)
works exactly as before. `cf-scoped-run.sh` is a wrapper over it, not a
replacement: everything credential-shaped still happens in the mint tool.

## cf-scoped-run.sh flags

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
| `--perm <Name:Level>` | ad-hoc permission instead of a profile, repeatable (e.g. `--perm DNS:Edit`) |
| `--dry-run` | print exactly what would be minted and run; no network calls, nothing created |
| `--list-profiles` | print the profiles and their reach |
| `--list-stale` | list `cfsr-*` tokens past the TTL their own name declares — i.e. runs whose burn failed. Exit 1 if any |
| `--burn-stale` | revoke exactly those. Tokens not named `cfsr-*` are never touched |

Exit code: the wrapped command's own — except **1** when the mint failed (the
command never ran) or when the burn failed after a green command. A run that
leaked a live credential is not a green run.

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
./cf-scoped-run.sh --minter-cmd 'op read op://Infra/cf-minter/credential' \
  --profile dns-edit --zone example.com -- ./publish-records.sh

# HashiCorp Vault
./cf-scoped-run.sh --minter-cmd 'vault kv get -field=token secret/cloudflare/minter' \
  --profile certs --zone example.com -- ./issue-origin-cert.sh

# AWS Secrets Manager
./cf-scoped-run.sh --minter-cmd 'aws secretsmanager get-secret-value --secret-id cf-minter --query SecretString --output text' \
  --profile pages-deploy -- npx wrangler pages deploy ./dist

# Azure Key Vault
./cf-scoped-run.sh --minter-cmd 'az keyvault secret show --vault-name my-vault --name cf-minter-token --query value -o tsv' \
  --profile zone-settings --zone example.com -- ./flip-tls-setting.sh
```

If the fetch command fails, the run fails and says so with the command's own
error — it is never treated as "no token configured".

### Is this credential actually a minter?

Ask by measurement, never by what it is named:

```bash
CF_MINTER_TOKEN=… ./cf-mint-token.sh --qualify-minter
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
./cf-scoped-run.sh --list-stale     # exit 1 if any run's burn failed
./cf-scoped-run.sh --burn-stale     # revoke exactly those
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
