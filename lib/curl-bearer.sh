#!/usr/bin/env bash
#
# curl-bearer.sh — a credential reaches curl as CONFIG on its stdin, never on argv.
#
# WHY
# ---
# A process's command line is readable by every other process on the machine
# (`ps -ef`, /proc/<pid>/cmdline). A call written as
#     curl -H "authorization: Bearer $TOKEN" …
# puts the credential there for as long as the call runs — the operator
# break-glass bearer on a laptop, a minted Entra or Cloudflare token on a seat or
# a runner. So every credential-bearing call hands curl its header through curl's
# own config syntax on stdin instead:
#     curl_bearer_config "$TOKEN" | curl -K - …
# printf is a shell builtin, so the value is written into the pipe without ever
# becoming an argument of any program.
#
#   curl_bearer_config TOKEN        the `authorization: Bearer TOKEN` header
#   curl_header_config NAME VALUE   any other credential header, byte-exact
#                                   (an API key header, or a vendor that
#                                   documents its scheme in lower case)
#   curl_url_config URL             a URL that is itself the credential (an
#                                   incoming webhook whose path is its token)
#   curl_body_config BODY           a request body that carries a credential (a
#                                   webhook registration naming its password, a
#                                   hook URL with the password embedded), sent
#                                   byte-exact as curl's `data-raw`
# Each prints ONE curl config line on stdout, for `curl -K -`. Several compose:
#     { curl_header_config NAME "$TOKEN"; curl_body_config "$BODY"; } | curl -K - …
#
# QUOTING. The value is written inside curl's quoted config string, where a
# backslash and a double quote are escape characters: both are escaped here, so
# neither can end the string early (measured against real curl: the header
# arrives byte-for-byte). A CONTROL character (a newline, a carriage return, a
# tab, anything below space, or DEL) is refused by name and nothing is printed:
# curl's config is line-based, so a newline inside a token would start a second
# config directive of the token's choosing — an injection, never a credential.
# A refusal leaves curl with no header at all, so the request fails at the server
# as unauthenticated instead of carrying a mangled credential, and the reason is
# on stderr.
#
# THE OTHER STDIN SPELLING. A caller may send the header as a header FILE on
# stdin instead (`printf 'Authorization: Bearer %s' … | … -H
# @/dev/stdin`). That is off argv too and stays valid; this library is the form
# for every other call. Where stdin already carries a request body (`--data @-`),
# the body moves to a private file so stdin is free for the config.
#
# Defines functions only; sourcing has no side effects.

[[ -n "${CURL_BEARER_LIB:-}" ]] && return 0
CURL_BEARER_LIB=1

# curl_header_config NAME VALUE — one `header = "NAME: VALUE"` config line.
# Returns 2, printing nothing on stdout, when NAME is empty or not a header token,
# or when either part carries a control character.
curl_header_config(){ # args: name value
  local name="${1-}" value="${2-}"
  if [[ -z "$name" || "$name" == *[!A-Za-z0-9_-]* ]]; then
    printf 'curl-bearer: refused — "%s" is not an HTTP header name; no credential header was written\n' "$name" >&2
    return 2
  fi
  case "$value" in
    *[[:cntrl:]]*)
      printf 'curl-bearer: refused — the %s value carries a control character (a newline, a carriage return or the like), which would break out of curl'"'"'s one-line config; no credential header was written\n' "$name" >&2
      return 2 ;;
  esac
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf 'header = "%s: %s"\n' "$name" "$value"
}

# curl_url_config URL — one `url = "URL"` config line, for a URL that is itself a
# credential (an incoming webhook whose path is its token). Returns 2, printing
# nothing on stdout, when URL is empty or carries a control character.
curl_url_config(){ # args: url
  local url="${1-}"
  if [[ -z "$url" ]]; then
    printf 'curl-bearer: refused — an empty URL; no url line was written\n' >&2
    return 2
  fi
  case "$url" in
    *[[:cntrl:]]*)
      printf 'curl-bearer: refused — the URL carries a control character, which would break out of curl'"'"'s one-line config; no url line was written\n' >&2
      return 2 ;;
  esac
  url="${url//\\/\\\\}"
  url="${url//\"/\\\"}"
  printf 'url = "%s"\n' "$url"
}

# curl_body_config BODY — one `data-raw = "BODY"` config line: the request body,
# sent exactly as given (data-raw, not data, so a body that begins with '@' is
# never read as a file name). A compact JSON body carries no control character
# (the encoder escapes them inside strings), so one is refused here like any
# other value. Returns 2, printing nothing on stdout, when BODY is empty or
# carries a control character — curl then sends no body and the vendor refuses
# the request, rather than the request carrying half a body.
curl_body_config(){ # args: body
  local body="${1-}"
  if [[ -z "$body" ]]; then
    printf 'curl-bearer: refused — an empty request body; no data line was written\n' >&2
    return 2
  fi
  case "$body" in
    *[[:cntrl:]]*)
      printf 'curl-bearer: refused — the request body carries a control character, which would break out of curl'"'"'s one-line config; no data line was written\n' >&2
      return 2 ;;
  esac
  body="${body//\\/\\\\}"
  body="${body//\"/\\\"}"
  printf 'data-raw = "%s"\n' "$body"
}

# curl_bearer_config TOKEN — the authorization header carrying TOKEN as a bearer.
curl_bearer_config(){ # args: token
  curl_header_config authorization "Bearer ${1-}"
}
