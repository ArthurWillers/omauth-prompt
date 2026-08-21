#!/bin/bash

# Shared bridge for omauth-prompt adapters. It intentionally communicates with
# the shell using only metadata and a private response-file path.

set -o pipefail

readonly OMAUTH_PLUGIN_ID="io.github.arthurwillers.omauth-prompt"
OMA_AUTH_SHELL_BINARY=""
OMA_AUTH_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}"
OMA_AUTH_REQUEST_DIR=""
OMA_AUTH_RESULT_PATH=""

omauth_init() {
  if [[ -n "${OMARCHY_PATH:-}" && -x "$OMARCHY_PATH/bin/omarchy-shell" ]]; then
    OMA_AUTH_SHELL_BINARY="$OMARCHY_PATH/bin/omarchy-shell"
  else
    OMA_AUTH_SHELL_BINARY="$(command -v omarchy-shell 2>/dev/null || true)"
  fi

  [[ -n "$OMA_AUTH_RUNTIME_DIR" && -d "$OMA_AUTH_RUNTIME_DIR" && -w "$OMA_AUTH_RUNTIME_DIR" ]] || return 1
  [[ -n "$OMA_AUTH_SHELL_BINARY" && -x "$OMA_AUTH_SHELL_BINARY" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  OMA_AUTH_REQUEST_DIR="$(mktemp -d "$OMA_AUTH_RUNTIME_DIR/omauth-prompt.XXXXXX")" || return 1
  OMA_AUTH_RESULT_PATH="$OMA_AUTH_REQUEST_DIR/result.json"
  : >"$OMA_AUTH_RESULT_PATH" || return 1
  chmod 600 "$OMA_AUTH_RESULT_PATH"
}

omauth_cleanup() {
  [[ -z "$OMA_AUTH_RESULT_PATH" ]] || rm -f -- "$OMA_AUTH_RESULT_PATH"
  [[ -z "$OMA_AUTH_REQUEST_DIR" ]] || rmdir -- "$OMA_AUTH_REQUEST_DIR" 2>/dev/null || true
}

omauth_shell_call() {
  local method="$1"
  shift

  case "$method" in
    open)
      OMARCHY_SHELL_IPC_TIMEOUT=2s \
        "$OMA_AUTH_SHELL_BINARY" omauth prompt "$@"
      ;;
    close)
      OMARCHY_SHELL_IPC_TIMEOUT=2s \
        "$OMA_AUTH_SHELL_BINARY" omauth cancel
      ;;
    *)
      return 1
      ;;
  esac
}

omauth_begin() {
  local title="$1"
  local description="$2"
  local prompt="$3"
  local error="$4"
  local timeout_ms="${5:-120000}"
  local payload response

  rm -f -- "$OMA_AUTH_RESULT_PATH"
  : >"$OMA_AUTH_RESULT_PATH"
  chmod 600 "$OMA_AUTH_RESULT_PATH"

  payload=$(jq -cn \
    --arg responsePath "$OMA_AUTH_RESULT_PATH" \
    --arg title "$title" \
    --arg description "$description" \
    --arg prompt "$prompt" \
    --arg error "$error" \
    --argjson timeoutMs "$timeout_ms" \
    '{responsePath:$responsePath,title:$title,description:$description,prompt:$prompt,error:$error,timeoutMs:$timeoutMs}') || return 1

  response=$(omauth_shell_call open "$payload" 2>/dev/null || true)
  [[ "$response" == "ok" ]]
}

omauth_wait() {
  local timeout_seconds="${1:-120}"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    [[ -s "$OMA_AUTH_RESULT_PATH" ]] && return 0
    sleep 0.05
  done
  return 1
}

omauth_cancel() {
  [[ -n "$OMA_AUTH_RESULT_PATH" ]] || return 0
  omauth_shell_call close "$OMA_AUTH_RESULT_PATH" >/dev/null 2>&1 || true
}
