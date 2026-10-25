#!/usr/bin/env bash
# shellcheck disable=SC2034  # the VAULT_PROBE_* results are read by the sourcing caller
#
# vault-store-probe.sh — prove a Key Vault will take a WRITE before a vendor is asked
# to mint a credential that only that write can keep.
#
# WHY
# ---
# A mint is a CREATE at the vendor: a Cloudflare API token is shown exactly once, and
# every Origin CA request issues a new certificate. When the vault store after it is
# refused (a lapsed role activation, a role that reads but cannot write, a vault name
# that is wrong), the credential is live at the vendor and kept nowhere — the failure
# this exists to make impossible. A READ of the target does not rule it out: a reader
# role, or a write-only denial, answers a read and refuses the store. So the probe is
# a real write of the same object class the store will make, read back, before the
# vendor is called at all.
#
# THE PROBE SHAPE, and why it does not pile up
# --------------------------------------------
# Key Vault soft-delete keeps a deleted object's NAME reserved for the vault's whole
# retention period (7–90 days, default 90), and while it is reserved a new object of
# that name cannot be created; with purge protection on, nothing can shorten that.
# (learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview.) So a
# "write a throwaway object, then delete it" probe either reuses one name — and the
# second probe is refused by the first one's deleted remains — or mints a fresh name
# every run and leaves one deleted object behind per mint, unpurgeable on a
# purge-protected vault. Neither is acceptable.
#
# Instead each vault holds ONE probe object per class, under a fixed name, that is
# never deleted. A probe is a new VERSION of it, written DISABLED in the write itself
# (`secret set --disabled true`, `certificate import --disabled true`). A disabled
# version cannot be read or used by anyone, so the probe is inert from the instant it
# exists — there is no window in which a usable throwaway object sits in the vault,
# and nothing to clean up if the run dies right after the write. What accumulates is
# one disabled version per mint under one name: bounded by how often credentials are
# minted, invisible to `list` (which returns one row per name), and never a second
# name. Read-back is the version's own attributes (list-versions — a disabled
# version's value is unreadable by design), which proves the write landed.
#
# Secrets and certificates are probed separately because the roles are separate: a
# certificate import needs certificates/import, which Key Vault Certificates Officer
# carries and Secrets Officer does not, and the reverse for a secret set (built-in
# role definitions, learn.microsoft.com/en-us/azure/role-based-access-control/
# built-in-roles/security). A secret write proves nothing about a certificate import.
# The two probe names differ because importing a certificate also creates a secret of
# the certificate's name, so one name cannot serve both classes.
#
# Both probe objects carry an expiry far past any warning window — the secret is
# stamped with one, the certificate is a local self-signed throwaway whose validity
# sets one — so an expiry check reads them as healthy rather than as unstamped or
# about to lapse. The certificate's key is junk generated for the probe, never used.
#
# THE TARGET
# ----------
# When the caller names the object it is about to store, the probe also asks whether
# that name is held in the deleted-but-recoverable state: a store onto such a name is
# refused for the whole retention period, so it is the same mint-then-store failure by
# another road. A target held deleted refuses the mint by name. Recovering it here
# would resurrect whatever credential was deleted, which is the operator's call, not
# this preflight's. A deleted-state read that cannot be answered (anything but found /
# not found) does not refuse — the write above already proved the store will be taken
# — it is handed back as a note for the caller to print.
#
# SELF-HEAL
# ---------
#   * Throttling, 5xx and connection drops are retried with backoff (Key Vault answers
#     429 under load; a dropped connection says nothing about the vault).
#   * The probe's own name found deleted (someone deleted the probe object) is
#     recovered once and the write retried — the probe object holds nothing anyone
#     needs, so bringing it back is safe, unlike a target.
# Every other refusal is final on the first answer and is handed back in az's words.
#
# INTERFACE
# ---------
#   vault_store_probe CLASS VAULT [TARGET]
#       CLASS is `secret` or `certificate`. Call it as a condition (if/||): it returns
#       rather than exits, so `set -e` callers keep control of the refusal.
#       rc 0 — the vault took a write of CLASS from this identity and read it back.
#              VAULT_PROBE_VERSION holds the probe version id; VAULT_PROBE_NOTE holds
#              anything the caller should print (empty when there is nothing).
#       rc 1 — refused; VAULT_PROBE_ERR names which step and why, with az's words.
#       rc 2 — usage error (bad CLASS / missing VAULT).
#
# Tunables (environment; defaults are what an operator run wants):
#   VAULT_PROBE_SECRET_NAME   the probe secret's name        (default mint-store-probe)
#   VAULT_PROBE_CERT_NAME     the probe certificate's name   (default mint-store-probe-cert)
#   VAULT_PROBE_ATTEMPTS      tries per call on a transient  (default 4)
#   VAULT_PROBE_BACKOFF       first backoff in seconds, doubled per retry (default 3)
#
# Sourced, never executed. Defines functions and the variables above; no other side
# effect on source. Needs az, jq and (for certificates) openssl.

