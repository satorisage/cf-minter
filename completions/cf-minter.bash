# bash completion for cf-minter.
#
#   source /path/to/cf-minter/completions/cf-minter.bash
#
# The profile names come from `cf-minter profiles --names`, not from reading
# profiles.conf: that file is the one home of the profile set, and a second
# reader of its format would make adding a profile two edits instead of one.
# Nothing here touches the network — no completion should cost an API call, and
# token ids are therefore deliberately not completed.

_cf_minter_profiles(){
  cf-minter profiles --names 2>/dev/null | cut -f1
}

_cf_minter(){
  local cur prev verb i
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Everything after '--' is the wrapped command, which owns its own completion.
  for (( i=1; i<COMP_CWORD; i++ )); do
    [[ "${COMP_WORDS[i]}" == "--" ]] && return 1
  done

  verb="${COMP_WORDS[1]:-}"
  if (( COMP_CWORD == 1 )); then
    COMPREPLY=( $(compgen -W "run mint profiles list burn doctor help version" -- "$cur") )
    return 0
  fi

  case "$prev" in
    --profile) COMPREPLY=( $(compgen -W "$(_cf_minter_profiles)" -- "$cur") ); return 0 ;;
    --ttl)     COMPREPLY=( $(compgen -W "30s 5m 15m 30m 1h 2h 8h 1d" -- "$cur") ); return 0 ;;
    --zone|--zone-id|--slug|--minter-cmd|--minter-token-file) return 0 ;;
  esac

  case "$verb" in
    run)  COMPREPLY=( $(compgen -W "--profile --zone --zone-id --ttl --slug --minter-cmd --minter-token-file --dry-run --help --" -- "$cur") ) ;;
    mint) COMPREPLY=( $(compgen -W "--profile --zone --zone-id --ttl --slug --minter-cmd --minter-token-file --dry-run --help" -- "$cur") ) ;;
    profiles) COMPREPLY=( $(compgen -W "--names --help" -- "$cur") ) ;;
    list|burn) COMPREPLY=( $(compgen -W "--stale --help" -- "$cur") ) ;;
    doctor)    COMPREPLY=( $(compgen -W "--help" -- "$cur") ) ;;
  esac
}
complete -F _cf_minter cf-minter
