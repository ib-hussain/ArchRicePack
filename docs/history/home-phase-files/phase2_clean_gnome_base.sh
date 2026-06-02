#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase2-clean-gnome-base-${STAMP}.log"

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

trap 'fail "Phase 2 failed at line ${LINENO}. Check log: ${LOG}"' ERR

if [[ "$(id -un)" != "ibrahim" ]]; then
    fail "Run this as ibrahim, not root."
fi

log "Starting PHASE 2 - clean GNOME base reinstall."
log "This phase installs clean GNOME, GDM, Wayland/XWayland support, audio, portals, power profiles, and theme build dependencies."
log "This phase does not install the final rice configuration yet."

log "Checking preserved tools."
command -v yay >/dev/null 2>&1 && log "yay exists: $(command -v yay)" || warn "yay not found."
command -v code >/dev/null 2>&1 && log "VS Code exists: $(command -v code)" || warn "code not found."

log "Synchronising repositories and upgrading base packages."
sudo pacman -Syu --noconfirm

log "Installing clean GNOME base packages."
sudo pacman -S --needed --noconfirm gdm gnome-shell gnome-session gnome-control-center gnome-settings-daemon gnome-terminal nautilus gvfs gvfs-mtp gvfs-smb xdg-user-dirs xdg-user-dirs-gtk xdg-desktop-portal xdg-desktop-portal-gnome xorg-xwayland mesa

log "Installing audio and session services."
sudo pacman -S --needed --noconfirm pipewire pipewire-audio pipewire-pulse wireplumber alsa-utils pavucontrol

log "Installing clean desktop utilities needed later."
sudo pacman -S --needed --noconfirm gnome-tweaks gnome-shell-extensions dconf-editor fastfetch power-profiles-daemon

log "Installing MacTahoe build/support dependencies for later phases."
sudo pacman -S --needed --noconfirm git sassc glib2 libxml2 imagemagick dialog curl wget unzip

log "Updating XDG user directories."
xdg-user-dirs-update || warn "xdg-user-dirs-update failed, continuing."

log "Enabling required system services."
sudo systemctl enable NetworkManager.service
sudo systemctl enable power-profiles-daemon.service
sudo systemctl enable gdm.service

log "Keeping boot target graphical now that GDM is cleanly installed."
sudo systemctl set-default graphical.target

log "Restoring GNOME Terminal dconf backup if available."
BACKUP_ROOT="$HOME/rice-reset-backups/latest-phase1"
if [[ -s "$BACKUP_ROOT/dconf-gnome-terminal-before-purge.ini" ]]; then
    mkdir -p "$HOME/.config/dconf"
    dconf load /org/gnome/terminal/ < "$BACKUP_ROOT/dconf-gnome-terminal-before-purge.ini" || warn "GNOME Terminal dconf restore failed; we can restore it later after first GNOME login."
else
    warn "No GNOME Terminal dconf backup found or backup is empty."
fi

log "Resetting GNOME shell extension enablement to avoid carrying old rice state."
mkdir -p "$HOME/.config/dconf"
dconf reset -f /org/gnome/shell/extensions/ || true
dconf reset -f /org/gnome/shell/enabled-extensions || true
dconf reset -f /org/gnome/shell/disabled-extensions || true

log "Verification: installed core GNOME packages."
pacman -Q gdm gnome-shell gnome-session gnome-control-center gnome-settings-daemon gnome-terminal nautilus xorg-xwayland xdg-desktop-portal-gnome pipewire wireplumber power-profiles-daemon fastfetch | tee -a "$LOG"

log "Verification: service states."
systemctl is-enabled NetworkManager.service | sed 's/^/[NetworkManager] /' | tee -a "$LOG"
systemctl is-enabled power-profiles-daemon.service | sed 's/^/[power-profiles-daemon] /' | tee -a "$LOG"
systemctl is-enabled gdm.service | sed 's/^/[gdm] /' | tee -a "$LOG"
systemctl get-default | sed 's/^/[default-target] /' | tee -a "$LOG"

log "PHASE 2 complete."
log "Log saved at: $LOG"
log "Now reboot with: sudo reboot"
