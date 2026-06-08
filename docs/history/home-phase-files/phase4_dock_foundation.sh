#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase4-dock-foundation-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase4-${STAMP}"
DASH_UUID="dash-to-dock@micxgx.gmail.com"

log() {
    echo "[INFO] $*" | tee -a "$LOG"
}

warn() {
    echo "[WARN] $*" | tee -a "$LOG"
}

fail() {
    echo "[ERROR] $*" | tee -a "$LOG"
    exit 1
}

trap 'fail "Phase 4 failed at line ${LINENO}. Check log: ${LOG}"' ERR

if [[ "$(id -un)" != "ibrahim" ]]; then
    fail "Run this as ibrahim, not root."
fi

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
    fail "DBus/session environment missing. Log out and log back into GNOME, then rerun."
fi

log "Starting PHASE 4 - Dock foundation only."
log "This phase keeps the GNOME top bar, keeps MacTahoe transparency as-is, and does not edit Files/Nautilus transparency."
log "This phase does not install Blur My Shell and does not change theme transparency."

mkdir -p "$BACKUP_DIR"

log "Backing up current extension state and dock settings."
gnome-extensions list > "$BACKUP_DIR/extensions-before-phase4.txt" 2>/dev/null || true
dconf dump /org/gnome/shell/extensions/dash-to-dock/ > "$BACKUP_DIR/dash-to-dock-before-phase4.ini" 2>/dev/null || true
dconf dump /org/gnome/shell/ > "$BACKUP_DIR/gnome-shell-before-phase4.ini" 2>/dev/null || true

log "Installing Extension Manager and browser connector fallback tools."
sudo pacman -S --needed --noconfirm extension-manager gnome-browser-connector

log "Installing Dash to Dock from AUR using yay."
yay -S --needed --noconfirm gnome-shell-extension-dash-to-dock || warn "AUR install failed or package was unavailable. Extension Manager is installed as fallback."

log "Checking whether Dash to Dock exists after installation."
if gnome-extensions list | grep -qx "$DASH_UUID"; then
    log "Dash to Dock found: $DASH_UUID"
else
    warn "Dash to Dock UUID not found yet."
    warn "Open Extension Manager, search 'Dash to Dock', install it, log out/in, then rerun this script."
    extension-manager >/dev/null 2>&1 &
    exit 0
fi

log "Enabling Dash to Dock."
gnome-extensions enable "$DASH_UUID" || warn "Could not enable Dash to Dock immediately. Logout/login may be needed."

log "Applying dock layout only. No transparency values are changed."
dconf write /org/gnome/shell/extensions/dash-to-dock/dock-position "'BOTTOM'"
dconf write /org/gnome/shell/extensions/dash-to-dock/extend-height false
dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed true
dconf write /org/gnome/shell/extensions/dash-to-dock/intellihide false
dconf write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 48
dconf write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true
dconf write /org/gnome/shell/extensions/dash-to-dock/show-trash true
dconf write /org/gnome/shell/extensions/dash-to-dock/click-action "'minimize-or-previews'"
dconf write /org/gnome/shell/extensions/dash-to-dock/scroll-action "'cycle-windows'"

log "Keeping top bar visible and Arch Activities icon unchanged."
gsettings set org.gnome.desktop.wm.preferences button-layout ':close,minimize,maximize'

log "Verification."
echo "Session: ${XDG_SESSION_TYPE:-unknown}" | tee -a "$LOG"
echo "GNOME: $(gnome-shell --version)" | tee -a "$LOG"
echo "GTK: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icons: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Buttons: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Dash to Dock enabled list:" | tee -a "$LOG"
gnome-extensions list --enabled | grep -E "dash-to-dock|user-theme" | tee -a "$LOG" || true
echo "Dash to Dock dconf:" | tee -a "$LOG"
dconf dump /org/gnome/shell/extensions/dash-to-dock/ | tee -a "$LOG" || true

log "PHASE 4 complete."
log "Log saved at: $LOG"
log "Log out and log back in once if the dock does not appear immediately."
