# cf-minter

Mint **scope-exact Cloudflare API tokens** declaratively — named permissions +
named zones on the command line instead of clicking through the Cloudflare
dashboard. Born in worksync's `infra/` (where it was built alongside the fleet
hardening scripts), formalized here as its own project so every project can
mint its deploy credentials the same way.

## What it does

- **Mint**: resolve human permission names (`DNS:Edit`, `Pages:Edit`, …) to Cloudflare permission-group UUIDs, resolve zone names to
  zone ids, split zone- vs account-scoped permissions into the right policies,
  `POST /user/tokens`, then **verify the minted token actually authenticates**
  (as itself, retried through Cloudflare's ~2-minute propagation window)
  before printing it once or storing it anywhere. An unverified value can
  never replace a working credential.
- **List**: `--list` shows existing tokens (id · status · name) so you don't
  mint duplicates — every mint creates a *new* token; there is no upsert.
- **Revoke / burn**: `--revoke <id>` deletes by id; `--burn` deletes by value
  (from `CF_BURN_TOKEN`, env-only) — the full lifecycle for ephemeral tokens.
- **Dry-run**: `--dry-run` prints the exact policy JSON and API calls it
  *would* make, with zero network calls. No token value ever appears in
  dry-run output, so it's safe to paste into runbooks.

## The minter credential

Creating (and deleting) tokens is itself privileged: you need a credential
carrying **User API Tokens:Edit** for the target account. It is read from
`CF_MINTER_TOKEN` (env only — never an argument, never printed), or from an
Azure Key Vault when `CF_MINTER_VAULT_SECRET` + `OPS_VAULT_NAME` are set.
Multi-account users: pin the account with `CF_ACCOUNT_ID`.

## Usage

```bash
# See what exists (avoid duplicates):
CF_MINTER_TOKEN=… ./cf-mint-token.sh --list

# Preview a mint (no network calls):
CF_MINTER_TOKEN=… ./cf-mint-token.sh --dry-run \
  --name my-project-deploy --perm "Pages:Edit" --perm "Pages:Read"

# Mint a Pages deploy token (account-scoped, no zones needed):
CF_MINTER_TOKEN=… CF_ACCOUNT_ID=… ./cf-mint-token.sh \
  --name my-project-deploy --perm "Pages:Edit" --perm "Pages:Read"

# Mint a DNS token scoped to exactly two zones:
CF_MINTER_TOKEN=… ./cf-mint-token.sh \
  --name dns-updater --perm DNS:Edit --zone example.com --zone example.org

# Rotate: mint the new one first, then revoke the old by id (see --list),
# or burn it by value:
CF_MINTER_TOKEN=… CF_BURN_TOKEN=… ./cf-mint-token.sh --burn
```

Exit codes: `0` success · `1` a step failed (API/curl/vault) · `2` usage or
precondition.

## Layout

- `cf-mint-token.sh` — the tool (mint / list / revoke / burn / dry-run).
- `lib/cf-retry.sh` — retries only Cloudflare's token-propagation transient
  (401 / error code 10000); real permission errors fail immediately.
- `test/cf-mint-token.test.sh` — hermetic tests (curl/az are PATH stubs):
  argument guards + the verify-before-store gate. Run: `bash test/cf-mint-token.test.sh`.

## Requirements

`curl`, `jq` (always); `az` CLI only when using the optional Key Vault
integration (`--vault-secret` / vault-held minter).
