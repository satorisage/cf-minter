#!/usr/bin/env bash
#
# cf-mint-token.test.sh — proves the token minter's two safety properties without
# ever touching Cloudflare or a vault:
#
#   1. Argument guards: every value-taking flag (--revoke above all — it drives a
#      DELETE) refuses a missing value instead of swallowing the next flag as its
#      value or looping forever when left bare at the end of argv. A bare
#      `--revoke --dry-run` must be a usage error (exit 2) with ZERO network
#      calls — the unguarded parser used to turn it into a LIVE delete of the
#      token id "--dry-run".
#
#   2. Verify-before-vault: after POST /user/tokens the minted value must be
#      verified (GET /user/tokens/verify authenticated AS the new token) before
#      it is presented as usable or stored. On verify failure the vault is never
#      written and the exit code is 1. The token value must reach the vault
#      byte-exactly (this doubles as the mangling/truncation regression check
#      for the extraction + store path).
#
# Hermetic: curl and az are PATH-stubbed binaries that log their argv to a
# chronological call log and answer with canned Cloudflare-shaped JSON. Only
# fabricated token values appear anywhere. The propagation-retry path is
# exercised with one stubbed 401 (costs one 5s backoff sleep).
#
# Run:  bash test/cf-mint-token.test.sh   (exit 0 = all pass)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../cf-mint-token.sh"

PASS=0 FAIL=0
ok(){   PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad(){  FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1" >&2; }

STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT
export STUB_DIR
CALLS="$STUB_DIR/calls.log"
export AZ_CORE="$HERE/fixtures/az-core.sh"           # what az's core does to an argument; the az stub uses it
export AZ_PROBE="$HERE/fixtures/az-vault-probe.sh"   # what Key Vault does to the store-write probe's calls
export VAULT_PROBE_BACKOFF=0                         # the probe's retry backoff, zeroed so a scripted 429 costs no time

# A fabricated token value with the hostile shape of a real one (40 chars of
# [A-Za-z0-9_-], leading underscore, embedded hyphens) so byte-exact passage
# through jq extraction and the az argv can be asserted.
FAKE_TOKEN="_Fk-token_0123456789abcdef-ABCDEF_xyz99"
printf '%s' "$FAKE_TOKEN" >"$STUB_DIR/token.txt"

# ── stub curl ─────────────────────────────────────────────────────────────────
# Logs "curl METHOD URL auth=BEARER" per call, answers by endpoint. Honors the
# retry lib's `-w '\n%{http_code}'` by appending the HTTP code on its own line.
# The verify endpoint's per-call behavior is scripted by verify.plan: one line
# per call, "CODE ok" or "CODE bad" (consumed top-down; last line repeats).
cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
set -u
url=""; method="GET"; auth=""; wfmt=0; data=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -X) method="${args[$((i+1))]}" ;;
    # The bearer arrives as curl config on stdin (-K -), never as an argument: a
    # header on argv is ignored, so a call that put the token there carries none.
    -K) if [[ "${args[$((i+1))]}" == - ]]; then
          h="$(sed -n 's/^header = "\(.*\)"$/\1/p')"
          case "$h" in [Aa]uthorization:*) auth="${h#*[Bb]earer }" ;; esac
        fi ;;
    -w) wfmt=1 ;;
    --data) data="${args[$((i+1))]}" ;;
    https://*) url="${args[$i]}" ;;
  esac
done
# The command line as any other process would see it: no credential may appear here.
printf '%s\n' "$*" >>"$STUB_DIR/curl-argv.log"
# The request BODY is logged too: the token's policy (which permission groups, on
# which resources) is the whole point of a mint, and it is only visible here.
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
      ok)
        body='{"success":true,"errors":[],"result":{"id":"tok-0001","status":"active"}}' ;;
      prop)
        # The real propagation transient: code 10000 — the ONLY 401 the retry lib
        # rides. (code 1000 = genuinely invalid, refused on the first attempt.)
        body='{"success":false,"errors":[{"code":10000,"message":"Authentication error"}],"result":null}' ;;
      *)
        body='{"success":false,"errors":[{"code":1000,"message":"Invalid API Token"}],"result":null}' ;;
    esac ;;
  "GET "*"/user/tokens/permission_groups")
    if [[ -f "$STUB_DIR/pg.deny" ]]; then
      code=403
      body='{"success":false,"errors":[{"code":9109,"message":"Unauthorized to access requested resource"}],"result":null}'
    elif [[ -f "$STUB_DIR/catalog.json" ]]; then
      # A case may stage its own catalogue; otherwise the default below.
      body="$(cat "$STUB_DIR/catalog.json")"
    else
      # "Access: Apps and Policies Write" is published TWICE under one name at
      # two different scopes. That is real Cloudflare behaviour, not a contrived
      # fixture: it is exactly what made a live mint fail with "2 candidates".
      body='{"success":true,"errors":[],"result":[{"id":"pg-dns-write","name":"DNS Write","scopes":["com.cloudflare.api.account.zone"]},{"id":"pg-aap-write-acct","name":"Access: Apps and Policies Write","scopes":["com.cloudflare.api.account"]},{"id":"pg-aap-write-zone","name":"Access: Apps and Policies Write","scopes":["com.cloudflare.api.account.zone"]},{"id":"pg-tunnel-write","name":"Cloudflare Tunnel Write","scopes":["com.cloudflare.api.account"]},{"id":"pg-cache-purge","name":"Cache Purge","scopes":["com.cloudflare.api.account.zone"]}]}'
    fi ;;
  "GET "*"/accounts")
    # Reached only when a mint carries an account-scoped permission. Before
    # @scope disambiguation existed, no test used one, so this endpoint was
    # never stubbed and an account-scoped mint died on "unexpected endpoint".
    body='{"success":true,"errors":[],"result":[{"id":"acct-abc-123","name":"Stub Account"}]}' ;;
  "GET "*"/zones?name="*)
    body='{"success":true,"errors":[],"result":[{"id":"zone-abc-123"}]}' ;;
  "DELETE "*"/user/tokens/"*)
    if [[ -f "$STUB_DIR/delete.fail" ]]; then
      body='{"success":false,"errors":[{"code":7000,"message":"stub: delete refused"}]}'
    else
      body="{\"success\":true,\"errors\":[],\"result\":{\"id\":\"${url##*/}\"}}"
    fi ;;
  "POST "*"/user/tokens")
    body="{\"success\":true,\"errors\":[],\"result\":{\"id\":\"tok-0001\",\"name\":\"t\",\"value\":\"$tok\"}}" ;;
  "GET "*"/user/tokens")
    if [[ -f "$STUB_DIR/list.json" ]]; then body="$(cat "$STUB_DIR/list.json")"
    else body='{"success":true,"errors":[],"result":[]}'; fi ;;
  *)
    body='{"success":false,"errors":[{"code":9999,"message":"stub: unexpected endpoint"}]}' ;;
esac
if [[ "$wfmt" -eq 1 ]]; then printf '%s\n%s' "$body" "$code"; else printf '%s' "$body"; fi
STUB
chmod +x "$STUB_DIR/curl"

# ── stub az ───────────────────────────────────────────────────────────────────
cat >"$STUB_DIR/az" <<'STUB'
#!/usr/bin/env bash
# argv.log records the command line as any other process would see it; calls.log
# records each command as az's core expands it (an @<file> read in), i.e. as az parses it.
printf 'argv %s\n' "$*" >>"$STUB_DIR/argv.log"
# shellcheck source=fixtures/az-core.sh
source "$AZ_CORE"; az_core_args "$@"
printf 'az %s\n' "${AZ_CORE_ARGS[*]}" >>"$STUB_DIR/calls.log"
# The vault-store probe's own calls are answered the way Key Vault would (and can be
# scripted to refuse); every other call is the no-op success it always was.
# shellcheck source=fixtures/az-vault-probe.sh
source "$AZ_PROBE"; if az_vault_probe "$@"; then exit "$AZ_PROBE_RC"; fi
exit 0
STUB
chmod +x "$STUB_DIR/az"

