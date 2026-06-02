#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase7-power-modes-${STAMP}.log"
BACKUP_DIR="$HOME/rice-reset-backups/phase7-${STAMP}"

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

trap 'fail "Phase 7 failed at line ${LINENO}. Check log: ${LOG}"' ERR

if [[ "$(id -un)" != "ibrahim" ]]; then
    fail "Run this as ibrahim, not root."
fi

log "Starting PHASE 7 - Power Modes / Quick Settings integration."
log "This phase does not change Files transparency, theme opacity, wallpaper rotation, fonts, icon theme, dock styling, or top bar layout."

mkdir -p "$BACKUP_DIR"

log "Backing up current power/profile state."
{
    echo "date=$(date)"
    echo "user=$USER"
    echo "session=${XDG_SESSION_TYPE:-unknown}"
    echo "gtk-theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || true)"
    echo "shell-theme=$(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || true)"
    echo "button-layout=$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || true)"
    echo "super-tab=$(gsettings get org.gnome.shell.keybindings toggle-overview 2>/dev/null || true)"
} > "$BACKUP_DIR/settings-before-phase7.txt"

log "Installing/confirming required power packages."
sudo pacman -S --needed --noconfirm power-profiles-daemon upower

log "Checking for known power-management conflicts."
if pacman -Qq tlp >/dev/null 2>&1; then
    warn "TLP is installed. TLP can conflict conceptually with power-profiles-daemon. I am not removing it automatically."
else
    log "TLP package not installed."
fi

if pacman -Qq auto-cpufreq >/dev/null 2>&1; then
    warn "auto-cpufreq is installed. It may interfere with GNOME power profiles. I am not removing it automatically."
else
    log "auto-cpufreq package not installed."
fi

log "Enabling and starting power-profiles-daemon."
sudo systemctl enable --now power-profiles-daemon.service

log "Restarting UPower to refresh battery/power state."
sudo systemctl restart upower.service || warn "Could not restart upower.service; continuing."

log "Checking available profiles."
if ! command -v powerprofilesctl >/dev/null 2>&1; then
    fail "powerprofilesctl was not found even after installing power-profiles-daemon."
fi

powerprofilesctl list | tee "$BACKUP_DIR/powerprofilesctl-list.txt" | tee -a "$LOG"

log "Setting default profile to balanced if available."
if powerprofilesctl list | grep -q "balanced"; then
    powerprofilesctl set balanced || warn "Could not set balanced profile."
else
    warn "Balanced profile not listed. Leaving current profile unchanged."
fi

log "Current power profile after set attempt."
powerprofilesctl get | tee "$BACKUP_DIR/current-profile.txt" | tee -a "$LOG"

log "Checking GNOME user services and extensions are still intact."
systemctl --user is-active pipewire pipewire-pulse wireplumber | tee -a "$LOG" || warn "One or more user audio services inactive."

log "Verification."
echo "Power daemon status:" | tee -a "$LOG"
systemctl is-enabled power-profiles-daemon.service | sed 's/^/[enabled] /' | tee -a "$LOG"
systemctl is-active power-profiles-daemon.service | sed 's/^/[active] /' | tee -a "$LOG"

echo "UPower status:" | tee -a "$LOG"
systemctl is-active upower.service | sed 's/^/[upower] /' | tee -a "$LOG" || true

echo "Power profile:" | tee -a "$LOG"
powerprofilesctl get | sed 's/^/[profile] /' | tee -a "$LOG"

echo "GNOME theme state preserved:" | tee -a "$LOG"
echo "GTK: $(gsettings get org.gnome.desktop.interface gtk-theme)" | tee -a "$LOG"
echo "Shell: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo unavailable)" | tee -a "$LOG"
echo "Icons: $(gsettings get org.gnome.desktop.interface icon-theme)" | tee -a "$LOG"
echo "Buttons: $(gsettings get org.gnome.desktop.wm.preferences button-layout)" | tee -a "$LOG"
echo "Super+Tab: $(gsettings get org.gnome.shell.keybindings toggle-overview)" | tee -a "$LOG"

echo "Enabled extensions:" | tee -a "$LOG"
gnome-extensions list --enabled | grep -Ei 'user-theme|dash.*dock' | tee -a "$LOG" || true

log "PHASE 7 complete."
log "Now open the top-right Quick Settings / action centre and check whether Power Mode appears."
log "If it does not appear, reboot once and check again. Some GNOME Shell quick-setting tiles only refresh cleanly after shell/session restart."
log "Log saved at: $LOG"
