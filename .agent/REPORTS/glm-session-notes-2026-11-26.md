# Agent notes — cf-minter (session 2026-11-26)

Nothing in this repo changed. It was used from `~/Projects/cf-minter` to mint
the scheduler's CI credential:

- Token **`scheduler-ci`**, minted with `cf-mint-token.sh --ttl 365d --slug`-style
  ad-hoc perms (`--perm 'Workers Scripts:Edit' --perm 'D1:Edit' --perm 'Account
  Settings:Read' --perm 'Workers Routes:Edit' --perm 'Zone:Read' --perm 'DNS:Edit'
  --zone stephenredding.com`), output via `--value-file … --no-print-value` and
  piped straight into `gh secret set CLOUDFLARE_API_TOKEN` on
  `satorisage/scheduler`. Expires ~2027-11-26; the renew command lives in the
  scheduler README → Deploy. The minter credential came through a one-time card
  and was not stored.
- If this pattern recurs, a `scheduler-deploy` profile would be the one edit to
  `profiles.conf` (mixed account+zone perms were done ad hoc; `--dry-run`
  accepted them).
- `./cf-minter doctor` from a non-interactive shell reports no minter
  configured — the owner supplies it per run.
