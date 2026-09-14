#!/usr/bin/env bash
#
# cf-scoped-run.test.sh — proves the mint-use-burn wrapper's lifecycle without
# touching Cloudflare: the REAL cf-scoped-run.sh drives the REAL cf-mint-token.sh
# over a PATH-stubbed curl (same idiom as cf-mint-token.test.sh), so the seam
# between the two tools — the flags the wrapper passes, the value file it reads,
# the burn it owes — is exercised for real, not mocked.
#
# What must hold:
#   1. Lifecycle order: mint (POST) → the command runs WITH CF_SCOPED_TOKEN →
#      burn (DELETE) — and the burn happens on EVERY exit: command success,
#      command failure, either way.
#   2. The command's exit code is preserved — except a failed burn after a green
#      command forces non-zero (a leaked credential is not a green run).
#   3. A failed mint means the command NEVER runs, and an orphaned token id from
#      a failed verify is revoked by the wrapper.
#   4. The token value appears nowhere in the wrapper's output, and its temp
#      value file does not outlive the run.
#   5. Naming convention: cfsr-<epoch>-t<ttl-seconds>-<slug>, expires_on in the
#      POST — and --list-stale/--burn-stale read that convention back, touching
#      ONLY cfsr-named tokens.
#
# Run:  bash test/cf-scoped-run.test.sh   (exit 0 = all pass)

# The wrapped test commands below are single-quoted ON PURPOSE: they must expand
# $STUB_DIR / $CF_SCOPED_TOKEN in the CHILD shell the wrapper launches (that is
# what proves the token reached the command's environment), not here.
# shellcheck disable=SC2016

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../cf-scoped-run.sh"

PASS=0 FAIL=0
ok(){   PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad(){  FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1" >&2; }

STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT
export STUB_DIR
CALLS="$STUB_DIR/calls.log"
mkdir -p "$STUB_DIR/tmp"

FAKE_TOKEN="_Fk-token_0123456789abcdef-ABCDEF_xyz99"
printf '%s' "$FAKE_TOKEN" >"$STUB_DIR/token.txt"

# ── stub curl ─────────────────────────────────────────────────────────────────
# Same shape as cf-mint-token.test.sh's stub, plus: the token LIST is served from
# list.json when present (for the stale-token cases), and delete.fail makes every
# token DELETE report failure (for the failed-burn case).
cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
set -u
url=""; method="GET"; auth=""; wfmt=0; data=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -X) method="${args[$((i+1))]}" ;;
    -H) case "${args[$((i+1))]}" in Authorization:*) auth="${args[$((i+1))]#Authorization: Bearer }" ;; esac ;;
    -w) wfmt=1 ;;
    --data) data="${args[$((i+1))]}" ;;
    https://*) url="${args[$i]}" ;;
  esac