# run_mint <outfile> <args…> — run the tool with stubs on PATH, a fake minter,
# stdin closed (the retry lib buffers stdin when it is not a tty), and a fresh
# call log. Echoes nothing; exit status is the tool's.
run_mint(){
  local out="$1"; shift
  : >"$CALLS"; : >"$STUB_DIR/argv.log"; rm -f "$STUB_DIR/verify.count"
  PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN="fake-minter-value" OPS_VAULT_NAME="fake-vault" \
    bash "$SCRIPT" "$@" >"$out" 2>&1 </dev/null
}

# run_guarded <timeout-s> <outfile> <args…> — like run_mint but killed if it
# hangs (the unguarded parser looped forever on a bare trailing flag). 124 = hung.
run_guarded(){
  local t="$1" out="$2"; shift 2
  : >"$CALLS"; : >"$STUB_DIR/argv.log"; rm -f "$STUB_DIR/verify.count"
  PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN="fake-minter-value" OPS_VAULT_NAME="fake-vault" \
    bash "$SCRIPT" "$@" >"$out" 2>&1 </dev/null &
  local pid=$! i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$((i+1))
    if [[ $i -gt $((t*10)) ]]; then kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; return 124; fi
    sleep 0.1
  done
  wait "$pid"
}

echo "500 bad" >"$STUB_DIR/verify.plan"   # default; each mint test overwrites

OUT="$STUB_DIR/out.txt"

# ── 1. --revoke guards (a delete path must never guess its target) ────────────
echo "revoke guards:"

run_guarded 5 "$OUT" --revoke; rc=$?
if [[ "$rc" -eq 2 ]]; then ok "bare --revoke at end of argv exits 2 (no hang, no delete)"; else bad "bare --revoke: want exit 2, got $rc"; fi
if grep -q "requires a value" "$OUT"; then ok "bare --revoke prints a usage error"; else bad "bare --revoke: no usage error in output"; fi

run_guarded 5 "$OUT" --revoke --dry-run; rc=$?
if [[ "$rc" -eq 2 ]]; then ok "--revoke --dry-run exits 2 (does NOT eat --dry-run as the id)"; else bad "--revoke --dry-run: want exit 2, got $rc"; fi
if [[ ! -s "$CALLS" ]]; then ok "--revoke --dry-run makes zero network/vault calls"; else bad "--revoke --dry-run touched the stubs: $(cat "$CALLS")"; fi

run_guarded 5 "$OUT" --name; rc=$?
if [[ "$rc" -eq 2 ]]; then ok "bare trailing --name exits 2 (parser no longer loops forever)"; else bad "bare --name: want exit 2, got $rc (124 = hung)"; fi

run_guarded 5 "$OUT" --vault-secret --name t; rc=$?
if [[ "$rc" -eq 2 ]]; then ok "--vault-secret followed by a flag exits 2"; else bad "--vault-secret flag-eat: want exit 2, got $rc"; fi

run_guarded 5 "$OUT" --burn; rc=$?
if [[ "$rc" -eq 2 ]]; then ok "--burn without CF_BURN_TOKEN exits 2 (value is env-only, no argv to eat)"; else bad "--burn without CF_BURN_TOKEN: want exit 2, got $rc"; fi
if [[ ! -s "$CALLS" ]]; then ok "--burn precondition failure makes zero network calls"; else bad "--burn touched the stubs before its guard"; fi

run_mint "$OUT" --revoke tok-dead-beef; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--revoke <id> with a real id succeeds against the stub"; else bad "--revoke <id>: want exit 0, got $rc"; fi
if grep -q "curl DELETE .*user/tokens/tok-dead-beef" "$CALLS"; then ok "revoke DELETEs exactly the given id"; else bad "revoke did not DELETE the given id"; fi

# A DELETE Cloudflare refuses must be a failure, not a success report: cf_ok runs
# in a command substitution on the delete paths, so its exit alone only ends the
# subshell — the regression here was "deleted/burned" printed for a token still
# standing.
touch "$STUB_DIR/delete.fail"
run_mint "$OUT" --revoke tok-dead-beef; rc=$?
if [[ "$rc" -eq 1 ]] && ! grep -q "deleted token id" "$OUT"; then
  ok "a refused DELETE fails --revoke (no phantom 'deleted' report)"
else bad "a refused revoke was reported as success: exit $rc — $(tail -3 "$OUT")"; fi
echo "200 ok" >"$STUB_DIR/verify.plan"
: >"$CALLS"; rm -f "$STUB_DIR/verify.count"
PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN="fake-minter-value" CF_BURN_TOKEN="$FAKE_TOKEN" \
  bash "$SCRIPT" --burn >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 1 ]] && ! grep -q "burned token id" "$OUT"; then
  ok "a refused DELETE fails --burn (a live token is never reported burned)"
else bad "a refused burn was reported as success: exit $rc — $(tail -3 "$OUT")"; fi
rm -f "$STUB_DIR/delete.fail"
echo "500 bad" >"$STUB_DIR/verify.plan"

# ── 2. mint: verify gate + vault ordering + byte-exact store ──────────────────
echo "mint (verify-before-vault):"

echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "happy-path mint exits 0"; else bad "happy-path mint: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
if grep -q "curl GET .*user/tokens/verify auth=$FAKE_TOKEN" "$CALLS"; then
  ok "verify call authenticates AS the minted token (not the minter)"
else
  bad "verify was not made with the minted token's own bearer"
fi
vline="$(grep -n "user/tokens/verify" "$CALLS" | head -1 | cut -d: -f1)"
aline="$(grep -n '^az keyvault secret set ' "$CALLS" | grep -v -- '--name mint-store-probe ' | head -1 | cut -d: -f1)"
if [[ -n "$vline" && -n "$aline" && "$vline" -lt "$aline" ]]; then
  ok "vault write happens strictly AFTER verify (order: verify line $vline < az line $aline)"
else
  bad "vault write is not gated behind verify (verify line '$vline', az line '$aline')"
fi
if grep -q -- "--value $FAKE_TOKEN " "$CALLS" || grep -q -- "--value $FAKE_TOKEN\$" "$CALLS"; then
  ok "vault receives the token byte-exactly (no field/whitespace/truncation mangling)"
else
  bad "vault value differs from the minted value: $(grep '^az' "$CALLS")"
fi
if ! grep -qF -- "$FAKE_TOKEN" "$STUB_DIR/argv.log" && grep -q -- '^argv keyvault secret set .*--value @' "$STUB_DIR/argv.log"; then
  ok "…and never on az's command line: it reaches az as a file az reads (--value @<file>)"
else
  bad "the minted value rode az's command line: $(grep '^argv keyvault' "$STUB_DIR/argv.log")"
fi
if grep -q "value: $FAKE_TOKEN" "$OUT"; then ok "boxed output shows the exact minted value"; else bad "boxed output does not show the minted value"; fi

echo "200 bad" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "verify failure exits 1"; else bad "verify failure: want exit 1, got $rc"; fi
if ! grep '^az keyvault secret set ' "$CALLS" | grep -qv -- '--name mint-store-probe '; then
  ok "verify failure never writes the vault (existing secret survives)"
else
  bad "verify failure STILL wrote the vault: $(grep '^az' "$CALLS")"
fi
if grep -q "FAILED VERIFICATION" "$OUT"; then ok "verify failure is reported loudly"; else bad "no clear verify-failure message"; fi
if grep -q -- "--revoke tok-0001" "$OUT"; then ok "failure output names the cleanup command with the token id"; else bad "failure output lacks the revoke hint"; fi
if grep -q "\[1000\]" "$OUT"; then ok "Cloudflare's error code is surfaced"; else bad "CF error code not surfaced"; fi

# One transient 401 (propagation window, code 10000), then active: must ride the
# retry and pass.
printf '401 prop\n200 ok\n' >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "verify rides one propagation 401 and succeeds (retry lib engaged)"; else bad "verify did not survive a transient 401: exit $rc"; fi
if [[ "$(cat "$STUB_DIR/verify.count")" -eq 2 ]]; then ok "verify was attempted exactly twice (401 then active)"; else bad "unexpected verify attempt count: $(cat "$STUB_DIR/verify.count")"; fi

# A genuinely-invalid token (401 code 1000) must FAIL on the first attempt — no
# propagation window to wait out, no retry budget burned.
printf '401 bad\n' >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "invalid token (code 1000) fails verify"; else bad "invalid-token verify: want exit 1, got $rc"; fi
if [[ "$(cat "$STUB_DIR/verify.count")" -eq 1 ]]; then ok "refused on the FIRST attempt (no ~110s budget burn)"; else bad "invalid token retried: $(cat "$STUB_DIR/verify.count") attempts"; fi