VAULT_PROBE_SECRET_NAME="${VAULT_PROBE_SECRET_NAME:-mint-store-probe}"
VAULT_PROBE_CERT_NAME="${VAULT_PROBE_CERT_NAME:-mint-store-probe-cert}"
VAULT_PROBE_ATTEMPTS="${VAULT_PROBE_ATTEMPTS:-4}"
VAULT_PROBE_BACKOFF="${VAULT_PROBE_BACKOFF:-3}"
# Results, read by the caller after vault_store_probe returns.
VAULT_PROBE_ERR="" VAULT_PROBE_NOTE="" VAULT_PROBE_VERSION=""

# vault_probe_classify TEXT — which kind of refusal this is, from Key Vault's own
# words. Anything not recognised is `other`, which is final: an unrecognised error is
# never retried into a different answer.
vault_probe_classify(){ # args: error-text
  case "$1" in
    *ObjectIsDeletedButRecoverable*|*"deleted but recoverable"*|*"Deleted but Recoverable"*)
      printf 'deleted' ;;
    *TooManyRequests*|*Throttl*|*throttl*|*"(429)"*|*ServiceUnavailable*|*"(503)"*|*InternalServerError*|*"(500)"*|*BadGateway*|*"(502)"*|*GatewayTimeout*|*"(504)"*|*ObjectIsBeingRecovered*|*"Connection aborted"*|*"Connection reset"*|*"timed out"*|*"RemoteDisconnected"*)
      printf 'transient' ;;
    *NotFound*|*"not found"*)
      printf 'absent' ;;
    *)
      printf 'other' ;;
  esac
}

# _vault_probe_az ERRFILE ARGS… — run `az ARGS…`, retrying a transient refusal with
# backoff. stdout lands in _VP_OUT and stderr in _VP_ERR, kept apart so a warning az
# prints on stderr never corrupts an id read from stdout. Returns az's exit code.
_vault_probe_az(){ # args: errfile az-args…
  local errf="$1"; shift
  local attempt=1 delay="$VAULT_PROBE_BACKOFF" rc
  while :; do
    rc=0
    _VP_OUT="$(az "$@" 2>"$errf")" || rc=$?
    _VP_ERR="$(cat "$errf" 2>/dev/null)"
    [[ "$rc" -eq 0 ]] && return 0
    [[ "$(vault_probe_classify "$_VP_ERR")" == transient ]] || return "$rc"
    [[ "$attempt" -ge "$VAULT_PROBE_ATTEMPTS" ]] && return "$rc"
    sleep "$delay"
    attempt=$((attempt + 1)); delay=$((delay * 2))
  done
}

