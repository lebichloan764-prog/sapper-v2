#!/usr/bin/env bash
# setup_wsl.sh — host-side bring-up of the sapper legion inside WSL (no Docker).
# Run from Windows:  wsl -e bash /mnt/d/CODING/OPEN/_work/sapper/setup_wsl.sh
set -uo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin:$PATH
export DEBIAN_FRONTEND=noninteractive

echo "== 1. base packages"
sudo apt-get update -qq
sudo apt-get install -y -qq nodejs npm tmux curl jq ca-certificates git >/dev/null
node -v; npm -v

echo "== 2. claude code"
if ! command -v claude >/dev/null 2>&1; then
  sudo npm i -g @anthropic-ai/claude-code >/tmp/npm.log 2>&1 || { echo "NPM FAIL"; tail -20 /tmp/npm.log; exit 1; }
fi
claude --version

echo "== 3. workspace"
mkdir -p "$HOME/sapper"
if [ ! -d "$HOME/sapper/repo/.git" ]; then
  cp -r /mnt/d/CODING/OPEN/_work/sapper/sapper-v2 "$HOME/sapper/repo"
fi
cd "$HOME/sapper/repo" && git log --oneline -1

echo "== 4. install sapper CLI"
bash install.sh --cli-only
export PATH="$HOME/.local/bin:$PATH"
sapper --version

echo "== 5. claude non-interactive preset"
mkdir -p "$HOME/.claude"
printf '%s\n' '{"hasCompletedOnboarding": true, "theme": "dark", "hasTrustDialogAccepted": true}' > "$HOME/.claude.json"
printf '%s\n' '{"permissions":{"defaultMode":"bypassPermissions"},"autoCompactEnabled":true}' > "$HOME/.claude/settings.json"

echo "DONE setup"
