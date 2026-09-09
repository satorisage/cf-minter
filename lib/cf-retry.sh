#!/usr/bin/env bash
#
# cf-retry.sh — retry a Cloudflare API call through the token-propagation window.
# Sourced by cf-mint-token.sh; sourcing only defines
# functions and has NO side effects (nothing runs, nothing is printed).
#
# ── Why this exists ───────────────────────────────────────────────────────────
# Cloudflare's auth edge is eventually-consistent. A just-minted, rolled, or
# re-scoped API token is rejected with `{"success":false,"errors":[{"code":10000,
# "message":"Authentication error"}]}` (HTTP 401) by some edge nodes for up to
# ~2 minutes before every node accepts it. Fleet scripts that call the CF API
# immediately after such a change would hard-fail on that first transient 401 even
# though the token is valid. This wrapper retries ONLY that transient signal so a
# valid-but-still-propagating token succeeds once the edge catches up.
#
# ── What it retries, and what it deliberately does NOT ────────────────────────
# Retry ONLY the propagation-transient signal:
#   * the JSON body is success:false carrying an error whose code is 10000, OR
#   * the HTTP status is 401 with an EMPTY body (nothing to classify — benefit of
#     the doubt, since a propagating token also answers 401).
# Everything else is passed straight through with no retry, because it will not
# self-heal on a wait:
#   * a 401 whose body carries any OTHER code — e.g. 1000 (invalid token) — is a
#     genuinely-bad credential, not auth lag; waiting ~110s would never fix it.
#   * code 9109 (unauthorized / out-of-scope) — a real permission gap.
#   * origin 5xx, DNS/connection failures, malformed requests — not auth lag.
#   * any other non-auth error.
# Retrying those would only add latency to a certain failure.
#
# To make that classification possible even for callers that pass -f/--fail
# (which suppresses the body on a 4xx and would leave every 401 unclassifiable —
# burning the full retry budget on a genuinely-bad token), each attempt appends
# curl's boolean negation --no-fail so the error body always survives internally.
# The -f contract is then re-imposed on hand-back: when the caller asked for
# fail-mode and the final status is 4xx/5xx, the wrapper prints nothing and
# returns 22, exactly as bare `curl -f` would.
#
# ── Interface ─────────────────────────────────────────────────────────────────
# cf_call_with_retry <curl-args…>
#   A thin wrapper around one `curl` invocation. It does NOT build the request —
#   the caller passes the exact curl argument list it already assembled, so the
#   method, path, headers, body, and flags (e.g. -sS vs -fsS) are unchanged. The
#   wrapper only:
#     1. prepends `-w '\n%{http_code}'` to observe the HTTP status, and appends
#        `--no-fail` so the error body survives a 4xx for classification even
#        under a caller's -f (see above),
#     2. runs the call, splits that status line back off,
#     3. echoes ONLY the caller's JSON body on stdout and returns curl's own exit
#        status — with -f semantics re-imposed for fail-mode callers (no body +
#        exit 22 on a final 4xx/5xx) — so a caller capturing
#        `$(cf_call_with_retry …)` sees exactly the bytes and status it would
#        have seen from a bare `curl`, and its existing success/error handling is
#        unchanged.
#   If the response is the propagation-transient signal it retries with bounded
#   backoff; after the final attempt it returns that last response as-is, so the
#   caller's own error path fires with the real Cloudflare message.
#
# Backoff: 5 attempts at ~0s, 5s, 15s, 30s, 60s before-attempt delays (≈110s of
# waiting across the four retries). Each retry logs one non-sensitive line to
# stderr; no token, header, or body value is ever printed.
#
# Bash 3.2 safe (macOS default): plain arrays, ANSI-C quoting, no associative
# arrays. Requires curl (the callers already do); uses jq when present and falls
# back to a grep match on the compact JSON otherwise.

# _cf_is_auth_10000 BODY — true when BODY is a Cloudflare success:false response
# carrying an error with code 10000 (the propagation-transient auth signal). An
# empty body (curl -f suppresses it on a 4xx) is never a match — the 401 status
# check covers that case in the caller.
_cf_is_auth_10000() {
  local body="$1"
  [ -n "$body" ] || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -e '(.success==false) and (any(.errors[]?; .code==10000))' <<<"$body" >/dev/null 2>&1
    return $?
  fi
  # jq-less fallback: Cloudflare returns compact single-line JSON, so a pair of
  # literal matches is a safe stand-in for the structural check above.
  printf '%s' "$body" | grep -q '"success":false' \
    && printf '%s' "$body" | grep -q '"code":10000'
}

