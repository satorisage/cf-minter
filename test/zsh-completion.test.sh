#!/usr/bin/env bash
#
# zsh-completion.test.sh — proves the zsh completion COMPLETES, not that it parses.
#
# This file exists because of a bug it would have caught. The first version of
# completions/_cf-minter was checked with `zsh -n` (it parses) and by loading it
# under compinit (it registers). Both passed. Pressing TAB produced a directory
# listing: _arguments reads the command line from words[1], so it saw the
# dispatcher as the command and every verb as an unexpected argument, matched
# nothing, and fell through to filenames. A syntax check cannot see that — it
# shares the blind spot of the thing it is checking.
#
# So the assertion here is the candidate list itself, captured from a real
# interactive zsh driven through a pseudo-terminal, with a real TAB keypress.
# Offline: the only command it runs is `cf-minter profiles --names`, which reads
# profiles.conf and nothing else.
#
# Run:  bash test/zsh-completion.test.sh   (exit 0 = all pass, or a clean skip)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

PASS=0 FAIL=0
ok(){  PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1" >&2; }

echo "zsh completion (driven through a pty, with a real TAB):"

# A skip is stated, never silent: a suite that quietly drops a check reads as
# green for a reason nobody can see. And where the environment was prepared on
# purpose — CI installs zsh on both runners — a skip is not a tolerable outcome
# at all, because the only thing it can mean is that the preparation broke.
# CF_REQUIRE_ZSH turns the skip into the failure it is there.
require_zsh="${CF_REQUIRE_ZSH:-0}"
unavailable(){
  if [[ "$require_zsh" != "0" ]]; then
    bad "$1 — CF_REQUIRE_ZSH is set, so this is a failure, not a skip"
    printf '\nzsh completion tests: %d passed, %d failed\n' "$PASS" "$FAIL"
    exit 1
  fi
  echo "  skip  $1"
  exit 0
}
command -v zsh >/dev/null 2>&1 \
  || unavailable "zsh is not installed here — completion behaviour unverified on this host"
zsh -fc 'zmodload zsh/zpty' 2>/dev/null \
  || unavailable "zsh/zpty unavailable — completion behaviour unverified on this host"

BOX="$(mktemp -d)"; trap 'rm -rf "$BOX"' EXIT

# A throwaway ZDOTDIR: the operator's own zshrc must not decide whether this
# passes, and compinit needs its dump somewhere writable and fresh.
#
# .zshenv is read BEFORE the system-wide /etc/zsh/zshrc, which is the only place
# this setting can be made in time. Debian and Ubuntu ship a zshrc that runs a
# bare `compinit` of its own, and on a machine with a group-writable directory
# on fpath — which is what a CI runner has — that call finds an insecure
# directory, cannot ask a question it has no one to ask, and aborts. It takes
# the completion system down with it before the completion under test is ever
# loaded. The variable is Debian's own documented escape hatch, named in a
# comment directly above the call it disables.
cat > "$BOX/.zshenv" <<'ZENV'
skip_global_compinit=1
ZENV

# -u and -i: use insecure directories and do not ask about them. A CI runner
# legitimately has world-writable directories on fpath, and this suite is not
# the place to adjudicate that — it is here to complete a command line.
cat > "$BOX/.zshrc" <<ZRC
fpath=($REPO/completions \$fpath)
path=($REPO \$path)
autoload -Uz compinit
compinit -u -i -d "$BOX/zcompdump"
PS1='RDY%# '
ZRC

# capture <line> — type <line> into an interactive zsh, press TAB, return what
# the terminal then showed, stripped of escape sequences.
capture(){
  ZDOTDIR="$BOX" zsh -fc '
    zmodload zsh/zpty
    zpty z "ZDOTDIR='"$BOX"' zsh -i"
    sleep 2
    zpty -r -t z junk "*RDY*" >/dev/null 2>&1
    zpty -w -n z "'"$1"'"
    sleep 0.5
    zpty -w -n z $'"'"'\t'"'"'
    sleep 3
    integer i=0; local chunk all=""
    while (( i++ < 40 )); do
      if zpty -r -t z chunk 2>/dev/null; then all+=$chunk; else sleep 0.1; fi
    done
    print -r -- $all
    zpty -d z
  ' 2>/dev/null | tr -d '\r' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
}

# 1. The verbs, at the first word.
out="$(capture 'cf-minter ')"
if grep -q 'run' <<<"$out" && grep -q 'doctor' <<<"$out" && grep -q 'profiles' <<<"$out"; then
  ok "the first word completes to the verbs"
else bad "first-word completion offered: $(tr '\n' ' ' <<<"$out" | cut -c1-120)"; fi
if grep -q 'burn it after' <<<"$out"; then
  ok "…each verb carrying what it does"
else bad "verbs completed without their descriptions"; fi

# 2. The profile names — the headline, and the case that was broken.
out="$(capture 'cf-minter run --profile ')"
for p in dns-edit zone-harden pages-deploy; do
  if grep -q "$p" <<<"$out"; then ok "--profile completes '$p'"
  else bad "--profile did not offer '$p'"; fi
done
# The bug's signature: a fall-through to filenames. Nothing in this repo's file
# list should ever appear as a profile candidate.
if grep -qE 'README\.md|cf-scoped-run\.sh|profiles\.conf' <<<"$out"; then
  bad "--profile fell through to filename completion (the _arguments words[1] bug)"
else ok "…and offers no filenames, so it is not falling through"; fi
# Reach beside the name is why this is worth having: choosing a profile is
# choosing a blast radius.
if grep -qE 'zone · |account · ' <<<"$out"; then
  ok "…with each profile's scope, ttl and purpose beside it"
else bad "profile candidates carried no reach description"; fi

# 3. A flag with a fixed vocabulary.
out="$(capture 'cf-minter run --ttl ')"
if grep -q '15m' <<<"$out" && grep -q '1d' <<<"$out"; then
  ok "--ttl completes durations"
else bad "--ttl offered: $(tr '\n' ' ' <<<"$out" | cut -c1-120)"; fi

# 4. Per-verb flags. Two candidates share the '--' prefix, so the line is typed
#    with it already present — otherwise zsh inserts the common prefix and waits.
out="$(capture 'cf-minter list --')"
if grep -q 'stale' <<<"$out"; then ok "list completes --stale"
else bad "list --  offered: $(tr '\n' ' ' <<<"$out" | cut -c1-120)"; fi

echo
printf 'zsh completion tests: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
