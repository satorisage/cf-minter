#!/usr/bin/env bash
#
# cf-mint-token.sh — mint a scope-exact Cloudflare API token over the CF API, so
# tokens are created declaratively (named permissions + named zones) instead of
# by clicking through the Cloudflare dashboard.
#
# This is the SIBLING of cf-harden.sh (which drives the CF zone/edge hardening)
# and cloudflare-origin-cert.sh (the Azure-origin side of the same migration).
# Same operator ergonomics: colored pass/fail/warn/info helpers, set -uo pipefail,
# a --dry-run that resolves the plan and prints the exact call it WOULD send, and
# the same exit-code contract (0 ok / 1 a step failed / 2 usage-or-precondition).
#
# THE MINTER CREDENTIAL:
#   Creating a token is itself a privileged operation — a normal scoped token
#   cannot do it. You need a credential that carries "User API Tokens:Edit". That
#   minter credential is read from the environment (CF_MINTER_TOKEN), or fetched
#   from the ops vault when CF_MINTER_VAULT_SECRET + OPS_VAULT_NAME are set. Its
#   canonical vault home is `cf-minter-token`: a DASHBOARD-created token with
#   user-scope "API Tokens: Edit". Minter status is a MEASURED property, never a
#   label — a credential qualifies iff GET /user/tokens/permission_groups returns
#   200 (measured 2026-07-26: no other vaulted Cloudflare token passes that probe;
#   the operator token verifies active but cannot mint). It is
#   NEVER a command-line argument (argv is visible in `ps`) and is NEVER printed:
#   it lives only in the Authorization: Bearer header built inside cf(). So
#   --dry-run output is always safe to paste into a runbook or a log.
#
# WHAT IT DOES (mint mode):
#   1. Resolve each requested permission by NAME -> its permission-group UUID,
#      via GET /user/tokens/permission_groups. You name permissions in human
#      terms (DNS:Edit, Zone Settings:Edit, SSL and Certificates:Edit,
#      Firewall Services:Edit, DNSSEC:Edit, User API Tokens:Edit). Edit maps to
#      the group's "Write" variant, Read to its "Read" variant.
#   2. Resolve each --zone <name> -> its zone id, via GET /zones?name=<name>. A
#      caller that already HOLDS the zone id (automation reading it from its own
#      config, where the id — not the name — is the authoritative value) passes
#      --zone-id <id> instead and skips the lookup: the token is then scoped to
#      exactly the zone the caller's other tooling writes to, with no name-to-id
#      derivation in between that could aim it at a different zone.
#   3. Split the requested permissions by scope: zone-scoped groups go in a
#      policy whose resources are the requested zones; account-scoped groups
#      (e.g. User API Tokens) go in a policy whose resource is the account
#      (account id from GET /accounts). A token can carry both policies at once.
#   4. POST /user/tokens to create the token.
#   5. VERIFY the minted token actually authenticates — GET /user/tokens/verify
#      called AS the new token (not the minter), riding lib/cf-retry.sh through
#      Cloudflare's ~2-minute token-propagation window. A mint once produced a
#      value that did not authenticate and it silently replaced the standing
#      deploy credential in the vault; verification is now a hard gate: if the
#      token does not verify, NOTHING is stored and the exit code is 1.
#   6. Only after verify passes: print the new token value ONCE, boxed, with a
#      "store it now — it cannot be retrieved again" warning, plus the token id.
#      --no-print-value suppresses that box for an UNATTENDED caller, whose
#      console output is a run log: a value printed there outlives the run in
#      whatever captured it. It requires --vault-secret, because the vault is
#      then the only place the value lands and a token created with nowhere to
#      go would be created and lost in the same breath. A --value-file also
#      satisfies it: the file is then where the value lands.
#   6b. Optionally, with --ttl <duration>, the token is minted with an expiry
#      (expires_on, computed here as now + duration, UTC): Cloudflare refuses the
#      token past that moment even if nobody ever burns it. This is the floor
#      under the mint-use-burn pattern — the burn is still the cleanup, the
#      expiry is what bounds the damage when the burn never runs. And with
#      --value-file <path>, the minted value is ALSO written (after the verify
#      gate, mode 0600) to that file, for a wrapping tool that must hold the
#      value programmatically without parsing the printed box.
#   7. Optionally, with --vault-secret <name>, also store the minted token into a
#      vault in the same step (value never printed). The vault write happens
#      strictly AFTER the verify gate, so an existing working secret can never be
#      overwritten by an unverified value.
#
#      WHICH vault it is written to is a separate question from where the MINTER
#      was read: --vault-name picks the write target, defaulting to OPS_VAULT_NAME.
#      A fleet-shared credential (e.g. cf-deploy-token) is written back to the ops
#      vault, so the default is right for it. A credential minted PER INSTANCE and
#      named per instance belongs in the per-instance credential vault instead, and
#      the caller names it: --vault-name "$INSTANCE_CREDS_VAULT_NAME". The minter is
#      always read from the ops vault either way — it is fleet-shared.
#
# WHAT IT DOES (revoke / burn mode):
#   The full token lifecycle — mint, use, delete — lives in this one tool, so an
#   ephemeral token (mint it, run cf-harden.sh with it, then delete it) never
#   lingers past the job it was made for. Deleting a token uses the SAME minter
#   credential as minting (User API Tokens:Edit is required to delete tokens too).
#   Two ways to delete:
#     --revoke <token-id>   DELETE /user/tokens/<id>, where <id> is what --list
#                           shows. Use it when you already know the id.
#     --burn                delete a token by its VALUE, read from CF_BURN_TOKEN
#                           (an env var, never an argument). The script first
#                           self-identifies the token's own id by calling
#                           GET /user/tokens/verify WITH that token (the response's
#                           .result.id is the token's own id), then deletes it by
#                           that id with the minter. This lets the operator burn
#                           the ephemeral hardening token they just used without
#                           hunting for its id. If verify fails (the token is
#                           already expired / revoked / invalid), it is reported
#                           as already-gone, not as an error.
#
# NOT AN UPSERT. Every mint creates a brand-new token — there is no
# "create-or-update". Re-running mints a DUPLICATE. Use --list to see what
# already exists before minting. Rotation is therefore a two-step story with the
# tools here: mint a fresh token, then --revoke (or --burn) the old one once the
# new one is in place — there is no in-place PUT/edit of a token's policy.
#
# Exit: 0 success   1 a step failed (API/curl/vault error)   2 usage / precondition.
#
# Tools: curl, jq (always); az CLI (only when --vault-secret is used on a real run).

set -uo pipefail

if [[ -t 1 ]]; then R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; Z=$'\033[0m'
else R=''; G=''; Y=''; B=''; Z=''; fi
pass(){ printf '  %sok%s    %s\n' "$G" "$Z" "$1"; }
fail(){ printf '  %sFAIL%s  %s\n' "$R" "$Z" "$1" >&2; }
warn(){ printf '  %swarn%s  %s\n' "$Y" "$Z" "$1"; }
info(){ printf '  %sinfo%s  %s\n' "$B" "$Z" "$1"; }
hdr(){  printf '\n%s== %s ==%s\n' "$B" "$1" "$Z"; }
die(){  fail "$1"; exit "${2:-2}"; }

