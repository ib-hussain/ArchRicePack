#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

log "Installing power profile system."

sudo mkdir -p /opt/ib-power-profiles

sudo cp -r "$REPO_ROOT/battery-profiles/"* /opt/ib-power-profiles/

sudo chmod +x /opt/ib-power-profiles/*.sh

echo balanced | sudo tee /etc/ib-power-profile >/dev/null

log "Power profile system installed."   