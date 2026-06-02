#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$HOME/phase1b-final-cleanup-${STAMP}.log"

log() {
    echo "[INFO] $*" | tee -a "$LOG"
}

warn() {
    echo "[WARN] $*" | tee -a "$LOG"
}

remove_if_installed() {
    local pkgs=()
    for pkg in "$@"; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            pkgs+=("$pkg")
        else
            log "Not installed, skipping: $pkg"
        fi
    done

    if [[ "${#pkgs[@]}" -gt 0 ]]; then
        log "Removing installed packages: ${pkgs[*]}"
        sudo pacman -Rns --noconfirm "${pkgs[@]}" || warn "Some packages could not be removed because another installed package still depends on them."
    else
        log "No matching installed packages in this removal group."
    fi
}

log "Starting PHASE 1B final cleanup."
log "This does not touch yay, code, NetworkManager, bootloader, user backups, fonts, icons, or wallpapers."

log "Default target before cleanup: $(systemctl get-default)"

log "Removing old GNOME Shell extension packages first because they were blocking gnome-shell removal."
mapfile -t EXT_PKGS < <(pacman -Qq | grep -E '^gnome-shell-extension' || true)

if [[ "${#EXT_PKGS[@]}" -gt 0 ]]; then
    log "Detected GNOME extension packages: ${EXT_PKGS[*]}"
    sudo pacman -Rns --noconfirm "${EXT_PKGS[@]}" || warn "Some GNOME extension packages could not be removed."
else
    log "No gnome-shell-extension packages detected by package name."
fi

log "Removing known old rice/extension blocker packages if installed."
remove_if_installed gnome-shell-extension-appindicator gnome-shell-extension-arc-menu gnome-shell-extension-dash-to-panel gnome-shell-extension-desktop-icons-ng gnome-shell-extensions

log "Removing old GNOME desktop core leftovers from Phase 1."
remove_if_installed gnome-shell mutter gnome-session gnome-settings-daemon gnome-menus xdg-desktop-portal-gnome xdg-user-dirs-gtk nautilus nautilus-python gvfs xorg-xwayland xorg-server-common xorg-setxkbmap xorg-xkbcomp

log "Removing extra old DE/rice tools if they still exist."
remove_if_installed dconf-editor gnome-tweaks nemo rofi wofi dunst picom eww eww-debug waybar hyprland sway sddm lightdm gdm

log "Cleaning unowned GNOME Shell extension directories after package removals."
if [[ -d /usr/share/gnome-shell/extensions ]]; then
    shopt -s nullglob
    for extdir in /usr/share/gnome-shell/extensions/*; do
        if pacman -Qo "$extdir" >/dev/null 2>&1; then
            warn "Still package-owned, leaving: $extdir"
        else
            log "Removing unowned extension directory: $extdir"
            sudo rm -rf "$extdir"
        fi
    done
    shopt -u nullglob
else
    log "/usr/share/gnome-shell/extensions does not exist."
fi

log "Removing safe orphan packages."
if pacman -Qtdq >/tmp/phase1b-orphans.txt 2>/dev/null; then
    mapfile -t ORPHANS < /tmp/phase1b-orphans.txt
    if [[ "${#ORPHANS[@]}" -gt 0 ]]; then
        FILTERED_ORPHANS=()
        for pkg in "${ORPHANS[@]}"; do
            case "$pkg" in
                yay|code|visual-studio-code-bin|visual-studio-code-insiders-bin|vscodium|networkmanager|git|base-devel|sudo|nano|grub|efibootmgr|os-prober|pyenv)
                    warn "Protected orphan, leaving: $pkg"
                    ;;
                ttf-*|otf-*|noto-fonts*|adobe-source-*|nerd-fonts*|font*)
                    warn "Font-related orphan, leaving: $pkg"
                    ;;
                *)
                    FILTERED_ORPHANS+=("$pkg")
                    ;;
            esac
        done

        if [[ "${#FILTERED_ORPHANS[@]}" -gt 0 ]]; then
            log "Removing filtered orphan packages: ${FILTERED_ORPHANS[*]}"
            sudo pacman -Rns --noconfirm "${FILTERED_ORPHANS[@]}" || warn "Some orphan packages could not be removed."
        else
            log "No removable orphans after filtering protected packages."
        fi
    fi
else
    log "No orphan packages detected."
fi

log "Verification: yay"
command -v yay | tee -a "$LOG" || warn "yay not found."

log "Verification: code"
command -v code | tee -a "$LOG" || warn "code not found."

log "Verification: default systemd target"
systemctl get-default | tee -a "$LOG"

log "Verification: display manager unit files"
systemctl list-unit-files 'gdm*.service' 'sddm.service' 'lightdm.service' 'lxdm.service' 'ly.service' 'greetd.service' | tee -a "$LOG" || true

log "Verification: remaining GNOME/X/rice packages"
pacman -Qq | grep -Ei '^(gnome-shell|mutter|gnome-session|gnome-settings-daemon|gdm|sddm|lightdm|dash-to-panel|gnome-shell-extension|arcmenu|nautilus|nemo|rofi|wofi|waybar|hyprland|sway|picom|dunst|eww|xorg-xwayland)$' | tee -a "$LOG" || true

log "PHASE 1B complete."
log "Log saved at: $LOG"
