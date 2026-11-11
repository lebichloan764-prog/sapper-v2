#!/usr/bin/env bash
# env.sh — canonical environment for the sapper outpost. Source it, never copy it.
#   . ~/sapper/repo/host/env.sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:"$HOME/.local/bin"

# ---- arena (local stub; nobody talks to Tencent) -----------------------------
export BENCHMARK_BASE_URL="${BENCHMARK_BASE_URL:-http://127.0.0.1:8899}"
export BENCHMARK_TOKEN="${BENCHMARK_TOKEN:-local}"
export SAPPER_ARENA_LIB="$HOME/sapper/repo/lib/arena.py"

# ---- model gateway (Anthropic wire, yeta platform) ---------------------------
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://platform.yeta.ai}"
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-iN06IAqVUdBRu19XyZg9dufHqR2FmN7gPaVajR6VKqcPQxjD}"
# SMART tier: commander + generals. LINE tier: soldiers, scouts, chores.
export SAPPER_MODEL="${SAPPER_MODEL:-glm-5.3-flash[1m]}"
export SAPPER_MODEL_FLASH="${SAPPER_MODEL_FLASH:-deepseek-v4.1-flash-uncensored[1m]}"
# worker.sh reads SAPPER_MODEL_DS as the DEFAULT spawn model -> LINE tier
export SAPPER_MODEL_DS="${SAPPER_MODEL_DS:-$SAPPER_MODEL_FLASH}"
export SAPPER_KEY_POOL="${SAPPER_KEY_POOL:-}"

# ---- campaign ---------------------------------------------------------------
export SAPPER_ROOT="${SAPPER_ROOT:-$HOME/sapper/runs}"
export SAPPER_SKILL_PATH="${SAPPER_SKILL_PATH:-$HOME/sapper/repo/host/DOCTRINE.md}"
export SAPPER_MISSION_LIB="${SAPPER_MISSION_LIB:-$HOME/sapper/repo/host/missions.sh}"
export SAPPER_MAX_WORKERS="${SAPPER_MAX_WORKERS:-4}"
export SAPPER_TOTAL_MINUTES="${SAPPER_TOTAL_MINUTES:-480}"
export SAPPER_STALL_SECONDS="${SAPPER_STALL_SECONDS:-600}"
export SAPPER_MAX_STEPS="${SAPPER_MAX_STEPS:-8}"
export SAPPER_VERIFY="${SAPPER_VERIFY:-1}"

# ---- chain access (workers export their own if they need others) ------------
export BASE_RPC="${BASE_RPC:-https://base-rpc.publicnode.com}"
export ETH_RPC="${ETH_RPC:-https://ethereum-rpc.publicnode.com}"

# ---- claude non-interactive / no telemetry ----------------------------------
export IS_SANDBOX=1
export DISABLE_TELEMETRY=1
export DISABLE_ERROR_REPORTING=1
export DISABLE_AUTOUPDATER=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export SAPPER_RETRY_MODEL="${SAPPER_RETRY_MODEL:-3}"

# ---- worker.sh gateway names (ds = LINE tier on the same yeta gateway) ------
export DEEPSEEK_BASE_URL="${DEEPSEEK_BASE_URL:-https://platform.yeta.ai}"
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-$ANTHROPIC_AUTH_TOKEN}"