# _vault_probe_cert_pfx DIR — a throwaway self-signed certificate + key, packaged as
# the passwordless .pfx the real import also takes. Printed path on success.
_vault_probe_cert_pfx(){ # args: dir
  local d="$1"
  openssl req -x509 -newkey rsa:2048 -nodes -days 36500 -subj "/CN=$VAULT_PROBE_CERT_NAME" \
    -keyout "$d/probe-key.pem" -out "$d/probe-cert.pem" >/dev/null 2>&1 || return 1
  openssl pkcs12 -export -inkey "$d/probe-key.pem" -in "$d/probe-cert.pem" \
    -out "$d/probe.pfx" -passout pass: >/dev/null 2>&1 || return 1
  [[ -s "$d/probe.pfx" ]] || return 1
  printf '%s' "$d/probe.pfx"
}

vault_store_probe(){ # args: class vault [target]
  local class="${1:-}" vault="${2:-}" target="${3:-}"
  VAULT_PROBE_ERR="" VAULT_PROBE_NOTE="" VAULT_PROBE_VERSION=""
  case "$class" in
    secret|certificate) ;;
    *) VAULT_PROBE_ERR="vault_store_probe: CLASS must be 'secret' or 'certificate' (got '$class')"; return 2 ;;
  esac
  [[ -n "$vault" ]] || { VAULT_PROBE_ERR="vault_store_probe: no vault named"; return 2; }

  local probe_name
  if [[ "$class" == secret ]]; then probe_name="$VAULT_PROBE_SECRET_NAME"; else probe_name="$VAULT_PROBE_CERT_NAME"; fi
  if [[ -n "$target" && "$target" == "$probe_name" ]]; then
    VAULT_PROBE_ERR="the store target '$target' is the probe's own name in vault '$vault' — store the credential under another name"
    return 1
  fi

  local work rc=0
  work="$(mktemp -d)" || { VAULT_PROBE_ERR="could not create a private work directory for the probe"; return 1; }
  # Every local file the probe makes lives in $work, which is removed whichever way
  # the body returns — the certificate probe's junk key included.
  _vault_store_probe_body "$class" "$vault" "$target" "$probe_name" "$work" || rc=$?
  rm -rf "$work"
  return "$rc"
}