done
printf 'curl %s %s auth=%s body=%s\n' "$method" "$url" "$auth" "$data" >>"$STUB_DIR/calls.log"
tok="$(cat "$STUB_DIR/token.txt")"
code=200 body=""
case "$method $url" in
  "GET "*"/user/tokens/verify")
    n=0; [[ -f "$STUB_DIR/verify.count" ]] && n="$(cat "$STUB_DIR/verify.count")"
    echo $((n+1)) >"$STUB_DIR/verify.count"
    line="$(sed -n "$((n+1))p" "$STUB_DIR/verify.plan")"
    [[ -n "$line" ]] || line="$(tail -1 "$STUB_DIR/verify.plan")"
    code="${line%% *}"
    case "${line##* }" in
      ok)  body='{"success":true,"errors":[],"result":{"id":"tok-0001","status":"active"}}' ;;
      *)   body='{"success":false,"errors":[{"code":1000,"message":"Invalid API Token"}],"result":null}' ;;
    esac ;;
  "GET "*"/user/tokens/permission_groups")
    body='{"success":true,"errors":[],"result":[
      {"id":"pg-dns-write","name":"DNS Write","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-dns-read","name":"DNS Read","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-zone-read","name":"Zone Read","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-zone-settings-write","name":"Zone Settings Write","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-zone-waf-write","name":"Zone WAF Write","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-fw-write","name":"Firewall Services Write","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-ssl-write","name":"SSL and Certificates Write","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-analytics-read","name":"Analytics Read","scopes":["com.cloudflare.api.account.zone"]},
      {"id":"pg-pages-write","name":"Pages Write","scopes":["com.cloudflare.api.account"]},
      {"id":"pg-pages-read","name":"Pages Read","scopes":["com.cloudflare.api.account"]},
      {"id":"pg-workers-write","name":"Workers Scripts Write","scopes":["com.cloudflare.api.account"]}
    ]}' ;;
  "DELETE "*"/user/tokens/"*)
    if [[ -f "$STUB_DIR/delete.fail" ]]; then
      body='{"success":false,"errors":[{"code":7000,"message":"stub: delete refused"}]}'
    else
      body="{\"success\":true,\"errors\":[],\"result\":{\"id\":\"${url##*/}\"}}"
    fi ;;
  "POST "*"/user/tokens")
    body="{\"success\":true,\"errors\":[],\"result\":{\"id\":\"tok-0001\",\"name\":\"t\",\"value\":\"$tok\"}}" ;;
  "GET "*"/user/tokens")
    if [[ -f "$STUB_DIR/list.json" ]]; then
      body="{\"success\":true,\"errors\":[],\"result\":$(cat "$STUB_DIR/list.json")}"
    else
      body='{"success":true,"errors":[],"result":[]}'
    fi ;;
  *)
    body='{"success":false,"errors":[{"code":9999,"message":"stub: unexpected endpoint"}]}' ;;
esac
if [[ "$wfmt" -eq 1 ]]; then printf '%s\n%s' "$body" "$code"; else printf '%s' "$body"; fi
STUB
chmod +x "$STUB_DIR/curl"

# run_scoped <outfile> <args…> — run the wrapper with the stub on PATH, a fake
# minter in the env, a private TMPDIR (so the value file's lifetime is
# observable), and a fresh call log. Exit status is the wrapper's.
run_scoped(){
  local out="$1"; shift
  : >"$CALLS"; rm -f "$STUB_DIR/verify.count"
  rm -rf "$STUB_DIR/tmp"; mkdir -p "$STUB_DIR/tmp"
  PATH="$STUB_DIR:$PATH" TMPDIR="$STUB_DIR/tmp" CF_MINTER_TOKEN="fake-minter-value" \
    bash "$SCRIPT" "$@" >"$out" 2>&1 </dev/null
}

echo "200 ok" >"$STUB_DIR/verify.plan"
OUT="$STUB_DIR/out.txt"

# ── 1. usage guards (before any network call) ─────────────────────────────────
echo "usage guards:"

run_scoped "$OUT" --perm DNS:Edit --zone-id z1; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "no command given" "$OUT"; then ok "a run without '--' and a command is a usage error"; else bad "commandless run: want exit 2, got $rc"; fi
if [[ ! -s "$CALLS" ]]; then ok "…with zero network calls"; else bad "touched the network without a command"; fi

run_scoped "$OUT" -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "no scope given" "$OUT"; then ok "a run without any --perm scope is refused (no blank credentials)"; else bad "scopeless run: want exit 2, got $rc"; fi

run_scoped "$OUT" --perm DNS:Edit --zone-id z1 --ttl nonsense -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "malformed --ttl" "$OUT"; then ok "a malformed --ttl is a usage error"; else bad "malformed --ttl: want exit 2, got $rc"; fi

run_scoped "$OUT" --perm; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "requires a value" "$OUT"; then ok "a bare value-taking flag is refused (no flag-eating)"; else bad "bare --perm: want exit 2, got $rc"; fi

# ── 2. the lifecycle: mint → run-with-token → burn ────────────────────────────
echo "mint-use-burn lifecycle:"

