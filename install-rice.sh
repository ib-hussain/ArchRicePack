#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

source "$ROOT_DIR/scripts/00-common.sh"

require_user_session

log "============================================================"
log "ArchRicePack installer started"
log "Repository: $ROOT_DIR"
log "Log file: $LOG_FILE"
log "============================================================"

STEPS=(
    "01-install-packages.sh"
    "02-restore-themes-and-configs.sh"
    "03-setup-terminal.sh"
    "04-setup-extensions.sh"
    "05-apply-gnome-settings.sh"
    "06-setup-nautilus-code.sh"
    "07-setup-assets-grub-gdm-wallpaper.sh"
    "08-finalize-and-verify.sh"
)

for step in "${STEPS[@]}"; do
    log "Running $step"
    bash "$ROOT_DIR/scripts/$step"
done

log "============================================================"
log "ArchRicePack installation complete"
log "Recommended: log out and back in. For icon/theme cache, reboot once."
log "============================================================"
