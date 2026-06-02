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
    "09-setup-vscode.sh"
    "10-setup-local-ai-ollama-openwebui.sh"
    "11-apply-custom-showapps-icon.sh"
    "08-finalize-and-verify.sh"
)

for step in "${STEPS[@]}"; do
    if [[ "${SKIP_LOCAL_AI:-0}" == "1" && "$step" == "10-setup-local-ai-ollama-openwebui.sh" ]]; then
        warn "Skipping $step because SKIP_LOCAL_AI=1."
        continue
    fi

    log "Running $step"
    bash "$ROOT_DIR/scripts/$step"
done

log "============================================================"
log "ArchRicePack installation complete"
log "Recommended: log out and back in. For icon/theme cache, reboot once."
log "============================================================"