# ── 3. dry-run stays offline and states the verify plan ───────────────────────
echo "dry-run:"

run_mint "$OUT" --dry-run --name t --perm DNS:Edit --zone example.test --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "mint --dry-run exits 0"; else bad "mint --dry-run: want exit 0, got $rc"; fi
if [[ ! -s "$CALLS" ]]; then ok "mint --dry-run runs no curl and no az"; else bad "mint --dry-run touched the stubs: $(cat "$CALLS")"; fi
if grep -qi "VERIFY the minted token" "$OUT"; then ok "dry-run plan includes the verify step"; else bad "dry-run plan omits the verify step"; fi
if grep -q "only after verify passes" "$OUT"; then ok "dry-run plan states the vault write is gated on verify"; else bad "dry-run plan does not gate the vault write"; fi

run_mint "$OUT" --dry-run --revoke tok-dead-beef; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "revoke --dry-run exits 0 with no calls"; else bad "revoke --dry-run: exit $rc, calls: $(cat "$CALLS")"; fi

# ── 4. --zone-id: scope by the id itself, no name lookup ──────────────────────
# An automated caller holds the zone ID as its authoritative value (it is what its
# terraform writes with). Resolving a NAME to an id in between is a second
# derivation that could aim the token at a different zone than the caller uses.
echo "--zone-id (scope without a name lookup):"

echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--zone-id mint exits 0"; else bad "--zone-id mint: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
if ! grep -q "curl GET .*zones?name=" "$CALLS"; then ok "no zone-name lookup is made"; else bad "--zone-id still resolved a name: $(grep 'zones?name' "$CALLS")"; fi
POST_BODY="$(grep '^curl POST .*user/tokens ' "$CALLS" | head -1 | sed 's/^.*body=//')"
if grep -q '"com.cloudflare.api.account.zone.zone-xyz-777":"\*"' <<<"$POST_BODY"; then
  ok "the policy resource is the given zone id, verbatim"
else bad "policy did not carry the given zone id: $POST_BODY"; fi
if [[ "$(jq '.policies | length' <<<"$POST_BODY")" -eq 1 ]] \
   && [[ "$(jq -r '.policies[0].resources | keys[]' <<<"$POST_BODY")" == "com.cloudflare.api.account.zone.zone-xyz-777" ]]; then
  ok "exactly ONE policy, one resource — no account-wide scope rides along"
else bad "policy shape is wider than the one zone: $POST_BODY"; fi

run_mint "$OUT" --name t --perm DNS:Edit --vault-secret cf-token; rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "no --zone/--zone-id was given" "$OUT"; then
  ok "a zone-scoped perm with neither --zone nor --zone-id is refused"
else bad "unscoped zone perm was accepted: exit $rc — $(tail -3 "$OUT")"; fi

run_mint "$OUT" --dry-run --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "--zone-id --dry-run stays offline"; else bad "--zone-id dry-run: exit $rc, calls: $(cat "$CALLS")"; fi
if grep -q "com.cloudflare.api.account.zone.zone-xyz-777" "$OUT"; then ok "dry-run renders the real zone resource (no placeholder)"; else bad "dry-run zone resource wrong: $(grep zone "$OUT" | head -3)"; fi

# ── 5. --no-print-value: the vault is the only copy ───────────────────────────
# An unattended caller's stdout is a run log. A token value printed there outlives
# the run in whatever captured it, so the box is suppressible — but only when the
# value has somewhere else to land, or it would be created and lost at once.
echo "--no-print-value (unattended callers):"

echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--no-print-value mint exits 0"; else bad "--no-print-value mint: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
if ! grep -qF "$FAKE_TOKEN" "$OUT"; then ok "the minted value appears NOWHERE in the output"; else bad "the token value leaked into stdout"; fi
if grep -q -- "--value $FAKE_TOKEN" "$CALLS"; then ok "…but it still reaches the vault byte-exactly"; else bad "vault write lost the value: $(grep '^az' "$CALLS")"; fi
if grep -q "tok-0001" "$OUT"; then ok "the token id is still reported (the handle for a revoke)"; else bad "no token id in the output"; fi

run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --no-print-value; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q -- "--no-print-value needs --vault-secret" "$OUT"; then
  ok "--no-print-value without --vault-secret is a usage error (would create-and-lose a token)"
else bad "unsafe --no-print-value accepted: exit $rc — $(tail -3 "$OUT")"; fi
if [[ ! -s "$CALLS" ]]; then ok "…refused before any network call (no token was created)"; else bad "it minted before the guard: $(cat "$CALLS")"; fi

# Verify failure with the box suppressed: still no value, still the id to clean up.
echo "200 bad" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "verify failure under --no-print-value exits 1"; else bad "want exit 1, got $rc"; fi
if ! grep -qF "$FAKE_TOKEN" "$OUT"; then ok "the failed token's value is not printed either"; else bad "the value leaked on the failure path"; fi
if grep -q -- "--revoke tok-0001" "$OUT"; then ok "the failure still names the id to revoke"; else bad "no cleanup handle on the failure path"; fi

# ── which vault the minted value is WRITTEN to ────────────────────────────────
# The fleet keeps two vaults and this tool touches both, in different roles: it
# READS the minter from the ops vault (fleet-shared, per-secret grant) and WRITES
# the minted value wherever the caller says. For a credential minted and named per
# instance that write target is the per-instance credential vault — writing it to
# the ops vault instead would put it beside the break-glass signing key, which is
# the exact escalation the vault split exists to prevent. So the target is an
# explicit flag, and the two roles never share one variable.
echo "the write target is chosen by --vault-name, independently of where the minter came from:"

echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 \
  --vault-secret cf-instance-acme-dns-token --vault-name inst-creds-kv --no-print-value; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "a mint with an explicit write vault succeeds"; else bad "want exit 0, got $rc — $(tail -3 "$OUT")"; fi
if grep -q -- "secret set --vault-name inst-creds-kv --name cf-instance-acme-dns-token" "$CALLS"; then
  ok "the value is written to the vault named by --vault-name"
else bad "wrong write target: $(grep '^az' "$CALLS")"; fi
if ! grep -q -- "secret set --vault-name fake-vault" "$CALLS"; then
  ok "…and NOT to OPS_VAULT_NAME, even though the minter came from there"
else bad "the write fell back to the ops vault: $(grep '^az' "$CALLS")"; fi

# Omitted, the target defaults to the ops vault — right for a fleet-shared token
# (cloudflare-token and friends are minted straight back into it).
echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 \
  --vault-secret cloudflare-token --no-print-value; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q -- "secret set --vault-name fake-vault --name cloudflare-token" "$CALLS"; then
  ok "omitting --vault-name writes to OPS_VAULT_NAME (right for a fleet-shared credential)"
else bad "the default write target changed: rc=$rc $(grep '^az' "$CALLS")"; fi

# With neither a --vault-name nor an OPS_VAULT_NAME there is nowhere to put the
# value: refuse before minting rather than create a token nobody can ever use.
: >"$CALLS"; rm -f "$STUB_DIR/verify.count"
PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN="fake-minter-value" \
  bash "$SCRIPT" --name t --perm DNS:Edit --zone-id zone-xyz-777 \
  --vault-secret cf-instance-acme-dns-token --no-print-value >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "needs a vault to write to" "$OUT"; then
  ok "no write target at all is a usage error, named as such"
else bad "a mint with nowhere to store the value was accepted: rc=$rc $(tail -3 "$OUT")"; fi
if [[ ! -s "$CALLS" ]]; then ok "…refused before any network call (no orphan token created)"; else bad "it minted before the guard: $(cat "$CALLS")"; fi

# ── --ttl: the token carries its own expiry ───────────────────────────────────
# The floor under the mint-use-burn pattern: a token whose burn never runs must
# still die on its own, so the mint can state an expires_on. Format-checked
# offline; the instant is computed at POST time.
echo "--ttl (self-expiring tokens):"

echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --ttl 30m; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "a mint with --ttl exits 0"; else bad "--ttl mint: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
POST_BODY="$(grep '^curl POST .*user/tokens ' "$CALLS" | head -1 | sed 's/^.*body=//')"
EXP="$(jq -r '.expires_on // empty' <<<"$POST_BODY")"
if [[ "$EXP" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  ok "the POST body carries an RFC3339 expires_on ($EXP)"
else bad "no well-formed expires_on in the POST body: $POST_BODY"; fi

run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777; rc=$?
POST_BODY="$(grep '^curl POST .*user/tokens ' "$CALLS" | head -1 | sed 's/^.*body=//')"
if [[ "$(jq 'has("expires_on")' <<<"$POST_BODY")" == "false" ]]; then
  ok "a mint WITHOUT --ttl sends exactly the body it always sent (no expires_on)"
else bad "expires_on leaked into a TTL-less mint: $POST_BODY"; fi

run_guarded 5 "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --ttl 2fortnights; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "malformed --ttl" "$OUT"; then
  ok "a malformed --ttl is a usage error, caught offline"
else bad "malformed --ttl accepted: exit $rc — $(tail -3 "$OUT")"; fi
if [[ ! -s "$CALLS" ]]; then ok "…before any network call"; else bad "a malformed TTL still reached the network: $(cat "$CALLS")"; fi

run_guarded 5 "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --ttl 0; rc=$?
if [[ "$rc" -eq 2 ]]; then ok "--ttl 0 is refused (a token born expired can only fail its own verify)"; else bad "--ttl 0 accepted: exit $rc"; fi

run_mint "$OUT" --dry-run --name t --perm DNS:Edit --zone-id zone-xyz-777 --ttl 1h; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "--ttl --dry-run stays offline"; else bad "--ttl dry-run: exit $rc, calls: $(cat "$CALLS")"; fi
if grep -q '"expires_on"' "$OUT"; then ok "…and the dry-run body shows the expiry it would send"; else bad "dry-run body lacks expires_on"; fi

# ── --value-file: the machine-readable handle for a wrapping tool ─────────────
# A wrapper that must hold the value (mint, run a command with it, burn it) gets
# it from a file, not by scraping the printed box — written strictly AFTER the
# verify gate, like the vault, and private by mode.
echo "--value-file (programmatic value hand-off):"

VFILE="$STUB_DIR/value-file"
echo "200 ok" >"$STUB_DIR/verify.plan"
rm -f "$VFILE"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --value-file "$VFILE" --no-print-value; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--value-file --no-print-value mint exits 0 (the file is a valid landing place)"; else bad "value-file mint: want exit 0, got $rc — $(tail -5 "$OUT")"; fi
if [[ "$(cat "$VFILE" 2>/dev/null)" == "$FAKE_TOKEN" ]]; then
  ok "the file receives the token byte-exactly"
else bad "value file content wrong: [$(cat "$VFILE" 2>/dev/null)]"; fi
# Mode, portably. Exit status is NOT a safe discriminator between the two stat
# dialects: GNU's `stat -f` rejects the BSD format string but still prints a
# `File: "..."` line to STDOUT before failing, so `$(bsd || gnu)` captures that
# junk concatenated with the real answer. BSD's `stat -c` fails cleanly with
# empty stdout. So validate the VALUE rather than trusting $? — whichever
# dialect yields octal digits is the right one.
PERMS_OCTAL="$(stat -c '%a' "$VFILE" 2>/dev/null || true)"
[[ "$PERMS_OCTAL" =~ ^[0-7]+$ ]] || PERMS_OCTAL="$(stat -f '%Lp' "$VFILE" 2>/dev/null || true)"
if [[ "$PERMS_OCTAL" == "600" ]]; then ok "…at mode 0600 (private to the minting user)"; else bad "value file mode is $PERMS_OCTAL, want 600"; fi
if ! grep -qF "$FAKE_TOKEN" "$OUT"; then ok "…and the value still appears nowhere in the output"; else bad "the value leaked into stdout"; fi

echo "200 bad" >"$STUB_DIR/verify.plan"
rm -f "$VFILE"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --value-file "$VFILE" --no-print-value; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "verify failure with a value file exits 1"; else bad "want exit 1, got $rc"; fi
if [[ ! -f "$VFILE" ]]; then
  ok "…and the file is NEVER written (the verify gate guards every store, not just the vault)"
else bad "an unverified value was written to the value file"; fi


# ── the minter credential: measured, pluggable, never on argv ─────────────────
echo "minter credential:"

run_mint "$OUT" --qualify-minter; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q "qualified:" "$OUT"; then ok "--qualify-minter passes a credential that CAN read the permission-group catalogue"; else bad "qualify: want exit 0, got $rc — $(tail -3 "$OUT")"; fi
if grep -q 'permission_groups' "$CALLS"; then ok "…by MEASUREMENT (it makes the read), not by the credential's name"; else bad "qualify made no permission-group read"; fi

touch "$STUB_DIR/pg.deny"
run_mint "$OUT" --qualify-minter; rc=$?
if [[ "$rc" -eq 1 ]] && grep -q "canNOT mint" "$OUT"; then ok "a credential that cannot read the catalogue is refused as a minter"; else bad "qualify-deny: want exit 1, got $rc — $(tail -3 "$OUT")"; fi
if grep -q "9109" "$OUT"; then ok "…with Cloudflare's own error body printed, not swallowed"; else bad "the API error body was swallowed"; fi
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test; rc=$?
if [[ "$rc" -ne 0 ]] && ! grep -q '^curl POST' "$CALLS"; then ok "a mint on an unqualified credential fails at the catalogue read — no token is created"; else bad "a token was created on a credential that cannot mint"; fi
rm -f "$STUB_DIR/pg.deny"

: >"$CALLS"
PATH="$STUB_DIR:$PATH" env -u CF_MINTER_TOKEN -u CF_MINTER_VAULT_SECRET -u OPS_VAULT_NAME \
  bash "$SCRIPT" --qualify-minter >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "no minter credential" "$OUT"; then ok "no minter at all is a named refusal, exit 2"; else bad "missing minter: want exit 2, got $rc"; fi

# A dry run mints nothing, so it must not require the credential a mint needs —
# but it must still say one will be needed. This is the cold operator's first
# command (the README opens with --dry-run), and requiring a minter here made it
# print a plan with its permissions silently missing: the tool died before
# resolving them, while the wrapper still reported "dry run complete".
: >"$CALLS"
PATH="$STUB_DIR:$PATH" env -u CF_MINTER_TOKEN -u CF_MINTER_CMD -u CF_MINTER_VAULT_SECRET -u OPS_VAULT_NAME \
  bash "$SCRIPT" --dry-run --name t --perm DNS:Edit --perm Zone:Read --zone example.test >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "a dry run with NO minter still succeeds — a preview needs no credential"; else bad "dry-run without a minter: want exit 0, got $rc — $(tail -3 "$OUT")"; fi
if [[ "$(grep -c 'would resolve permission' "$OUT")" -eq 2 ]]; then ok "…and states the full permission plan, which is the whole point of --dry-run"; else bad "dry-run without a minter omitted its permissions: $(grep -c 'would resolve permission' "$OUT") of 2"; fi
if grep -q "no minter credential is configured" "$OUT"; then ok "…while warning that a real run will need one"; else bad "dry-run never mentioned the missing minter"; fi
if [[ ! -s "$CALLS" ]]; then ok "…and makes zero network calls doing it"; else bad "dry-run without a minter touched the network: $(cat "$CALLS")"; fi

# The relaxation above must not have reached the live path. Deleting is as
# privileged as creating, so both are checked.
: >"$CALLS"
PATH="$STUB_DIR:$PATH" env -u CF_MINTER_TOKEN -u CF_MINTER_CMD -u CF_MINTER_VAULT_SECRET -u OPS_VAULT_NAME \
  bash "$SCRIPT" --name t --perm DNS:Edit --zone example.test >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "no minter credential" "$OUT"; then ok "a LIVE mint with no minter still refuses by name — the relaxation is dry-run only"; else bad "live mint without a minter: want a named refusal, got $rc"; fi
if [[ ! -s "$CALLS" ]]; then ok "…before any network call is made"; else bad "live mint without a minter reached the network"; fi
: >"$CALLS"
PATH="$STUB_DIR:$PATH" env -u CF_MINTER_TOKEN -u CF_MINTER_CMD -u CF_MINTER_VAULT_SECRET -u OPS_VAULT_NAME \
  bash "$SCRIPT" --revoke sometoken >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "no minter credential" "$OUT"; then ok "…and so does a live revoke, since deleting is as privileged as creating"; else bad "live revoke without a minter: want a named refusal, got $rc"; fi
if grep -q -- "--minter-cmd" "$OUT" && grep -q "CF_MINTER_TOKEN" "$OUT" && [[ ! -s "$CALLS" ]]; then ok "…listing every supported way to supply one, before any network call"; else bad "the refusal does not name the alternatives"; fi

printf '%s\n' "minter-from-a-store" >"$STUB_DIR/minter.txt"
: >"$CALLS"
PATH="$STUB_DIR:$PATH" env -u CF_MINTER_TOKEN \
  bash "$SCRIPT" --minter-cmd "cat $STUB_DIR/minter.txt" --qualify-minter >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "--minter-cmd sources the minter from an arbitrary command"; else bad "--minter-cmd: want exit 0, got $rc — $(tail -3 "$OUT")"; fi
if grep -q 'auth=minter-from-a-store' "$CALLS"; then ok "…and that value is what authenticates the call"; else bad "the fetched minter did not reach the API call: $(cat "$CALLS")"; fi
if ! grep -q "minter-from-a-store" "$OUT"; then ok "…while never appearing in the output"; else bad "the minter value LEAKED into stdout"; fi

: >"$CALLS"
printf '%s\n' "minter-from-a-file" >"$STUB_DIR/minter2.txt"
PATH="$STUB_DIR:$PATH" env -u CF_MINTER_TOKEN \
  bash "$SCRIPT" --minter-token-file "$STUB_DIR/minter2.txt" --qualify-minter >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'auth=minter-from-a-file' "$CALLS"; then ok "--minter-token-file reads it from a private file"; else bad "--minter-token-file: exit $rc"; fi

: >"$CALLS"
PATH="$STUB_DIR:$PATH" env -u CF_MINTER_TOKEN \
  bash "$SCRIPT" --minter-token-file "$STUB_DIR/does-not-exist" --qualify-minter >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "not readable" "$OUT"; then ok "a missing minter file refuses by name (it is not a silent fallback)"; else bad "missing minter file: want exit 2, got $rc"; fi

run_mint "$OUT" --minter-token some-secret --qualify-minter; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "argv is world-readable" "$OUT"; then ok "--minter-token on argv is refused, with the reason"; else bad "--minter-token: want a named refusal, got $rc"; fi

# ── @scope disambiguation ─────────────────────────────────────────────────────
# Cloudflare publishes some permission groups twice under one name, differing
# only in scope. Resolving by name alone cannot tell them apart, so the tool
# must refuse rather than guess -- and must say how to proceed.
#
# Mints that are expected to SUCCEED need a passing verify plan; the harness
# default is "500 bad" and each mint test overwrites it (see above).
echo "200 ok" >"$STUB_DIR/verify.plan"

run_mint "$OUT" --name t --perm "Access: Apps and Policies:Edit" --zone example.test; rc=$?
if [[ "$rc" -ne 0 ]]; then ok "an ambiguous permission name is refused, not guessed"; else bad "ambiguous name was silently resolved (rc=$rc)"; fi
if ! grep -q '^curl POST' "$CALLS"; then ok "…and no token is created when it cannot be resolved"; else bad "a token was minted despite an unresolvable perm"; fi
if grep -q 'ambiguous' "$OUT" && grep -q '@account' "$OUT" && grep -q '@zone' "$OUT"; then
  ok "…and the error names both scopes and the exact flag to add"
else bad "ambiguity error did not teach the @scope syntax — $(tail -4 "$OUT")"; fi

run_mint "$OUT" --name t --perm "Access: Apps and Policies:Edit@account"; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "@account resolves the same ambiguous name"; else bad "@account failed (rc=$rc) — $(tail -4 "$OUT")"; fi
if grep -q 'pg-aap-write-acct' "$CALLS"; then ok "…to the ACCOUNT-scoped group id"; else bad "wrong group id sent for @account"; fi
if ! grep -q 'pg-aap-write-zone' "$CALLS"; then ok "…and not the zone-scoped one"; else bad "the zone-scoped id leaked into an @account mint"; fi

run_mint "$OUT" --name t --perm "Access: Apps and Policies:Edit@zone" --zone example.test; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'pg-aap-write-zone' "$CALLS"; then ok "@zone resolves the same name to the ZONE-scoped group"; else bad "@zone did not resolve correctly (rc=$rc)"; fi

# A hint no candidate satisfies must say so specifically, rather than reporting
# the generic "no such permission group" and sending the reader off to scan the
# whole catalogue for a name that is plainly there.
run_mint "$OUT" --name t --perm "Cloudflare Tunnel:Edit@zone" --zone example.test; rc=$?
if [[ "$rc" -ne 0 ]] && grep -q 'none is @zone' "$OUT"; then ok "a hint no candidate satisfies reports THAT, not 'no such group'"; else bad "wrong-scope hint gave an unhelpful error — $(tail -4 "$OUT")"; fi
if grep -q 'com.cloudflare.api.account' "$OUT"; then ok "…and shows which scopes that name does offer"; else bad "did not show the available scopes"; fi

run_guarded 5 "$OUT" --name t --perm "DNS:Edit@region" --zone example.test; rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "want @account or @zone" "$OUT"; then ok "an unknown @scope is refused by name"; else bad "bad scope not refused (rc=$rc)"; fi

# Regression: the hint is optional, and unique names must be unaffected by it.
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'pg-dns-write' "$CALLS"; then ok "a unique name still needs no hint"; else bad "unhinted resolution regressed (rc=$rc)"; fi
run_mint "$OUT" --name t --perm "DNS:Edit@zone" --zone example.test; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'pg-dns-write' "$CALLS"; then ok "…and accepts a redundant but correct hint"; else bad "correct hint on a unique name failed (rc=$rc)"; fi

# Cloudflare's "Cache Purge" group has no Write/Read form — its only level is
# Purge, and the catalogue name carries no level suffix at all. "Cache
# Purge:Purge" therefore has no exact match ("Cache Purge Purge") and must
# resolve through the fallback: name ends with the level, contains the base.
run_mint "$OUT" --name t --perm "Cache Purge:Purge" --zone example.test; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'pg-cache-purge' "$CALLS"; then ok "'X:Purge' resolves to the level-suffixed catalogue group via the fallback match"; else bad "Cache Purge:Purge did not resolve (rc=$rc) — $(tail -4 "$OUT")"; fi
run_guarded 5 "$OUT" --name t --perm "Cache Purge:Delete" --zone example.test; rc=$?
if [[ "$rc" -eq 2 ]] && grep -q "want Edit, Read or Purge" "$OUT"; then ok "an unknown level is refused offline, naming all three accepted levels"; else bad "unknown level: want exit 2 naming Purge, got $rc — $(tail -3 "$OUT")"; fi

# The dry-run must agree with the live path about which scope a hinted perm
# lands in, or the plan misrepresents the token it is previewing.
PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN=fake bash "$SCRIPT" --dry-run --name t \
  --perm "Access: Apps and Policies:Edit@account" >"$OUT" 2>&1 </dev/null
if grep -q '@account' "$OUT"; then ok "dry-run echoes the @scope hint back"; else bad "dry-run dropped the hint"; fi

# ── no credential rides curl's command line ───────────────────────────────────
# argv is world-readable (`ps`, /proc/<pid>/cmdline): the minter and the minted token
# reach curl only as config on its stdin (-K -).
echo "credentials stay off curl's command line:"
: >"$STUB_DIR/curl-argv.log"
echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 0 && -s "$STUB_DIR/curl-argv.log" ]] && ! grep -qF -- "fake-minter-value" "$STUB_DIR/curl-argv.log" \
   && ! grep -qF -- "$FAKE_TOKEN" "$STUB_DIR/curl-argv.log" && ! grep -qi 'authorization' "$STUB_DIR/curl-argv.log"; then
  ok "neither the minter nor the minted token appears on any curl command line (mint + verify)"
