#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Applying assets: GRUB background, GDM background, wallpaper rotation."

if [[ -f "$REPO_ROOT/assets/bg.png" ]]; then
    log "Installing GRUB background from assets/bg.png."
    sudo mkdir -p /boot/grub
    sudo cp -a "$REPO_ROOT/assets/bg.png" /boot/grub/bg.png

    if [[ -f /etc/default/grub ]]; then
        sudo cp -a /etc/default/grub "/etc/default/grub.rice-backup-$(date +%Y%m%d-%H%M%S)"
        if grep -q '^#\?GRUB_BACKGROUND=' /etc/default/grub; then
            sudo sed -i 's|^#\?GRUB_BACKGROUND=.*|GRUB_BACKGROUND="/boot/grub/bg.png"|' /etc/default/grub
        else
            echo 'GRUB_BACKGROUND="/boot/grub/bg.png"' | sudo tee -a /etc/default/grub >/dev/null
        fi

        if command -v grub-mkconfig >/dev/null 2>&1; then
            sudo grub-mkconfig -o /boot/grub/grub.cfg || warn "grub-mkconfig failed."
        fi
    else
        warn "/etc/default/grub missing. Skipping GRUB config update."
    fi
else
    warn "assets/bg.png missing. Skipping GRUB background."
fi

if [[ -f "$REPO_ROOT/assets/ib.png" ]]; then
    log "Installing GDM/login background from assets/ib.png."
    sudo mkdir -p /usr/share/backgrounds/rice
    sudo cp -a "$REPO_ROOT/assets/ib.png" /usr/share/backgrounds/rice/ib.png
    sudo chmod 644 /usr/share/backgrounds/rice/ib.png

    sudo mkdir -p /etc/dconf/db/gdm.d
    sudo tee /etc/dconf/db/gdm.d/90-rice-login-background >/dev/null <<'GDMBG'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/rice/ib.png'
picture-uri-dark='file:///usr/share/backgrounds/rice/ib.png'
picture-options='zoom'

[org/gnome/login-screen]
logo=''
GDMBG

    sudo dconf update || warn "GDM dconf update failed."
else
    warn "assets/ib.png missing. Skipping login background."
fi

WALL_SRC="$REPO_ROOT/assets/wallpapers"
WALL_DEST="$HOME/.local/share/backgrounds/rice/wallpapers"

mkdir -p "$WALL_DEST"

if find "$WALL_SRC" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | grep -q .; then
    log "Installing rotating wallpapers."
    cp -a "$WALL_SRC"/* "$WALL_DEST"/

    mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"

    cat > "$HOME/.local/bin/rice-wallpaper-rotator" <<'ROTATOR'
#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$HOME/.local/share/backgrounds/rice/wallpapers"

while true; do
    mapfile -t files < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
    if [[ "${#files[@]}" -eq 0 ]]; then
        sleep 5
        continue
    fi

    for img in "${files[@]}"; do
        uri="file://$img"
        gsettings set org.gnome.desktop.background picture-uri "$uri" || true
        gsettings set org.gnome.desktop.background picture-uri-dark "$uri" || true
        sleep 5
    done
done
ROTATOR

    chmod +x "$HOME/.local/bin/rice-wallpaper-rotator"

    cat > "$HOME/.config/systemd/user/rice-wallpaper-rotator.service" <<'SERVICE'
[Unit]
Description=Rice wallpaper rotator

[Service]
ExecStart=%h/.local/bin/rice-wallpaper-rotator
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
SERVICE

    systemctl --user daemon-reload || true
    systemctl --user enable --now rice-wallpaper-rotator.service || warn "Could not enable wallpaper rotator."
else
    warn "No wallpapers in assets/wallpapers. Leaving wallpaper rotation unchanged."
fi