run_scoped "$OUT" --perm DNS:Edit --zone-id zone-xyz-777 --ttl 120 --slug tst -- \
  bash -c 'echo "CMD-RAN token-present=$([[ -n "${CF_SCOPED_TOKEN:-}" ]] && echo yes || echo no)" >> "$STUB_DIR/calls.log"; printf "%s" "${CF_SCOPED_TOKEN:-}" > "$STUB_DIR/seen"'; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "happy path exits 0"; else bad "happy path: want exit 0, got $rc — $(tail -8 "$OUT")"; fi
if [[ "$(cat "$STUB_DIR/seen" 2>/dev/null)" == "$FAKE_TOKEN" ]]; then
  ok "the command receives the minted value in CF_SCOPED_TOKEN, byte-exactly"
else bad "the command saw the wrong token: [$(cat "$STUB_DIR/seen" 2>/dev/null)]"; fi
POST_BODY="$(grep '^curl POST .*user/tokens ' "$CALLS" | head -1 | sed 's/^.*body=//')"
TOKEN_NAME="$(jq -r '.name' <<<"$POST_BODY")"
if [[ "$TOKEN_NAME" =~ ^cfsr-[0-9]+-t120-tst$ ]]; then
  ok "the token name carries the convention: cfsr-<epoch>-t<ttl-seconds>-<slug> ($TOKEN_NAME)"
else bad "token name off-convention: $TOKEN_NAME"; fi
if [[ -n "$(jq -r '.expires_on // empty' <<<"$POST_BODY")" ]]; then
  ok "the mint carries expires_on (the TTL floor rides the token itself)"
else bad "no expires_on in the mint body: $POST_BODY"; fi
MINT_LINE="$(grep -n '^curl POST .*user/tokens ' "$CALLS" | head -1 | cut -d: -f1)"
CMD_LINE="$(grep -n '^CMD-RAN' "$CALLS" | head -1 | cut -d: -f1)"
BURN_LINE="$(grep -n '^curl DELETE .*user/tokens/tok-0001' "$CALLS" | head -1 | cut -d: -f1)"
if [[ -n "$MINT_LINE" && -n "$CMD_LINE" && -n "$BURN_LINE" && "$MINT_LINE" -lt "$CMD_LINE" && "$CMD_LINE" -lt "$BURN_LINE" ]]; then
  ok "order is mint → command → burn (lines $MINT_LINE < $CMD_LINE < $BURN_LINE)"
else bad "lifecycle order wrong: mint@${MINT_LINE:-none} cmd@${CMD_LINE:-none} burn@${BURN_LINE:-none}"; fi
if ! grep -qF "$FAKE_TOKEN" "$OUT"; then ok "the token value appears nowhere in the wrapper's output"; else bad "the token value leaked into the output"; fi
if [[ -z "$(ls -A "$STUB_DIR/tmp" 2>/dev/null)" ]]; then ok "the value temp file does not outlive the run"; else bad "temp residue: $(ls "$STUB_DIR/tmp")"; fi

# A failing command: its exit code survives, the burn still happens.
run_scoped "$OUT" --perm DNS:Edit --zone-id zone-xyz-777 -- bash -c 'exit 7'; rc=$?
if [[ "$rc" -eq 7 ]]; then ok "a failing command's exit code is preserved (7)"; else bad "want exit 7, got $rc"; fi
if grep -q '^curl DELETE .*user/tokens/tok-0001' "$CALLS"; then
  ok "…and the token is STILL burned (the trap owes the burn regardless of outcome)"
else bad "a failed command skipped the burn"; fi

# ── 3. a failed mint: no command, no orphan ───────────────────────────────────
echo "failed mint:"

echo "200 bad" >"$STUB_DIR/verify.plan"
run_scoped "$OUT" --perm DNS:Edit --zone-id zone-xyz-777 -- \
  bash -c 'echo "CMD-RAN" >> "$STUB_DIR/calls.log"'; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "a mint that fails its verify gate exits 1"; else bad "failed mint: want exit 1, got $rc"; fi
if ! grep -q '^CMD-RAN' "$CALLS"; then ok "the command NEVER ran without a verified token"; else bad "the command ran off a failed mint"; fi
if grep -q '^curl DELETE .*user/tokens/tok-0001' "$CALLS"; then
  ok "the orphaned token from the failed verify is revoked by the wrapper"
