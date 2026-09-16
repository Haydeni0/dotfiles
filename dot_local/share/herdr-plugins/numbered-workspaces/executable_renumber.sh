#!/bin/bash
# Publishes each space's ordinal as a `num` metadata token, which
# ui.sidebar.spaces renders via the "$num" row token. herdr reports the ordinal
# over the API but has no built-in row token for it, so this is the bridge.
#
# Only spaces whose token disagrees with their current number are written, so
# the steady state (nothing moved) costs a single `workspace list` call.
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"

# Server may not be running (e.g. event fired during shutdown); no-op then.
"$herdr" workspace list >/dev/null 2>&1 || exit 0

"$herdr" workspace list |
  jq -r '
    .result.workspaces[]
    | select((.tokens.num // "") != (.number | tostring))
    | "\(.workspace_id)\t\(.number)"
  ' |
  while IFS=$'\t' read -r id number; do
    "$herdr" workspace report-metadata "$id" \
      --source numbered-workspaces --token "num=$number"
  done
