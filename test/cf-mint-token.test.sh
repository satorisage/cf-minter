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
    -H) case "${args[$((i+1))]}" in Authorization:*) auth="${args[$((i+1))]#Authorization: Bearer }" ;; esac ;;
    -w) wfmt=1 ;;
    --data) data="${args[$((i+1))]}" ;;
    https://*) url="${args[$i]}" ;;
  esac
done
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

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "cf-mint-token tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
