#!/usr/bin/env bash
#
# cf-mint-token.sh — mint a scope-exact Cloudflare API token over the CF API, so
# tokens are created declaratively (named permissions + named zones) instead of
# by clicking through the Cloudflare dashboard.
#
# Standalone home of the minter (born in worksync's infra/, formalized here so
# every project can mint scope-exact deploy tokens the same way). Operator
# ergonomics: colored pass/fail/warn/info helpers, set -uo pipefail, a --dry-run
# that resolves the plan and prints the exact call it WOULD send, and a fixed
# exit-code contract (0 ok / 1 a step failed / 2 usage-or-precondition).
#
# THE MINTER CREDENTIAL:
#   Creating a token is itself a privileged operation — a normal scoped token
#   cannot do it. You need a credential that carries "User API Tokens:Edit". That
#   minter credential is read from the environment (CF_MINTER_TOKEN), or fetched
#   from the ops vault when CF_MINTER_VAULT_SECRET + OPS_VAULT_NAME are set. It is
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
#   2. Resolve each --zone <name> -> its zone id, via GET /zones?name=<name>.
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
#   7. Optionally, with --vault-secret <name> + OPS_VAULT_NAME, also store the
#      minted token into the ops vault in the same step (value never printed).
#      The vault write happens strictly AFTER the verify gate, so an existing
#      working secret can never be overwritten by an unverified value.
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

NAME=""; VAULT_SECRET=""; MODE="mint"; REVOKE_ID=""
PERMS=(); ZONES=()
DRY_RUN="${DRY_RUN:-0}"

usage(){
  cat >&2 <<'EOF'
cf-mint-token.sh — mint a scope-exact Cloudflare API token over the CF API.
Sibling of cf-harden.sh. Names permissions + zones in human terms and resolves
them to the UUIDs Cloudflare's token API wants. Every mint creates a NEW token
(not an upsert) — use --list to avoid duplicates before minting.

  --name <token-name>     name for the new token (required to mint).
  --perm <Name:Level>     permission to grant, repeatable. Level is Edit or Read.
                          e.g. --perm DNS:Edit --perm "Zone Settings:Edit"
  --zone <zonename>       zone to scope zone-permissions to, repeatable.
                          e.g. --zone font11a.io --zone worksync.works
                          Omit -> the token is account-scoped only (no zone perms).
  --vault-secret <name>   also store the minted token into the ops vault under
                          this secret name (needs OPS_VAULT_NAME). Value never
                          printed; the vault becomes the source of truth. The
                          write happens only AFTER the minted token verifies
                          against Cloudflare — an unverified value can never
                          replace an existing secret.
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
read from CF_MINTER_TOKEN, or from the ops vault when CF_MINTER_VAULT_SECRET +
OPS_VAULT_NAME are set. It needs "User API Tokens:Edit" (a normal scoped token
cannot create OR delete tokens). Never passed as an argument; never printed.

Env:
  CF_MINTER_TOKEN         the minter credential (User API Tokens:Edit). Used to
                          mint AND to delete (--revoke / --burn).
  CF_MINTER_VAULT_SECRET  vault secret name to read the minter from (with
                          OPS_VAULT_NAME) if CF_MINTER_TOKEN is unset.
  CF_BURN_TOKEN           (--burn only) the VALUE of the token to delete. Read
                          from the environment only — never an argument, never
                          printed; it lives only in a Bearer header for the
                          self-verify call.
  OPS_VAULT_NAME          Azure Key Vault name (for --vault-secret and/or the
                          minter fetch).
  CF_ACCOUNT_ID           pin the account id (skips GET /accounts; used when the
                          minter can see more than one account).

Examples:
  # See what already exists before minting (avoid duplicates):
  CF_MINTER_TOKEN=… ./cf-mint-token.sh --list

  # Preview the exact policy + POST without creating anything:
  CF_MINTER_TOKEN=… ./cf-mint-token.sh --dry-run \
      --name fleet-provisioner --perm DNS:Edit \
      --zone font11a.io --zone worksync.works --vault-secret cloudflare-token

  # Mint for real and stash it in the ops vault in one step:
  CF_MINTER_TOKEN=… OPS_VAULT_NAME=ws-ops-kv ./cf-mint-token.sh \
      --name fleet-provisioner --perm DNS:Edit --perm "SSL and Certificates:Edit" \
      --zone font11a.io --zone worksync.works --vault-secret cloudflare-token

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
    --vault-secret)  need_arg "$1" "${2:-}"; VAULT_SECRET="$2"; shift 2 ;;
    --list)          MODE="list"; shift ;;
    --revoke)        need_arg "$1" "${2:-}"; MODE="revoke"; REVOKE_ID="$2"; shift 2 ;;
    --burn)          MODE="burn"; shift ;;
    --dry-run)       DRY_RUN=1; shift ;;
    -h|--help)       usage 0 ;;
    *)               die "unknown flag: $1" ;;
  esac
