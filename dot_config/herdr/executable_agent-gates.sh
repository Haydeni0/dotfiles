#!/bin/sh

pane_id=${HERDR_ACTIVE_PANE_ID:-}
[ -n "$pane_id" ] || exit 0

herdr_bin=${HERDR_BIN_PATH:-herdr}
pane_info=$("$herdr_bin" pane get "$pane_id" 2>/dev/null) || exit 0
agent=$(printf '%s' "$pane_info" | jq -r '.result.pane.agent // empty')
[ -n "$agent" ] || exit 0

process_info=$("$herdr_bin" pane process-info --pane "$pane_id" 2>/dev/null) || exit 0
pid=$(printf '%s' "$process_info" | jq -r '.result.process_info.foreground_processes[0].pid // empty')
[ -n "$pid" ] || exit 0

# The agent's environment as NAME=VALUE lines.
case "$(uname -s)" in
    Linux)
        [ -r "/proc/$pid/environ" ] || exit 0
        environment=$(tr '\0' '\n' < "/proc/$pid/environ")
        ;;
    Darwin)
        # ps -E appends the environment after the command line; strip the
        # command line first so an argument cannot pose as a variable.
        with_env=$(ps -wwE -p "$pid" -o command= 2>/dev/null) || exit 0
        command_line=$(ps -ww -p "$pid" -o command= 2>/dev/null) || exit 0
        environment=$(printf '%s\n' "${with_env#"$command_line"}" | tr ' ' '\n')
        ;;
    *) exit 0 ;;
esac

# Same rule as the agent-config commit/push gate hook: open when the
# authorise var is non-empty and the revoke var is not.
gate() { # $1 = COMMIT or PUSH
    if printf '%s\n' "$environment" | grep -q "^$1_AUTHORISED=." &&
        ! printf '%s\n' "$environment" | grep -q "^$1_UNAUTHORISED=."; then
        printf '✓'
    else
        printf '✗'
    fi
}

printf 'Gates: C%s P%s\n' "$(gate COMMIT)" "$(gate PUSH)"
