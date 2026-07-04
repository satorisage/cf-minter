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
# Run:  bash infra/test/cf-mint-token.test.sh   (exit 0 = all pass)

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
url=""; method="GET"; auth=""; wfmt=0
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -X) method="${args[$((i+1))]}" ;;
    -H) case "${args[$((i+1))]}" in Authorization:*) auth="${args[$((i+1))]#Authorization: Bearer }" ;; esac ;;
    -w) wfmt=1 ;;
    https://*) url="${args[$i]}" ;;
  esac
done
printf 'curl %s %s auth=%s\n' "$method" "$url" "$auth" >>"$STUB_DIR/calls.log"
tok="$(cat "$STUB_DIR/token.txt")"
code=200 body=""
case "$method $url" in
  "GET "*"/user/tokens/verify")
    n=0; [[ -f "$STUB_DIR/verify.count" ]] && n="$(cat "$STUB_DIR/verify.count")"
    echo $((n+1)) >"$STUB_DIR/verify.count"
    line="$(sed -n "$((n+1))p" "$STUB_DIR/verify.plan")"
    [[ -n "$line" ]] || line="$(tail -1 "$STUB_DIR/verify.plan")"
    code="${line%% *}"
    if [[ "${line##* }" == "ok" ]]; then
      body='{"success":true,"errors":[],"result":{"id":"tok-0001","status":"active"}}'
    else
      body='{"success":false,"errors":[{"code":1000,"message":"Invalid API Token"}],"result":null}'
    fi ;;
  "GET "*"/user/tokens/permission_groups")
    body='{"success":true,"errors":[],"result":[{"id":"pg-dns-write","name":"DNS Write","scopes":["com.cloudflare.api.account.zone"]}]}' ;;
  "GET "*"/zones?name="*)
    body='{"success":true,"errors":[],"result":[{"id":"zone-abc-123"}]}' ;;
  "DELETE "*"/user/tokens/"*)
    body="{\"success\":true,\"errors\":[],\"result\":{\"id\":\"${url##*/}\"}}" ;;
  "POST "*"/user/tokens")
    body="{\"success\":true,\"errors\":[],\"result\":{\"id\":\"tok-0001\",\"name\":\"t\",\"value\":\"$tok\"}}" ;;
  "GET "*"/user/tokens")
    body='{"success":true,"errors":[],"result":[]}' ;;
  *)
    body='{"success":false,"errors":[{"code":9999,"message":"stub: unexpected endpoint"}]}' ;;
esac
if [[ "$wfmt" -eq 1 ]]; then printf '%s\n%s' "$body" "$code"; else printf '%s' "$body"; fi
STUB
chmod +x "$STUB_DIR/curl"

# ── stub az ───────────────────────────────────────────────────────────────────
cat >"$STUB_DIR/az" <<'STUB'
#!/usr/bin/env bash
printf 'az %s\n' "$*" >>"$STUB_DIR/calls.log"
exit 0
STUB
chmod +x "$STUB_DIR/az"

# run_mint <outfile> <args…> — run the tool with stubs on PATH, a fake minter,
# stdin closed (the retry lib buffers stdin when it is not a tty), and a fresh
# call log. Echoes nothing; exit status is the tool's.
run_mint(){
  local out="$1"; shift
  : >"$CALLS"; rm -f "$STUB_DIR/verify.count"
  PATH="$STUB_DIR:$PATH" CF_MINTER_TOKEN="fake-minter-value" OPS_VAULT_NAME="fake-vault" \
    bash "$SCRIPT" "$@" >"$out" 2>&1 </dev/null
}

# run_guarded <timeout-s> <outfile> <args…> — like run_mint but killed if it
# hangs (the unguarded parser looped forever on a bare trailing flag). 124 = hung.
run_guarded(){
  local t="$1" out="$2"; shift 2
  : >"$CALLS"; rm -f "$STUB_DIR/verify.count"
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
aline="$(grep -n '^az keyvault secret set' "$CALLS" | head -1 | cut -d: -f1)"
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
if grep -q "value: $FAKE_TOKEN" "$OUT"; then ok "boxed output shows the exact minted value"; else bad "boxed output does not show the minted value"; fi

echo "200 bad" >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 1 ]]; then ok "verify failure exits 1"; else bad "verify failure: want exit 1, got $rc"; fi
if ! grep -q '^az keyvault secret set' "$CALLS"; then
  ok "verify failure never writes the vault (existing secret survives)"
else
  bad "verify failure STILL wrote the vault: $(grep '^az' "$CALLS")"
fi
if grep -q "FAILED VERIFICATION" "$OUT"; then ok "verify failure is reported loudly"; else bad "no clear verify-failure message"; fi
if grep -q -- "--revoke tok-0001" "$OUT"; then ok "failure output names the cleanup command with the token id"; else bad "failure output lacks the revoke hint"; fi
if grep -q "\[1000\]" "$OUT"; then ok "Cloudflare's error code is surfaced"; else bad "CF error code not surfaced"; fi

# One transient 401 (propagation window), then active: must ride the retry and pass.
printf '401 bad\n200 ok\n' >"$STUB_DIR/verify.plan"
run_mint "$OUT" --name t --perm DNS:Edit --zone example.test; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "verify rides one propagation 401 and succeeds (retry lib engaged)"; else bad "verify did not survive a transient 401: exit $rc"; fi
if [[ "$(cat "$STUB_DIR/verify.count")" -eq 2 ]]; then ok "verify was attempted exactly twice (401 then active)"; else bad "unexpected verify attempt count: $(cat "$STUB_DIR/verify.count")"; fi

# ── 3. dry-run stays offline and states the verify plan ───────────────────────
echo "dry-run:"

run_mint "$OUT" --dry-run --name t --perm DNS:Edit --zone example.test --vault-secret cf-token; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "mint --dry-run exits 0"; else bad "mint --dry-run: want exit 0, got $rc"; fi
if [[ ! -s "$CALLS" ]]; then ok "mint --dry-run runs no curl and no az"; else bad "mint --dry-run touched the stubs: $(cat "$CALLS")"; fi
if grep -qi "VERIFY the minted token" "$OUT"; then ok "dry-run plan includes the verify step"; else bad "dry-run plan omits the verify step"; fi
if grep -q "only after verify passes" "$OUT"; then ok "dry-run plan states the vault write is gated on verify"; else bad "dry-run plan does not gate the vault write"; fi

run_mint "$OUT" --dry-run --revoke tok-dead-beef; rc=$?
if [[ "$rc" -eq 0 && ! -s "$CALLS" ]]; then ok "revoke --dry-run exits 0 with no calls"; else bad "revoke --dry-run: exit $rc, calls: $(cat "$CALLS")"; fi

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "cf-mint-token tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