else bad "a credential rode curl's argv (rc=$rc): $(grep -iF -e fake-minter -e "$FAKE_TOKEN" -e authorization "$STUB_DIR/curl-argv.log" | head -3)"; fi
if grep -q 'curl POST .*user/tokens auth=fake-minter-value ' "$CALLS"; then
  ok "…and the minter still authenticates the mint, from curl's stdin config"
else bad "the mint call carried no minter bearer: $(grep 'POST' "$CALLS")"; fi
: >"$STUB_DIR/curl-argv.log"
: >"$CALLS"
PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN="fake-minter-value" CF_BURN_TOKEN="$FAKE_TOKEN" \
  bash "$SCRIPT" --burn >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q "curl GET .*user/tokens/verify auth=$FAKE_TOKEN" "$CALLS" \
   && ! grep -qF -- "$FAKE_TOKEN" "$STUB_DIR/curl-argv.log" && ! grep -qF -- "fake-minter-value" "$STUB_DIR/curl-argv.log"; then
  ok "--burn's self-verify and delete keep both tokens off argv too"
else bad "--burn put a credential on argv, or lost its bearer (rc=$rc): $(cat "$STUB_DIR/curl-argv.log")"; fi

# ── the stored version is born stamped (the expiry hook) ──────────────────────
# Each store makes a new vault version, and a version carries only the expiry its own
# write gave it — a re-mint stored bare un-stamps the secret. A site's expiry hook
# names the window; the tool asks it before minting and stamps the same write.
echo "the stored version carries its expiry:"
store_line(){ grep '^az keyvault secret set ' "$CALLS" | grep -v -- '--name mint-store-probe ' | head -1; }
store_expiry(){ sed -n 's/.*--expires \([^ ]*\).*/\1/p' <<<"$(store_line)"; }
to_epoch(){ date -u -d "$1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null; }
HOOK="$STUB_DIR/window-hook"
# A stub hook: 45 days for "rotated-token" in fake-vault, no window for anything else.
# It records the arguments it was asked with.
cat >"$HOOK" <<'H'
#!/usr/bin/env bash
printf '%s|%s\n' "$1" "$2" >>"$STUB_DIR/hook.calls"
[[ "$1" == rotated-token && "$2" == fake-vault ]] && { echo 45; exit 0; }
exit 3
H
chmod +x "$HOOK"

echo "200 ok" >"$STUB_DIR/verify.plan"; rm -f "$STUB_DIR/hook.calls"
CF_MINT_EXPIRY_WINDOW_CMD="$HOOK" run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret rotated-token --no-print-value; rc=$?
EXP="$(store_expiry)"
if [[ "$rc" -eq 0 && -n "$EXP" ]]; then ok "a secret the hook keeps a window for is stored WITH an expiry"; else bad "it was stored bare (rc=$rc): $(store_line)"; fi
WANT=$(( $(date -u +%s) + 45 * 86400 )); GOT="$(to_epoch "$EXP")"
if [[ -n "$GOT" ]] && (( GOT > WANT - 86400 && GOT < WANT + 86400 )); then
  ok "…at now + the hook's window (45 days)"
else bad "the stamp '$EXP' is not now + 45 days"; fi
if [[ "$(cat "$STUB_DIR/hook.calls" 2>/dev/null)" == "rotated-token|fake-vault" ]]; then
  ok "…the hook was asked once, with the target secret and the target vault"
else bad "the hook was asked '$(cat "$STUB_DIR/hook.calls" 2>/dev/null)'"; fi
if grep -q -- "--value $FAKE_TOKEN " <<<"$(store_line)"; then ok "…in the same write as the value (the version is never bare, even briefly)"; else bad "the stamp is not in the value's own write: $(store_line)"; fi
if ! grep -qF -- "$FAKE_TOKEN" "$STUB_DIR/argv.log" && grep -q -- '^argv keyvault secret set .*--value @[^ ]* --expires [^ ]' "$STUB_DIR/argv.log"; then
  ok "…and that stamped write still carries the value as a file az reads, never on az's command line"
else bad "the stamped write put the value on argv, or lost its stamp: $(grep '^argv keyvault' "$STUB_DIR/argv.log")"; fi

echo "200 ok" >"$STUB_DIR/verify.plan"; rm -f "$STUB_DIR/hook.calls"
CF_MINT_EXPIRY_WINDOW_CMD="$HOOK" run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --ttl 2h --vault-secret rotated-token --no-print-value; rc=$?
POST_EXP="$(grep '^curl POST .*user/tokens ' "$CALLS" | head -1 | grep -o '"expires_on":"[^"]*"' | cut -d'"' -f4)"
if [[ "$rc" -eq 0 && -n "$POST_EXP" && "$(store_expiry)" == "$POST_EXP" && ! -s "$STUB_DIR/hook.calls" ]]; then
  ok "a --ttl token is stamped with its own end, and the hook is not asked"
else bad "a --ttl token's stamp '$(store_expiry)' is not its own end '$POST_EXP' (hook asked: $(cat "$STUB_DIR/hook.calls" 2>/dev/null))"; fi

echo "200 ok" >"$STUB_DIR/verify.plan"
CF_MINT_EXPIRY_WINDOW_CMD="$HOOK" run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret other-token --no-print-value; rc=$?
if [[ "$rc" -eq 0 && -z "$(store_expiry)" ]]; then ok "a secret the hook has no window for (exit 3) is stored without one"; else bad "an unwindowed name got a stamp (rc=$rc): $(store_line)"; fi

echo "200 ok" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret rotated-token --no-print-value; rc=$?
if [[ "$rc" -eq 0 && -z "$(store_expiry)" ]]; then ok "with no hook configured the store is unchanged: no expiry"; else bad "no hook, yet a stamp (rc=$rc): $(store_line)"; fi

# A hook that cannot answer refuses the mint BEFORE a token exists — never a live
# token stored bare.
printf '#!/usr/bin/env bash\necho "register unreadable (stub)" >&2\nexit 2\n' >"$STUB_DIR/broken-hook"; chmod +x "$STUB_DIR/broken-hook"
echo "200 ok" >"$STUB_DIR/verify.plan"
CF_MINT_EXPIRY_WINDOW_CMD="$STUB_DIR/broken-hook" run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret rotated-token --no-print-value; rc=$?
if [[ "$rc" -ne 0 ]] && ! grep -q '^curl ' "$CALLS" && ! grep -q '^az ' "$CALLS" \
   && grep -qF 'refusing to mint a version it cannot stamp' "$OUT" && grep -qF 'register unreadable (stub)' "$OUT"; then
  ok "a hook that cannot answer refuses the mint before any call, quoting the hook's own words"
else bad "a failing hook did not refuse before minting (rc=$rc, POSTs=$(grep -c '^curl POST' "$CALLS"))"; fi
printf '#!/usr/bin/env bash\necho soon\n' >"$STUB_DIR/word-hook"; chmod +x "$STUB_DIR/word-hook"
CF_MINT_EXPIRY_WINDOW_CMD="$STUB_DIR/word-hook" run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret rotated-token --no-print-value; rc=$?
if [[ "$rc" -ne 0 ]] && ! grep -q '^curl ' "$CALLS" && grep -qF "answered 'soon'" "$OUT"; then
  ok "a hook that answers something other than a number of days refuses the mint, offline"
else bad "a non-numeric hook answer was not refused (rc=$rc): $(tail -2 "$OUT")"; fi

# The default hook: lib/cf-mint-expiry-window.sh beside the tool, when present.
ISO="$(mktemp -d)"; mkdir -p "$ISO/lib"
cp "$SCRIPT" "$ISO/cf-mint-token.sh"; cp "$HERE"/../lib/*.sh "$ISO/lib/"
cp "$HOOK" "$ISO/lib/cf-mint-expiry-window.sh"
echo "200 ok" >"$STUB_DIR/verify.plan"; : >"$CALLS"; : >"$STUB_DIR/argv.log"; rm -f "$STUB_DIR/verify.count" "$STUB_DIR/hook.calls"
PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN="fake-minter-value" OPS_VAULT_NAME="fake-vault" \
  bash "$ISO/cf-mint-token.sh" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret rotated-token --no-print-value >"$OUT" 2>&1 </dev/null; rc=$?
if [[ "$rc" -eq 0 && -n "$(store_expiry)" && "$(cat "$STUB_DIR/hook.calls" 2>/dev/null)" == "rotated-token|fake-vault" ]]; then
  ok "a hook at lib/cf-mint-expiry-window.sh is found with no configuration"
else bad "the default hook path was not used (rc=$rc): $(store_line)"; fi
rm -rf "$ISO"

run_mint "$OUT" --dry-run --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret rotated-token; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]] && ! grep -q -- '--expires' "$OUT"; then
  ok "a dry run with no hook plans an unstamped store and calls nothing"
else bad "dry run (no hook): rc=$rc $(grep 'secret set' "$OUT")"; fi
CF_MINT_EXPIRY_WINDOW_CMD="$HOOK" run_mint "$OUT" --dry-run --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret rotated-token; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]] && grep -qF -- "--expires <now + 45 days" "$OUT"; then
  ok "a dry run states the hook's stamp in its plan, still calling nothing"
else bad "dry run (hook): rc=$rc $(grep 'secret set' "$OUT")"; fi

# ── a permission the vendor spells two ways ───────────────────────────────────
# Its own references disagree for one grant: the dashboard says "Account Filter Lists
# Edit", the API reference's table "Account Rule Lists Write". A --perm may name
# alternatives ("A|B:Edit"), and a write grant resolves to the "Edit" spelling only
# where no "Write" group exists — so every name that resolved before resolves to the
# same group now.
echo "names spelled two ways (alternatives, and Edit only where no Write exists):"
catalog(){ printf '{"success":true,"errors":[],"result":%s}' "$1" >"$STUB_DIR/catalog.json"; }
LISTS_ALT="Account Filter Lists|Account Rule Lists:Edit"
export CF_ACCOUNT_ID=acct-test
echo "200 ok" >"$STUB_DIR/verify.plan"

catalog '[{"id":"pg-dns-write","name":"DNS Write","scopes":["com.cloudflare.api.account.zone"]},{"id":"pg-rule-lists-write","name":"Account Rule Lists Write","scopes":["com.cloudflare.api.account"]}]'
run_mint "$OUT" --name t --perm "$LISTS_ALT" --no-print-value --value-file "$STUB_DIR/alt-value"; rc=$?
if [[ "$rc" -eq 0 ]] && grep -qF "resolved $LISTS_ALT  ->  Account Rule Lists Write (account-scoped)" "$OUT"; then
  ok "the second alternative resolves when the first spelling is absent from the catalogue"
else bad "alternatives did not resolve (rc=$rc): $(grep -E 'resolve|FAIL' "$OUT" | head -3)"; fi
if grep -q 'curl POST .*user/tokens auth=fake-minter-value body=.*pg-rule-lists-write.*com.cloudflare.api.account.acct-test' "$CALLS"; then
  ok "…and the minted token carries that group on the account"
else bad "the POST body does not carry the resolved group on the account: $(grep 'POST' "$CALLS")"; fi

catalog '[{"id":"pg-filter-lists-edit","name":"Account Filter Lists Edit","scopes":["com.cloudflare.api.account"]}]'
run_mint "$OUT" --name t --perm "Account Filter Lists:Edit" --no-print-value --value-file "$STUB_DIR/alt-value"; rc=$?
if [[ "$rc" -eq 0 ]] && grep -qF "resolved Account Filter Lists:Edit  ->  Account Filter Lists Edit (account-scoped)" "$OUT"; then
  ok "an Edit-spelled group resolves when the catalogue has no Write spelling"
else bad "the Edit spelling did not resolve (rc=$rc): $(grep -E 'resolve|FAIL' "$OUT" | head -3)"; fi

catalog '[{"id":"pg-zs-edit","name":"Zone Settings Edit","scopes":["com.cloudflare.api.account.zone"]},{"id":"pg-zs-write","name":"Zone Settings Write","scopes":["com.cloudflare.api.account.zone"]}]'
run_mint "$OUT" --name t --perm "Zone Settings:Edit" --zone-id zone-xyz-777 --no-print-value --value-file "$STUB_DIR/alt-value"; rc=$?
if [[ "$rc" -eq 0 ]] && grep -qF "resolved Zone Settings:Edit  ->  Zone Settings Write (zone-scoped)" "$OUT" && ! grep -q 'pg-zs-edit' "$CALLS"; then
  ok "where both spellings exist, Write still wins — a name that resolved before resolves to the same group"
else bad "the Write spelling lost its precedence (rc=$rc): $(grep -E 'resolve|FAIL' "$OUT" | head -3)"; fi

# Alternatives and the @scope hint compose: a spelling that exists only at the other
# scope does not shadow a later spelling that exists at the hinted one.
catalog '[{"id":"pg-a-zone","name":"Thing A Write","scopes":["com.cloudflare.api.account.zone"]},{"id":"pg-b-acct","name":"Thing B Write","scopes":["com.cloudflare.api.account"]}]'
run_mint "$OUT" --name t --perm "Thing A|Thing B:Edit@account" --no-print-value --value-file "$STUB_DIR/alt-value"; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'pg-b-acct' "$CALLS" && ! grep -q 'pg-a-zone' "$CALLS"; then
  ok "with an @scope hint, the first alternative AT that scope wins"
else bad "the hint and alternatives did not compose (rc=$rc): $(grep -E 'resolve|FAIL|none is' "$OUT" | head -3)"; fi
run_mint "$OUT" --name t --perm "Thing A:Edit@account" --no-print-value --value-file "$STUB_DIR/alt-value"; rc=$?
if [[ "$rc" -eq 1 ]] && grep -q "named 'Thing A Write', but none is @account" "$OUT"; then
  ok "…and a name that exists only at the other scope still says so"
else bad "wrong-scope report regressed (rc=$rc): $(tail -3 "$OUT")"; fi

catalog '[{"id":"pg-dns-write","name":"DNS Write","scopes":["com.cloudflare.api.account.zone"]}]'
run_mint "$OUT" --name t --perm "$LISTS_ALT" --no-print-value --value-file "$STUB_DIR/alt-value"; rc=$?
if [[ "$rc" -eq 1 ]] && grep -qF "looked for 'Account Filter Lists Write' | 'Account Filter Lists Edit' | 'Account Rule Lists Write' | 'Account Rule Lists Edit'" "$OUT"; then
  ok "no alternative in the catalogue: exit 1, naming every name tried"
else bad "an unresolvable alternative set did not refuse by name (rc=$rc): $(grep -E 'resolve|FAIL' "$OUT" | head -3)"; fi
if ! grep -q 'curl POST .*user/tokens ' "$CALLS"; then ok "…and nothing was minted"; else bad "a token was minted despite an unresolved permission"; fi

for spec in "Account Filter Lists||Account Rule Lists:Edit" "Account Filter Lists|:Edit" "|Account Rule Lists:Edit"; do
  run_mint "$OUT" --name t --perm "$spec" --no-print-value --value-file "$STUB_DIR/alt-value"; rc=$?
  if [[ "$rc" -eq 2 ]] && grep -q 'an empty alternative' "$OUT" && [[ ! -s "$CALLS" ]]; then ok "'$spec' is a usage error before any network call"
  else bad "'$spec' was not refused offline (rc=$rc): $(tail -2 "$OUT"; head -2 "$CALLS")"; fi
done

run_mint "$OUT" --name t --perm "$LISTS_ALT" --dry-run; rc=$?
if [[ "$rc" -eq 0 ]] && grep -qF "the first live group of 'Account Filter Lists Write' | 'Account Filter Lists Edit' | 'Account Rule Lists Write' | 'Account Rule Lists Edit'" "$OUT" \
   && grep -q 'com.cloudflare.api.account.<account-id>' "$OUT" && [[ ! -s "$CALLS" ]]; then
  ok "the dry run names every alternative, places an Account group on the account, and calls nothing"
else bad "the dry run did not render the alternatives offline (rc=$rc): $(grep -E 'would resolve' "$OUT")"; fi
rm -f "$STUB_DIR/catalog.json"; unset CF_ACCOUNT_ID

# ── the vault proves it takes a WRITE before anything is minted ───────────────
# The store after a mint has been refused live (a lapsed write activation): the token
# was then live at Cloudflare and kept nowhere. A read of the target cannot rule that
# out — a role that reads but cannot write answers it — so the preflight is a real
# secret write of a throwaway disabled version, read back, before any Cloudflare call.
echo "the vault store is proven writable before the mint:"
probe_reset(){ rm -f "$STUB_DIR"/probe.*; }
first_curl(){ grep -n '^curl ' "$CALLS" | head -1 | cut -d: -f1; }
probe_write_line(){ grep -n '^az keyvault secret set .*--name mint-store-probe ' "$CALLS" | head -1 | cut -d: -f1; }
target_writes(){ grep '^az keyvault secret set ' "$CALLS" | grep -v -- '--name mint-store-probe ' || true; }
echo "200 ok" >"$STUB_DIR/verify.plan"

probe_reset; touch "$STUB_DIR/probe.deny"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 1 ]] && grep -q "vault preflight FAILED for vault 'fake-vault' secret 'cf-token'" "$OUT" \
   && grep -q "Forbidden" "$OUT" && grep -q "no token was created" "$OUT"; then
  ok "a vault that refuses the write refuses the mint by name (exit 1), carrying the vault's own words"
else bad "a write-denied vault did not refuse by name (rc=$rc): $(tail -4 "$OUT")"; fi
if ! grep -q '^curl ' "$CALLS"; then ok "…before ANY Cloudflare call — nothing minted, nothing to orphan"; else bad "Cloudflare was called despite the refused write: $(grep '^curl' "$CALLS")"; fi
if [[ -z "$(target_writes)" ]]; then ok "…and the target secret was never written"; else bad "the target was written after a refused probe: $(target_writes)"; fi

probe_reset
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
pw="$(probe_write_line)"; fc="$(first_curl)"
if [[ "$rc" -eq 0 && -n "$pw" && -n "$fc" && "$pw" -lt "$fc" ]]; then
  ok "a vault that takes the write lets the mint proceed — the probe write lands before the first Cloudflare call (az line $pw < curl line $fc)"
else bad "probe/mint order wrong (rc=$rc, probe line '$pw', first curl '$fc'): $(tail -3 "$OUT")"; fi
if grep -q '^az keyvault secret set --vault-name fake-vault --name mint-store-probe .*--disabled true --expires [0-9]\{4\}-01-01T00:00:00Z' "$CALLS"; then
  ok "…the probe is a new version of the vault's ONE probe secret, written disabled and stamped far past any expiry window in the write itself"
else bad "the probe write is not a disabled version of the fixed probe name: $(grep 'mint-store-probe' "$CALLS")"; fi
if grep -q '^az keyvault secret list-versions --vault-name fake-vault --name mint-store-probe' "$CALLS"; then
  ok "…and is read back (the version's own attributes) before the mint"
else bad "the probe was not read back: $(grep 'mint-store-probe' "$CALLS")"; fi
if grep -q '^az keyvault secret show-deleted --vault-name fake-vault --name cf-token' "$CALLS"; then
  ok "…and the target name is asked whether it is held deleted"
else bad "the target's deleted state was not asked: $(grep '^az' "$CALLS")"; fi
if ! grep -qE '^az keyvault secret (delete|purge) ' "$CALLS" && ! grep -q '^[a-z]* true$' "$STUB_DIR/probe.versions"; then
  ok "…and it is cleaned up without a delete: every probe version is disabled, no name left reserved by soft-delete"
else bad "the probe left an enabled version or deleted a name: $(cat "$STUB_DIR/probe.versions"; grep -E 'delete|purge' "$CALLS")"; fi
if ! grep 'mint-store-probe' "$CALLS" | grep -qF -- "$FAKE_TOKEN"; then ok "…and the probe never carries the minted value"; else bad "the minted value reached the probe write"; fi
if [[ -n "$(target_writes)" ]]; then ok "…and the real store still follows"; else bad "the real store did not happen after a passing probe"; fi
if ! grep -q '^az keyvault secret show --vault-name fake-vault --name cf-token' "$CALLS"; then
  ok "…and the old read-only preflight (a read of the target) is gone — a read proves nothing about a write"
else bad "the preflight still reads the target: $(grep 'secret show ' "$CALLS")"; fi

probe_reset; touch "$STUB_DIR/probe.target-deleted"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 1 ]] && grep -q "target secret 'cf-token' is held deleted-but-recoverable" "$OUT" && ! grep -q '^curl ' "$CALLS"; then
  ok "a target name held deleted-but-recoverable refuses the mint by name, before Cloudflare"
else bad "a soft-deleted target did not refuse before the mint (rc=$rc): $(tail -3 "$OUT")"; fi

probe_reset; echo 2 >"$STUB_DIR/probe.throttle"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 0 && "$(grep -c '^az keyvault secret set .*--name mint-store-probe ' "$CALLS")" -eq 3 ]]; then
  ok "a throttled vault (429 twice) is retried, and the mint proceeds once the write is taken"
else bad "the probe did not ride a transient 429 (rc=$rc, writes $(grep -c 'name mint-store-probe ' "$CALLS")): $(tail -3 "$OUT")"; fi

probe_reset; touch "$STUB_DIR/probe.deleted"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q '^az keyvault secret recover --vault-name fake-vault --name mint-store-probe' "$CALLS" && grep -q "it was recovered" "$OUT"; then
  ok "a deleted PROBE name heals itself: recovered, the write retried, the mint proceeds, and the run says so"
else bad "a deleted probe name did not self-heal (rc=$rc): $(tail -3 "$OUT")"; fi

probe_reset; touch "$STUB_DIR/probe.readdeny"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 1 ]] && grep -q "read-back" "$OUT" && ! grep -q '^curl ' "$CALLS"; then
  ok "a write that cannot be read back refuses the mint (an unproven write is not a proven store)"
else bad "an unreadable probe write did not refuse (rc=$rc): $(tail -3 "$OUT")"; fi

probe_reset; touch "$STUB_DIR/probe.keep-enabled"
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token --no-print-value; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q 'secrets/mint-store-probe/' "$STUB_DIR/probe.disabled" 2>/dev/null; then
  ok "a probe version that reads back ENABLED is disabled after the fact — the probe never leaves a usable object"
else bad "an enabled probe version was left enabled (rc=$rc): $(cat "$STUB_DIR/probe.disabled" 2>/dev/null)"; fi

probe_reset
run_mint "$OUT" --name t --perm DNS:Edit --zone-id zone-xyz-777 --no-print-value --value-file "$STUB_DIR/noprobe-value"; rc=$?
if [[ "$rc" -eq 0 ]] && ! grep -q 'mint-store-probe' "$CALLS"; then
  ok "a mint with no vault store makes no probe (nothing to prove)"
else bad "a vault-less mint probed a vault (rc=$rc): $(grep 'mint-store-probe' "$CALLS")"; fi

run_mint "$OUT" --dry-run --name t --perm DNS:Edit --zone-id zone-xyz-777 --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]] && grep -q "would first prove vault 'fake-vault' takes a secret write" "$OUT"; then
  ok "the dry run states the write probe in its plan and still calls nothing"
else bad "the dry run did not plan the probe offline (rc=$rc): $(grep -i probe "$OUT")"; fi
probe_reset

# ── --list: a detail line under each row, never a value ───────────────────────
echo "--list carries a tab-free detail line:"
printf '%s' '{"success":true,"errors":[],"result":[{"id":"tok-aaa","status":"active","name":"cfsr-1-t60-x","issued_on":"2026-01-01T00:00:00Z","expires_on":"2026-01-01T00:01:00Z","last_used_on":null,"policies":[{"effect":"allow","permission_groups":[{"name":"DNS Write"}],"resources":{"z1":"*"}}]}]}' >"$STUB_DIR/list.json"
run_mint "$OUT" --list; rc=$?
if [[ "$rc" -eq 0 ]] && grep -q $'^  tok-aaa  active\tcfsr-1-t60-x$' "$OUT" \
   && grep -q '^      issued=2026-01-01T00:00:00Z  expires=2026-01-01T00:01:00Z  last_used=never  policies=allow:\[DNS Write\]@1$' "$OUT" \
   && [[ "$(grep -c $'\t' "$OUT")" -eq 1 ]]; then
  ok "each row keeps its '<id>  <status><TAB><name>' shape, and its detail line carries no tab (the stale sweep skips it)"
else bad "--list rows changed shape (rc=$rc): $(cat "$OUT")"; fi
rm -f "$STUB_DIR/list.json"

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "cf-mint-token tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