# need_arg <flag> <candidate>: a value-taking flag must be followed by a real
# value — non-empty and not another flag. Without this check a bare flag would
# swallow whatever comes next as its value (catastrophic on --revoke, a delete
# path: `--revoke --dry-run` would run a LIVE delete against the id "--dry-run"),
# and a flag left bare at the very end of argv would loop the parser forever
# (`shift 2` cannot shift past the end of the argument list). Usage error, exit 2.
need_arg(){
  [[ $# -ge 2 && -n "${2:-}" && "${2:-}" != -* ]] \
    || die "$1 requires a value (got '${2:-}')"
}

NAME=""; VAULT_SECRET=""; VAULT_NAME=""; MODE="mint"; REVOKE_ID=""
PERMS=(); ZONES=(); ZONE_IDS=()
PRINT_VALUE=1
TTL=""; TTL_SECONDS=""; VALUE_FILE=""
DRY_RUN="${DRY_RUN:-0}"

usage(){
  cat >&2 <<'EOF'
cf-mint-token.sh — mint a scope-exact Cloudflare API token over the CF API.
Sibling of cf-harden.sh. Names permissions + zones in human terms and resolves
them to the UUIDs Cloudflare's token API wants. Every mint creates a NEW token
(not an upsert) — use --list to avoid duplicates before minting.

  --name <token-name>     name for the new token (required to mint).
  --perm <Name:Level>     permission to grant, repeatable. Level is Edit, Read, or
                          Purge (the Cache Purge group's only level).
                          e.g. --perm DNS:Edit --perm "Zone Settings:Edit"
                          Append @account or @zone when a name exists at both
                          scopes (Cloudflare publishes some groups twice under
                          one name) — e.g.
                            --perm "Access: Apps and Policies:Edit@account"
                          Optional: names that are unique need no hint, and an
                          ambiguous one tells you the exact flag to add.
  --zone <zonename>       zone to scope zone-permissions to, repeatable.
                          e.g. --zone example.com --zone example.org
                          Omit -> the token is account-scoped only (no zone perms).
  --zone-id <zoneid>      same, but by zone ID — no name lookup. Repeatable, and
                          mixable with --zone. For a caller that already holds the
                          id as its authoritative value (so the token is scoped to
                          exactly the zone that caller writes to).
  --ttl <duration>        mint the token with an expiry: expires_on = now + this
                          duration (UTC). Duration is <n>s / <n>m / <n>h / <n>d,
                          or a bare number of seconds. Cloudflare refuses the
                          token past that moment even if nobody burns it — the
                          floor under an ephemeral mint-use-burn token.
  --value-file <path>     also write the minted value to this file (created mode
                          0600), strictly AFTER the verify gate — for a wrapping
                          tool that must hold the value programmatically instead
                          of parsing the printed box. Counts as a place for the
                          value to land, so it satisfies --no-print-value.
  --no-print-value        do NOT print the minted value box (requires
                          --vault-secret or --value-file: that store becomes the
                          only copy). For unattended callers whose stdout is a
                          run log.
  --vault-secret <name>   also store the minted token into a vault under this
                          secret name. Value never printed; the vault becomes the
                          source of truth. The write happens only AFTER the minted
                          token verifies against Cloudflare — an unverified value
                          can never replace an existing secret.
  --vault-name <vault>    which vault --vault-secret writes to. Default:
                          OPS_VAULT_NAME (right for a fleet-shared credential). A
                          credential minted and named PER INSTANCE goes to the
                          per-instance credential vault instead — pass its name
                          here. Independent of where the MINTER is read from,
                          which is always the ops vault.
  --minter-cmd <cmd>      shell command that PRINTS the minter token on stdout —
                          how you wire your own secret store (also CF_MINTER_CMD).
  --minter-token-file <p> read the minter token from this file's first line.
  --qualify-minter        measure whether the supplied credential can actually
                          mint (GET /user/tokens/permission_groups must succeed),
                          and print the verdict. Mints nothing.
  --list                  list existing tokens (id + status + name, no values)
                          instead of minting. Ignores --name/--perm/--zone.
                          Pass an id shown here to --revoke to delete that token.
  --revoke <token-id>     delete (revoke) the token with this id via
                          DELETE /user/tokens/<id>, using the minter. The id is
                          what --list shows. Ignores --name/--perm/--zone.
  --burn                  delete a token by its VALUE, read from CF_BURN_TOKEN
                          (env only, never an argument). Self-identifies the
                          token's own id via GET /user/tokens/verify with that
                          token, then deletes it with the minter. Lets you burn
                          the ephemeral token you just used without its id. If
                          the token is already gone, that is reported, not an error.
  --dry-run               resolve the plan and print the exact call(s) it WOULD
                          make, running NO network calls and changing nothing.
                          Works for mint, --revoke and --burn. No token (minter
                          or burn) is ever printed.
  -h, --help              this help.

Minter credential (required, exit 2 if absent — for mint, --revoke and --burn):
resolved in this precedence: CF_MINTER_TOKEN (env) -> --minter-cmd/CF_MINTER_CMD
(a command that prints it) -> --minter-token-file -> CF_MINTER_VAULT_SECRET +
OPS_VAULT_NAME (the optional Azure Key Vault path). Never an argument. It needs "User API Tokens:Edit" (a normal scoped token
cannot create OR delete tokens). Never passed as an argument; never printed.

Env:
  CF_MINTER_TOKEN         the minter credential (User API Tokens:Edit). Used to
                          mint AND to delete (--revoke / --burn).
  CF_MINTER_CMD           shell command printing the minter token (same as
                          --minter-cmd) — the pluggable secret-store hook.
  CF_MINTER_VAULT_SECRET  vault secret name to read the minter from (with
                          OPS_VAULT_NAME) if CF_MINTER_TOKEN is unset.
  CF_BURN_TOKEN           (--burn only) the VALUE of the token to delete. Read
                          from the environment only — never an argument, never
                          printed; it lives only in a Bearer header for the
                          self-verify call.
  OPS_VAULT_NAME          the ops vault: where the minter is read from, and the
                          default --vault-name write target.
  CF_ACCOUNT_ID           pin the account id (skips GET /accounts; used when the
                          minter can see more than one account).

Examples:
  # See what already exists before minting (avoid duplicates):
  CF_MINTER_TOKEN=… ./cf-mint-token.sh --list

  # Preview the exact policy + POST without creating anything:
  CF_MINTER_TOKEN=… ./cf-mint-token.sh --dry-run \
      --name deploy-token --perm DNS:Edit \
      --zone example.com --zone example.org --vault-secret cf-deploy-token

  # Mint for real and stash it in the ops vault in one step:
  CF_MINTER_TOKEN=… OPS_VAULT_NAME=my-vault ./cf-mint-token.sh \
      --name deploy-token --perm DNS:Edit --perm "SSL and Certificates:Edit" \
      --zone example.com --zone example.org --vault-secret cf-deploy-token

  # Delete a token by id (get the id from --list):
  CF_MINTER_TOKEN=… ./cf-mint-token.sh --revoke 0123456789abcdef0123456789abcdef

  # Burn the ephemeral token you just used, by its value (no id hunting):
  CF_MINTER_TOKEN=… CF_BURN_TOKEN=… ./cf-mint-token.sh --burn
EOF
  exit "${1:-2}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)          need_arg "$1" "${2:-}"; NAME="$2"; shift 2 ;;
    --perm)          need_arg "$1" "${2:-}"; PERMS+=("$2"); shift 2 ;;
    --zone)          need_arg "$1" "${2:-}"; ZONES+=("$2"); shift 2 ;;
    --zone-id)       need_arg "$1" "${2:-}"; ZONE_IDS+=("$2"); shift 2 ;;
    --ttl)           need_arg "$1" "${2:-}"; TTL="$2"; shift 2 ;;
    --value-file)    need_arg "$1" "${2:-}"; VALUE_FILE="$2"; shift 2 ;;
    --no-print-value) PRINT_VALUE=0; shift ;;
    --minter-cmd)    need_arg "$1" "${2:-}"; CF_MINTER_CMD="$2"; shift 2 ;;
    --minter-token-file) need_arg "$1" "${2:-}"; CF_MINTER_TOKEN_FILE="$2"; shift 2 ;;
    --minter-token)  die "--minter-token is refused on purpose: argv is world-readable in \`ps\`, so a token passed there leaks to every process on the host. Supply it as CF_MINTER_TOKEN in the environment, as --minter-token-file <path> (mode 0600), or as --minter-cmd '<command that prints it>'." ;;
    --vault-secret)  need_arg "$1" "${2:-}"; VAULT_SECRET="$2"; shift 2 ;;
    --vault-name)    need_arg "$1" "${2:-}"; VAULT_NAME="$2"; shift 2 ;;
    --qualify-minter) MODE="qualify"; shift ;;
    --list)          MODE="list"; shift ;;
    --revoke)        need_arg "$1" "${2:-}"; MODE="revoke"; REVOKE_ID="$2"; shift 2 ;;
    --burn)          MODE="burn"; shift ;;
    --dry-run)       DRY_RUN=1; shift ;;
    -h|--help)       usage 0 ;;
    *)               die "unknown flag: $1 — run cf-mint-token.sh --help for this tool's flags, or cf-minter help for the friendlier surface over it." ;;
  esac
