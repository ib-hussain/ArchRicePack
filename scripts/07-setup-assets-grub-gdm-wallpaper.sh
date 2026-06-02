#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

###############################################################################
# 07-setup-assets-grub-gdm-wallpaper.sh
#
# Handles:
#   - GRUB background: assets/bg.png -> /boot/grub/bg.png
#   - GDM/login background: assets/ib.png -> /usr/share/backgrounds/rice/ib.png
#   - user face image: assets/ib.png -> ~/.face
#   - wallpaper import from assets/wallpapers/
#   - physical wallpaper scaling/cropping through ImageMagick
#   - GNOME wallpaper scaling mode through picture-options='zoom'
#   - 5-second wallpaper rotation through a systemd user service where possible
#   - chroot-safe fallback through XDG autostart
#
# Scaling behaviour:
#   - Source images are copied to:
#       ~/.local/share/backgrounds/rice/wallpapers/raw/
#   - Scaled/cropped outputs are generated into:
#       ~/.local/share/backgrounds/rice/wallpapers/scaled/
#   - Images are resized with:
#       resize WIDTHxHEIGHT^ + gravity center + extent WIDTHxHEIGHT
#     This fills the screen without letterboxing.
#
# Optional overrides:
#   RICE_WALLPAPER_WIDTH=1920
#   RICE_WALLPAPER_HEIGHT=1080
#   RICE_WALLPAPER_INTERVAL=5
###############################################################################

log "Applying assets: GRUB background, GDM background, scaled wallpaper rotation."

run_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

has_user_session() {
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${XDG_RUNTIME_DIR:-}" && "${EUID}" -ne 0 ]]
}

detect_target_user() {
    if [[ -n "${TARGET_USER:-}" ]]; then
        printf '%s\n' "$TARGET_USER"
        return 0
    fi

    if [[ -n "${RICE_TARGET_USER:-}" ]]; then
        printf '%s\n' "$RICE_TARGET_USER"
        return 0
    fi

    if [[ "${EUID}" -ne 0 ]]; then
        id -un
        return 0
    fi

    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        printf '%s\n' "$SUDO_USER"
        return 0
    fi

    if getent passwd ibrahim >/dev/null 2>&1; then
        printf '%s\n' "ibrahim"
        return 0
    fi

    printf '%s\n' "root"
}

target_home_for_user() {
    local user="$1"
    local home_dir=""

    home_dir="$(getent passwd "$user" | awk -F: '{print $6}' || true)"

    if [[ -z "$home_dir" ]]; then
        if [[ "$user" == "root" ]]; then
            home_dir="/root"
        else
            home_dir="/home/$user"
        fi
    fi

    printf '%s\n' "$home_dir"
}

ensure_imagemagick() {
    if command -v magick >/dev/null 2>&1; then
        return 0
    fi

    log "Installing ImageMagick for wallpaper scaling."
    run_root pacman -S --needed --noconfirm imagemagick || warn "Could not install imagemagick. Wallpaper scaling will fall back to raw images."
}

safe_chown_user() {
    local user="$1"
    local path="$2"

    if [[ "$user" != "root" && -e "$path" ]]; then
        run_root chown -R "$user:$user" "$path" || true
    fi
}

safe_gsettings() {
    if has_user_session && command -v gsettings >/dev/null 2>&1; then
        gsettings set "$@" || true
    fi
}

detect_resolution() {
    local width="${RICE_WALLPAPER_WIDTH:-}"
    local height="${RICE_WALLPAPER_HEIGHT:-}"

    if [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]]; then
        printf '%s %s\n' "$width" "$height"
        return 0
    fi

    if command -v xrandr >/dev/null 2>&1; then
        local xr=""
        xr="$(xrandr --current 2>/dev/null | awk '/ connected primary/{getline; print $1; exit} / connected/{getline; print $1; exit}' || true)"
        if [[ "$xr" =~ ^([0-9]+)x([0-9]+) ]]; then
            printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            return 0
        fi

        xr="$(xrandr --current 2>/dev/null | awk '/\*/{print $1; exit}' || true)"
        if [[ "$xr" =~ ^([0-9]+)x([0-9]+) ]]; then
            printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            return 0
        fi
    fi

    if command -v xdpyinfo >/dev/null 2>&1; then
        local dims=""
        dims="$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2; exit}' || true)"
        if [[ "$dims" =~ ^([0-9]+)x([0-9]+) ]]; then
            printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            return 0
        fi
    fi

    printf '%s %s\n' "1920" "1080"
}

sanitize_name() {
    local name="$1"
    printf '%s\n' "$name" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_//; s/_$//'
}

