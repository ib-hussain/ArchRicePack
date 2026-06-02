#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase5-buttons-overview-dock-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase5-${STAMP}"

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

trap 'fail "Phase 5 failed at line ${LINENO}. Check log: ${LOG}"' ERR

if [[ "$(id -un)" != "ibrahim" ]]; then
    fail "Run this as ibrahim, not root."
fi

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
    fail "DBus/session environment missing. Log out and log back into GNOME, then rerun."
fi

log "Starting PHASE 5 - window buttons, overview keybinding, and dock verification."
log "This phase does not change Files/Nautilus transparency."
log "This phase does not change GTK opacity, Shell opacity, wallpaper rotation, fonts, or icon theme."

mkdir -p "$BACKUP_DIR"

log "Backing up current GNOME settings."
{
    echo "button-layout=$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || true)"
    echo "toggle-overview=$(gsettings get org.gnome.shell.keybindings toggle-overview 2>/dev/null || true)"
    echo "switch-applications=$(gsettings get org.gnome.desktop.wm.keybindings switch-applications 2>/dev/null || true)"
    echo "switch-applications-backward=$(gsettings get org.gnome.desktop.wm.keybindings switch-applications-backward 2>/dev/null || true)"
    echo "gtk-theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || true)"
    echo "shell-theme=$(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || true)"
    echo "icon-theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || true)"
    echo "font-name=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || true)"
} > "$BACKUP_DIR/settings-before-phase5.txt"

gnome-extensions list > "$BACKUP_DIR/extensions-before-phase5.txt" 2>/dev/null || true
dconf dump /org/gnome/shell/extensions/dash-to-dock/ > "$BACKUP_DIR/dash-to-dock-before-phase5.ini" 2>/dev/null || true

log "Setting Windows-style window button order on the right: Minimise, Maximise/Restore, Close."
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

log "Mapping Super+Tab to GNOME Overview, matching the top-left Arch icon behaviour."
gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>Tab']"

log "Keeping Alt+Tab for normal app switching, so Super+Tab is free for overview."
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Alt>Tab']"

log "Detecting Dash to Dock UUID."
DASH_UUID=""

if gnome-extensions list | grep -qx 'dash-to-dock@micxgx.gmail.com'; then
    DASH_UUID='dash-to-dock@micxgx.gmail.com'
elif gnome-extensions list | grep -i 'dash.*dock' >/tmp/phase5-dash-candidates.txt 2>/dev/null; then
    DASH_UUID="$(head -n 1 /tmp/phase5-dash-candidates.txt)"
fi

if [[ -z "$DASH_UUID" && -d "/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com" ]]; then
    DASH_UUID='dash-to-dock@micxgx.gmail.com'
fi

if [[ -z "$DASH_UUID" ]]; then
    warn "Dash to Dock is still not visible to GNOME Shell."
    warn "Open Extension Manager and confirm Dash to Dock is installed/enabled, then log out/in and rerun Phase 5."
else
    log "Dash to Dock UUID selected: $DASH_UUID"
    gnome-extensions enable "$DASH_UUID" || warn "Could not enable $DASH_UUID immediately. It may already be active or need another logout/login."

    log "Applying dock layout settings without changing transparency."
    dconf write /org/gnome/shell/extensions/dash-to-dock/dock-position "'BOTTOM'" || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/extend-height false || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed true || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/intellihide false || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 48 || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/show-trash true || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/click-action "'minimize-or-previews'" || true
    dconf write /org/gnome/shell/extensions/dash-to-dock/scroll-action "'cycle-windows'" || true
fi

log "Verification."
echo "Session: ${XDG_SESSION_TYPE:-unknown}" | tee -a "$LOG"
echo "GNOME: $(gnome-shell --version)" | tee -a "$LOG"
echo "GTK theme: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell theme: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icon theme preserved: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Font preserved: $(gsettings get org.gnome.desktop.interface font-name)" | tee -a "$LOG"
echo "Button layout: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Super+Tab overview binding: $(gsettings get org.gnome.shell.keybindings toggle-overview)" | tee -a "$LOG"
echo "Alt+Tab app switch binding: $(gsettings get org.gnome.desktop.wm.keybindings switch-applications)" | tee -a "$LOG"
echo "Enabled extensions matching user-theme/dock:" | tee -a "$LOG"
gnome-extensions list --enabled | grep -Ei 'user-theme|dash.*dock' | tee -a "$LOG" || true
echo "Dash to Dock settings:" | tee -a "$LOG"
dconf dump /org/gnome/shell/extensions/dash-to-dock/ | tee -a "$LOG" || true

log "PHASE 5 complete."
log "Close and reopen apps to see the new button order everywhere."
log "Test: press Super+Tab. It should open the same overview shown by the Arch icon."
log "Log saved at: $LOG"
