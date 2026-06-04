#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Setting up Visual Studio Code from ArchRicePack assets."

install_aur_package visual-studio-code-bin

VSCODE_ASSET_DIR="$REPO_ROOT/vscode"
VSCODE_USER_SRC="$VSCODE_ASSET_DIR/User"
VSCODE_EXT_SRC="$VSCODE_ASSET_DIR/extensions"

VSCODE_USER_DEST="$HOME/.config/Code/User"
VSCODE_EXT_DEST="$HOME/.vscode/extensions"

if [[ -d "$VSCODE_USER_SRC" ]]; then
    log "Replacing VS Code User config."
    backup_path "$VSCODE_USER_DEST"
    mkdir -p "$VSCODE_USER_DEST"
    cp -r "$VSCODE_USER_SRC"/. "$VSCODE_USER_DEST"/
else
    warn "VS Code User config asset missing: $VSCODE_USER_SRC"
fi

if [[ -d "$VSCODE_EXT_SRC" ]]; then
    log "Replacing VS Code extensions folder."
    backup_path "$VSCODE_EXT_DEST"
    mkdir -p "$VSCODE_EXT_DEST"
    cp -r "$VSCODE_EXT_SRC"/. "$VSCODE_EXT_DEST"/
else
    warn "VS Code extensions asset missing: $VSCODE_EXT_SRC"
fi

if command -v code >/dev/null 2>&1; then
    code --version | head -n 1 | tee -a "$LOG_FILE" || true
else
    warn "code command not found after visual-studio-code-bin install."
fi

log "VS Code setup complete."