done

# ── the minter credential ─────────────────────────────────────────────────────
# Resolve it into CF_MINTER_TOKEN (from env, or the ops vault). It is required in
# every mode — even --dry-run and --list — so the missing-minter failure is caught
# the same way regardless. It is never echoed anywhere below this block.
if [[ -z "${CF_MINTER_TOKEN:-}" && -n "${CF_MINTER_CMD:-}" ]]; then
  # The pluggable fetch: any command that PRINTS the token on stdout. This is how
  # a project wires its own secret store without this tool knowing anything about
  # it. Its stderr is left attached so a failing fetch says why, in its own words.
  CF_MINTER_TOKEN="$(eval "$CF_MINTER_CMD")" \
    || die "the minter fetch command failed (its error is above): $CF_MINTER_CMD" 1
  CF_MINTER_TOKEN="${CF_MINTER_TOKEN%%$'\n'*}"
  [[ -n "$CF_MINTER_TOKEN" ]] \
    || die "the minter fetch command succeeded but printed nothing: $CF_MINTER_CMD" 1
fi
if [[ -z "${CF_MINTER_TOKEN:-}" && -n "${CF_MINTER_TOKEN_FILE:-}" ]]; then
  [[ -r "$CF_MINTER_TOKEN_FILE" ]] \
    || die "minter token file not readable: $CF_MINTER_TOKEN_FILE"
  CF_MINTER_TOKEN="$(head -n1 "$CF_MINTER_TOKEN_FILE")"
  [[ -n "$CF_MINTER_TOKEN" ]] || die "minter token file is empty: $CF_MINTER_TOKEN_FILE"
fi
if [[ -z "${CF_MINTER_TOKEN:-}" ]]; then
  if [[ -n "${CF_MINTER_VAULT_SECRET:-}" && -n "${OPS_VAULT_NAME:-}" ]]; then
    command -v az >/dev/null 2>&1 || die "az CLI not found (needed to read the minter from the vault)"
    CF_MINTER_TOKEN="$(az keyvault secret show --vault-name "$OPS_VAULT_NAME" \
      --name "$CF_MINTER_VAULT_SECRET" --query value -o tsv 2>/dev/null || true)"
    [[ -n "$CF_MINTER_TOKEN" ]] || die "could not read minter secret '$CF_MINTER_VAULT_SECRET' from vault '$OPS_VAULT_NAME'"
  fi
fi
# A dry run mints nothing, so it needs no minter — and refusing here would break
# the one command a newcomer is told to run first, leaving them with a plan that
# silently omits its permissions. Say what they will need, then show the plan.
# Same shape as the curl precondition below: preconditions of the REAL path are
# required on the real path only. The live mint still refuses, unchanged.
if [[ -z "${CF_MINTER_TOKEN:-}" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "no minter credential is configured — this preview does not need one, but a real run does. Set CF_MINTER_TOKEN, or pass --minter-cmd '<command that prints it>'."
  else
    die "no minter credential — a credential carrying \"User API Tokens:Edit\" is required to create OR delete tokens. Supply exactly one of, in this precedence: CF_MINTER_TOKEN=<value> in the environment; --minter-cmd '<command that prints the token>' (or CF_MINTER_CMD) to pull it from your own secret store; --minter-token-file <path>; or CF_MINTER_VAULT_SECRET + OPS_VAULT_NAME for the optional Azure Key Vault path."
  fi
fi

# ── common preconditions ──────────────────────────────────────────────────────
command -v jq >/dev/null 2>&1 || die "jq not found — required to parse the Cloudflare API's responses. Install it (brew install jq / apt install jq), then re-run; cf-minter doctor checks for it."
if [[ "$DRY_RUN" -ne 1 ]]; then
  command -v curl >/dev/null 2>&1 || die "curl not found — required to reach the Cloudflare API. Install it, then re-run; cf-minter doctor checks for it."
fi

# Cloudflare's auth edge is eventually-consistent: a just-minted token can be
# rejected with a transient 401 (error code 10000) by some edge nodes for up to
# ~2 minutes. The post-mint verification below rides this retry wrapper so a
# valid-but-still-propagating token is retried instead of failing the verify
# gate on the first 401. Sourcing only defines functions (no side effects), and
# --dry-run never reaches a live call.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/lib/cf-retry.sh"

# cf(): the CF API curl helper. On --dry-run it prints the METHOD + PATH + BODY it
# would send and runs nothing — the Bearer token lives only in the header, which is
# never printed, so dry-run output is always safe to paste. On a real run it emits
# the raw JSON response on stdout for the caller to parse. Callers must NOT capture
# cf under --dry-run (stdout then carries the printed call, not JSON); every capture
# site below is only reached on a real run.
#
# The 4th arg is the Bearer token to authenticate with. It defaults to the minter
# (CF_MINTER_TOKEN) — every existing call site relies on that default. The one
# exception is --burn's self-verify, which passes the burn token so it can identify
# itself. Either way the token is only ever a header, never printed.
cf(){
  # The minter default is written ${CF_MINTER_TOKEN:-} rather than
  # $CF_MINTER_TOKEN because a dry run never authenticates and is allowed to run
  # without a minter at all; under `set -u` the bare form would abort here on a
  # value this branch does not use. On a real run the variable is guaranteed set
  # — the refusal above sees to that — so the resolved bearer is unchanged.
  local method="$1" path="$2" body="${3:-}" bearer="${4:-${CF_MINTER_TOKEN:-}}"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -n "$body" ]]; then
      printf '  %s+%s %s %s %s\n' "$B" "$Z" "$method" "$path" "$body"
    else
      printf '  %s+%s %s %s\n' "$B" "$Z" "$method" "$path"
    fi
    return 0
  fi
  # -sS (not -fsS): on a 4xx/5xx Cloudflare's JSON error body IS the diagnosis —
  # -f would discard it and leave cf_ok able to say only "request failed".
  # cf_ok checks .success on every response, so HTTP errors still fail hard.
  local args=(-sS -X "$method" "https://api.cloudflare.com/client/v4/$path"
              -H "Authorization: Bearer $bearer" -H "Content-Type: application/json")
  [[ -n "$body" ]] && args+=(--data "$body")
  curl "${args[@]}"
}

