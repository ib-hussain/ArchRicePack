#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Installing power profile system."

mkdir -p "$HOME/.local/bin"

copy_file \
"$REPO_ROOT/configs/local-bin/ib-power-mode" \
"$HOME/.local/bin/ib-power-mode"

copy_file \
"$REPO_ROOT/configs/local-bin/ib-power-menu" \
"$HOME/.local/bin/ib-power-menu"

chmod +x "$HOME/.local/bin/ib-power-mode"
chmod +x "$HOME/.local/bin/ib-power-menu"

sudo touch /etc/ib-power-profile

if [[ ! -s /etc/ib-power-profile ]]; then
    echo balanced | sudo tee /etc/ib-power-profile >/dev/null
fi

log "Power profile system installed."