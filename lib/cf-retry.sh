#!/usr/bin/env bash
#
# cf-retry.sh — retry a Cloudflare API call through the token-propagation window.
# Sourced by cf-mint-token.sh; sourcing only defines functions and has NO side
# effects (nothing runs, nothing is printed).
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
#   * the HTTP status is 401, OR
#   * the JSON body is success:false carrying an error whose code is 10000.
# Everything else is passed straight through with no retry, because it will not
# self-heal on a wait:
#   * code 9109 (unauthorized / out-of-scope) — a real permission gap.
#   * origin 5xx, DNS/connection failures, malformed requests — not auth lag.
#   * any other non-auth error.
# Retrying those would only add latency to a certain failure.
#
# ── Interface ─────────────────────────────────────────────────────────────────
# cf_call_with_retry <curl-args…>
#   A thin wrapper around one `curl` invocation. It does NOT build the request —
#   the caller passes the exact curl argument list it already assembled, so the
#   method, path, headers, body, and flags (e.g. -sS vs -fsS) are unchanged. The
#   wrapper only:
#     1. appends `-w '\n%{http_code}'` so it can observe the HTTP status even when
#        the caller's own -f suppresses the response body on a 4xx,
#     2. runs the call, splits that status line back off,
#     3. echoes ONLY the caller's JSON body on stdout and returns curl's own exit
#        status — so a caller capturing `$(cf_call_with_retry …)` sees exactly the
#        bytes it would have seen from a bare `curl`, and its existing success/error
#        handling is unchanged.
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

  # Buffer any piped stdin once so it can be replayed on every attempt. deploy.sh /
  # acs-esp-setup.sh feed the Authorization header via `-H @/dev/stdin`; stdin is
  # consumed by the first curl, so a naive re-run on retry would send no auth header
  # and manufacture the very 401 we are trying to ride out. When stdin is a terminal
  # there is nothing to replay.
  local _stdin_buf="" _have_stdin=0
  if [ ! -t 0 ]; then
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

    # Run the caller's exact curl call plus our observability -w. The `&& … || …`
    # list keeps a non-zero curl (e.g. -f on a 401 → exit 22) from tripping the
    # caller's `set -e`; curl's status is captured either way.
    if [ "$_have_stdin" -eq 1 ]; then
      resp="$(printf '%s' "$_stdin_buf" | curl -w '\n%{http_code}' "$@")" && status=0 || status=$?
    else
      resp="$(curl -w '\n%{http_code}' "$@" </dev/null)" && status=0 || status=$?
    fi

    # Split the trailing "\n<http_code>" back off; the rest is the caller's body.
    http_code="${resp##*$'\n'}"
    body="${resp%$'\n'*}"

    if [ "$http_code" = "401" ]; then
      reason="HTTP 401"
    elif _cf_is_auth_10000 "$body"; then
      reason="auth 10000"
    else
      # Success, or a failure that will not self-heal — hand it straight back.
      printf '%s' "$body"
      return "$status"
    fi
    # Transient: fall through to the next attempt (or exhaust the loop).
  done

  # Propagation window exhausted — return the final response so the caller's own
  # error handling fires with the real Cloudflare message.
  printf '%s' "$body"
  return "$status"
}