else bad "the failed mint left its orphan behind: $(grep DELETE "$CALLS")"; fi

# ── 4. a failed burn is not a green run ───────────────────────────────────────
echo "failed burn:"

echo "200 ok" >"$STUB_DIR/verify.plan"
touch "$STUB_DIR/delete.fail"
run_scoped "$OUT" --perm DNS:Edit --zone-id zone-xyz-777 -- true; rc=$?
rm -f "$STUB_DIR/delete.fail"
if [[ "$rc" -ne 0 ]]; then ok "a green command with a failed burn exits non-zero (got $rc)"; else bad "a leaked credential was reported as a green run"; fi
if grep -q "may still be live" "$OUT"; then ok "…and the failure names the risk and the TTL bound"; else bad "no leak warning: $(tail -3 "$OUT")"; fi

# ── 5. dry-run stays offline ──────────────────────────────────────────────────
echo "dry-run:"

run_scoped "$OUT" --dry-run --perm DNS:Edit --zone-id zone-xyz-777 -- \
  bash -c 'echo "CMD-RAN" >> "$STUB_DIR/calls.log"'; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "--dry-run makes zero network calls"; else bad "dry-run: exit $rc, calls: $(cat "$CALLS")"; fi
if ! grep -q '^CMD-RAN' "$CALLS" && grep -q "would then run" "$OUT"; then
  ok "…the command is described, not executed"
else bad "dry-run ran the command or omitted the plan"; fi

# ── 6. stale enumeration reads the naming convention back ─────────────────────
echo "stale tokens (--list-stale / --burn-stale):"

NOW="$(date -u +%s)"
cat >"$STUB_DIR/list.json" <<EOF
[{"id":"tok-old","status":"active","name":"cfsr-1000000000-t60-old"},
 {"id":"tok-new","status":"active","name":"cfsr-${NOW}-t86400-new"},
 {"id":"tok-other","status":"active","name":"a-long-lived-deploy-token"}]
EOF

run_scoped "$OUT" --list-stale; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "--list-stale exits 1 when stale tokens exist"; else bad "list-stale with residue: want exit 1, got $rc — $(tail -5 "$OUT")"; fi
if grep -q "cfsr-1000000000-t60-old" "$OUT"; then ok "the over-TTL cfsr token is listed as stale"; else bad "the stale token was not listed"; fi
if ! grep -q "STALE: cfsr-${NOW}-t86400-new" "$OUT"; then ok "a cfsr token still inside its TTL is not stale"; else bad "a fresh token was called stale"; fi
if ! grep -q "a-long-lived-deploy-token" "$OUT"; then ok "tokens outside the cfsr convention are not ours to report"; else bad "a foreign token was reported"; fi

run_scoped "$OUT" --burn-stale; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--burn-stale exits 0 when every stale token burns"; else bad "burn-stale: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
if grep -q '^curl DELETE .*user/tokens/tok-old' "$CALLS"; then ok "the stale token is revoked by id"; else bad "the stale token was not revoked"; fi
if ! grep -q '^curl DELETE .*user/tokens/tok-new' "$CALLS" && ! grep -q '^curl DELETE .*user/tokens/tok-other' "$CALLS"; then
  ok "fresh and foreign tokens are NEVER touched (the convention is the ownership boundary)"
else bad "burn-stale deleted a token it does not own: $(grep DELETE "$CALLS")"; fi

cat >"$STUB_DIR/list.json" <<EOF
[{"id":"tok-new","status":"active","name":"cfsr-${NOW}-t86400-new"}]
EOF
run_scoped "$OUT" --list-stale; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--list-stale exits 0 when nothing is stale"; else bad "clean list-stale: want exit 0, got $rc"; fi

run_scoped "$OUT" --burn-stale --dry-run; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "--burn-stale --dry-run stays offline"; else bad "burn-stale dry-run touched the network: $(cat "$CALLS")"; fi
rm -f "$STUB_DIR/list.json"


# ── 7. profiles: the named purposes, declared as data ─────────────────────────
echo "profiles (--profile / --list-profiles):"

