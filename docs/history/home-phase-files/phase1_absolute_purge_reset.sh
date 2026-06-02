#!/usr/bin/env bash
set -Eeuo pipefail

PHASE_NAME="PHASE 1 - ABSOLUTE PURGE AND RESET"
USER_NAME="${SUDO_USER:-${USER}}"
USER_HOME="$(getent passwd "${USER_NAME}" | cut -d: -f6)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="${USER_HOME}/rice-reset-backups"
BACKUP_DIR="${BACKUP_ROOT}/phase1-${STAMP}"
REPORT="${BACKUP_DIR}/phase1-report.txt"

log() {
    echo "[INFO] $*" | tee -a "${REPORT}"
}

warn() {
    echo "[WARN] $*" | tee -a "${REPORT}"
}

fail() {
    echo "[ERROR] $*" | tee -a "${REPORT}"
    exit 1
}

on_error() {
    local line="$1"
    fail "Script failed at line ${line}. Check backup/report: ${REPORT}"
}

trap 'on_error ${LINENO}' ERR

require_tty_safety() {
    if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == "wayland" || "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
        fail "You are still inside a graphical session. Switch to TTY with Ctrl+Alt+F3, log in, then rerun this script."
    fi
}

as_user() {
    sudo -u "${USER_NAME}" "$@"
}

move_to_backup() {
    local src="$1"
    local rel="${src#${USER_HOME}/}"
    local dest="${BACKUP_DIR}/purged-home/${rel}"

    if [[ -e "${src}" || -L "${src}" ]]; then
        mkdir -p "$(dirname "${dest}")"
        log "Moving ${src} -> ${dest}"
        mv "${src}" "${dest}"
    else
        log "Skipping missing path: ${src}"
    fi
}

copy_to_backup() {
    local src="$1"
    local rel="${src#${USER_HOME}/}"
    local dest="${BACKUP_DIR}/preserved/${rel}"

    if [[ -e "${src}" || -L "${src}" ]]; then
        mkdir -p "$(dirname "${dest}")"
        log "Copying ${src} -> ${dest}"
        cp -a "${src}" "${dest}"
    else
        log "Preserve skip, missing: ${src}"
    fi
}

move_system_to_backup_if_unowned() {
    local src="$1"
    local dest="${BACKUP_DIR}/purged-system${src}"

    if [[ ! -e "${src}" && ! -L "${src}" ]]; then
        log "Skipping missing system path: ${src}"
        return 0
    fi

    if pacman -Qo "${src}" >/dev/null 2>&1; then
        warn "Leaving package-owned system path in place: ${src}"
        return 0
    fi

    mkdir -p "$(dirname "${dest}")"
    log "Moving unowned system path ${src} -> ${dest}"
    sudo mv "${src}" "${dest}"
}

restore_gdm_theme_backups() {
    log "Restoring any GNOME/GDM theme backups created by prior theme installers."

    local candidates=(
        "/usr/share/gnome-shell/gnome-shell-theme.gresource"
        "/usr/share/gnome-shell/theme/gnome-shell.css"
        "/usr/share/gnome-shell/theme/ubuntu.css"
        "/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource"
        "/usr/share/gnome-shell/theme/Pop/gnome-shell-theme.gresource"
        "/etc/alternatives/gdm3.css"
        "/etc/alternatives/gdm3-theme.gresource"
    )

    for f in "${candidates[@]}"; do
        if [[ -e "${f}.bak" || -L "${f}.bak" ]]; then
            log "Restoring ${f}.bak -> ${f}"
            sudo rm -rf "${f}"
            sudo mv "${f}.bak" "${f}"
        fi
    done

    if [[ -d "/usr/share/gnome-shell/theme/MacTahoe" ]]; then
        mkdir -p "${BACKUP_DIR}/purged-system/usr/share/gnome-shell/theme"
        log "Moving old MacTahoe GNOME shell theme out of system theme path."
        sudo mv "/usr/share/gnome-shell/theme/MacTahoe" "${BACKUP_DIR}/purged-system/usr/share/gnome-shell/theme/MacTahoe"
    fi
}

