#!/usr/bin/env bash
# boot.sh — bring the outpost up: arena stub -> commander -> watchdog.
#   bash ~/sapper/repo/host/boot.sh [--reset] [--minutes N]
# --reset stops a running outpost first. Without --reset it is a no-op when up.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
REPO="$(dirname "$HERE")"
WATCHDOG="$REPO/docker/commander/watchdog.sh"
WORKER="$REPO/docker/commander/worker.sh"

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

(( RESET )) && bash "$HERE/stop.sh" >/dev/null 2>&1

# ---- 0. one outpost only ----------------------------------------------------
if pgrep -f 'commander/watchdog\.sh$' >/dev/null 2>&1 && tmux has-session -t sapper-cmd 2>/dev/null; then
  log "outpost already running (watchdog + session) — use --reset to rebuild"
  exit 0
fi
pkill -f 'commander/watchdog\.sh$' 2>/dev/null && sleep 1

# ---- 1. arena stub ----------------------------------------------------------
if ! curl -sf --max-time 3 "$BENCHMARK_BASE_URL/health" >/dev/null 2>&1; then
  log "starting arena stub"
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

# ---- 3. session, commander TUI, bootstrap -----------------------------------
tmux has-session -t sapper-cmd 2>/dev/null || tmux new-session -d -s sapper-cmd -n commander \
  || die "cannot create tmux session"

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

tmux list-windows -t sapper-cmd -F '#W' 2>/dev/null | grep -qx commander \
  || tmux new-window -d -t sapper-cmd -n commander

if ! tmux capture-pane -pt sapper-cmd:commander 2>/dev/null | grep -q '❯'; then
  log "launching commander TUI (model $SAPPER_MODEL)"
  tmux respawn-pane -k -t sapper-cmd:commander \
    "cd '$CMD_HOME' && claude --model '$SAPPER_MODEL' --effort max --dangerously-skip-permissions 2>&1; echo DRIVE_PANE_EXITED; exec sleep infinity"
  waited=0
  while (( waited < 90 )); do
    tmux capture-pane -pt sapper-cmd:commander 2>/dev/null | grep -q '❯' && break
    if tmux capture-pane -pt sapper-cmd:commander 2>/dev/null | grep -qE 'Enter to confirm|Yes, I accept'; then
      tmux send-keys -t sapper-cmd:commander Down; sleep 0.4
      tmux send-keys -t sapper-cmd:commander Enter
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
  settle=0
  while (( settle < 20 )); do
    tmux capture-pane -pt sapper-cmd:commander 2>/dev/null \
      | awk '/❯/{line=$0} END{exit (line ~ /DOCTRINE/ ? 0 : 1)}' || break
    sleep 1; settle=$((settle + 1))
  done
fi

# ---- 4. watchdog ------------------------------------------------------------
chmod +x "$WATCHDOG" "$WORKER"
log "starting watchdog (total ${SAPPER_TOTAL_MINUTES}m)"
nohup "$WATCHDOG" >>"$LOG" 2>&1 &
sleep 2
pgrep -f 'commander/watchdog\.sh$' >/dev/null 2>&1 || die "watchdog did not stay up (see $LOG)"

sleep 4
tmux list-windows -t sapper-cmd -F '#W' 2>/dev/null | sed 's/^/  window: /' | tee -a "$LOG"
log "outpost up — attach: tmux attach -t sapper-cmd   board: bash board.sh"