run_scoped "$OUT" --list-profiles; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "--list-profiles is offline"; else bad "--list-profiles: exit $rc, calls $(cat "$CALLS")"; fi
if grep -q "dns-edit" "$OUT" && grep -q "zone-harden" "$OUT"; then ok "…and names the profiles the file declares"; else bad "profile listing is empty"; fi

run_scoped "$OUT" --profile no-such-profile --zone-id z1 -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "unknown profile 'no-such-profile'" "$OUT"; then ok "an unknown profile is refused BY NAME"; else bad "unknown profile: want exit 2 + named refusal, got $rc"; fi
if grep -q "Known profiles:" "$OUT" && [[ ! -s "$CALLS" ]]; then ok "…listing the known ones, before any network call"; else bad "unknown profile did not list alternatives or hit the network"; fi

# The listing answers "how far does this reach" at the moment of choosing, so
# the reach has to be IN it — split by level, because the level decides how far
# a mistake goes. Asserted on the real profiles.conf: dns-edit changes DNS and
# only reads Zone, and printing that the other way round would be a lie about a
# blast radius.
run_scoped "$OUT" --list-profiles
if grep -qE '^[[:space:]]*changes[[:space:]]+.*DNS' "$OUT" && grep -qE '^[[:space:]]*reads[[:space:]]+' "$OUT"; then
  ok "…splitting each profile's reach into what it changes and what it reads"
else bad "profile listing does not separate changed from read permissions"; fi
if grep -qE '^[[:space:]]*reads[[:space:]]+DNS, Zone' "$OUT"; then
  ok "…and a read-only profile shows no 'changes' reach at all"
else bad "dns-read did not render as read-only"; fi

# The profile set the run under test actually reads — the denominator for the
# conservation check below. Counting against the file the tool reads, rather
# than against the tool's own output, is the whole point: a parser that silently
# skipped a block would otherwise agree with itself.
PROFILES_SRC="$(cd "$(dirname "$SCRIPT")" && pwd)/profiles.conf"

# The machine-readable emit is the contract shell completion depends on, which
# is why it exists: completion must never become a second parser of
# profiles.conf. One record per profile, tab-separated, no decoration.
run_scoped "$OUT" --profile-names; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "--profile-names is offline"; else bad "--profile-names: exit $rc, calls $(cat "$CALLS")"; fi
if [[ "$(grep -c . "$OUT")" -eq "$(grep -c '^profile:' "$PROFILES_SRC")" ]]; then
  ok "…emitting exactly one record per profile the file declares"
else bad "--profile-names emitted $(grep -c . "$OUT") records for $(grep -c '^profile:' "$PROFILES_SRC") profiles"; fi
if awk -F'\t' 'NF!=4{exit 1}' "$OUT"; then
  ok "…every record carrying name, scope, ttl and purpose as four tab-separated fields"
else bad "--profile-names emitted a record without exactly 4 tab-separated fields"; fi
if ! grep -qP '\033' "$OUT" 2>/dev/null && ! grep -q '==' "$OUT"; then
  ok "…with no colour or header, safe for a program to read"
else bad "--profile-names emitted decoration"; fi

# A typo should be answered, not just rejected. The refusal still refuses —
# the suggestion only rides along with it.
run_scoped "$OUT" --profile dns --zone-id z1 -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "Did you mean 'dns-edit'" "$OUT"; then
  ok "a near-miss profile name is answered with the nearest real one"
else bad "near-miss profile: want exit 2 + a suggestion, got $rc"; fi
if [[ "$rc" -eq 2 ]] && grep -q "Known profiles:" "$OUT"; then
  ok "…without replacing the full list, and still a refusal"
else bad "the suggestion swallowed the refusal or the profile list"; fi

run_scoped "$OUT" --profile dns-edit -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "zone-scoped and no zone was named" "$OUT"; then ok "a zone profile with no zone is refused (no accidental account-wide reach)"; else bad "zoneless zone-profile: want exit 2, got $rc"; fi