backup_state() {
    mkdir -p "${BACKUP_DIR}"
    touch "${REPORT}"
    ln -sfn "${BACKUP_DIR}" "${BACKUP_ROOT}/latest-phase1"

    log "Starting ${PHASE_NAME}"
    log "User: ${USER_NAME}"
    log "Home: ${USER_HOME}"
    log "Backup directory: ${BACKUP_DIR}"

    log "Saving package inventories."
    pacman -Qqe > "${BACKUP_DIR}/pkg-explicit-all.txt" || true
    pacman -Qqen > "${BACKUP_DIR}/pkg-native-explicit.txt" || true
    pacman -Qqem > "${BACKUP_DIR}/pkg-foreign-aur.txt" || true
    pacman -Qq | grep -Ei '(^ttf-|^otf-|font|noto|nerd)' > "${BACKUP_DIR}/pkg-fonts-detected.txt" || true

    log "Saving VS Code package/binary status."
    command -v code > "${BACKUP_DIR}/code-binary-path.txt" 2>/dev/null || true
    pacman -Qq | grep -Ei '^(code|visual-studio-code-bin|visual-studio-code-insiders-bin|vscodium|code-marketplace)$' > "${BACKUP_DIR}/vscode-packages-detected.txt" || true

    log "Saving yay status."
    command -v yay > "${BACKUP_DIR}/yay-binary-path.txt" 2>/dev/null || true
    pacman -Qq yay > "${BACKUP_DIR}/yay-package-status.txt" 2>/dev/null || true

    log "Backing up dconf state."
    if command -v dconf >/dev/null 2>&1; then
        as_user dconf dump / > "${BACKUP_DIR}/dconf-full-before-purge.ini" || true
        as_user dconf dump /org/gnome/terminal/ > "${BACKUP_DIR}/dconf-gnome-terminal-before-purge.ini" || true
        as_user dconf dump /org/gnome/Ptyxis/ > "${BACKUP_DIR}/dconf-ptyxis-before-purge.ini" || true
    else
        warn "dconf command not found; skipping dconf dumps."
    fi

    log "Saving GNOME interface values for reference only."
    if command -v gsettings >/dev/null 2>&1; then
        {
            echo "icon-theme=$(as_user gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || true)"
            echo "gtk-theme=$(as_user gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || true)"
            echo "cursor-theme=$(as_user gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || true)"
            echo "font-name=$(as_user gsettings get org.gnome.desktop.interface font-name 2>/dev/null || true)"
            echo "document-font-name=$(as_user gsettings get org.gnome.desktop.interface document-font-name 2>/dev/null || true)"
            echo "monospace-font-name=$(as_user gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null || true)"
            echo "color-scheme=$(as_user gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)"
        } > "${BACKUP_DIR}/gnome-interface-values-before-purge.txt"
    else
        warn "gsettings command not found; skipping GNOME interface values."
    fi

    log "Backing up terminal profiles/configs without deleting them."
    copy_to_backup "${USER_HOME}/.config/gnome-terminal"
    copy_to_backup "${USER_HOME}/.config/kitty"
    copy_to_backup "${USER_HOME}/.config/alacritty"
    copy_to_backup "${USER_HOME}/.config/wezterm"
    copy_to_backup "${USER_HOME}/.config/ghostty"
    copy_to_backup "${USER_HOME}/.config/tilix"
    copy_to_backup "${USER_HOME}/.config/terminator"
    copy_to_backup "${USER_HOME}/.config/konsole"
    copy_to_backup "${USER_HOME}/.local/share/konsole"
    copy_to_backup "${USER_HOME}/.config/ptyxis"
    copy_to_backup "${USER_HOME}/.config/blackbox"

    log "Backing up shell startup files."
    copy_to_backup "${USER_HOME}/.bashrc"
    copy_to_backup "${USER_HOME}/.bash_profile"
    copy_to_backup "${USER_HOME}/.profile"
    copy_to_backup "${USER_HOME}/.zshrc"
    copy_to_backup "${USER_HOME}/.zprofile"

    log "Backing up user fonts and icon-theme folders."
    copy_to_backup "${USER_HOME}/.fonts"
    copy_to_backup "${USER_HOME}/.local/share/fonts"
    copy_to_backup "${USER_HOME}/.icons"
    copy_to_backup "${USER_HOME}/.local/share/icons"

    log "Backing up likely wallpaper/dynamic-wallpaper assets."
    copy_to_backup "${USER_HOME}/Pictures"
    copy_to_backup "${USER_HOME}/Wallpapers"
    copy_to_backup "${USER_HOME}/.local/share/backgrounds"
    copy_to_backup "${USER_HOME}/.config/wallpapers"
    copy_to_backup "${USER_HOME}/.config/wallpaper"
    copy_to_backup "${USER_HOME}/.config/swww"
    copy_to_backup "${USER_HOME}/.config/hyprpaper"
    copy_to_backup "${USER_HOME}/.config/nitrogen"
}

