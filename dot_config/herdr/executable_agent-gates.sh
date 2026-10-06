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

commit='C✗'
push='P✗'
case "$(uname -s)" in
    Linux)
        [ -r "/proc/$pid/environ" ] || exit 0
        jq -Rse 'split("\u0000") | index("COMMIT_AUTHORISED=1") != null' "/proc/$pid/environ" >/dev/null && commit='C✓'
        jq -Rse 'split("\u0000") | index("PUSH_AUTHORISED=1") != null' "/proc/$pid/environ" >/dev/null && push='P✓'
        ;;
    Darwin)
        process_environment=$(ps -wwE -p "$pid" -o command= 2>/dev/null) || exit 0
        case " $process_environment " in *' COMMIT_AUTHORISED=1 '*) commit='C✓' ;; esac
        case " $process_environment " in *' PUSH_AUTHORISED=1 '*) push='P✓' ;; esac
        ;;
    *) exit 0 ;;
esac

printf 'Gates: %s %s\n' "$commit" "$push"
