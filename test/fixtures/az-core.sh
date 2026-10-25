# az-core.sh — what the real az CLI's core does to its arguments before any command
# parses them, for the suites' az stubs to do the same.
#
# az reads an argument that is `@<file>` — or, in a `name=value` argument, a value
# that is `@<file>` — as that file's contents, trailing newlines dropped, and `@-` as
# its stdin (azure-cli-core _expand_file_prefixed_files). cf-mint-token.sh hands az
# every secret value that way (lib/az-secret-file.sh), so a stub that records
# what az was asked to store must expand the same way, or it records a path where the
# value belongs. A stub that also logs "$@" untouched keeps the command line as any
# other process would have seen it, which is where a value must never appear.
#
#   az_core_args ARG…   sets the array AZ_CORE_ARGS to ARG… as az's core expands them
#
# Defines one function; sourcing has no side effect.

az_core_args(){
  AZ_CORE_ARGS=()
  local a v p
  for a in "$@"; do
    v="$a" p=""
    if [[ "$a" != @* && "$a" == *=@* ]]; then p="${a%%=*}="; v="${a#*=}"; fi
    if [[ "$v" == "@-" ]]; then
      AZ_CORE_ARGS+=("$p$(cat)")
    elif [[ "$v" == @* && -f "${v#@}" ]]; then
      AZ_CORE_ARGS+=("$p$(cat "${v#@}")")
    else
      AZ_CORE_ARGS+=("$a")
    fi
  done
}
