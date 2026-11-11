#!/usr/bin/env bash
# board.sh — the war board, plus arena state and the campaign ledger.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
REPO="$(dirname "$HERE")"

case "${1:-board}" in
  board) exec "$REPO/docker/commander/worker.sh" board "${@:2}" ;;
  json) exec "$REPO/docker/commander/worker.sh" board --json ;;
  ledger)
    echo "== arena (local stub)"
    curl -s "$BENCHMARK_BASE_URL/openapi/v1/challenges" -H "BENCHMARK_TOKEN: $BENCHMARK_TOKEN" \
      | python3 -c 'import json,sys
rows=json.load(sys.stdin)
for r in rows:
    print("%-12s done=%-5s proof=%s/%s  %s" % (r["unique_code"], r["is_completed"],
          r["correct_flag_count"], r["flag_count"], r["title"][:52]))'
    echo "== commander state"
    sed -n '1,40p' "$SAPPER_ROOT/commander-state.md" 2>/dev/null || echo "(no state yet)"
    echo "== last watchdog lines"
    tail -5 "$SAPPER_ROOT/drive.log" 2>/dev/null
    ;;
  *) echo "usage: board.sh [board|json|ledger]" >&2; exit 1 ;;
esac
