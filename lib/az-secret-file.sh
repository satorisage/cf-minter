#!/usr/bin/env bash
#
# az-secret-file.sh — a secret VALUE reaches az as a file az reads itself, never on argv.
#
# WHY
# ---
# A process's command line is readable by every other process on the machine
# (`ps -ef`, /proc/<pid>/cmdline). A call written as
#     az containerapp secret set … --secrets "api-token=$TOKEN"
# puts every value there for as long as az runs — the break-glass signing key, the
# control token, a registry URL with its password inside.
#
# az has no stdin or file parameter for Container App secrets (the reference lists
# only `--secrets` in 'key=value' or keyvaultref form), and most of its other
# credential flags — a certificate's `--password`, a server's `--admin-password`,
# a storage `--account-key` — are plain strings too. But the CLI's core expands ANY
# argument that begins with `@` — or, in a `name=value` argument, the part after the
# first `=` — to the contents of that file before the command is even parsed, and
# `@-` reads stdin ("Azure CLI's `@<file>` convention", learn.microsoft.com/en-us/
# cli/azure/use-azure-cli-successfully-powershell). So the argv carries
# `name=@/private/path` or `--password @/private/path` and the value is read inside
# az. (azure-cli-core: azure/cli/core/commands/__init__.py,
# _expand_file_prefixed_files, applied to every argument as the first step of
# AzCliCommandInvoker.execute; measured on azure-cli 2.90.0.)
#
#   az_secrets_from_files az <args…> [--secrets name=value…] [--password VALUE] [<more args…>]
#       runs that az command with each secret value written to its own file (mode
#       600, in a fresh mode-700 directory) and passed by reference: each --secrets
#       item as `name=@file`, and the value after each flag in AZ_SECRET_VALUE_FLAGS
#       as `@file` (written `--flag VALUE` or `--flag=VALUE`). The --secrets list runs
#       to the next argument that starts with `-`; the argument after a single-value
#       flag is its value whatever it looks like; every other argument passes through
#       untouched and in order. The files are removed when az returns, pass or fail,
#       and az's own exit code is returned. The first word may be anything that runs
#       the az command it is handed (az_retry 3 5 az …) or that forwards its own
#       arguments to az (a function whose body runs `az "$@"`).
#
# A value is stored exactly as handed in: az reads a file once and never expands an
# `@` inside it again, so a value that itself begins with `@` arrives as written.
#
# A Key Vault secret goes as `--value @<file>`, not through keyvault's own `--file`
# parameter: `--value @<file>` reaches the very code path `--value VALUE` did, so the
# stored value and the version's tags are what they always were (the set validator
# stamps file-encoding=utf-8 on both paths; `--file` would read the file raw instead).
# (azure-cli 2.90.0 command_modules/keyvault/_validators.py
# process_secret_set_namespace; reference: learn.microsoft.com/en-us/cli/azure/
# keyvault/secret#az-keyvault-secret-set.)
#
# TWO VENDOR BEHAVIOURS THIS GUARDS (both measured on 2.90.0):
#   * a file that does not exist is NOT an error to az: the argument passes through
#     as the literal text `@/path`, which `secret set` would store as the secret. So
#     every value is proven to have landed in its file before az runs.
#   * az strips trailing newlines from a value it reads from a file. A value ending
#     in a newline would be stored without it, silently different from the value that
#     was composed — so such a value is refused, never trimmed here.
# An empty value is refused too: a secret with no value is never what was meant.
#
# A refusal returns 2, runs nothing, and names the secret or the flag (or the item's
# position when it has no name) on stderr — never a value. Tracing is switched off
# inside, so a caller's `set -x` cannot print the values as they are written.
#
# The federated token az login takes rides the same core expansion through stdin:
#     printf '%s' "$oidc" | az login … --federated-token @-
#
# Defines one function and the flag list below; sourcing has no other side effect.

[[ -n "${AZ_SECRET_FILE_LIB:-}" ]] && return 0
AZ_SECRET_FILE_LIB=1