done

# ── the minter credential ─────────────────────────────────────────────────────
# Resolve it into CF_MINTER_TOKEN (from env, or the ops vault). It is required in
# every mode — even --dry-run and --list — so the missing-minter failure is caught
# the same way regardless. It is never echoed anywhere below this block.
if [[ -z "${CF_MINTER_TOKEN:-}" ]]; then
  if [[ -n "${CF_MINTER_VAULT_SECRET:-}" && -n "${OPS_VAULT_NAME:-}" ]]; then
    command -v az >/dev/null 2>&1 || die "az CLI not found (needed to read the minter from the vault)"
    CF_MINTER_TOKEN="$(az keyvault secret show --vault-name "$OPS_VAULT_NAME" \
      --name "$CF_MINTER_VAULT_SECRET" --query value -o tsv 2>/dev/null || true)"
    [[ -n "$CF_MINTER_TOKEN" ]] || die "could not read minter secret '$CF_MINTER_VAULT_SECRET' from vault '$OPS_VAULT_NAME'"
  fi
fi
[[ -n "${CF_MINTER_TOKEN:-}" ]] || die "CF_MINTER_TOKEN must be set (a credential with User API Tokens:Edit), \
or set CF_MINTER_VAULT_SECRET + OPS_VAULT_NAME to read it from the ops vault"

# ── common preconditions ──────────────────────────────────────────────────────
command -v jq >/dev/null 2>&1 || die "jq not found (required)"
if [[ "$DRY_RUN" -ne 1 ]]; then
  command -v curl >/dev/null 2>&1 || die "curl not found"
fi

# Cloudflare's auth edge is eventually-consistent: a just-minted token can be
# rejected with a transient 401 (error code 10000) by some edge nodes for up to
# ~2 minutes. The post-mint verification below rides this retry wrapper so a
# valid-but-still-propagating token is retried instead of failing the verify
# gate on the first 401. Sourcing only defines functions (no side effects), and
# --dry-run never reaches a live call.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # infra/
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
  local method="$1" path="$2" body="${3:-}" bearer="${4:-$CF_MINTER_TOKEN}"
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

