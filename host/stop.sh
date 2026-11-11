#!/usr/bin/env bash
# stop.sh — stop the legion but KEEP the graphs, the arena state and the logs.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"

pkill -f 'commander/watchdog\.sh$' 2>/dev/null && echo "watchdog stopped"
pkill -f 'commander/worker\.sh$' 2>/dev/null
tmux has-session -t sapper-cmd 2>/dev/null && tmux kill-session -t sapper-cmd && echo "tmux session killed"
pkill -f 'arena_stub\.py$' 2>/dev/null && echo "arena stub stopped"
echo "graphs kept under $SAPPER_ROOT"
