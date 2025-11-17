#!/usr/bin/env    bash

#?/name           module - a simple bash module system
#?/synopsis       source module

#?/environment    MODULE_DEBUG if set, debug information will be printed to the console
#?/environment    MODULE_ARGS contains the arguments passed to the module

set -eo pipefail

#@/main
 # Initializes the module system
 #
 # @arg $@ arguments to be forwarded to the module
 #
module() {
  MODULE_ARGS=("$@")

  trap 'module::_route' EXIT
}

#@/private
# Applies rouing logic to <caller> (the sourcing script).
#
# @arg $@ arguments to be forwarded to the module
#
# @stdout debug information if MODULE_DEBUG is set
# @stderr error message if the routing failed
#
# @exit 0 if the routing succeeded
# @exit 1 if the routing failed
#
module::_route() {
  local module_name

  module::_debug "Routing with arguments: ${MODULE_ARGS[*]}"
  module::_debug "$(module::_get_stack_trace)"

  # <caller> is being sourced, skip routing
  if [[ "$(module::_check_context)" == "sourced" ]]; then
    return
  fi

  # <caller> is being executed, apply routing
  module_name=$(module::_get_module_name)
  module::_debug "Module name: $module_name"

  # Route: <caller>::$1()
  if [[ ${#MODULE_ARGS[@]} -gt 0 ]]; then
    local target_func="$module_name::${MODULE_ARGS[0]}"
    module::_debug "Looking for function: $target_func"
    if declare -F "$target_func" > /dev/null; then
      module::_debug "Found function: $target_func"
      "${target_func}" "${MODULE_ARGS[@]:1}"
      return
    fi
  fi

  # Route: <caller>()
  module::_debug "Looking for function: $module_name"

  if declare -F "$module_name" > /dev/null; then
    module::_debug "Found function: $module_name"
    "$module_name" "${MODULE_ARGS[@]}"
    return
  fi

  # Routing failed, exit with error
  module::_error "Function '$module_name' not found."
  exit 1
}

#@/private checks the execution context of the <caller> script
module::_check_context() {
    # The last entry in BASH_SOURCE is the original script
    local original_script="${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}"

    # $0 is the script that's actually being run
    local running_script="$0"

    module::_debug "Original script: $original_script"
    module::_debug "Running script: $running_script"

    # If the original script is being run directly, it's executed
    # Otherwise it's being sourced by something else
    if [[ "$(basename "$original_script")" == "$(basename "$running_script")" ]]; then
        echo "executed"
    else
        echo "sourced"
    fi
}

#@/private prints debug information to stdout if MODULE_DEBUG is set
module::_debug() {
  # Only output if MODULE_DEBUG is non-zero
  if [[ "${MODULE_DEBUG:-0}" -ne 0 ]]; then
    echo -e "$1"
  fi
}

#@/private prints error messages to stderr
module::_error() {
  echo -e "Error: $1" >&2
}

#@/private prints a stack trace
# @arg [-d | --depth <number>] number of frames to skip from the top (default: 1)
module::_get_stack_trace() {
  local call_stack=""
  local depth_mask=1
  local -a frames=()
  local gray=$'\e[90m'
  local reset=$'\e[0m'

  # Parse optional depth argument
  if [[ "${1:-}" == "-d" || "${1:-}" == "--depth" ]]; then
    if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
      depth_mask="$2"
      shift 2
    else
      module::_error "Depth argument must be a number"
      return 1
    fi
  fi

  # If no function call stack, return empty
  if [[ -z "${FUNCNAME[*]:-}" ]]; then
    return 0
  fi

  for ((i = depth_mask; i < ${#FUNCNAME[@]}; i++)); do
    local func_name="${FUNCNAME[$i]}"
    local source_file="${BASH_SOURCE[$i]:-}"
    local line_num="${BASH_LINENO[$((i-1))]:-}"

    if [[ -z "$func_name" ]]; then
      func_name="<main>"
    fi

    if [[ "$func_name" =~ ^module:: ]]; then
      source_file="${BASH_SOURCE[0]}"
    elif [[ -z "$source_file" ]]; then
      source_file="<unknown>"
    fi

    if [[ -n "$line_num" ]]; then
      frames+=("  [$((i-depth_mask))] $func_name ${gray}($source_file:$line_num)${reset}")
    else
      frames+=("  [$((i-depth_mask))] $func_name ${gray}($source_file)${reset}")
    fi
  done

  # Print frames in reverse order
  for ((i = ${#frames[@]} - 1; i >= 0; i--)); do
    if [[ -n "$call_stack" ]]; then
      call_stack+="\n"
    fi
    call_stack+="${frames[$i]}"
  done

  echo "$call_stack"
}

#@/private extracts the module name from the <caller> script
module::_get_module_name() {
  filename=$(basename "$0")
  echo "${filename%.*}"
}

module "$@"