# The single-value az flags whose value is a secret: a certificate's password, a
# server's admin password, a storage account's key or connection string or SAS
# token, an app's client secret, a registry password, and `--value` (the value of a
# Key Vault secret). az_secrets_from_files moves the value after each one into a
# private file. ONE home: a gate that keeps credentials off argv reads this list from
# this line, so a flag the wrapper does not move can never pass that gate as wrapped.
# A short form (`-p`) is not read here or there — `-p` is `--password` on one command
# and a switch on another — so callers spell these flags long.
AZ_SECRET_VALUE_FLAGS=(--password --admin-password --account-key --client-secret --registry-password --sas-token --connection-string --value)

# az_secrets_from_files AZ_COMMAND… — see the header. The body is a subshell, so its
# EXIT trap (the cleanup) can never replace a trap the caller set, and none of its
# variables reach the caller — which is also why none of them is declared `local`:
# bash 3.2 (the macOS seat's /bin/bash) unwinds a function's locals BEFORE a subshell's
# EXIT trap runs, so a trap reading a local finds it unset (measured: the directory was
# left behind). The trap carries the directory's path literally for the same reason.
az_secrets_from_files(){ # args: an az command line carrying --secrets name=value… and/or a single-value secret flag
  (
    set +x
    n=0 pos=0 in_list=0 rc=0 want="" f=""
    cmd=()
    dir="$(umask 077 && mktemp -d "${TMPDIR:-/tmp}/az-secrets.XXXXXX" 2>/dev/null)" || dir=""
    if [[ -z "$dir" || ! -d "$dir" ]]; then
      printf 'az-secret-file: refused — no private directory could be made for the secret values under %s; nothing was run\n' "${TMPDIR:-/tmp}" >&2
      exit 2
    fi
    # shellcheck disable=SC2064  # expanded NOW on purpose: the path, not a variable read at exit
    trap "rm -rf $(printf '%q' "$dir")" EXIT
    chmod 700 "$dir"
    # _azsf_put LABEL VALUE — VALUE into the next private file, its path in f. A refusal
    # exits this subshell with 2 and names LABEL, never the value.
    _azsf_put(){
      if [[ -z "$2" ]]; then
        printf 'az-secret-file: refused — %s has an empty value; nothing was run\n' "$1" >&2
        exit 2
      fi
      if [[ "$2" == *$'\n' ]]; then
        printf 'az-secret-file: refused — %s ends with a newline, which az drops from a value it reads from a file, so the stored secret would silently differ from this one; strip it where the value is read. Nothing was run\n' "$1" >&2
        exit 2
      fi
      n=$((n + 1))
      f="$dir/$n"
      if ! (umask 077 && printf '%s' "$2" > "$f") || [[ ! -s "$f" ]]; then
        printf 'az-secret-file: refused — the value of %s did not land in its file under %s; nothing was run\n' "$1" "$dir" >&2
        exit 2
      fi
    }
    for a in "$@"; do
      if [[ -n "$want" ]]; then
        _azsf_put "$want" "$a"
        cmd+=("@$f")
        want=""
        continue
      fi
      if [[ "$in_list" == 1 && "$a" != -* ]]; then
        pos=$((pos + 1))
        name="${a%%=*}"
        if [[ "$a" != *=* || -z "$name" ]]; then
          printf 'az-secret-file: refused — --secrets item %d is not name=value; nothing was run\n' "$pos" >&2
          exit 2
        fi
        _azsf_put "the secret $name" "${a#*=}"
        cmd+=("$name=@$f")
        continue
      fi
      in_list=0
      if [[ "$a" == "--secrets" ]]; then
        in_list=1
        pos=0
      fi
      for flag in "${AZ_SECRET_VALUE_FLAGS[@]}"; do
        if [[ "$a" == "$flag" ]]; then
          want="$flag"
        elif [[ "$a" == "$flag="* ]]; then
          _azsf_put "$flag" "${a#*=}"
          a="$flag=@$f"
        fi
      done
      cmd+=("$a")
    done
    if [[ -n "$want" ]]; then
      printf 'az-secret-file: refused — %s is the last argument and carries no value; nothing was run\n' "$want" >&2
      exit 2
    fi
    if [[ "$n" -eq 0 ]]; then
      printf 'az-secret-file: refused — no secret value was handed in (no --secrets item, and none of %s), and moving those values off the command line is all this wrapper is for; nothing was run\n' "${AZ_SECRET_VALUE_FLAGS[*]}" >&2
      exit 2
    fi
    "${cmd[@]}" || rc=$?
    exit "$rc"
  )
}