enter_console_target() {
    log "Setting default boot target to multi-user.target so old display managers cannot relaunch."
    sudo systemctl set-default multi-user.target

    log "Disabling and stopping known display managers."
    local dms=(gdm.service gdm3.service sddm.service lightdm.service lxdm.service ly.service greetd.service)
    for dm in "${dms[@]}"; do
        if systemctl list-unit-files "${dm}" >/dev/null 2>&1; then
            sudo systemctl disable --now "${dm}" >/dev/null 2>&1 || warn "Could not disable/stop ${dm}; continuing."
        fi
    done
}

reset_vscode_to_default() {
    log "Closing VS Code processes if present."
    pkill -u "${USER_NAME}" -x code >/dev/null 2>&1 || true
    pkill -u "${USER_NAME}" -f 'Visual Studio Code' >/dev/null 2>&1 || true

    log "Resetting VS Code, Code - OSS, and VSCodium user state/extensions by moving data into backup."
    move_to_backup "${USER_HOME}/.config/Code"
    move_to_backup "${USER_HOME}/.config/Code - OSS"
    move_to_backup "${USER_HOME}/.config/VSCodium"
    move_to_backup "${USER_HOME}/.vscode"
    move_to_backup "${USER_HOME}/.vscode-oss"
    move_to_backup "${USER_HOME}/.cache/Code"
    move_to_backup "${USER_HOME}/.cache/Code - OSS"
    move_to_backup "${USER_HOME}/.cache/VSCodium"
    move_to_backup "${USER_HOME}/.local/share/Code"
    move_to_backup "${USER_HOME}/.local/share/code"
    move_to_backup "${USER_HOME}/.local/share/VSCodium"
    move_to_backup "${USER_HOME}/.var/app/com.visualstudio.code"
    move_to_backup "${USER_HOME}/.var/app/com.vscodium.codium"
}

purge_user_desktop_configs() {
    log "Purging user-level DE/rice configs by moving them into backup, not deleting."

    shopt -s nullglob

    local paths=(
        "${USER_HOME}/.config/dconf"
        "${USER_HOME}/.config/gtk-2.0"
        "${USER_HOME}/.config/gtk-3.0"
        "${USER_HOME}/.config/gtk-4.0"
        "${USER_HOME}/.config/gnome-shell"
        "${USER_HOME}/.config/gnome-session"
        "${USER_HOME}/.config/mutter"
        "${USER_HOME}/.config/nautilus"
        "${USER_HOME}/.config/nemo"
        "${USER_HOME}/.config/caja"
        "${USER_HOME}/.config/dolphinrc"
        "${USER_HOME}/.config/kdeglobals"
        "${USER_HOME}/.config/Kvantum"
        "${USER_HOME}/.config/qt5ct"
        "${USER_HOME}/.config/qt6ct"
        "${USER_HOME}/.config/rofi"
        "${USER_HOME}/.config/waybar"
        "${USER_HOME}/.config/hypr"
        "${USER_HOME}/.config/sway"
        "${USER_HOME}/.config/i3"
        "${USER_HOME}/.config/bspwm"
        "${USER_HOME}/.config/awesome"
        "${USER_HOME}/.config/openbox"
        "${USER_HOME}/.config/picom"
        "${USER_HOME}/.config/polybar"
        "${USER_HOME}/.config/eww"
        "${USER_HOME}/.config/conky"
        "${USER_HOME}/.config/dunst"
        "${USER_HOME}/.config/fastfetch"
        "${USER_HOME}/.local/share/gnome-shell"
        "${USER_HOME}/.local/share/themes"
        "${USER_HOME}/.themes"
        "${USER_HOME}/.cache/gnome-shell"
        "${USER_HOME}/.cache/gdm"
        "${USER_HOME}/.cache/thumbnails"
    )

    for p in "${paths[@]}"; do
        move_to_backup "${p}"
    done

    for p in "${USER_HOME}"/.config/plasma* "${USER_HOME}"/.config/kde* "${USER_HOME}"/.config/xfce4 "${USER_HOME}"/.config/cinnamon "${USER_HOME}"/.config/mate "${USER_HOME}"/.config/lxqt "${USER_HOME}"/.config/lxsession; do
        move_to_backup "${p}"
    done

    shopt -u nullglob
}