run_scoped "$OUT" --profile pages-deploy --zone-id z1 -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "account-scoped and cannot be narrowed" "$OUT"; then ok "an account profile given a zone is refused (the scoping would be a lie)"; else bad "zoned account-profile: want exit 2, got $rc"; fi

run_scoped "$OUT" --profile dns-edit --zone-id zone-xyz-777 --slug prof -- true; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "a profile run completes the whole lifecycle"; else bad "profile run: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
POSTED="$(grep -m1 '^curl POST .*user/tokens' "$CALLS" || true)"
if grep -q 'cfsr-[0-9]*-t900-prof' <<<"$POSTED"; then ok "the profile's default TTL (15m) lands in the token name"; else bad "profile TTL not applied: $POSTED"; fi
if grep -q '^curl DELETE .*user/tokens/' "$CALLS"; then ok "…and the profile-minted token is burned like any other"; else bad "profile run did not burn"; fi

run_scoped "$OUT" --profile dns-edit --zone-id zone-xyz-777 --ttl 5m -- true; rc=$?
if grep -q 'cfsr-[0-9]*-t300-dns-edit' "$CALLS"; then ok "an explicit --ttl overrides the profile default, and the slug defaults to the profile name"; else bad "TTL override/slug default failed: $(grep -m1 POST "$CALLS")"; fi

run_scoped "$OUT" --dry-run --profile zone-harden --zone example.test -- true; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "a profile dry-run stays offline"; else bad "profile dry-run touched the network"; fi
if grep -q "Analytics:Read" "$OUT" && grep -q "profile 'zone-harden'" "$OUT"; then ok "…and prints the exact permission set it would mint"; else bad "profile dry-run did not print the permission set"; fi

# ── 8. the minter credential: precedence and named refusal ────────────────────
echo "minter credential:"

: >"$CALLS"; rm -rf "$STUB_DIR/tmp"; mkdir -p "$STUB_DIR/tmp"
PATH="$STUB_DIR:$PATH" TMPDIR="$STUB_DIR/tmp" \
  env -u CF_MINTER_TOKEN -u CF_MINTER_CMD -u CF_MINTER_VAULT_SECRET -u OPS_VAULT_NAME \
  bash "$SCRIPT" --profile dns-edit --zone-id z1 -- true >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "no minter credential" "$OUT"; then ok "a missing minter refuses BY NAME"; else bad "missing minter: want a named refusal, got $rc — $(tail -3 "$OUT")"; fi
if grep -q "command was NOT run" "$OUT"; then ok "…and the command never ran without a credential"; else bad "missing minter: the command may have run"; fi
if grep -q -- "--minter-cmd" "$OUT" && [[ ! -s "$CALLS" ]]; then ok "…naming every way to supply one, before any network call"; else bad "missing-minter message does not name the alternatives"; fi

printf '%s' "fake-minter-from-store" >"$STUB_DIR/minter.txt"
: >"$CALLS"; rm -rf "$STUB_DIR/tmp"; mkdir -p "$STUB_DIR/tmp"
PATH="$STUB_DIR:$PATH" TMPDIR="$STUB_DIR/tmp" \
  env -u CF_MINTER_TOKEN \
  bash "$SCRIPT" --minter-cmd "cat $STUB_DIR/minter.txt" \
    --profile dns-edit --zone-id zone-xyz-777 -- true >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--minter-cmd pulls the minter from an arbitrary secret store"; else bad "--minter-cmd run: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
if grep -q '^curl POST .*user/tokens' "$CALLS"; then ok "…and the mint proceeded on the fetched credential"; else bad "--minter-cmd did not reach the mint"; fi
if ! grep -q "fake-minter-from-store" "$OUT"; then ok "…with the fetched value never printed"; else bad "the minter value LEAKED into the output"; fi

: >"$CALLS"; rm -rf "$STUB_DIR/tmp"; mkdir -p "$STUB_DIR/tmp"
PATH="$STUB_DIR:$PATH" TMPDIR="$STUB_DIR/tmp" \
  env -u CF_MINTER_TOKEN \
  bash "$SCRIPT" --minter-cmd "exit 3" \
    --profile dns-edit --zone-id z1 -- true >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "minter fetch command failed" "$OUT"; then ok "a failing secret-fetch fails loudly, it is not skipped"; else bad "failing --minter-cmd: got $rc — $(tail -3 "$OUT")"; fi