# cf_ok(): run a real CF call and fail hard if the API reports success=false. CF
# returns HTTP 200 with {"success":false,"errors":[…]} for some errors, which
# curl -f does not catch — so we check the body too. Echoes the JSON on success.
cf_ok(){
  local what="$1"; shift
  local resp
  resp="$(cf "$@")" || die "$what — request failed" 1
  if [[ "$(jq -r '.success // false' <<<"$resp" 2>/dev/null)" != "true" ]]; then
    fail "$what — Cloudflare returned an error:"
    jq -r '.errors[]? | "    [\(.code)] \(.message)"' <<<"$resp" >&2 2>/dev/null || printf '%s\n' "$resp" >&2
    exit 1
  fi
  printf '%s' "$resp"
}

# verify_minted_token TOKEN: prove a just-minted token actually authenticates by
# calling GET /user/tokens/verify AS that token (not the minter — the minter
# verifying itself would prove nothing about the new value). Routed through
# cf_call_with_retry so the token-propagation transient (401 / code 10000) is
# retried, while a genuinely invalid token (code 1000) fails immediately. Uses
# -sS (not -fsS) so the error body survives a 4xx and can be shown. Returns 0
# only when Cloudflare reports success + an active status; prints the Cloudflare
# error and returns 1 otherwise. The token lives only in the Bearer header.
verify_minted_token(){
  local token="$1" vresp
  local args=(-sS -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify"
              -H "Authorization: Bearer $token" -H "Content-Type: application/json")
  vresp="$(cf_call_with_retry "${args[@]}")" || vresp=""
  if [[ "$(jq -r '.success // false' <<<"$vresp" 2>/dev/null)" == "true" && \
        "$(jq -r '.result.status // empty' <<<"$vresp" 2>/dev/null)" == "active" ]]; then
    return 0
  fi
  fail "the minted token did NOT verify against Cloudflare:"
  if [[ -n "$vresp" ]]; then
    jq -r '.errors[]? | "    [\(.code)] \(.message)"' <<<"$vresp" >&2 2>/dev/null \
      || printf '    %s\n' "$vresp" >&2
  else
    printf '    (no response from the verify endpoint)\n' >&2
  fi
  return 1
}

# lc(): lowercase a string. Portable (works on the bash 3.2 that ships with macOS,
# which lacks the ${var,,} expansion), matching the reference scripts' posture.
lc(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ── token expiry (--ttl) ──────────────────────────────────────────────────────
# ttl_to_seconds: "<n>", "<n>s", "<n>m", "<n>h", "<n>d" -> seconds. Anything else
# is a usage error caught before any network call. Zero is refused too — a token
# born expired is a mint that can only fail its own verify gate.
ttl_to_seconds(){
  local spec="$1" n unit
  [[ "$spec" =~ ^([0-9]+)([smhd]?)$ ]] || return 1
  n="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]}"
  [[ "$n" -gt 0 ]] || return 1
  case "$unit" in
    ''|s) printf '%s' "$n" ;;
    m)    printf '%s' "$((n * 60))" ;;
    h)    printf '%s' "$((n * 3600))" ;;
    d)    printf '%s' "$((n * 86400))" ;;
  esac
}

# epoch_to_rfc3339: format an epoch as the UTC RFC3339 instant Cloudflare's
# expires_on field takes. BSD date (macOS) reads the epoch with -r; GNU date
# with -d @ — try both so the tool runs on either.
epoch_to_rfc3339(){
  date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ
}

# ── permission-level normalisation ────────────────────────────────────────────
# Operators name a permission as "Name:Level". Edit (the human word) maps to the
# permission group's "Write" variant; Read maps to "Read". "Write" is accepted as
# an alias for Edit. Anything else is a usage error caught up front (no network).
level_suffix(){
  case "$(lc "$1")" in
    edit|write) printf 'Write' ;;
    read)       printf 'Read' ;;
    purge)      printf 'Purge' ;;   # Cloudflare's "Cache Purge" group has no Write/Read form
    *)          return 1 ;;
  esac
}

# account_scoped_hint(): DRY-RUN-ONLY heuristic to preview whether a permission
# lands in the zone policy or the account policy. On a REAL run this is never used
# — the split is driven by the permission group's actual `scopes` field returned
# by the API (the source of truth). It exists only so --dry-run can render a
# realistic skeleton without a network lookup.
account_scoped_hint(){
  case "$(lc "$1")" in
    "user api tokens"|"api tokens"|"account api tokens"|"account settings"|\
    "account rulesets"|"account waf"|"memberships"|"billing") return 0 ;;
    *) return 1 ;;
  esac
}

# Split a "Name:Level" spec into its base name and level; validate the level.
# Sets PERM_BASE / PERM_LEVEL / PERM_SUFFIX. Dies (exit 2) on a malformed spec —
# this is the offline "unknown perm" precondition (before any API call).
# split_perm SPEC: parse "Name:Level" or "Name:Level@scope" into PERM_BASE,
# PERM_LEVEL, PERM_SUFFIX and PERM_SCOPE (empty when no hint was given).
#
# The @scope hint exists because Cloudflare publishes some permission groups
# TWICE under one name, differing only in scope — "Access: Apps and Policies
# Write" is both account- and zone-scoped, as are "Logs Read/Write" and
# "Disable ESC Read/Write". Resolving by name alone cannot tell those apart, so
# without a hint the only honest thing is to refuse. The hint says which one you
# meant; it stays optional because most names are unique and requiring it
# everywhere would be noise.
split_perm(){
  local spec="$1"
  PERM_SCOPE=""
  # Strip the scope hint first: the permission name itself may contain ':' and
  # ' ', but never '@', so this split is unambiguous whichever comes first.
  if [[ "$spec" == *@* ]]; then
    PERM_SCOPE="$(lc "${spec##*@}")"
    spec="${spec%@*}"
    case "$PERM_SCOPE" in
      account|zone) ;;
      *) die "unknown scope '@$PERM_SCOPE' in '$1' — want @account or @zone" ;;
    esac
  fi
  [[ "$spec" == *:* ]] || die "malformed --perm '$spec' — want Name:Level (e.g. DNS:Edit)"
  PERM_BASE="${spec%:*}"; PERM_LEVEL="${spec##*:}"
  [[ -n "$PERM_BASE" ]] || die "malformed --perm '$spec' — empty permission name"
  PERM_SUFFIX="$(level_suffix "$PERM_LEVEL")" \
    || die "unknown permission level '$PERM_LEVEL' in '$spec' — want Edit, Read or Purge"
}

# scope_of GROUP_JSON: "zone" or "account", from the group's own scopes field
# (the source of truth). A scope naming ".zone" is zone-scoped; anything else is
# account-scoped. One definition, used by both the filter and the classifier, so
# they cannot drift apart.
scope_of(){
  case "$(jq -r '.scopes // [] | join(",")' <<<"$1")" in
    *zone*) printf 'zone' ;;
    *)      printf 'account' ;;
  esac
}