install_grub_background() {
    if [[ -f "$REPO_ROOT/assets/bg.png" ]]; then
        log "Installing GRUB background from assets/bg.png."

        run_root mkdir -p /boot/grub
        run_root cp -a "$REPO_ROOT/assets/bg.png" /boot/grub/bg.png
        run_root chmod 644 /boot/grub/bg.png

        if [[ -f /etc/default/grub ]]; then
            run_root cp -a /etc/default/grub "/etc/default/grub.rice-backup-$(date +%Y%m%d-%H%M%S)"

            if grep -q '^#\?GRUB_BACKGROUND=' /etc/default/grub; then
                run_root sed -i 's|^#\?GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/bg.png"|' /etc/default/grub
            else
                echo 'GRUB_BACKGROUND="/boot/grub/bg.png"' | run_root tee -a /etc/default/grub >/dev/null
            fi

            if grep -q '^#\?GRUB_GFXMODE=' /etc/default/grub; then
                run_root sed -i 's|^#\?GRUB_GFXMODE=.*|GRUB_GFXMODE=auto|' /etc/default/grub
            else
                echo 'GRUB_GFXMODE=auto' | run_root tee -a /etc/default/grub >/dev/null
            fi

            if grep -q '^#\?GRUB_GFXPAYLOAD_LINUX=' /etc/default/grub; then
                run_root sed -i 's|^#\?GRUB_GFXPAYLOAD_LINUX=.*|GRUB_GFXPAYLOAD_LINUX=keep|' /etc/default/grub
            else
                echo 'GRUB_GFXPAYLOAD_LINUX=keep' | run_root tee -a /etc/default/grub >/dev/null
            fi

            if command -v grub-mkconfig >/dev/null 2>&1; then
                run_root grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed."
            fi
        else
            warn "/etc/default/grub missing. Skipping GRUB config update."
        fi
    else
        warn "assets/bg.png missing. Skipping GRUB background."
    fi
}

install_gdm_background() {
    local target_user="$1"
    local target_home="$2"

    if [[ -f "$REPO_ROOT/assets/ib.png" ]]; then
        log "Installing GDM/login background from assets/ib.png."

        run_root mkdir -p /usr/share/backgrounds/rice
        run_root cp -a "$REPO_ROOT/assets/ib.png" /usr/share/backgrounds/rice/ib.png
        run_root chmod 644 /usr/share/backgrounds/rice/ib.png

        if [[ -n "$target_home" && -d "$target_home" ]]; then
            cp -a "$REPO_ROOT/assets/ib.png" "$target_home/.face" || run_root cp -a "$REPO_ROOT/assets/ib.png" "$target_home/.face" || true
            chmod 644 "$target_home/.face" 2>/dev/null || true
            safe_chown_user "$target_user" "$target_home/.face"
            log "Installed user face image at $target_home/.face"
        fi

        run_root mkdir -p /etc/dconf/db/gdm.d
        run_root tee /etc/dconf/db/gdm.d/90-rice-login-background >/dev/null <<'GDMBG'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/rice/ib.png'
picture-uri-dark='file:///usr/share/backgrounds/rice/ib.png'
picture-options='zoom'

[org/gnome/login-screen]
logo=''
GDMBG

        run_root dconf update || warn "GDM dconf update failed."
    else
        warn "assets/ib.png missing. Skipping GDM/login background."
    fi
}

prepare_wallpapers() {
    local target_user="$1"
    local target_home="$2"

    local wall_src="$REPO_ROOT/assets/wallpapers"
    local wall_root="$target_home/.local/share/backgrounds/rice/wallpapers"
    local raw_dir="$wall_root/raw"
    local scaled_dir="$wall_root/scaled"

    mkdir -p "$raw_dir" "$scaled_dir"

    mapfile -t source_images < <(
        find "$wall_src" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            | sort
    )

    if [[ "${#source_images[@]}" -eq 0 ]]; then
        warn "No wallpaper images found in assets/wallpapers. Wallpaper rotation will not be changed."
        safe_chown_user "$target_user" "$wall_root"
        return 0
    fi

    log "Installing ${#source_images[@]} wallpaper image(s)."

    rm -rf "$raw_dir" "$scaled_dir"
    mkdir -p "$raw_dir" "$scaled_dir"

    local img=""
    for img in "${source_images[@]}"; do
        cp -a "$img" "$raw_dir/"
    done

    ensure_imagemagick

    read -r width height < <(detect_resolution)
    log "Wallpaper scaling target: ${width}x${height}"

    if command -v magick >/dev/null 2>&1; then
        local index=0
        for img in "${source_images[@]}"; do
            index=$((index + 1))

            local base
            local stem
            local safe
            local out

            base="$(basename "$img")"
            stem="${base%.*}"
            safe="$(sanitize_name "$stem")"
            [[ -n "$safe" ]] || safe="wallpaper_${index}"

            out="$scaled_dir/$(printf '%03d' "$index")-${safe}-${width}x${height}.png"

            log "Scaling wallpaper: $base -> $(basename "$out")"
            magick "$img" \
                -auto-orient \
                -resize "${width}x${height}^" \
                -gravity center \
                -extent "${width}x${height}" \
                "$out" || {
                    warn "Scaling failed for $img. Copying raw fallback."
                    cp -a "$img" "$scaled_dir/$(printf '%03d' "$index")-${safe}-raw.${base##*.}"
                }
        done
    else
        warn "ImageMagick unavailable. Using raw wallpapers without physical scaling."
        cp -a "$raw_dir"/. "$scaled_dir"/
    fi

    safe_chown_user "$target_user" "$wall_root"

    log "Wallpaper files prepared:"
    find "$scaled_dir" -maxdepth 1 -type f | sort | sed 's/^/[WALLPAPER] /' | tee -a "$LOG_FILE" || true
}