# cf_call_with_retry <curl-args…> — see the header block for the full contract.
cf_call_with_retry() {
  # Before-attempt delays (the first is immediate). Four retries → ≈110s of waiting.
  local -a _delays=(0 5 15 30 60)

  # Did the caller ask for curl's fail mode (-f / --fail)? Each attempt runs with
  # --no-fail appended so the 401 body survives for classification; this flag
  # re-imposes the -f contract (no body, exit 22) on the final hand-back. The scan
  # treats an element as a short-flag cluster only when it is letters-only (so an
  # attached numeric value like -m30 can't false-match); a letters-only attached
  # value containing 'f' (e.g. -ofile) would be misread, but no cf caller passes
  # one and the wrapper exists for this tool's cf_* helpers.
  # The same pass also notes whether any argument names /dev/stdin (e.g. the
  # `-H @/dev/stdin` the stdin-feeding callers use) — that reference is what decides
  # whether piped stdin gets buffered below.
  local _fail_mode=0 _wants_stdin=0 _arg
  for _arg in "$@"; do
    case "$_arg" in
      */dev/stdin*) _wants_stdin=1 ;;
    esac
    case "$_arg" in
      --fail) _fail_mode=1 ;;
      --*) : ;;
      -[A-Za-z]*)
        case "$_arg" in
          *[!A-Za-z-]*) : ;;
          *f*) _fail_mode=1 ;;
        esac ;;
    esac
  done

  # Buffer piped stdin once so it can be replayed on every attempt — but ONLY when
  # the caller's curl args actually read stdin (an argument naming /dev/stdin).
  # Callers that feed the Authorization header via `-H @/dev/stdin` need this:
  # stdin is consumed by the first curl, so a naive re-run on retry would send no
  # auth header and manufacture the very 401 we are trying to ride out. A non-tty
  # stdin ALONE is not a signal to buffer: a backgrounded run inherits an
  # open-but-silent pipe as fd 0, and an unconditional read on it blocks forever —
  # a call that carries its auth in argv must never wait on stdin it will not use.
  local _stdin_buf="" _have_stdin=0
  if [ "$_wants_stdin" -eq 1 ] && [ ! -t 0 ]; then
    _stdin_buf="$(cat)"
    _have_stdin=1
  fi

  local i delay resp status http_code body reason=""
  for i in 0 1 2 3 4; do
    delay="${_delays[$i]}"
    if [ "$i" -gt 0 ]; then
      # $reason was set by the previous (transient) attempt. Attempt number is i+1.
      printf '  info  Cloudflare token still propagating (%s) — retry %d/5 in %ds…\n' \
        "$reason" "$((i + 1))" "$delay" >&2
      sleep "$delay"
    fi

    # Run the caller's exact curl call plus our observability -w, with --no-fail
    # appended AFTER the caller's args so it overrides a caller -f and the error
    # body survives for classification. The `&& … || …` list keeps a non-zero curl
    # (network failure etc.) from tripping the caller's `set -e`; curl's status is
    # captured either way.
    if [ "$_have_stdin" -eq 1 ]; then
      resp="$(printf '%s' "$_stdin_buf" | curl -w '\n%{http_code}' "$@" --no-fail)" && status=0 || status=$?
    else
      resp="$(curl -w '\n%{http_code}' "$@" --no-fail </dev/null)" && status=0 || status=$?
    fi

    # Split the trailing "\n<http_code>" back off; the rest is the caller's body.
    http_code="${resp##*$'\n'}"
    body="${resp%$'\n'*}"

    if _cf_is_auth_10000 "$body"; then
      reason="auth 10000"
    elif [ "$http_code" = "401" ] && [ -z "$body" ]; then
      # Nothing to classify — benefit of the doubt (a propagating token answers
      # 401 too). Rare now that --no-fail keeps the body; kept for the odd edge
      # where the body genuinely goes missing.
      reason="HTTP 401, empty body"
    else
      # Success, or a failure that will not self-heal — hand it straight back. A
      # 401 carrying any non-10000 code (e.g. 1000, invalid token) lands here and
      # returns on the FIRST attempt instead of burning the whole retry budget.
      _cf_hand_back "$_fail_mode" "$http_code" "$body" "$status"
      return $?
    fi
    # Transient: fall through to the next attempt (or exhaust the loop).
  done

  # Propagation window exhausted — return the final response so the caller's own
  # error handling fires with the real Cloudflare message.
  _cf_hand_back "$_fail_mode" "$http_code" "$body" "$status"
}

# _cf_hand_back FAIL_MODE HTTP_CODE BODY STATUS — emit the final response with the
# caller's own curl semantics. Fail-mode callers get exactly what bare `curl -f`
# gives on an HTTP error: no body, exit 22. Everyone else gets the body and curl's
# own exit status.
_cf_hand_back() {
  local _fm="$1" _code="$2" _body="$3" _st="$4"
  if [ "$_fm" -eq 1 ]; then
    case "$_code" in
      [45][0-9][0-9]) return 22 ;;
    esac
  fi
  printf '%s' "$_body"
  return "$_st"
}