# ── LIST mode ─────────────────────────────────────────────────────────────────
list_tokens(){
  hdr "existing API tokens (id · status · name — no values are retrievable)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    cf GET "user/tokens"
    info "would print each token's id, status, and name (never a value — CF does not return them)"
    return 0
  fi
  local resp
  resp="$(cf_ok "list tokens" GET "user/tokens")"
  local n; n="$(jq -r '.result | length' <<<"$resp")"
  if [[ "$n" -eq 0 ]]; then
    info "no tokens exist for this account/user"
    return 0
  fi
  # Lead each row with the id — it is what --revoke takes — then status, then name.
  printf '  %-34s %-9s %s\n' "ID" "STATUS" "NAME"
  jq -r '.result[] | "  \(.id)  \(.status)\t\(.name)"' <<<"$resp"
  info "$n token(s). Values are shown only once at creation and cannot be listed."
  info "to delete one: --revoke <id> (or --burn to delete by value via CF_BURN_TOKEN)."
}

# ── REVOKE mode (delete by id) ────────────────────────────────────────────────
# DELETE /user/tokens/<id> with the minter. The id is what --list shows. The
# minter guard above already required CF_MINTER_TOKEN (User API Tokens:Edit is
# needed to delete tokens too), so here we only need the id itself.
revoke_token(){
  [[ -n "$REVOKE_ID" ]] || die "--revoke needs a token id (see --list for ids)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    hdr "dry run — revoke token id '$REVOKE_ID' (nothing is deleted, no network calls)"
    info "would delete this token by id, using the minter (in the header, never shown):"
    cf DELETE "user/tokens/$REVOKE_ID"
    hdr "dry run complete — no token was deleted"
    return 0
  fi

  hdr "revoke token id '$REVOKE_ID'"
  # cf_ok runs inside a command substitution here, so its exit only ends the
  # subshell — the assignment's status must be checked, or a DELETE Cloudflare
  # refused would fall through to the success line below and report a token
  # deleted that is still standing.
  local resp del_id
  resp="$(cf_ok "revoke token $REVOKE_ID" DELETE "user/tokens/$REVOKE_ID")" || exit 1
  del_id="$(jq -r '.result.id // empty' <<<"$resp")"
  pass "deleted token id ${del_id:-$REVOKE_ID}"
}

# ── BURN mode (delete by value) ───────────────────────────────────────────────
# Delete a token when you hold its VALUE but not its id — e.g. the ephemeral token
# you just minted and used for a cf-harden.sh run. The value is read from
# CF_BURN_TOKEN (env only, never argv). We self-identify the token's own id by
# verifying it AGAINST ITSELF: GET /user/tokens/verify authenticated with the burn
# token returns that token's own id in .result.id. Then we DELETE that id with the
# MINTER (deleting is a User API Tokens:Edit operation). If verify fails, the token
# is already gone — report it, don't error.
burn_token(){
  [[ -n "${CF_BURN_TOKEN:-}" ]] \
    || die "--burn needs the token VALUE in CF_BURN_TOKEN (env only, never an argument)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    hdr "dry run — burn a token by value (nothing is deleted, no network calls)"
    info "step 1: self-identify the token's id by verifying it against itself"
    info "        (the burn token authenticates this call — in the header, never shown):"
    cf GET "user/tokens/verify"
    info "        -> read .result.id from that response = the token's own id"
    info "step 2: delete that id with the minter (in the header, never shown):"
    cf DELETE "user/tokens/<id-from-verify>"
    hdr "dry run complete — no token was burned"
    return 0
  fi

  hdr "burn token by value (self-identify its id, then delete)"

  # Step 1: verify the burn token as itself to learn its id. Use cf directly (not
  # cf_ok): a dead/expired/invalid token makes verify fail, and that is a normal
  # "already gone" outcome here, not a hard error.
  local vresp burn_id
  vresp="$(cf GET "user/tokens/verify" "" "$CF_BURN_TOKEN" 2>/dev/null)" || vresp=""
  if [[ -z "$vresp" ]] || [[ "$(jq -r '.success // false' <<<"$vresp" 2>/dev/null)" != "true" ]]; then
    info "the burn token did not verify — it is already gone (expired, revoked, or invalid). Nothing to delete."
    return 0
  fi
  burn_id="$(jq -r '.result.id // empty' <<<"$vresp")"
  if [[ -z "$burn_id" ]]; then
    info "verify returned no token id — treating the burn token as already gone. Nothing to delete."
    return 0
  fi
  pass "self-identified the burn token's id: $burn_id"

  # Step 2: delete it with the MINTER (the burn token cannot be assumed able to
  # delete itself; deletion requires User API Tokens:Edit, which the minter holds).
  # cf_ok runs inside a command substitution, so its exit only ends the subshell —
  # the assignment's status must be checked, or a refused DELETE would report the
  # token burned while it is still live.
  local dresp del_id
  dresp="$(cf_ok "burn token $burn_id" DELETE "user/tokens/$burn_id")" || exit 1
  del_id="$(jq -r '.result.id // empty' <<<"$dresp")"
  pass "burned token id ${del_id:-$burn_id}"
}