write_wallpaper_rotator() {
    local target_user="$1"
    local target_home="$2"

    local bin_dir="$target_home/.local/bin"
    local service_dir="$target_home/.config/systemd/user"
    local autostart_dir="$target_home/.config/autostart"

    mkdir -p "$bin_dir" "$service_dir" "$autostart_dir"

    cat > "$bin_dir/rice-wallpaper-rotator" <<'ROTATOR'
#!/usr/bin/env bash
set -Eeuo pipefail

RAW_DIR="$HOME/.local/share/backgrounds/rice/wallpapers/raw"
SCALED_DIR="$HOME/.local/share/backgrounds/rice/wallpapers/scaled"
INTERVAL="${RICE_WALLPAPER_INTERVAL:-5}"

choose_dir() {
    if find "$SCALED_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | grep -q .; then
        printf '%s\n' "$SCALED_DIR"
    else
        printf '%s\n' "$RAW_DIR"
    fi
}

apply_scaling_options() {
    gsettings set org.gnome.desktop.background picture-options 'zoom' || true
    gsettings set org.gnome.desktop.screensaver picture-options 'zoom' || true
}

while true; do
    DIR="$(choose_dir)"

    mapfile -t files < <(
        find "$DIR" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            | sort
    )

    if [[ "${#files[@]}" -eq 0 ]]; then
        sleep "$INTERVAL"
        continue
    fi

    for img in "${files[@]}"; do
        uri="file://$img"

        apply_scaling_options

        gsettings set org.gnome.desktop.background picture-uri "$uri" || true
        gsettings set org.gnome.desktop.background picture-uri-dark "$uri" || true
        gsettings set org.gnome.desktop.screensaver picture-uri "$uri" || true

        sleep "$INTERVAL"
    done
done
ROTATOR

    chmod +x "$bin_dir/rice-wallpaper-rotator"

    cat > "$service_dir/rice-wallpaper-rotator.service" <<'SERVICE'
[Unit]
Description=Rice wallpaper rotator

[Service]
ExecStart=%h/.local/bin/rice-wallpaper-rotator
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
SERVICE

    cat > "$autostart_dir/rice-wallpaper-rotator.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Rice Wallpaper Rotator
Comment=Rotate scaled ArchRicePack wallpapers every 5 seconds
Exec=$target_home/.local/bin/rice-wallpaper-rotator
X-GNOME-Autostart-enabled=true
Terminal=false
Hidden=false
DESKTOP

    safe_chown_user "$target_user" "$bin_dir/rice-wallpaper-rotator"
    safe_chown_user "$target_user" "$service_dir/rice-wallpaper-rotator.service"
    safe_chown_user "$target_user" "$autostart_dir/rice-wallpaper-rotator.desktop"

    if has_user_session; then
        log "Enabling wallpaper rotator as user systemd service."

        systemctl --user daemon-reload || true
        systemctl --user enable --now rice-wallpaper-rotator.service || warn "Could not enable wallpaper rotator user service."

        safe_gsettings org.gnome.desktop.background picture-options zoom
        safe_gsettings org.gnome.desktop.screensaver picture-options zoom

        local first_wallpaper
        first_wallpaper="$(find "$target_home/.local/share/backgrounds/rice/wallpapers/scaled" -maxdepth 1 -type f | sort | head -n 1 || true)"

        if [[ -n "$first_wallpaper" ]]; then
            local uri="file://$first_wallpaper"
            safe_gsettings org.gnome.desktop.background picture-uri "$uri"
            safe_gsettings org.gnome.desktop.background picture-uri-dark "$uri"
            safe_gsettings org.gnome.desktop.screensaver picture-uri "$uri"
            log "Applied initial scaled wallpaper: $first_wallpaper"
        fi
    else
        warn "No active GNOME user session. Wallpaper rotator installed through autostart and will activate on first login."
    fi
}

main() {
    local target_user
    local target_home

    target_user="$(detect_target_user)"
    target_home="$(target_home_for_user "$target_user")"

    log "Target user: $target_user"
    log "Target home: $target_home"

    install_grub_background
    install_gdm_background "$target_user" "$target_home"
    prepare_wallpapers "$target_user" "$target_home"
    write_wallpaper_rotator "$target_user" "$target_home"

    log "Asset, GDM, GRUB, and scaled wallpaper setup complete."
}

main "$@"