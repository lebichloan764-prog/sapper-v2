#!/usr/bin/env python3
"""patch_host.py — make the shipped legion runnable outside the container.

Localises hardcoded container paths (/opt/sapper, /work/runs) and adds the
--scout spawn form. Idempotent: re-running does not duplicate anything.
"""
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
W = REPO / "docker" / "commander" / "worker.sh"
D = REPO / "docker" / "commander" / "watchdog.sh"


def sub(text, old, new, label):
    if new in text:
        print(f"  skip (done): {label}")
        return text
    if old not in text:
        print(f"  !! MISS: {label}")
        return text
    print(f"  patched: {label}")
    return text.replace(old, new, 1)


w = W.read_text()
w = sub(w,
        'SAPPER="${SAPPER_BIN:-sapper}"',
        'SAPPER="${SAPPER_BIN:-$HOME/.local/bin/sapper}"',
        "worker: sapper bin default")
w = sub(w,
        '      --name) [[ $# -gt 0 ]] || die 1 "spawn: --name needs a value"; name=$1; shift ;;',
        '      --scout) scout=1 ;;\n      --name) [[ $# -gt 0 ]] || die 1 "spawn: --name needs a value"; name=$1; shift ;;',
        "worker: --scout option")
w = sub(w,
        'local code="" mode=tui mission="" minutes=$DEF_MINUTES name="" model="" gw="" engine=claude general=0 a',
        'local code="" mode=tui mission="" minutes=$DEF_MINUTES name="" model="" gw="" engine=claude general=0 scout=0 a',
        "worker: scout var")
w = sub(w,
        '      if (( general )); then mission=$(general_mission "$code" "$addrs")',
        '      if (( scout )); then mission=$(scout_mission "$code" "$addrs")\n      elif (( general )); then mission=$(general_mission "$code" "$addrs")',
        "worker: scout mission dispatch")
w = sub(w,
        'case "${1:-}" in\n  spawn) shift; cmd_spawn "$@" ;;',
        'MISSION_LIB="${SAPPER_MISSION_LIB:-}"\nif [[ -n "$MISSION_LIB" && -f "$MISSION_LIB" ]]; then\n  # shellcheck disable=SC1090\n  . "$MISSION_LIB"\nfi\n\ncase "${1:-}" in\n  spawn) shift; cmd_spawn "$@" ;;',
        "worker: source mission lib")
w = sub(w,
        "  spawn <code> [--tui|--p] [--mission \"...\"] [--minutes N] [--name NAME] [--model <id>]",
        "  spawn <code> [--tui|--p|--scout] [--mission \"...\"] [--minutes N] [--name NAME] [--model <id>]",
        "worker: usage line")
w = sub(w,
        "grep -qE '❯.*autonomous pentest operator'",
        "grep -qE '❯.*autonomous (pentest|on-chain) operator'",
        "worker: mission-wedge regex")
W.write_text(w)

d = D.read_text()
d = sub(d,
        'SKILL_PATH=/opt/sapper/docker/commander/SKILL.md',
        'SKILL_PATH="${SAPPER_SKILL_PATH:-/opt/sapper/docker/commander/SKILL.md}"',
        "watchdog: skill path env")
d = sub(d,
        'spec = importlib.util.spec_from_file_location("arena", "/opt/sapper/lib/arena.py")',
        'import os\nspec = importlib.util.spec_from_file_location("arena", os.environ.get("SAPPER_ARENA_LIB", "/opt/sapper/lib/arena.py"))',
        "watchdog: arena lib path (arena helper)")
d = sub(d,
        'spec = importlib.util.spec_from_file_location("arena", "/opt/sapper/lib/arena.py")\nm = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)\ntry:\n    client = m.ArenaClient.load(None)',
        'import os\nspec = importlib.util.spec_from_file_location("arena", os.environ.get("SAPPER_ARENA_LIB", "/opt/sapper/lib/arena.py"))\nm = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)\ntry:\n    client = m.ArenaClient.load(None)',
        "watchdog: arena lib path (finish_flags)")
d = sub(d,
        'grep -qE "❯.*docker/commander/SKILL\\.md"',
        'grep -qE "❯.*(SKILL\\.md|DOCTRINE\\.md)"',
        "watchdog: bootstrap regex")
d = sub(d,
        "grep -qE '\u276f.*autonomous pentest operator'",
        "grep -qE '\u276f.*autonomous (pentest|on-chain) operator'",
        "watchdog: mission-wedge regex")
D.write_text(d)
print("done")
