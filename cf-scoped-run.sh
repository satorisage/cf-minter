#!/usr/bin/env bash
#
# cf-scoped-run.sh — run ONE command under an ephemeral, scope-exact Cloudflare
# token: mint it, hand it to the command, and BURN it on exit no matter how the
# command ended. The mint-use-burn lifecycle as a single tool, so an ad-hoc job
# that needs a Cloudflare credential for five minutes never acquires one that
# outlives the job.
#
# This is a WRAPPER around cf-mint-token.sh — the sibling that owns the whole
# token lifecycle (mint / verify / revoke / burn). Everything credential-shaped
# happens THERE: permission-group and zone resolution are live API lookups (never
# hardcoded ids), the minted value is verified against Cloudflare before anything
# may use it, and the burn self-identifies the token by value. This tool only
# sequences those capabilities and owns the trap.
#
# WHAT A RUN DOES:
#   1. Mint: cf-mint-token.sh --name cfsr-<epoch>-t<ttl-seconds>-<slug> with the
#      requested --perm/--zone/--zone-id scope, a --ttl (default 1h), and the
#      value landed in a private temp file (--value-file, mode 0600,
#      --no-print-value — the value never appears in this tool's output). The
#      TTL is the FLOOR under the pattern: even if this process is SIGKILLed
#      between mint and burn, Cloudflare refuses the token once it expires.
#   2. Use: run the given command with the value exported as CF_SCOPED_TOKEN and
#      as CLOUDFLARE_API_TOKEN — the name the Cloudflare ecosystem already reads,
#      so an unmodified tool needs no adaptation (environment only, never argv,
#      never printed).
#   3. Burn: an EXIT trap deletes the token at Cloudflare (cf-mint-token.sh
#      --burn, by value) regardless of the command's outcome — success, failure,
#      or interrupt. The command's own exit code is preserved, EXCEPT that a
#      failed burn forces a non-zero exit: a green job that leaked a live
#      credential is not a green run (the TTL still bounds the leak).
#   If the mint itself fails, the command NEVER runs — and if the mint tool's
#   failure output names an orphaned token id (created but failed verification),
#   that id is revoked here so the failure leaves nothing behind.
#
# NAMING CONVENTION = THE TTL RECORD:
#   Every token this tool mints is named cfsr-<mint-epoch>-t<ttl-seconds>-<slug>.
#   The name is the durable record of when the token was born and how long it was
#   meant to live — which is what lets --list-stale answer "did any run's burn
#   fail?" from the token list alone, with no state file to drift:
#     --list-stale   list minted-by-us (cfsr-*) tokens older than the TTL their
#                    own name declares. Exit 0 when none, 1 when any are listed.
#     --burn-stale   revoke exactly those. Tokens not named cfsr-* are NEVER
#                    touched — the convention is the ownership boundary.
#   A stale cfsr token is already EXPIRED at Cloudflare (its expires_on was mint
#   + TTL), so it no longer authenticates — burning it is hygiene plus a visible
#   signal that some run's burn failed, not an open credential hole.
#
# MINTER CREDENTIAL: read exactly as cf-mint-token.sh reads it (CF_MINTER_TOKEN,
# or CF_MINTER_VAULT_SECRET + OPS_VAULT_NAME for the ops-vault path) — this tool
# never handles it, it only inherits the environment through to the mint tool.
#
# Usage:
#   cf-scoped-run.sh --profile <name> [--zone <name>|--zone-id <id>]...
#                    [--ttl <duration>] [--slug <label>] [--dry-run] -- cmd [args...]
#   cf-scoped-run.sh [--perm Name:Level]... [--zone <name>|--zone-id <id>]...
#                    [--ttl <duration>] [--slug <label>] [--dry-run] -- cmd [args...]
#   cf-scoped-run.sh --profile <name> --mint-only [--zone …] [--ttl …]
#   cf-scoped-run.sh --list-profiles
#   cf-scoped-run.sh --list-stale
#   cf-scoped-run.sh --burn-stale [--dry-run]
#
#   --profile <name>    a named purpose from profiles.conf: its permission set,
#                       its zone-vs-account scope rule, and its default TTL. The
#                       profile set is DATA (profiles.conf) — adding one is a
#                       single edit there. --list-profiles prints them.
#   --mint-only         mint the token, print it once, and DO NOT burn it — for
#                       interactive use where you drive the API by hand. The TTL
#                       is then the only thing that ends it, so it defaults short
#                       and the token is named cfsr-* like any other, which means
#                       --list-stale/--burn-stale still sweep it up.
#   --minter-cmd <cmd>  shell command that prints the minter token (passed to the
#                       mint tool; also CF_MINTER_CMD). How a project wires its
#                       own secret store without this tool knowing about it.
#   --perm Name:Level   permission for the ephemeral token, repeatable (resolved
#                       live by cf-mint-token.sh; e.g. --perm DNS:Edit).
#   --zone <name>       zone to scope to, by name (live lookup). Repeatable.
#   --zone-id <id>      zone to scope to, by id (no lookup — for a caller whose
#                       own config holds the id as the authoritative value).
#   --ttl <duration>    token lifetime: <n>[s|m|h|d] (default 1h). Also written
#                       into the token's name (the t<seconds> field).
#   --slug <label>      trailing label in the token name (lowercase [a-z0-9-];
#                       default "run") so --list-stale output says WHAT each
#                       stale token was minted for.
#   --dry-run           print the mint plan (via cf-mint-token.sh --dry-run) and
#                       the command that would run; no network calls, no token,
#                       the command is NOT executed. With --burn-stale: prints
#                       what would be enumerated and burned, offline.
#   -h, --help          this help.
#
# Env:
#   CF_SCOPED_TOKEN         what the wrapped command receives: the minted value.
#   CLOUDFLARE_API_TOKEN    the same value under the ecosystem's own name.
#   CF_MINTER_TOKEN         the minter credential (User API Tokens:Edit), or
#   CF_MINTER_VAULT_SECRET  + OPS_VAULT_NAME to read it from the ops vault —
#                           passed through to cf-mint-token.sh untouched.
#   CF_MINT_TOKEN_SCRIPT    override the cf-mint-token.sh path (tests).
#
# Exit: run mode: the wrapped command's own exit code — except 1 when the mint
#       failed (command never ran) or when the burn failed after a 0 command.
#       --list-stale: 0 no stale tokens, 1 stale tokens listed (or list failed).
#       --burn-stale: 0 all stale tokens revoked (or none), 1 a revoke failed.
#       2 usage / precondition.
#
# Tools: cf-mint-token.sh (which needs curl + jq; az only for a vaulted minter).

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
# value — non-empty and not another flag (same guard as the mint tool: a bare
# flag must never swallow its neighbour or loop the parser).
need_arg(){
  [[ $# -ge 2 && -n "${2:-}" && "${2:-}" != -* ]] \
    || die "$1 requires a value (got '${2:-}')"
}

# Resolve through symlinks. The common install is a link on PATH
# (ln -s /opt/cf-minter/cf-scoped-run.sh /usr/local/bin/cf-scoped-run.sh), and BASH_SOURCE[0] is the link's
# own path, not the target's — so without this the siblings beside the real
# script are invisible. readlink is used without -f because BSD's lacks it;
# the loop is the portable equivalent and also handles a chain of links.
_src="${BASH_SOURCE[0]}"
while [ -L "$_src" ]; do
  _dir="$(cd -P "$(dirname "$_src")" && pwd)"
  _src="$(readlink "$_src")"
  case "$_src" in /*) ;; *) _src="$_dir/$_src" ;; esac
done
HERE="$(cd -P "$(dirname "$_src")" && pwd)"
unset _src _dir
CF_MINT="${CF_MINT_TOKEN_SCRIPT:-$HERE/cf-mint-token.sh}"
[[ -x "$CF_MINT" || -f "$CF_MINT" ]] || die "cf-mint-token.sh not found at '$CF_MINT'"

# ttl_to_seconds: same grammar the mint tool accepts — <n>[s|m|h|d] or bare
# seconds. Parsed here too because the seconds figure is baked into the token
# NAME (the t<seconds> field --list-stale reads back).
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

# An exported DRY_RUN is HONOURED, not overwritten. `DRY_RUN=1` in the
# environment is this repo's preview spelling across every verb, and this file
# itself relies on it: the dry-run branch below exports DRY_RUN=1 into
# cf-mint-token.sh to mean "do not mint". Reading it on the way in and ignoring
# it on the way out is the one combination that cannot be defended — an operator
# who exports DRY_RUN=1 for safety got a real token minted, a real command run
# against Cloudflare, and a real burn. A spelling this tool cannot act on
# refuses by name rather than reading as "no": silently ignoring a safety flag
# is the same failure in a third costume.
MODE="run"; TTL=""; TTL_DEFAULT="1h"; SLUG=""; DRY_RUN="${DRY_RUN:-0}"
PROFILE=""; MINT_ONLY=0
PROFILES_FILE="${CF_PROFILES_FILE:-$HERE/profiles.conf}"
[[ "$DRY_RUN" == 0 || "$DRY_RUN" == 1 ]] \
  || die "DRY_RUN is set to '$DRY_RUN' in the environment, and this tool reads only 0 or 1 — refusing rather than mutating on a flag it cannot act on. Export DRY_RUN=1 (or pass --dry-run) for a preview, DRY_RUN=0 to apply." 2
MINT_ARGS=()   # the --perm/--zone/--zone-id scope, passed through verbatim
PERM_COUNT=0   # how many --perm the caller named directly (a profile adds more)
ZONE_COUNT=0   # how many zones the run named, by name or id
CMD=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --perm)       need_arg "$1" "${2:-}"; MINT_ARGS+=(--perm "$2"); PERM_COUNT=$((PERM_COUNT+1)); shift 2 ;;
    --zone)       need_arg "$1" "${2:-}"; MINT_ARGS+=(--zone "$2"); ZONE_COUNT=$((ZONE_COUNT+1)); shift 2 ;;
    --zone-id)    need_arg "$1" "${2:-}"; MINT_ARGS+=(--zone-id "$2"); ZONE_COUNT=$((ZONE_COUNT+1)); shift 2 ;;
    --ttl)        need_arg "$1" "${2:-}"; TTL="$2"; shift 2 ;;
    --slug)       need_arg "$1" "${2:-}"; SLUG="$2"; shift 2 ;;
    --profile)    need_arg "$1" "${2:-}"; PROFILE="$2"; shift 2 ;;
    --mint-only)  MINT_ONLY=1; shift ;;
    --minter-cmd) need_arg "$1" "${2:-}"; export CF_MINTER_CMD="$2"; shift 2 ;;
    --minter-token-file) need_arg "$1" "${2:-}"; MINT_ARGS+=(--minter-token-file "$2"); shift 2 ;;
    --minter-token) die "--minter-token is refused on purpose: argv is world-readable in \`ps\`, so a token passed there leaks to every process on the host. Supply it as CF_MINTER_TOKEN in the environment, as --minter-token-file <path> (mode 0600), or as --minter-cmd '<command that prints it>'." ;;
    --list-profiles) MODE="list-profiles"; shift ;;
    --list-stale) MODE="list-stale"; shift ;;
    --burn-stale) MODE="burn-stale"; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)    sed -n '2,/^set -uo pipefail$/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
    --)           shift; CMD=("$@"); break ;;
    *)            die "unknown flag: $1 (command goes after '--')" ;;
  esac
done


# ── profiles: the named purposes, read from profiles.conf ─────────────────────
# The file is the ONE home of the profile set (see its header for the format).
# Everything below only reads it: the permission list, the zone-vs-account scope
# rule, the default TTL and the one-line "why". No profile is known to this code.
PROFILE_PERMS=(); PROFILE_SCOPE=""; PROFILE_TTL=""; PROFILE_WHY=""

profiles_file_or_die(){
  [[ -r "$PROFILES_FILE" ]] \
    || die "profiles file not readable: '$PROFILES_FILE'. It is the one home of the named profiles; point at another with CF_PROFILES_FILE=<path>."
}

# profile_names: every `profile:` name in the file, in file order.
profile_names(){ sed -n 's/^profile:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$PROFILES_FILE"; }

list_profiles(){
  profiles_file_or_die
  hdr "profiles ($PROFILES_FILE)"
  local n
  for n in $(profile_names); do
    load_profile "$n"
    printf '  %s%s%s  [%s, ttl %s]\n' "$G" "$n" "$Z" "$PROFILE_SCOPE" "$PROFILE_TTL"
    printf '        perms: %s\n' "${PROFILE_PERMS[*]}"
    [[ -n "$PROFILE_WHY" ]] && printf '        %s\n' "$PROFILE_WHY"
  done
  info "add one by editing $PROFILES_FILE — no code change is needed"
}

# load_profile <name>: fill PROFILE_* from the file, refusing by name on anything
# the format does not allow. A malformed profile is a refusal, never a partial
# token: a block missing its perms would otherwise mint a credential with no
# stated reach.
load_profile(){
  local want="$1" cur="" key val line seen=0
  profiles_file_or_die
  PROFILE_PERMS=(); PROFILE_SCOPE=""; PROFILE_TTL=""; PROFILE_WHY=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$line" =~ ^profile:[[:space:]]*(.*)$ ]]; then
      cur="${BASH_REMATCH[1]}"
      [[ "$cur" == "$want" ]] && seen=1
      continue
    fi
    [[ "$cur" == "$want" ]] || continue
    if [[ "$line" =~ ^[[:space:]]+ && -n "$PROFILE_WHY" ]]; then
      # a continuation line of a wrapped `why:`
      PROFILE_WHY="$PROFILE_WHY $(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
      continue
    fi
    [[ "$line" =~ ^([a-z]+):[[:space:]]*(.*)$ ]] \
      || die "malformed line in profile '$want' ($PROFILES_FILE): $line"
    key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
    case "$key" in
      perm)  PROFILE_PERMS+=("$val") ;;
      scope) PROFILE_SCOPE="$val" ;;
      ttl)   PROFILE_TTL="$val" ;;
      why)   PROFILE_WHY="$val" ;;
      *)     die "unknown key '$key:' in profile '$want' ($PROFILES_FILE) — the format allows profile/perm/scope/ttl/why" ;;
    esac
  done < "$PROFILES_FILE"

  if [[ "$seen" -eq 0 ]]; then
    die "unknown profile '$want'. Known profiles: $(profile_names | tr '\n' ' ')— see $PROFILES_FILE, where adding one is a single edit."
  fi
  [[ ${#PROFILE_PERMS[@]} -gt 0 ]] \
    || die "profile '$want' declares no perm: line ($PROFILES_FILE) — a profile with no permissions would mint a blank credential"
  case "$PROFILE_SCOPE" in
    zone|account) ;;
    '') die "profile '$want' declares no scope: line ($PROFILES_FILE) — want 'zone' or 'account'" ;;
    *)  die "profile '$want' declares scope '$PROFILE_SCOPE' ($PROFILES_FILE) — want 'zone' or 'account'" ;;
  esac
  [[ -n "$PROFILE_TTL" ]] || PROFILE_TTL="$TTL_DEFAULT"
}

# Apply the selected profile to this run: its perms join the mint scope, its TTL
# and slug are DEFAULTS the caller's own flags override, and its scope rule is
# enforced here so a zone profile without a zone (an account-wide credential by
# accident) is refused before anything is created.
if [[ -n "$PROFILE" ]]; then
  load_profile "$PROFILE"
  for _p in "${PROFILE_PERMS[@]}"; do MINT_ARGS+=(--perm "$_p"); done
  [[ -n "$TTL" ]]  || TTL="$PROFILE_TTL"
  [[ -n "$SLUG" ]] || SLUG="$PROFILE"
  if [[ "$PROFILE_SCOPE" == "zone" && "$ZONE_COUNT" -eq 0 ]]; then
    die "profile '$PROFILE' is zone-scoped and no zone was named — pass --zone <name> or --zone-id <id>. Minting its permissions with no zone would hand the command reach over every zone the account owns."
  fi
  if [[ "$PROFILE_SCOPE" == "account" && "$ZONE_COUNT" -gt 0 ]]; then
    die "profile '$PROFILE' is account-scoped and cannot be narrowed to a zone — drop --zone/--zone-id (its permissions are not zone permissions, so the scoping would be silently ignored)."
  fi
elif [[ "$MODE" == "run" && "$PERM_COUNT" -eq 0 ]]; then
  : # the scopeless-run refusal below owns this case, with the command in hand
fi
[[ -n "$TTL" ]]  || TTL="$TTL_DEFAULT"
[[ -n "$SLUG" ]] || SLUG="run"

TTL_SECONDS="$(ttl_to_seconds "$TTL")" \
  || die "malformed --ttl '$TTL' — want a positive duration: <n>[s|m|h|d] (e.g. 30m, 1h, 3600)"

# The slug lands inside a token name; keep it to the charset the stale parser
# reads back, rather than letting an odd character break the convention.
SLUG="$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
[[ -n "$SLUG" ]] || SLUG="run"

# The one name pattern this tool owns, mints under, and is allowed to burn.
CFSR_NAME_RE='^cfsr-([0-9]+)-t([0-9]+)(-[a-z0-9-]+)?$'

# ── stale enumeration (--list-stale / --burn-stale) ───────────────────────────
# Read the token list THROUGH the mint tool (--list: "  <id>  <status>\t<name>"
# rows), select only cfsr-named tokens, and compare now against the mint-epoch +
# TTL each name itself declares. No state file: the names are the record.
# stale_tokens: emits "id<TAB>name<TAB>overdue-seconds" per stale token.
stale_tokens(){
  local list now line row id name epoch ttl expiry
  list="$("$CF_MINT" --list)" || return 2
  now="$(date -u +%s)"
  while IFS= read -r line; do
    [[ "$line" == *$'\t'* ]] || continue
    name="${line#*$'\t'}"
    row="${line%%$'\t'*}"
    read -r id _ <<<"$row" || continue
    [[ "$name" =~ $CFSR_NAME_RE ]] || continue
    epoch="${BASH_REMATCH[1]}"; ttl="${BASH_REMATCH[2]}"
    expiry=$((epoch + ttl))
    if (( now > expiry )); then
      printf '%s\t%s\t%s\n' "$id" "$name" "$((now - expiry))"
    fi
  done <<<"$list"
  return 0
}

list_stale(){
  hdr "stale mint-use-burn tokens (cfsr-* older than the TTL in their own name)"
  local rows id name over n=0
  rows="$(stale_tokens)" || die "could not list tokens (the mint tool's error is above)" 1
  while IFS=$'\t' read -r id name over; do
    [[ -n "$id" ]] || continue
    n=$((n + 1))
    warn "STALE: $name (id $id) — ${over}s past its declared TTL; some run's burn did not happen"
  done <<<"$rows"
  if [[ "$n" -eq 0 ]]; then
    pass "no stale cfsr tokens — every mint-use-burn run cleaned up after itself"
    return 0
  fi
  info "$n stale token(s). They are already expired at Cloudflare (minted with expires_on = mint + TTL); burn the residue: $0 --burn-stale"
  return 1
}

burn_stale(){
  if [[ "$DRY_RUN" -eq 1 ]]; then
    hdr "dry run — burn-stale (no network calls, nothing is deleted)"
    info "would list tokens via cf-mint-token.sh --list, select names matching"
    info "  cfsr-<epoch>-t<ttl-seconds>[-slug] whose epoch + ttl < now, and revoke"
    info "each by id (cf-mint-token.sh --revoke <id>). Non-cfsr tokens are never touched."
    return 0
  fi
  hdr "burn stale mint-use-burn tokens"
  local rows id name over n=0 rc=0
  rows="$(stale_tokens)" || die "could not list tokens (the mint tool's error is above)" 1
  while IFS=$'\t' read -r id name over; do
    [[ -n "$id" ]] || continue
    n=$((n + 1))
    if "$CF_MINT" --revoke "$id" >/dev/null 2>&1; then
      pass "burned stale token $name (id $id, ${over}s overdue)"
    else
      fail "could not revoke stale token $name (id $id) — it remains listed at Cloudflare (already expired, so not live). Retry: $CF_MINT --revoke $id"
      rc=1
    fi
  done <<<"$rows"
  [[ "$n" -eq 0 ]] && pass "no stale cfsr tokens to burn"
  return "$rc"
}

# ── run mode: mint, use, burn ─────────────────────────────────────────────────
run_scoped(){
  if [[ "$MINT_ONLY" -eq 0 ]]; then
    [[ ${#CMD[@]} -gt 0 ]] \
      || die "no command given — put it after '--' (e.g. -- ./publish-records.sh), or pass --mint-only to get the value printed for hand-driven use"
  else
    [[ ${#CMD[@]} -eq 0 ]] \
      || die "--mint-only takes no command — it mints and prints, it does not run anything"
  fi
  [[ ${#MINT_ARGS[@]} -gt 0 ]] \
    || die "no scope given — name a --profile (see --list-profiles), or at least one --perm with its --zone/--zone-id; an ephemeral token with no stated scope is a blank credential"
  command -v curl >/dev/null 2>&1 || die "curl not found — required to reach the Cloudflare API"
  command -v jq   >/dev/null 2>&1 || die "jq not found — required to parse the Cloudflare API's responses"

  local token_name; token_name="cfsr-$(date -u +%s)-t${TTL_SECONDS}-${SLUG}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    hdr "dry run — scoped run (no token is minted, the command does not run)"
    if [[ -n "$PROFILE" ]]; then
      info "profile '$PROFILE' ($PROFILE_SCOPE-scoped): ${PROFILE_PERMS[*]}"
      [[ -n "$PROFILE_WHY" ]] && info "  purpose: $PROFILE_WHY"
    fi
    info "would mint '$token_name' (TTL $TTL) with this plan:"
    DRY_RUN=1 "$CF_MINT" --dry-run --name "$token_name" --ttl "$TTL" "${MINT_ARGS[@]}"
    if [[ "$MINT_ONLY" -eq 1 ]]; then
      info "would then PRINT the value once and NOT burn it (--mint-only); only the TTL ends it"
    else
      info "would then run (value exported as CF_SCOPED_TOKEN + CLOUDFLARE_API_TOKEN):"
      printf '    %s\n' "${CMD[*]}"
      info "and BURN the token on exit — success, failure, or interrupt alike"
    fi
    hdr "dry run complete — nothing was created, nothing ran"
    return 0
  fi

  # The value file: the mint tool writes the verified value here (0600); it is
  # read once into memory and removed before the command runs, so the wrapped
  # command sees the value only in its environment.
  local vfile
  vfile="$(umask 077; mktemp "${TMPDIR:-/tmp}/cf-scoped-run.XXXXXX")" \
    || die "could not create a private temp file for the token value — check that TMPDIR (${TMPDIR:-/tmp}) exists and is writable. Nothing was minted, nothing ran." 1

  hdr "mint ephemeral token '$token_name' (TTL $TTL)"
  local mint_out mint_rc=0
  mint_out="$("$CF_MINT" --name "$token_name" --ttl "$TTL" "${MINT_ARGS[@]}" \
      --value-file "$vfile" --no-print-value 2>&1)" || mint_rc=$?
  printf '%s\n' "$mint_out"
  if [[ "$mint_rc" -ne 0 ]]; then
    rm -f "$vfile"
    # A mint can fail AFTER creating the token (the verify gate): its output
    # names the orphan's id as "--revoke <id>". Clean that up here so a failed
    # run leaves nothing behind at Cloudflare.
    local orphan
    orphan="$(grep -oE -- '--revoke [A-Za-z0-9-]+' <<<"$mint_out" | head -1 | cut -d' ' -f2 || true)"
    if [[ -n "$orphan" ]]; then
      if "$CF_MINT" --revoke "$orphan" >/dev/null 2>&1; then
        pass "revoked the orphaned token from the failed mint (id $orphan)"
      else
        fail "the failed mint left token id $orphan behind and the cleanup revoke also failed — revoke it: $CF_MINT --revoke $orphan"
      fi
    fi
    die "mint failed — the command was NOT run" 1
  fi

  local token
  token="$(cat "$vfile")"; rm -f "$vfile"
  [[ -n "$token" ]] || die "the mint reported success but the value file is empty — the command was NOT run" 1

  if [[ "$MINT_ONLY" -eq 1 ]]; then
    hdr "mint-only — the token is NOT burned here"
    printf '\n  %sCF token (%s, TTL %s):%s %s\n\n' "$G" "$token_name" "$TTL" "$Z" "$token"
    warn "nothing will delete this token except its own expiry in $TTL. Burn it by hand when you are done:"
    info "  CF_BURN_TOKEN=<the value above> $CF_MINT --burn"
    info "  or sweep it once expired: $0 --burn-stale"
    return 0
  fi

  # The burn trap. Armed the moment the value exists in memory; fires on EXIT,
  # INT and TERM alike, and self-disarms so it cannot run twice. The value goes
  # to the mint tool in the environment only (CF_BURN_TOKEN), never argv.
  BURN_FAILED=0
  # shellcheck disable=SC2317  # reached via trap
  cfsr_burn(){
    trap - EXIT INT TERM
    [[ -n "$token" ]] || return 0
    hdr "burn ephemeral token '$token_name'"
    if CF_BURN_TOKEN="$token" "$CF_MINT" --burn >&2; then
      pass "token burned"
    else
      BURN_FAILED=1
      fail "could not burn the ephemeral token '$token_name' — it may still be live at Cloudflare until its TTL ($TTL) expires it. Burn the residue once the API answers: $0 --burn-stale"
    fi
    token=""
  }
  trap 'cfsr_burn; exit 130' INT
  trap 'cfsr_burn; exit 143' TERM
  trap 'cfsr_burn' EXIT

  hdr "run (CF_SCOPED_TOKEN + CLOUDFLARE_API_TOKEN exported, value never printed)"
  info "$ ${CMD[*]}"
  local cmd_rc=0
  # Two names for one value, both environment-only. CLOUDFLARE_API_TOKEN is what
  # the Cloudflare ecosystem already reads (wrangler, the terraform provider,
  # flarectl, most curl snippets), so an unmodified tool works under this wrapper
  # with no adaptation; CF_SCOPED_TOKEN is the explicit name for a script written
  # for this lifecycle, and says WHERE its credential came from.
  CF_SCOPED_TOKEN="$token" CLOUDFLARE_API_TOKEN="$token" "${CMD[@]}" || cmd_rc=$?

  cfsr_burn
  trap - EXIT
  if [[ "$cmd_rc" -eq 0 && "$BURN_FAILED" -ne 0 ]]; then
    # The command was green but a credential was left behind: not a green run.
    exit 1
  fi
  exit "$cmd_rc"
}

case "$MODE" in
  run)           run_scoped ;;
  list-profiles) list_profiles ;;
  list-stale)    list_stale ;;
  burn-stale)    burn_stale ;;
esac