purge_system_desktop_leftovers() {
    log "Purging unowned system-level theme/extension leftovers while preserving package-owned files."

    shopt -s nullglob

    for p in /usr/share/themes/MacTahoe* /usr/share/themes/WhiteSur* /usr/share/themes/Orchis* /usr/share/themes/Graphite* /usr/share/themes/Colloid*; do
        move_system_to_backup_if_unowned "${p}"
    done

    for p in /usr/share/gnome-shell/extensions/*; do
        move_system_to_backup_if_unowned "${p}"
    done

    shopt -u nullglob
}

remove_desktop_packages() {
    log "Building package removal list for existing DE/window-system stack."

    local groups=(gnome gnome-extra plasma kde-applications xfce4 xfce4-goodies mate cinnamon lxqt deepin pantheon budgie xorg)
    local extra_pkgs=(
        gdm sddm lightdm lxdm ly greetd tuigreet
        gnome-shell gnome-session mutter gnome-control-center gnome-settings-daemon gnome-tweaks gnome-shell-extensions dconf-editor
        dash-to-dock dash-to-panel blur-my-shell
        xorg-server xorg-xinit xorg-xwayland xorg-xrandr xorg-xsetroot xorg-apps xorg-xhost xorg-xauth xorg-xinput
        wayland-utils wl-clipboard
        plasma-desktop plasma-workspace kwin systemsettings
        xfce4-session xfwm4 xfdesktop xfce4-panel
        cinnamon muffin nemo
        mate-session-manager marco caja
        lxqt-session openbox
        hyprland sway waybar rofi wofi bemenu dunst picom polybar eww conky nitrogen feh swww hyprpaper
    )

    local protected_exact=(
        yay
        code
        visual-studio-code-bin
        visual-studio-code-insiders-bin
        code-marketplace
        vscodium
        networkmanager
        git
        base-devel
        sudo
        nano
        grub
        efibootmgr
        os-prober
        pyenv
        alacritty
        kitty
        wezterm
        ghostty
        gnome-terminal
        kgx
        ptyxis
        tilix
        terminator
        konsole
        xterm
        foot
    )

    local raw_list="${BACKUP_DIR}/desktop-removal-candidates-raw.txt"
    local final_list="${BACKUP_DIR}/desktop-removal-candidates-final.txt"
    : > "${raw_list}"
    : > "${final_list}"

    for group in "${groups[@]}"; do
        pacman -Qgq "${group}" >> "${raw_list}" 2>/dev/null || true
    done

    for pkg in "${extra_pkgs[@]}"; do
        echo "${pkg}" >> "${raw_list}"
    done

    sort -u "${raw_list}" | while read -r pkg; do
        [[ -z "${pkg}" ]] && continue

        if ! pacman -Qq "${pkg}" >/dev/null 2>&1; then
            continue
        fi

        local protect="no"
        for keep in "${protected_exact[@]}"; do
            if [[ "${pkg}" == "${keep}" ]]; then
                protect="yes"
                break
            fi
        done

        if [[ "${pkg}" =~ ^(ttf-|otf-|noto-fonts|adobe-source|nerd-fonts|font) ]]; then
            protect="yes"
        fi

        if [[ "${protect}" == "yes" ]]; then
            log "Protecting installed package: ${pkg}"
        else
            echo "${pkg}" >> "${final_list}"
        fi
    done

    if [[ ! -s "${final_list}" ]]; then
        log "No desktop packages selected for removal."
        return 0
    fi

    log "Final desktop package removal list saved to ${final_list}"
    log "Attempting package removal in one transaction."

    mapfile -t remove_pkgs < "${final_list}"

    if sudo pacman -Rns --noconfirm "${remove_pkgs[@]}"; then
        log "Desktop package removal transaction completed."
    else
        warn "Bulk removal had dependency conflicts. Retrying package-by-package and logging failures."
        for pkg in "${remove_pkgs[@]}"; do
            sudo pacman -Rns --noconfirm "${pkg}" || warn "Could not remove ${pkg}; it may be required by a protected package."
        done
    fi
}

remove_orphans_safely() {
    log "Removing orphan packages, while preserving fonts and protected development tools."

    local orphan_file="${BACKUP_DIR}/orphans-before-filter.txt"
    local orphan_final="${BACKUP_DIR}/orphans-final-remove.txt"

    pacman -Qtdq > "${orphan_file}" 2>/dev/null || true
    : > "${orphan_final}"

    if [[ ! -s "${orphan_file}" ]]; then
        log "No orphan packages found."
        return 0
    fi

    while read -r pkg; do
        [[ -z "${pkg}" ]] && continue

        if [[ "${pkg}" =~ ^(ttf-|otf-|noto-fonts|adobe-source|nerd-fonts|font) ]]; then
            log "Protecting orphan font package: ${pkg}"
            continue
        fi

        case "${pkg}" in
            yay|code|visual-studio-code-bin|visual-studio-code-insiders-bin|vscodium|git|base-devel|pyenv|networkmanager)
                log "Protecting orphan package: ${pkg}"
                ;;
            *)
                echo "${pkg}" >> "${orphan_final}"
                ;;
        esac
    done < "${orphan_file}"

    if [[ -s "${orphan_final}" ]]; then
        mapfile -t orphans < "${orphan_final}"
        sudo pacman -Rns --noconfirm "${orphans[@]}" || warn "Some orphan packages could not be removed."
    else
        log "No safe orphan packages selected for removal."
    fi
}

restore_terminal_dconf_only() {
    log "Restoring GNOME Terminal/Ptyxis dconf profiles only, not full GNOME rice settings."

    if command -v dconf >/dev/null 2>&1; then
        if [[ -s "${BACKUP_DIR}/dconf-gnome-terminal-before-purge.ini" ]]; then
            as_user mkdir -p "${USER_HOME}/.config/dconf"
            as_user dconf load /org/gnome/terminal/ < "${BACKUP_DIR}/dconf-gnome-terminal-before-purge.ini" || warn "Could not restore GNOME Terminal dconf."
        fi

        if [[ -s "${BACKUP_DIR}/dconf-ptyxis-before-purge.ini" ]]; then
            as_user mkdir -p "${USER_HOME}/.config/dconf"
            as_user dconf load /org/gnome/Ptyxis/ < "${BACKUP_DIR}/dconf-ptyxis-before-purge.ini" || warn "Could not restore Ptyxis dconf."
        fi
    else
        warn "dconf command not available after purge; terminal dconf restore will be deferred."
    fi
}

verify_phase1() {
    log "Verifying preserved items."

    if command -v yay >/dev/null 2>&1; then
        log "yay preserved: $(command -v yay)"
    else
        warn "yay binary not found after purge. Check whether it was installed before Phase 1."
    fi

    if command -v code >/dev/null 2>&1; then
        log "VS Code binary preserved: $(command -v code)"
    else
        warn "VS Code binary not found after purge. Package may not have been installed as 'code'."
    fi

    log "Current default target: $(systemctl get-default)"
    log "Enabled display managers after purge:"
    systemctl list-unit-files 'gdm*.service' 'sddm.service' 'lightdm.service' 'lxdm.service' 'ly.service' 'greetd.service' | tee -a "${REPORT}" || true

    log "Remaining GNOME/X/WM package quick scan:"
    pacman -Qq | grep -Ei '^(gnome-shell|gdm|mutter|plasma|xfce4|sddm|lightdm|xorg-server|xorg-xwayland|hyprland|sway|waybar|rofi|picom|dunst)$' | tee -a "${REPORT}" || true

    log "Phase 1 completed."
    log "Backup is here: ${BACKUP_DIR}"
    log "Latest backup symlink: ${BACKUP_ROOT}/latest-phase1"
}

main() {
    require_tty_safety
    backup_state
    enter_console_target
    restore_gdm_theme_backups
    reset_vscode_to_default
    purge_user_desktop_configs
    purge_system_desktop_leftovers
    remove_desktop_packages
    remove_orphans_safely
    restore_terminal_dconf_only
    verify_phase1
}

main "$@"