_vault_store_probe_body(){ # args: class vault target probe-name work-dir
  local class="$1" vault="$2" target="$3" probe_name="$4" work="$5"
  local errf="$work/az.err" write_args=() id="" ver="" recovered=0 kind

  # 1. the write — a new version of the probe object, disabled in the write itself.
  if [[ "$class" == secret ]]; then
    # The nonce is not a secret (it guards nothing and the version is born unreadable),
    # so it rides the command line like any other argument.
    local nonce far
    nonce="store-write-probe $(date -u +%Y-%m-%dT%H:%M:%SZ) $RANDOM$RANDOM"
    far="$(( $(date -u +%Y) + 100 ))-01-01T00:00:00Z"
    write_args=(keyvault secret set --vault-name "$vault" --name "$probe_name"
      --value "$nonce" --disabled true --expires "$far" --tags purpose=store-write-probe
      --query id -o tsv)
  else
    local pfx
    pfx="$(_vault_probe_cert_pfx "$work")" \
      || { VAULT_PROBE_ERR="could not generate the throwaway probe certificate locally (openssl) — nothing was written to '$vault'"; return 1; }
    write_args=(keyvault certificate import --vault-name "$vault" --name "$probe_name"
      --file "$pfx" --disabled true --tags purpose=store-write-probe
      --query id -o tsv)
  fi

  while :; do
    if _vault_probe_az "$errf" "${write_args[@]}"; then
      id="$(printf '%s' "$_VP_OUT" | tr -d '[:space:]')"
      break
    fi
    kind="$(vault_probe_classify "$_VP_ERR")"
    if [[ "$kind" == deleted && "$recovered" -eq 0 ]]; then
      # The probe object itself was deleted and its name is reserved. It holds
      # nothing anyone needs, so it is recovered and the write tried again (a
      # recovery in progress answers ObjectIsBeingRecovered, which the write's own
      # retry rides).
      recovered=1
      if ! _vault_probe_az "$errf" keyvault "$class" recover --vault-name "$vault" --name "$probe_name" -o none; then
        VAULT_PROBE_ERR="vault '$vault' refused a $class write: the probe name '$probe_name' is held deleted-but-recoverable and could not be recovered. Recover or purge it, then re-run. az said: ${_VP_ERR:-<no error output>}"
        return 1
      fi
      VAULT_PROBE_NOTE="the probe $class '$probe_name' had been deleted; it was recovered so the probe could write"
      continue
    fi
    VAULT_PROBE_ERR="vault '$vault' refused a $class write (az keyvault $class ${write_args[2]} '$probe_name'). az said: ${_VP_ERR:-<no error output>}"
    return 1
  done
  ver="${id##*/}"
  if [[ -z "$id" || -z "$ver" || "$ver" == "$id" ]]; then
    VAULT_PROBE_ERR="vault '$vault' accepted the $class probe write but returned no version id (got '${_VP_OUT}') — cannot prove the write landed"
    return 1
  fi

  # 2. the read-back — the version's own attributes. Retried a few times on a miss:
  #    a version listed a moment after its write is the normal case, but the listing
  #    is a separate read and is not promised to be instant.
  local enabled="" attempt=1
  while :; do
    if _vault_probe_az "$errf" keyvault "$class" list-versions --vault-name "$vault" --name "$probe_name" -o json; then
      enabled="$(jq -r --arg v "$ver" \
        '[.[]? | select(((.id // "") | split("/") | last) == $v)] | if length == 0 then "missing" else (.[0].attributes.enabled | tostring) end' \
        <<<"$_VP_OUT" 2>/dev/null)" || enabled=""
    else
      VAULT_PROBE_ERR="vault '$vault' took the $class probe write but its read-back (list-versions '$probe_name') was refused. az said: ${_VP_ERR:-<no error output>}"
      return 1
    fi
    [[ "$enabled" == false || "$enabled" == true ]] && break
    if [[ "$attempt" -ge "$VAULT_PROBE_ATTEMPTS" ]]; then
      VAULT_PROBE_ERR="vault '$vault' reported the $class probe write (version $ver) but the version does not read back — the write cannot be shown to have landed"
      return 1
    fi
    sleep "$VAULT_PROBE_BACKOFF"; attempt=$((attempt + 1))
  done

  # 3. the clean-up — nothing to delete (see the header: a deleted probe name would
  #    block the next probe). The version must be disabled; it was written that way,
  #    and if the vault somehow kept it enabled it is disabled now.
  if [[ "$enabled" == true ]]; then
    if _vault_probe_az "$errf" keyvault "$class" set-attributes --id "$id" --enabled false -o none; then
      VAULT_PROBE_NOTE="${VAULT_PROBE_NOTE:+$VAULT_PROBE_NOTE; }the probe version $ver read back ENABLED and was disabled after the fact"
    else
      VAULT_PROBE_NOTE="${VAULT_PROBE_NOTE:+$VAULT_PROBE_NOTE; }the probe version $ver read back ENABLED and could not be disabled (az said: ${_VP_ERR:-<no error output>}) — it is a throwaway value, but disable it: az keyvault $class set-attributes --id $id --enabled false"
    fi
  fi
  VAULT_PROBE_VERSION="$ver"

  # 4. the target — a name held deleted-but-recoverable refuses the store for the
  #    whole retention period.
  if [[ -n "$target" ]]; then
    if _vault_probe_az "$errf" keyvault "$class" show-deleted --vault-name "$vault" --name "$target" -o none; then
      VAULT_PROBE_ERR="vault '$vault' takes writes, but the target $class '$target' is held deleted-but-recoverable, so the store onto that name would be refused until it is recovered or purged. Recover it (az keyvault $class recover --vault-name $vault --name $target) or purge it, then re-run"
      return 1
    fi
    if [[ "$(vault_probe_classify "$_VP_ERR")" != absent ]]; then
      VAULT_PROBE_NOTE="${VAULT_PROBE_NOTE:+$VAULT_PROBE_NOTE; }could not read whether '$target' is held deleted in '$vault' (az said: ${_VP_ERR:-<no error output>}) — the write probe passed, so the store is expected to be taken"
    fi
  fi
  return 0
}
