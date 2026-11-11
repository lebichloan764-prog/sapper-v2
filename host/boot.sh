#!/usr/bin/env bash
# boot.sh — bring the outpost up: arena stub -> tmux session -> watchdog -> commander.
#   bash ~/sapper/repo/host/boot.sh [--reset] [--minutes N]
# --reset kills any running session/stub first.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
REPO="$(dirname "$HERE")"

RESET=0
while (( $# )); do
  case "$1" in
    --reset) RESET=1; shift ;;
    --minutes) SAPPER_TOTAL_MINUTES="$2"; shift 2 ;;
    *) echo "boot: unknown option $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$SAPPER_ROOT"
LOG="$SAPPER_ROOT/drive.log"
log() { printf '[boot %s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }
die() { log "FATAL: $*"; exit 1; }

if (( RESET )); then
  bash "$HERE/stop.sh" >/dev/null 2>&1 || true
fi

# ---- 1. arena stub ----------------------------------------------------------
if ! curl -sf --max-time 3 "$BENCHMARK_BASE_URL/health" >/dev/null 2>&1; then
  log "starting arena stub on 127.0.0.1:8899"
  ARENA_PORT=8899 nohup python3 "$HERE/arena_stub.py" >>"$SAPPER_ROOT/arena.log" 2>&1 &
  sleep 1.5
fi
curl -sf --max-time 3 "$BENCHMARK_BASE_URL/health" >/dev/null 2>&1 \
  || die "arena stub not reachable at $BENCHMARK_BASE_URL"
log "arena ok: $(curl -s "$BENCHMARK_BASE_URL/health")"

# ---- 2. model smoke ---------------------------------------------------------
SMOKE=$(printf 'reply with the single word: ok' | timeout 90 claude -p --model "$SAPPER_MODEL_FLASH" 2>/dev/null | tail -1)
[[ "$SMOKE" == *ok* ]] || die "model smoke failed (gateway $ANTHROPIC_BASE_URL, model $SAPPER_MODEL_FLASH)"
log "model ok ($SAPPER_MODEL_FLASH)"

# ---- 3. session + commander + watchdog --------------------------------------
tmux has-session -t sapper-cmd 2>/dev/null && log "session exists (adopting)" \
  || tmux new-session -d -s sapper-cmd -n commander || die "cannot create tmux session"

CMD_HOME="$SAPPER_ROOT/commander-home"
mkdir -p "$CMD_HOME/.claude"
printf '%s\n' '{"permissions":{"defaultMode":"bypassPermissions"},"autoCompactEnabled":true}' \
  > "$CMD_HOME/.claude/settings.json"
python3 - "$CMD_HOME" <<'PYTRUST'
import json, os, sys
path = os.path.expanduser("~/.claude.json")
try: d = json.load(open(path))
except Exception: d = {}
d.setdefault("projects", {})[sys.argv[1]] = {
    "hasTrustDialogAccepted": True, "bypassPermissionsModeAccepted": True}
json.dump(d, open(path, "w"))
PYTRUST

if ! tmux list-windows -t sapper-cmd -F '#W' 2>/dev/null | grep -qx commander; then
  tmux new-window -d -t sapper-cmd -n commander
fi
if ! tmux capture-pane -pt sapper-cmd:commander 2>/dev/null | grep -q '❯'; then
  log "launching commander TUI (model $SAPPER_MODEL)"
  tmux respawn-pane -k -t sapper-cmd:commander \
    "cd '$CMD_HOME' && claude --model '$SAPPER_MODEL' --effort max --dangerously-skip-permissions 2>&1; echo DRIVE_PANE_EXITED; exec sleep infinity"
  waited=0
  while (( waited < 90 )); do
    if tmux capture-pane -pt sapper-cmd:commander 2>/dev/null | grep -q '❯'; then break; fi
    if tmux capture-pane -pt sapper-cmd:commander 2>/dev/null | grep -qE 'Enter to confirm|Yes, I accept'; then
      tmux send-keys -t sapper-cmd:commander Down; sleep 0.4; tmux send-keys -t sapper-cmd:commander Enter
    fi
    sleep 1; waited=$((waited + 1))
  done
  tmux send-keys -t sapper-cmd:commander C-u 2>/dev/null; sleep 0.3
  VERB="start commanding"
  [[ -f "$SAPPER_ROOT/commander-state.md" ]] && VERB="resume command"
  tmux send-keys -t sapper-cmd:commander -l -- \
    "Read $SAPPER_SKILL_PATH and $VERB. First read $SAPPER_ROOT/commander-state.md if it exists."
  sleep 0.5
  tmux send-keys -t sapper-cmd:commander Enter
  log "commander bootstrap sent ($VERB)"
  # let the TUI consume the bootstrap before the watchdog starts watching the
  # box (otherwise it re-Enters an already-submitted prompt for nothing)
  settle=0
  while (( settle < 20 )); do
    tmux capture-pane -pt sapper-cmd:commander 2>/dev/null | grep -qE "❯.*DOCTRINE" || break
    sleep 1; settle=$((settle + 1))
  done
fi

chmod +x "$REPO/docker/commander/watchdog.sh" "$REPO/docker/commander/worker.sh"
if pgrep -f 'commander/watchdog.sh' >/dev/null 2>&1; then
  log "watchdog already running"
else
  log "starting watchdog (total ${SAPPER_TOTAL_MINUTES}m)"
  nohup "$REPO/docker/commander/watchdog.sh" >>"$LOG" 2>&1 &
  sleep 2
fi
pgrep -f 'commander/watchdog.sh' >/dev/null 2>&1 || die "watchdog did not stay up (see $LOG)"

sleep 6
tmux list-windows -t sapper-cmd -F '#W' 2>/dev/null | sed 's/^/  window: /' | tee -a "$LOG"
log "outpost up — attach with: tmux attach -t sapper-cmd   (board: board.sh)"