run_scoped "$OUT" --minter-token hunter2 --profile dns-edit --zone-id z1 -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "argv is world-readable" "$OUT"; then ok "a token on argv is refused with the reason (ps leaks it)"; else bad "--minter-token: want a named refusal, got $rc"; fi

# ── 9. burn on interrupt ──────────────────────────────────────────────────────
# Job control (`set -m`) is switched on for this case ON PURPOSE: bash sets SIGINT
# to SIG_IGN in a command started asynchronously without job control, and a `trap`
# cannot override an INHERITED ignore — so a plain `cmd & kill -INT` would prove
# nothing about the tool, only about the harness. With -m the run gets its own
# process group and a real Ctrl-C is delivered the way a terminal delivers it.
echo "burn on interrupt:"
set -m

: >"$CALLS"; rm -rf "$STUB_DIR/tmp"; mkdir -p "$STUB_DIR/tmp"
PATH="$STUB_DIR:$PATH" TMPDIR="$STUB_DIR/tmp" CF_MINTER_TOKEN="fake-minter-value" \
  bash "$SCRIPT" --profile dns-edit --zone-id zone-xyz-777 -- \
  bash -c 'echo READY >"$STUB_DIR/ready"; sleep 30' >"$OUT" 2>&1 </dev/null &
WRAP_PID=$!
for _ in $(seq 1 100); do [[ -f "$STUB_DIR/ready" ]] && break; sleep 0.1; done
kill -INT "$WRAP_PID" 2>/dev/null
wait "$WRAP_PID"; rc=$?
if [[ -f "$STUB_DIR/ready" ]]; then ok "the wrapped command was running when the interrupt arrived"; else bad "the command never started — the interrupt case proves nothing"; fi
if grep -q '^curl DELETE .*user/tokens/' "$CALLS"; then ok "SIGINT still burns the token (the trap owes it on every exit path)"; else bad "INTERRUPT LEAKED THE TOKEN: $(cat "$CALLS")"; fi
if [[ "$rc" -eq 130 ]]; then ok "…and an interrupted run exits 130, not 0"; else bad "an interrupted run exited 0"; fi
set +m
rm -f "$STUB_DIR/ready"

run_scoped "$OUT" --profile dns-edit --zone-id zone-xyz-777 -- \
  bash -c 'printf "ENVCHECK %s %s\n" "$CLOUDFLARE_API_TOKEN" "$CF_SCOPED_TOKEN" >> "$STUB_DIR/calls.log"'; rc=$?
if grep -q "ENVCHECK $FAKE_TOKEN $FAKE_TOKEN" "$CALLS"; then ok "the command gets the value under BOTH names (CLOUDFLARE_API_TOKEN for unmodified tools)"; else bad "the two env names do not both carry the value: $(grep ENVCHECK "$CALLS")"; fi

# ── 10. --mint-only: mint, print, do not burn ─────────────────────────────────
echo "mint-only:"

run_scoped "$OUT" --mint-only --profile dns-edit --zone-id zone-xyz-777; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--mint-only exits 0"; else bad "--mint-only: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
if grep -q "$FAKE_TOKEN" "$OUT"; then ok "…prints the value once, for hand-driven use"; else bad "--mint-only printed no value"; fi
if ! grep -q '^curl DELETE .*user/tokens/' "$CALLS"; then ok "…and does NOT burn (the TTL is what ends it)"; else bad "--mint-only burned the token it was asked to hand over"; fi
if grep -q "burn-stale" "$OUT"; then ok "…while naming how to clean it up"; else bad "--mint-only did not say how to burn it"; fi

run_scoped "$OUT" --mint-only --profile dns-edit --zone-id z1 -- true; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q -- "--mint-only takes no command" "$OUT"; then ok "--mint-only with a command is a usage error"; else bad "--mint-only + command: want exit 2, got $rc"; fi

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "cf-scoped-run tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
