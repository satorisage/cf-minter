#!/usr/bin/env bash
#
# cf-minter.test.sh — proves the DISPATCHER, and only the dispatcher.
#
# cf-minter is a pure mapping from a verb to an exec of one of the two tools, so
# what must be true here is narrow and entirely about routing and refusal:
#
#   1. Every verb reaches the right tool with the right flags — asserted by
#      stubbing the two tools themselves and reading back what they were called
#      with. Nothing here re-tests minting, burning, or scope rules; those are
#      the tools' own suites (cf-mint-token.test.sh, cf-scoped-run.test.sh) and
#      duplicating them here would give two places to update for one fact.
#   2. Every refusal names the fix, not just the problem — the help surface is a
#      claim about what the tool does, so an unknown verb, a leading flag, and a
#      bare 'burn' each have to point somewhere useful.
#   3. Exit codes: 2 for a usage error, 0 for help, so callers can tell a typo
#      from a failure.
#
# Run:  bash test/cf-minter.test.sh   (exit 0 = all pass)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL="$HERE/../cf-minter"

PASS=0 FAIL=0
ok(){  PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1" >&2; }

# A sandbox holding cf-minter beside STUBS of the two tools it drives. The
# dispatcher resolves them relative to its own path, so copying it next to the
# stubs is what redirects the handoff — no flag, no env var, no edit to the
# script under test.
BOX="$(mktemp -d)"; trap 'rm -rf "$BOX"' EXIT
cp "$REAL" "$BOX/cf-minter"
for tool in cf-scoped-run.sh cf-mint-token.sh; do
  cat > "$BOX/$tool" <<STUB
#!/usr/bin/env bash
printf '%s' "\$(basename "\$0")" > "$BOX/called-tool"
printf '%s\n' "\$*"             > "$BOX/called-args"
exit 0
STUB
  chmod +x "$BOX/$tool"
done

# dispatch VERB... -> sets TOOL and ARGS to what the dispatcher actually invoked.
dispatch(){
  rm -f "$BOX/called-tool" "$BOX/called-args"
  "$BOX/cf-minter" "$@" >/dev/null 2>&1
  RC=$?
  TOOL="$(cat "$BOX/called-tool" 2>/dev/null || true)"
  ARGS="$(cat "$BOX/called-args" 2>/dev/null || true)"
}

routes(){ # routes "<desc>" "<verb...>" "<expected tool>" "<expected args>"
  local desc="$1" tool="$3" args="$4"; read -r -a argv <<<"$2"
  dispatch "${argv[@]}"
  if [[ "$TOOL" == "$tool" && "$ARGS" == "$args" ]]; then ok "$desc"
  else bad "$desc — got tool='$TOOL' args='$ARGS', wanted tool='$tool' args='$args'"; fi
}

echo "verb routing (each verb reaches the right tool, with the right flags):"
routes "run passes everything through untouched" \
  "run --profile dns-edit --zone example.com -- ./x.sh" \
  "cf-scoped-run.sh" "--profile dns-edit --zone example.com -- ./x.sh"
routes "mint is the runner's --mint-only, not a second mint path" \
  "mint --profile dns-edit --zone example.com" \
  "cf-scoped-run.sh" "--mint-only --profile dns-edit --zone example.com"
routes "profiles reads the profile file via the runner" \
  "profiles" "cf-scoped-run.sh" "--list-profiles"
routes "list without --stale means every token on the account" \
  "list" "cf-mint-token.sh" "--list"
routes "list --stale means only this tool's own residue" \
  "list --stale" "cf-scoped-run.sh" "--list-stale"
routes "burn <id> revokes exactly that token" \
  "burn abc123" "cf-mint-token.sh" "--revoke abc123"
routes "burn --stale sweeps runs whose burn failed" \
  "burn --stale" "cf-scoped-run.sh" "--burn-stale"

echo
echo "refusals (each names the fix, not just the problem):"

refuses(){ # refuses "<desc>" "<verb...>" "<substring the message must carry>"
  local desc="$1" want="$3"; read -r -a argv <<<"$2"
  local out; out="$("$BOX/cf-minter" "${argv[@]}" 2>&1)"; local rc=$?
  if [[ "$rc" -eq 2 && "$out" == *"$want"* ]]; then ok "$desc"
  else bad "$desc — rc=$rc, message lacked '$want': $out"; fi
}

refuses "an unknown verb lists the real ones" \
  "nonsense" "run, mint, profiles, list, burn, doctor"
refuses "a leading flag shows the corrected command, not just 'wrong'" \
  "--profile dns-edit" "cf-minter run --profile dns-edit"
refuses "bare 'burn' says both ways to name a target" \
  "burn" "--stale"
refuses "bare 'burn' points at how to find an id" \
  "burn" "cf-minter list"

echo
echo "the help surface is the cold operator's entry point:"

out="$("$BOX/cf-minter" 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] && ok "bare invocation succeeds — it is help, not an error" \
                  || bad "bare invocation exited $rc, wanted 0"
for verb in run mint profiles list burn doctor; do
  [[ "$out" == *"$verb"* ]] || { bad "help omits the '$verb' command"; continue; }
done
ok "help names every command it dispatches"
[[ "$out" == *"CF_MINTER_TOKEN"* ]] \
  && ok "help names the credential you need before anything works" \
  || bad "help never mentions CF_MINTER_TOKEN"
[[ "$out" == *"--dry-run"* ]] \
  && ok "help offers the zero-network first step" \
  || bad "help never mentions --dry-run"
[[ "$out" == *"Ctrl-C"* || "$out" == *"interrupt"* ]] \
  && ok "help states the burn-on-every-exit guarantee" \
  || bad "help never states the burn guarantee"

hout="$("$BOX/cf-minter" help 2>&1)"
[[ "$hout" == "$out" ]] && ok "'help' and a bare invocation print the same thing" \
                        || bad "'help' differs from bare invocation"

echo
echo "the dispatcher never touches a credential:"
# Principle: this file is a mapping. If it ever learns to handle a token value,
# the secret-never-escapes constraint acquires a second home to audit.
# Read EXECUTABLE lines only. A substring check over the whole file cannot tell
# code that handles a credential from help text that explains one — the help
# necessarily names CLOUDFLARE_API_TOKEN, because telling the operator what
# their command will receive is its job. Strip comments and the usage heredoc,
# then look at what is left: that is the code.
CODE="$(sed -e '/cat <<USAGE/,/^USAGE$/d' -e 's/[[:space:]]*#.*$//' "$REAL")"

grep -qE 'CF_SCOPED_TOKEN|CLOUDFLARE_API_TOKEN|--value-file|--minter-token-file' <<<"$CODE" \
  && bad "cf-minter's code touches a token value or value file — it must only route" \
  || ok "no token value, value file, or credential flag appears in the dispatcher's code"
# Key on what a CALL looks like, not on the word. `doctor` legitimately runs
# `command -v curl` to check the dependency is installed, and naming curl is not
# the same as invoking it — a detector that cannot tell those apart would have
# to be waived here, and a waived check is one nobody trusts later.
grep -qE '(^|[;&|({]|\$\()[[:space:]]*curl[[:space:]]|api\.cloudflare\.com' <<<"$CODE" \
  && bad "cf-minter's code invokes curl or names the API host — it must only route" \
  || ok "no network call appears in the dispatcher's code"

grep -qE '(^|[;&|({]|\$\()[[:space:]]*curl[[:space:]]' <<<"$(printf 'f(){ curl -sS https://api.cloudflare.com/x; }')" \
  && ok "…and that guard still detects a genuine curl invocation" \
  || bad "the network guard no longer detects a real call — it is vacuous"

# The guard above is only worth having if it can still fail. Prove the detector
# sees a real violation rather than agreeing with the stripping.
grep -qE 'CF_SCOPED_TOKEN' <<<"$(printf 'x(){ export CF_SCOPED_TOKEN=1; }')" \
  && ok "…and that guard still detects a genuine violation when one exists" \
  || bad "the credential guard no longer detects anything — it is vacuous"

echo
echo "installed as a symlink on PATH (the common install):"
# ln -s /opt/cf-minter/cf-minter /usr/local/bin/cf-minter is how anyone puts this
# on PATH, and BASH_SOURCE[0] is then the LINK's path, not the target's — so the
# sibling tools beside the real script are invisible unless the link is resolved.
LINKDIR="$(mktemp -d)"
ln -s "$BOX/cf-minter" "$LINKDIR/cf-minter"
rm -f "$BOX/called-tool" "$BOX/called-args"
PATH="$LINKDIR:$PATH" cf-minter profiles >/dev/null 2>&1; rc=$?
if [[ "$rc" -eq 0 ]]; then ok "a symlinked cf-minter runs at all"; else bad "symlinked cf-minter exited $rc"; fi
if [[ "$(cat "$BOX/called-tool" 2>/dev/null)" == "cf-scoped-run.sh" ]]; then
  ok "…and resolves its siblings next to the TARGET, not next to the link"
else bad "symlinked cf-minter reached '$(cat "$BOX/called-tool" 2>/dev/null)', wanted cf-scoped-run.sh"; fi
# A chain of links is the same problem twice; the resolver loops for this reason.
ln -s "$LINKDIR/cf-minter" "$LINKDIR/cf-minter-2"
rm -f "$BOX/called-tool"
PATH="$LINKDIR:$PATH" cf-minter-2 profiles >/dev/null 2>&1
if [[ "$(cat "$BOX/called-tool" 2>/dev/null)" == "cf-scoped-run.sh" ]]; then
  ok "…through a chain of symlinks, not just one"
else bad "a symlink-to-a-symlink did not resolve"; fi
rm -rf "$LINKDIR"

echo
printf 'cf-minter dispatcher tests: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