# ── MINT mode ─────────────────────────────────────────────────────────────────
mint_token(){
  [[ -n "$NAME" ]] || die "--name is required to mint a token"
  [[ ${#PERMS[@]} -gt 0 ]] || die "at least one --perm is required to mint a token"

  # Validate every perm's FORMAT before any network call (offline precondition).
  local p
  for p in "${PERMS[@]}"; do split_perm "$p"; done

  # Validate the TTL format before any network call (offline precondition). The
  # actual expires_on instant is computed at POST time, not here, so a slow
  # permission-group resolution cannot eat into the requested lifetime.
  if [[ -n "$TTL" ]]; then
    TTL_SECONDS="$(ttl_to_seconds "$TTL")" \
      || die "malformed --ttl '$TTL' — want a positive duration: <n>[s|m|h|d] (e.g. 30m, 1h, 3600)"
  fi

  # Suppressing the value box is only safe when the value has somewhere else to
  # land. Cloudflare shows a token value exactly once; a mint that neither prints
  # nor stores it creates a live credential nobody can ever use or (by value)
  # burn — an orphan by construction. Caught before any network call.
  if [[ "$PRINT_VALUE" -eq 0 && -z "$VAULT_SECRET" && -z "$VALUE_FILE" ]]; then
    die "--no-print-value needs --vault-secret or --value-file: with neither a printed value nor a stored one, the minted token would be created and immediately unrecoverable"
  fi

  # --vault-secret needs a vault to write to: --vault-name, else OPS_VAULT_NAME.
  if [[ -n "$VAULT_SECRET" ]]; then
    [[ -n "$VAULT_NAME" ]] || VAULT_NAME="${OPS_VAULT_NAME:-}"
    [[ -n "$VAULT_NAME" ]] || die "--vault-secret '$VAULT_SECRET' needs a vault to write to: pass --vault-name, or set OPS_VAULT_NAME"
    if [[ "$DRY_RUN" -ne 1 ]]; then
      command -v az >/dev/null 2>&1 || die "az CLI not found (needed for --vault-secret)"
    fi
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then mint_dry_run; else mint_live; fi
}

# mint_dry_run: resolve the plan STRUCTURALLY (no curl). Show which names would be
# looked up and print a valid policy-JSON skeleton with placeholder ids, using the
# account-scoped hint to decide zone-policy vs account-policy placement.
mint_dry_run(){
  hdr "dry run — plan for token '$NAME' (nothing is created, no network calls)"

  # Classify each perm by the dry-run hint into zone vs account permission groups,
  # carrying a readable placeholder id ("<pg-id: DNS Write>").
  local zone_pg='[]' acct_pg='[]' p want
  for p in "${PERMS[@]}"; do
    split_perm "$p"
    want="$PERM_BASE $PERM_SUFFIX"
    if [[ -n "$PERM_SCOPE" ]]; then
      info "would resolve permission: $p  ->  group named '$want', @$PERM_SCOPE"
    else
      info "would resolve permission: $p  ->  permission group named '$want'"
    fi
    local obj
    obj="$(jq -nc --arg id "<pg-id: $want>" --arg n "$want" '{id:$id, name:$n}')"
    # An explicit @scope hint wins over the built-in guess: the caller has told
    # us which one they mean, and the guess exists only to fill that silence.
    if [[ "$PERM_SCOPE" == "zone" ]]; then
      zone_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$zone_pg")"
    elif [[ "$PERM_SCOPE" == "account" ]]; then
      acct_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$acct_pg")"
    elif account_scoped_hint "$PERM_BASE"; then
      acct_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$acct_pg")"
    else
      zone_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$zone_pg")"
    fi
  done

  # Zones -> placeholder zone resources. A --zone-id needs no lookup, so it
  # renders as the real resource key it will send.
  local zone_res='{}' z
  if [[ ${#ZONES[@]} -gt 0 ]]; then
    for z in "${ZONES[@]}"; do
      info "would resolve zone: $z  ->  GET /zones?name=$z  ->  its zone id"
      zone_res="$(jq -c --arg k "com.cloudflare.api.account.zone.<zone-id: $z>" \
        '. + {($k): "*"}' <<<"$zone_res")"
    done
  fi
  if [[ ${#ZONE_IDS[@]} -gt 0 ]]; then
    for z in "${ZONE_IDS[@]}"; do
      info "zone id given directly (no lookup): $z"
      zone_res="$(jq -c --arg k "com.cloudflare.api.account.zone.$z" \
        '. + {($k): "*"}' <<<"$zone_res")"
    done
  fi

  # Account resource (only if any account-scoped perms are requested).
  local acct_res='{}'
  if [[ "$acct_pg" != "[]" ]]; then
    info "would resolve account id: GET /accounts (or CF_ACCOUNT_ID if set)"
    acct_res="$(jq -nc '{"com.cloudflare.api.account.<account-id>": "*"}')"
  fi

  # Guard the same way the live path does: zone-scoped perms need at least one zone.
  if [[ "$zone_pg" != "[]" && ${#ZONES[@]} -eq 0 && ${#ZONE_IDS[@]} -eq 0 ]]; then
    warn "zone-scoped permissions were requested but no --zone was given —"
    warn "the live run would refuse (a zone policy needs at least one zone)."
  fi

  local body expires=""
  if [[ -n "$TTL_SECONDS" ]]; then
    expires="$(epoch_to_rfc3339 "$(( $(date -u +%s) + TTL_SECONDS ))")"
    info "would set an expiry (--ttl $TTL): expires_on ≈ $expires (recomputed at POST time on a real run)"
  fi
  body="$(build_body "$NAME" "$zone_pg" "$zone_res" "$acct_pg" "$acct_res" "$expires")"

  hdr "policy JSON that WOULD be sent"
  jq . <<<"$body"

  hdr "the API call that WOULD be made (minter token is in the header, never shown)"
  cf POST "user/tokens" "$body"

  info "would then VERIFY the minted token authenticates: GET user/tokens/verify"
  info "  authenticated AS the new token (header only, never shown), retried through"
  info "  the token-propagation window. If it does not verify: nothing stored, exit 1."
  if [[ "$PRINT_VALUE" -eq 0 ]]; then
    info "the value box is SUPPRESSED (--no-print-value) — the store(s) below are the only copy"
  fi
  if [[ -n "$VALUE_FILE" ]]; then
    info "only after verify passes: write the value to '$VALUE_FILE' (created mode 0600, value never printed)"
  fi
  if [[ -n "$VAULT_SECRET" ]]; then
    info "only after verify passes: az keyvault secret set --vault-name $VAULT_NAME --name $VAULT_SECRET --value <token> (value never printed)"
  fi
  hdr "dry run complete — no token was created"
}

# build_body: assemble the {name, policies:[…]} request body. Emits a zone policy
# when there are zone-scoped groups and an account policy when there are
# account-scoped groups — either, both, or (degenerate) neither. Shared by the
# dry-run (placeholder ids) and live (real ids) paths so they can never drift.
# The 6th arg is the optional expires_on instant (--ttl); empty omits the field,
# so a mint without a TTL sends exactly the body it always sent.
build_body(){
  local name="$1" zpg="$2" zres="$3" apg="$4" ares="$5" expires="${6:-}"
  local policies='[]'
  if [[ "$zpg" != "[]" ]]; then
    policies="$(jq -c --argjson pg "$zpg" --argjson res "$zres" \
      '. + [{effect:"allow", permission_groups:$pg, resources:$res}]' <<<"$policies")"
  fi
  if [[ "$apg" != "[]" ]]; then
    policies="$(jq -c --argjson pg "$apg" --argjson res "$ares" \
      '. + [{effect:"allow", permission_groups:$pg, resources:$res}]' <<<"$policies")"
  fi
  jq -nc --arg n "$name" --argjson p "$policies" --arg e "$expires" \
    '{name:$n, policies:$p} + (if $e == "" then {} else {expires_on:$e} end)'
}

mint_live(){
  hdr "mint token '$NAME'"

  # 0. Vault-store preflight — prove the vault will take the write BEFORE a live
  #    token exists. The way this has actually failed is a lapsed role activation
  #    on the vault: the mint succeeded, the store was refused, and the live token
  #    was orphaned. A read of the target secret exercises the same auth path
  #    (a lapsed activation refuses reads and writes alike), so it catches that
  #    class here, while there is still nothing to orphan. It is a READ probe, so
  #    a write-only denial can still slip through — which is why the store below
  #    also prints its real error when it fails.
  if [[ -n "$VAULT_SECRET" ]]; then
    local pre_err
    if ! pre_err=$(az keyvault secret show --vault-name "$VAULT_NAME" \
           --name "$VAULT_SECRET" --output none 2>&1); then
      if [[ "$pre_err" == *SecretNotFound* ]]; then
        pass "vault preflight: '$VAULT_NAME' reachable ('$VAULT_SECRET' does not exist yet — the store will create it)"
      else
        fail "vault preflight FAILED for vault '$VAULT_NAME' secret '$VAULT_SECRET' — refusing to mint while the store would fail:"
        fail "  ${pre_err:-<no error output>}"
        die "fix vault access first (activate the vault role / check the vault name) — no token was created" 1
      fi
    else
      pass "vault preflight: '$VAULT_NAME'/'$VAULT_SECRET' readable — the store below will write a new version"
    fi
  fi

  # 1. Fetch the permission-group catalogue once and resolve each requested perm.
  local pg_all
  pg_all="$(cf_ok "fetch permission groups" GET "user/tokens/permission_groups")"

  local zone_pg='[]' acct_pg='[]' p want match n_match pg_id pg_name pg_scope
  for p in "${PERMS[@]}"; do
    split_perm "$p"
    want="$PERM_BASE $PERM_SUFFIX"
    # Exact (case-insensitive) name match first.
    match="$(jq -c --arg n "$want" \
      '[.result[] | select((.name|ascii_downcase) == ($n|ascii_downcase))]' <<<"$pg_all")"
    n_match="$(jq -r 'length' <<<"$match")"
    if [[ "$n_match" -eq 0 ]]; then
      # Fall back to a contains-match on the base + matching level suffix.
      match="$(jq -c --arg b "$PERM_BASE" --arg s "$PERM_SUFFIX" \
        '[.result[] | select((.name|ascii_downcase|endswith(" " + ($s|ascii_downcase))) and (.name|ascii_downcase|contains($b|ascii_downcase)))]' <<<"$pg_all")"
      n_match="$(jq -r 'length' <<<"$match")"
    fi

    # Narrow by the @scope hint when one was given. Applied AFTER matching so a
    # wrong hint reports "no candidate with that scope" rather than silently
    # behaving like no match at all.
    if [[ -n "$PERM_SCOPE" && "$n_match" -gt 0 ]]; then
      local scoped='[]' cand i
      for (( i=0; i<n_match; i++ )); do
        cand="$(jq -c --argjson i "$i" '.[$i]' <<<"$match")"
        [[ "$(scope_of "$cand")" == "$PERM_SCOPE" ]] \
          && scoped="$(jq -c --argjson c "$cand" '. + [$c]' <<<"$scoped")"
      done
      if [[ "$(jq -r 'length' <<<"$scoped")" -eq 0 ]]; then
        fail "--perm '$p': found $n_match group(s) named '$want', but none is @$PERM_SCOPE."
        printf '%s  what that name actually offers:%s\n' "$Y" "$Z" >&2
        jq -r '.[] | "    \(.name)  [\(.scopes // [] | join(", "))]"' <<<"$match" >&2
        exit 1
      fi
      match="$scoped"
      n_match="$(jq -r 'length' <<<"$match")"
    fi

    if [[ "$n_match" -gt 1 ]]; then
      fail "--perm '$p' is ambiguous — $n_match permission groups share the name '$want':"
      jq -r '.[] | "    \(.name)  [\(.scopes // [] | join(", "))]"' <<<"$match" >&2
      printf '%s  Cloudflare publishes some groups under one name at both scopes.%s\n' "$Y" "$Z" >&2
      printf '%s  Say which you mean by appending @account or @zone:%s\n' "$Y" "$Z" >&2
      printf '      --perm "%s:%s@account"\n' "$PERM_BASE" "$PERM_LEVEL" >&2
      printf '      --perm "%s:%s@zone"\n' "$PERM_BASE" "$PERM_LEVEL" >&2
      exit 1
    fi
    if [[ "$n_match" -eq 0 ]]; then
      fail "could not resolve --perm '$p' (looked for '$want') — no such permission group."
      printf '%s  available permission groups (name — scope):%s\n' "$Y" "$Z" >&2
      jq -r '.result | sort_by(.name)[] | "    \(.name)  [\(.scopes // [] | join(", "))]"' <<<"$pg_all" >&2
      exit 1
    fi
    pg_id="$(jq -r '.[0].id' <<<"$match")"
    pg_name="$(jq -r '.[0].name' <<<"$match")"
    # Scope class from the group's own scopes field (the source of truth). A scope
    # that names ".zone" is zone-scoped; anything else is account-scoped.
    pg_scope="$(scope_of "$(jq -c '.[0]' <<<"$match")")"
    local obj; obj="$(jq -nc --arg id "$pg_id" '{id:$id}')"
    if [[ "$pg_scope" == "zone" ]]; then
      zone_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$zone_pg")"
      pass "resolved $p  ->  $pg_name (zone-scoped)"
    else
      acct_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$acct_pg")"
      pass "resolved $p  ->  $pg_name (account-scoped)"
    fi
  done

  # 2. Zone-scoped perms require at least one zone; resolve each zone name -> id.
  #    A --zone-id is already the id and is used as given (no lookup, so nothing
  #    between the caller's authoritative zone and the policy this token carries).
  local zone_res='{}' z zid
  if [[ "$zone_pg" != "[]" ]]; then
    [[ ${#ZONES[@]} -gt 0 || ${#ZONE_IDS[@]} -gt 0 ]] \
      || die "zone-scoped permissions were requested but no --zone/--zone-id was given"
    for z in "${ZONES[@]+"${ZONES[@]}"}"; do
      zid="$(cf_ok "resolve zone $z" GET "zones?name=$z" | jq -r '.result[0].id // empty')"
      [[ -n "$zid" ]] || die "zone '$z' not found (is the minter authorised for it?)" 1
      zone_res="$(jq -c --arg k "com.cloudflare.api.account.zone.$zid" '. + {($k): "*"}' <<<"$zone_res")"
      pass "resolved zone $z  ->  $zid"
    done
    for z in "${ZONE_IDS[@]+"${ZONE_IDS[@]}"}"; do
      zone_res="$(jq -c --arg k "com.cloudflare.api.account.zone.$z" '. + {($k): "*"}' <<<"$zone_res")"
      pass "zone id used as given (no lookup): $z"
    done
  elif [[ ${#ZONES[@]} -gt 0 || ${#ZONE_IDS[@]} -gt 0 ]]; then
    warn "--zone/--zone-id was given but no zone-scoped permissions were requested — zones ignored"
  fi

  # 3. Account resource (only when account-scoped perms are present).
  local acct_res='{}' acct_id
  if [[ "$acct_pg" != "[]" ]]; then
    if [[ -n "${CF_ACCOUNT_ID:-}" ]]; then
      acct_id="$CF_ACCOUNT_ID"
    else
      local acc; acc="$(cf_ok "resolve account" GET "accounts")"
      acct_id="$(jq -r '.result[0].id // empty' <<<"$acc")"
      [[ -n "$acct_id" ]] || die "no account visible to the minter (GET /accounts returned none) — the credential can read tokens but belongs to no account, which an account-scoped permission needs. Check it was created under the right account." 1
      [[ "$(jq -r '.result | length' <<<"$acc")" -eq 1 ]] \
        || warn "minter can see >1 account — using the first ($acct_id); pin with CF_ACCOUNT_ID"
    fi
    acct_res="$(jq -c --arg k "com.cloudflare.api.account.$acct_id" '. + {($k): "*"}' <<<"$acct_res")"
    pass "account-scoped policy targets account $acct_id"
  fi

  # 4. Build and POST the token. The expiry (--ttl) is computed HERE — now + TTL
  #    at the moment of the POST — so the token's lifetime starts when it exists,
  #    not when this process did.
  local body result token token_id expires=""
  if [[ -n "$TTL_SECONDS" ]]; then
    expires="$(epoch_to_rfc3339 "$(( $(date -u +%s) + TTL_SECONDS ))")"
  fi
  body="$(build_body "$NAME" "$zone_pg" "$zone_res" "$acct_pg" "$acct_res" "$expires")"
  result="$(cf_ok "create token" POST "user/tokens" "$body")"
  token="$(jq -r '.result.value // empty' <<<"$result")"
  token_id="$(jq -r '.result.id // empty' <<<"$result")"
  [[ -n "$token" ]] || die "token created but no value returned — check with --list (id: ${token_id:-unknown})" 1

  # 5. VERIFY before anything can treat the new value as a credential. A mint
  #    once produced a value that did not authenticate, and storing it replaced
  #    the working deploy token in the vault — so the verify is a hard gate in
  #    front of BOTH the "store this" instruction and the vault write. Failure
  #    still shows the value once (a created token can never be re-fetched, and
  #    the operator needs the id to clean it up) but marks it unusable, touches
  #    no vault secret, and exits 1.
  hdr "verify the minted token (as itself, against Cloudflare)"
  if verify_minted_token "$token"; then
    pass "Cloudflare confirms the minted token authenticates (status: active)"
  else
    printf '\n%s============ NEW TOKEN — FAILED VERIFICATION ==============%s\n' "$R" "$Z"
    printf '  name:  %s\n' "$NAME"
    printf '  id:    %s\n' "$token_id"
    # The value is shown here because a created token can never be re-fetched and
    # the operator may need it — except when the caller asked for no value in its
    # log at all. The id above is what --revoke takes, so the cleanup path holds
    # either way.
    if [[ "$PRINT_VALUE" -eq 1 ]]; then
      printf '  value: %s\n' "$token"
    else
      printf '  value: (suppressed by --no-print-value — clean it up by the id above)\n'
    fi
    printf '%s  This token was created but does NOT authenticate. Do not use or%s\n' "$R" "$Z"
    printf '%s  store it. Clean it up:  --revoke %s%s\n' "$R" "$token_id" "$Z"
    printf '%s===========================================================%s\n' "$R" "$Z"
    [[ -n "$VAULT_SECRET" ]] \
      && fail "vault secret '$VAULT_SECRET' was NOT written — it keeps its existing value"
    die "minted token failed verification — nothing was stored" 1
  fi

  # 6. Emit the value ONCE, boxed. This is the only place a good token is printed
  #    — and --no-print-value turns even that off, for a caller whose stdout is a
  #    run log rather than an operator's eyes. The vault write below is then the
  #    only copy, which is why that flag requires --vault-secret.
  if [[ "$PRINT_VALUE" -eq 1 ]]; then
    printf '\n%s================= NEW CLOUDFLARE API TOKEN =================%s\n' "$G" "$Z"
    printf '  name:  %s\n' "$NAME"
    printf '  id:    %s\n' "$token_id"
    printf '  value: %s\n' "$token"
    printf '%s  STORE THIS NOW. Cloudflare shows a token value exactly ONCE —%s\n' "$Y" "$Z"
    printf '%s  it cannot be retrieved again. If lost, roll a new one and delete this.%s\n' "$Y" "$Z"
    printf '%s===========================================================%s\n' "$G" "$Z"
  else
    pass "minted token '$NAME' (id $token_id) — value NOT printed (--no-print-value); it lands only in the store(s) named by --value-file/--vault-secret"
  fi
  [[ -n "$expires" ]] && info "the token expires on its own at $expires (--ttl $TTL) — Cloudflare refuses it past that moment even if it is never burned"

  # 6b. Optional: write the value to a file (--value-file), mode 0600, reached
  #     only after the verify gate — same rule as the vault: an unverified value
  #     is never stored anywhere. This is the machine-readable handle for a
  #     wrapping tool (mint, hand the value to a command, burn) that must not
  #     scrape the printed box.
  local value_file_written=0
  if [[ -n "$VALUE_FILE" ]]; then
    if (umask 077; printf '%s' "$token" > "$VALUE_FILE") 2>/dev/null; then
      chmod 600 "$VALUE_FILE" 2>/dev/null || true
      value_file_written=1
      pass "value written to '$VALUE_FILE' (mode 0600, value not printed)"
    else
      fail "could not write the value file '$VALUE_FILE'"
      if [[ "$PRINT_VALUE" -eq 0 && -z "$VAULT_SECRET" ]]; then
        # No printed value, no vault write coming: the file was the only copy.
        fail "the value was not printed (--no-print-value) and no vault write is configured — the minted token is now UNRECOVERABLE. It is live at Cloudflare; revoke it: --revoke $token_id"
        exit 1
      fi
      warn "the token is verified and valid — it survives in the printed box and/or the vault write below; fix the file path if a wrapper needs it"
    fi
  fi

  # 7. Optional: land it in the ops vault (value passed to az, never printed).
  #    Reached only after the verify gate above, so an existing working secret
  #    is never replaced by a value Cloudflare has not confirmed.
  if [[ -n "$VAULT_SECRET" ]]; then
    hdr "store into the ops vault"
    # Capture the store's stderr so a refusal names its cause (an RBAC denial, a
    # lapsed activation, a wrong vault name) instead of eating it — the eaten
    # error is exactly how this failure once cost a live instrument-the-path
    # session to diagnose. The token value is scrubbed from the captured text
    # before printing, so the one-print rule above still holds.
    local store_err=""
    if store_err=$(az keyvault secret set --vault-name "$VAULT_NAME" --name "$VAULT_SECRET" \
         --value "$token" --output none 2>&1); then
      pass "stored in vault '$VAULT_NAME' as secret '$VAULT_SECRET' (value not printed)"
    else
      store_err="${store_err//"$token"/<redacted>}"
      fail "vault store FAILED: ${store_err:-<no error output>}"
      if [[ "$PRINT_VALUE" -eq 1 ]]; then
        warn "the token above is verified and valid; store it manually"
      elif [[ "$value_file_written" -eq 1 ]]; then
        warn "the token is verified and valid; its only surviving copy is the value file '$VALUE_FILE' — store it from there"
      else
        # No printed value and no vault write: the value is gone the moment this
        # process exits. Say so plainly and name the only remaining handle on it —
        # its id — so a live credential nobody holds does not just linger.
        fail "the value was not printed (--no-print-value) — the minted token is now UNRECOVERABLE. It is live at Cloudflare; revoke it: --revoke $token_id"
      fi
      exit 1
    fi
  fi
}

# ── QUALIFY mode (measure, never label) ───────────────────────────────────────
# A credential is a minter iff it can READ the permission-group catalogue —
# GET /user/tokens/permission_groups answering success. That call is the same one
# a mint makes first, so a credential that passes here can begin a mint, and one
# that fails here fails by name now instead of half way through a mint. Nothing
# about the credential's NAME, vault key, or dashboard label is consulted: a token
# called "the minter" that cannot read this catalogue is not a minter.
qualify_minter(){
  if [[ "$DRY_RUN" -eq 1 ]]; then
    hdr "dry run — qualify the minter (no network calls)"
    info "would measure the credential with this read, and qualify it only if it succeeds:"
    cf GET "user/tokens/permission_groups"
    hdr "dry run complete — nothing was measured"
    return 0
  fi
  hdr "qualify the minter credential (measured, not labelled)"
  local resp n
  resp="$(cf GET "user/tokens/permission_groups")" || \
    die "the permission-group read did not complete (curl failed; its error is above) — the credential is NOT qualified as a minter" 1
  if [[ "$(jq -r '.success // false' <<<"$resp" 2>/dev/null)" != "true" ]]; then
    fail "Cloudflare refused the permission-group read; its error body follows verbatim:"
    printf '%s\n' "$resp" >&2
    die "this credential canNOT mint: GET /user/tokens/permission_groups did not succeed. A minter needs \"User API Tokens:Edit\"; a credential with any amount of DNS/zone reach but not that group will fail here every time, whatever it is named." 1
  fi
  n="$(jq -r '.result | length' <<<"$resp")"
  pass "qualified: the credential read $n permission groups — it can create and delete tokens"
}

# ── dispatch ──────────────────────────────────────────────────────────────────
case "$MODE" in
  qualify) qualify_minter ;;
  list)   list_tokens ;;
  mint)   mint_token ;;
  revoke) revoke_token ;;
  burn)   burn_token ;;
  *)      die "internal: unknown mode '$MODE'" ;;
esac