# ── permission-level normalisation ────────────────────────────────────────────
# Operators name a permission as "Name:Level". Edit (the human word) maps to the
# permission group's "Write" variant; Read maps to "Read". "Write" is accepted as
# an alias for Edit. Anything else is a usage error caught up front (no network).
level_suffix(){
  case "$(lc "$1")" in
    edit|write) printf 'Write' ;;
    read)       printf 'Read' ;;
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
split_perm(){
  local spec="$1"
  [[ "$spec" == *:* ]] || die "malformed --perm '$spec' — want Name:Level (e.g. DNS:Edit)"
  PERM_BASE="${spec%:*}"; PERM_LEVEL="${spec##*:}"
  [[ -n "$PERM_BASE" ]] || die "malformed --perm '$spec' — empty permission name"
  PERM_SUFFIX="$(level_suffix "$PERM_LEVEL")" \
    || die "unknown permission level '$PERM_LEVEL' in '$spec' — want Edit or Read"
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
  local resp del_id
  resp="$(cf_ok "revoke token $REVOKE_ID" DELETE "user/tokens/$REVOKE_ID")"
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
  local dresp del_id
  dresp="$(cf_ok "burn token $burn_id" DELETE "user/tokens/$burn_id")"
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

  # --vault-secret needs a vault to write to.
  if [[ -n "$VAULT_SECRET" ]]; then
    [[ -n "${OPS_VAULT_NAME:-}" ]] || die "--vault-secret '$VAULT_SECRET' needs OPS_VAULT_NAME set"
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
    info "would resolve permission: $p  ->  permission group named '$want'"
    local obj
    obj="$(jq -nc --arg id "<pg-id: $want>" --arg n "$want" '{id:$id, name:$n}')"
    if account_scoped_hint "$PERM_BASE"; then
      acct_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$acct_pg")"
    else
      zone_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$zone_pg")"
    fi
  done

  # Zones -> placeholder zone resources.
  local zone_res='{}' z
  if [[ ${#ZONES[@]} -gt 0 ]]; then
    for z in "${ZONES[@]}"; do
      info "would resolve zone: $z  ->  GET /zones?name=$z  ->  its zone id"
      zone_res="$(jq -c --arg k "com.cloudflare.api.account.zone.<zone-id: $z>" \
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
  if [[ "$zone_pg" != "[]" && ${#ZONES[@]} -eq 0 ]]; then
    warn "zone-scoped permissions were requested but no --zone was given —"
    warn "the live run would refuse (a zone policy needs at least one zone)."
  fi

  local body
  body="$(build_body "$NAME" "$zone_pg" "$zone_res" "$acct_pg" "$acct_res")"

  hdr "policy JSON that WOULD be sent"
  jq . <<<"$body"

  hdr "the API call that WOULD be made (minter token is in the header, never shown)"
  cf POST "user/tokens" "$body"

  info "would then VERIFY the minted token authenticates: GET user/tokens/verify"
  info "  authenticated AS the new token (header only, never shown), retried through"
  info "  the token-propagation window. If it does not verify: nothing stored, exit 1."
  if [[ -n "$VAULT_SECRET" ]]; then
    info "only after verify passes: az keyvault secret set --vault-name $OPS_VAULT_NAME --name $VAULT_SECRET --value <token> (value never printed)"
  fi
  hdr "dry run complete — no token was created"
}

# build_body: assemble the {name, policies:[…]} request body. Emits a zone policy
# when there are zone-scoped groups and an account policy when there are
# account-scoped groups — either, both, or (degenerate) neither. Shared by the
# dry-run (placeholder ids) and live (real ids) paths so they can never drift.
build_body(){
  local name="$1" zpg="$2" zres="$3" apg="$4" ares="$5"
  local policies='[]'
  if [[ "$zpg" != "[]" ]]; then
    policies="$(jq -c --argjson pg "$zpg" --argjson res "$zres" \
      '. + [{effect:"allow", permission_groups:$pg, resources:$res}]' <<<"$policies")"
  fi
  if [[ "$apg" != "[]" ]]; then
    policies="$(jq -c --argjson pg "$apg" --argjson res "$ares" \
      '. + [{effect:"allow", permission_groups:$pg, resources:$res}]' <<<"$policies")"
  fi
  jq -nc --arg n "$name" --argjson p "$policies" '{name:$n, policies:$p}'
}

mint_live(){
  hdr "mint token '$NAME'"

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
    if [[ "$n_match" -ne 1 ]]; then
      fail "could not resolve --perm '$p' (looked for '$want') — $n_match candidates."
      printf '%s  available permission groups (name — scope):%s\n' "$Y" "$Z" >&2
      jq -r '.result | sort_by(.name)[] | "    \(.name)  [\(.scopes // [] | join(", "))]"' <<<"$pg_all" >&2
      exit 1
    fi
    pg_id="$(jq -r '.[0].id' <<<"$match")"
    pg_name="$(jq -r '.[0].name' <<<"$match")"
    # Scope class from the group's own scopes field (the source of truth). A scope
    # that names ".zone" is zone-scoped; anything else is account-scoped.
    pg_scope="$(jq -r '.[0].scopes // [] | join(",")' <<<"$match")"
    local obj; obj="$(jq -nc --arg id "$pg_id" '{id:$id}')"
    if [[ "$pg_scope" == *zone* ]]; then
      zone_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$zone_pg")"
      pass "resolved $p  ->  $pg_name (zone-scoped)"
    else
      acct_pg="$(jq -c --argjson o "$obj" '. + [$o]' <<<"$acct_pg")"
      pass "resolved $p  ->  $pg_name (account-scoped)"
    fi
  done

  # 2. Zone-scoped perms require at least one zone; resolve each zone name -> id.
  local zone_res='{}' z zid
  if [[ "$zone_pg" != "[]" ]]; then
    [[ ${#ZONES[@]} -gt 0 ]] || die "zone-scoped permissions were requested but no --zone was given"
    for z in "${ZONES[@]}"; do
      zid="$(cf_ok "resolve zone $z" GET "zones?name=$z" | jq -r '.result[0].id // empty')"
      [[ -n "$zid" ]] || die "zone '$z' not found (is the minter authorised for it?)" 1
      zone_res="$(jq -c --arg k "com.cloudflare.api.account.zone.$zid" '. + {($k): "*"}' <<<"$zone_res")"
      pass "resolved zone $z  ->  $zid"
    done
  elif [[ ${#ZONES[@]} -gt 0 ]]; then
    warn "--zone was given but no zone-scoped permissions were requested — zones ignored"
  fi

  # 3. Account resource (only when account-scoped perms are present).
  local acct_res='{}' acct_id
  if [[ "$acct_pg" != "[]" ]]; then
    if [[ -n "${CF_ACCOUNT_ID:-}" ]]; then
      acct_id="$CF_ACCOUNT_ID"
    else
      local acc; acc="$(cf_ok "resolve account" GET "accounts")"
      acct_id="$(jq -r '.result[0].id // empty' <<<"$acc")"
      [[ -n "$acct_id" ]] || die "no account visible to the minter (GET /accounts empty)" 1
      [[ "$(jq -r '.result | length' <<<"$acc")" -eq 1 ]] \
        || warn "minter can see >1 account — using the first ($acct_id); pin with CF_ACCOUNT_ID"
    fi
    acct_res="$(jq -c --arg k "com.cloudflare.api.account.$acct_id" '. + {($k): "*"}' <<<"$acct_res")"
    pass "account-scoped policy targets account $acct_id"
  fi

  # 4. Build and POST the token.
  local body result token token_id
  body="$(build_body "$NAME" "$zone_pg" "$zone_res" "$acct_pg" "$acct_res")"
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
    printf '  value: %s\n' "$token"
    printf '%s  This token was created but does NOT authenticate. Do not use or%s\n' "$R" "$Z"
    printf '%s  store it. Clean it up:  --revoke %s%s\n' "$R" "$token_id" "$Z"
    printf '%s===========================================================%s\n' "$R" "$Z"
    [[ -n "$VAULT_SECRET" ]] \
      && fail "vault secret '$VAULT_SECRET' was NOT written — it keeps its existing value"
    die "minted token failed verification — nothing was stored" 1
  fi

  # 6. Emit the value ONCE, boxed. This is the only place a good token is printed.
  printf '\n%s================= NEW CLOUDFLARE API TOKEN =================%s\n' "$G" "$Z"
  printf '  name:  %s\n' "$NAME"
  printf '  id:    %s\n' "$token_id"
  printf '  value: %s\n' "$token"
  printf '%s  STORE THIS NOW. Cloudflare shows a token value exactly ONCE —%s\n' "$Y" "$Z"
  printf '%s  it cannot be retrieved again. If lost, roll a new one and delete this.%s\n' "$Y" "$Z"
  printf '%s===========================================================%s\n' "$G" "$Z"

  # 7. Optional: land it in the ops vault (value passed to az, never printed).
  #    Reached only after the verify gate above, so an existing working secret
  #    is never replaced by a value Cloudflare has not confirmed.
  if [[ -n "$VAULT_SECRET" ]]; then
    hdr "store into the ops vault"
    if az keyvault secret set --vault-name "$OPS_VAULT_NAME" --name "$VAULT_SECRET" \
         --value "$token" --output none 2>/dev/null; then
      pass "stored in vault '$OPS_VAULT_NAME' as secret '$VAULT_SECRET' (value not printed)"
    else
      warn "vault store FAILED — the token above is verified and valid; store it manually"
      exit 1
    fi
  fi
}

# ── dispatch ──────────────────────────────────────────────────────────────────
case "$MODE" in
  list)   list_tokens ;;
  mint)   mint_token ;;
  revoke) revoke_token ;;
  burn)   burn_token ;;
  *)      die "internal: unknown mode '$MODE'" ;;
esac
