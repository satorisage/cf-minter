# shellcheck shell=bash disable=SC2034  # AZ_PROBE_RC is read by the sourcing stub
# az-vault-probe.sh — what a Key Vault does to the store-write probe's calls, for the
# suites' az stubs to answer them the same way (lib/vault-store-probe.sh).
#
#   az_vault_probe ARG…   returns 0 when ARG… is one of the probe's calls and it has
#                         been answered (stdout/stderr written, AZ_PROBE_RC set to the
#                         exit code the stub should use); returns 1 when the call is
#                         not the probe's, so the stub answers it as it always has.
#
# State lives in "$STUB_DIR" (the suite's own scratch), all optional:
#   probe.deny             every probe WRITE is refused (a role that cannot write)
#   probe.readdeny         the probe's read-back is refused (writes still taken)
#   probe.throttle         holds N: the next N probe writes answer 429, then succeed
#   probe.deleted          the probe's own name is held deleted until a recover
#   probe.target-deleted   any non-probe name asked of show-deleted is held deleted
#   probe.keep-enabled     the vault ignores --disabled (the version reads back enabled)
# and the stub records into it:
#   probe.versions         one line per probe version: "<class> <name> <ver> <enabled>"
#   probe.files            each --file a certificate import was handed (to prove the
#                          probe's local key material is removed after the run)
#   probe.disabled         one line per set-attributes --enabled false the probe made
#
# Defines one function; sourcing has no side effect.

az_vault_probe(){
  local probe_secret="${VAULT_PROBE_SECRET_NAME:-mint-store-probe}"
  local probe_cert="${VAULT_PROBE_CERT_NAME:-mint-store-probe-cert}"
  local class="${2:-}" verb="${3:-}" name="" vault="" file="" id="" disabled=false a prev=""
  [[ "${1:-}" == keyvault && ( "$class" == secret || "$class" == certificate ) ]] || return 1
  for a in "$@"; do
    case "$prev" in
      --name|-n)    name="$a" ;;
      --vault-name) vault="$a" ;;
      --file|-f)    file="$a" ;;
      --id)         id="$a" ;;
      --disabled)   disabled="$a" ;;
    esac
    prev="$a"
  done
  local pname="$probe_secret"; [[ "$class" == certificate ]] && pname="$probe_cert"
  local coll="secrets"; [[ "$class" == certificate ]] && coll="certificates"
  AZ_PROBE_RC=0

  case "$verb" in
    set|import)
      [[ "$name" == "$pname" ]] || return 1
      [[ -n "$file" ]] && printf '%s\n' "$file" >>"$STUB_DIR/probe.files"
      if [[ -f "$STUB_DIR/probe.deny" ]]; then
        echo "ERROR: (Forbidden) Caller is not authorized to perform action on resource. Action: 'Microsoft.KeyVault/vaults/$coll/setSecret/action'" >&2
        AZ_PROBE_RC=1; return 0
      fi
      if [[ -f "$STUB_DIR/probe.deleted" ]]; then
        echo "ERROR: (Conflict) $class $name is currently in a deleted but recoverable state, and its name cannot be reused; in this state, the $class can only be recovered or purged. Code: ObjectIsDeletedButRecoverable" >&2
        AZ_PROBE_RC=1; return 0
      fi
      if [[ -s "$STUB_DIR/probe.throttle" ]]; then
        local n; n="$(cat "$STUB_DIR/probe.throttle")"
        if [[ "$n" -gt 0 ]]; then
          echo $((n - 1)) >"$STUB_DIR/probe.throttle"
          echo "ERROR: (TooManyRequests) Too many requests. Code: Throttled" >&2
          AZ_PROBE_RC=1; return 0
        fi
      fi
      if [[ "$class" == certificate && ! -s "$file" ]]; then
        echo "ERROR: the probe certificate file '$file' is missing or empty" >&2
        AZ_PROBE_RC=1; return 0
      fi
      local ver; ver="ver$(( $(wc -l <"$STUB_DIR/probe.versions" 2>/dev/null || echo 0) + 1 ))0000aaaa"
      local en=true; [[ "$disabled" == true ]] && en=false
      [[ -f "$STUB_DIR/probe.keep-enabled" ]] && en=true
      printf '%s %s %s %s\n' "$class" "$name" "$ver" "$en" >>"$STUB_DIR/probe.versions"
      printf 'https://%s.vault.azure.net/%s/%s/%s\n' "$vault" "$coll" "$name" "$ver"
      return 0 ;;
    list-versions)
      [[ "$name" == "$pname" ]] || return 1
      if [[ -f "$STUB_DIR/probe.readdeny" ]]; then
        echo "ERROR: (Forbidden) Caller is not authorized to perform action on resource. Action: 'Microsoft.KeyVault/vaults/$coll/readMetadata/action'" >&2
        AZ_PROBE_RC=1; return 0
      fi
      local c n v e first=1
      printf '['
      while read -r c n v e; do
        [[ "$c" == "$class" && "$n" == "$name" ]] || continue
        [[ "$first" -eq 1 ]] || printf ','
        first=0
        printf '{"id":"https://%s.vault.azure.net/%s/%s/%s","attributes":{"enabled":%s}}' "$vault" "$coll" "$n" "$v" "$e"
      done < <(cat "$STUB_DIR/probe.versions" 2>/dev/null)
      printf ']\n'
      return 0 ;;
    recover)
      [[ "$name" == "$pname" ]] || return 1
      rm -f "$STUB_DIR/probe.deleted"
      return 0 ;;
    set-attributes)
      [[ "$id" == */"$coll"/"$pname"/* ]] || return 1
      printf '%s\n' "$id" >>"$STUB_DIR/probe.disabled"
      return 0 ;;
    show-deleted)
      if [[ "$name" != "$pname" && -f "$STUB_DIR/probe.target-deleted" ]]; then
        printf '{"name":"%s","recoveryId":"https://%s.vault.azure.net/deleted%s/%s"}\n' "$name" "$vault" "$coll" "$name"
        return 0
      fi
      if [[ "$class" == secret ]]; then echo "ERROR: (SecretNotFound) Deleted Secret not found" >&2
      else echo "ERROR: (CertificateNotFound) Deleted Certificate not found" >&2; fi
      AZ_PROBE_RC=3; return 0 ;;
  esac
  return 1
}
