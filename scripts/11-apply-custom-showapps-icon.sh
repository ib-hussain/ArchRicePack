#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Applying final custom Show Applications dock icon."

EXT_UUID="rice-arch-showapps@local"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
ICON_THEME="$HOME/.local/share/icons/Rice-Papirus"

SRC=""

for f in \
    "$REPO_ROOT/assets/arch-icons/arch-logo.png" \
    "$REPO_ROOT/assets/arch-icons/arch-logo.webp" \
    "$REPO_ROOT/assets/arch-icons/arch-logo.svg"
do
    if [[ -f "$f" ]]; then
        SRC="$f"
        break
    fi
done

if [[ -z "$SRC" ]]; then
    warn "No custom Arch icon source found. Skipping Show Applications icon patch."
    exit 0
fi

install_pacman_package imagemagick
install_pacman_package gtk3

mkdir -p "$ICON_THEME" "$EXT_DIR/icons"

WORK="$HOME/.cache/rice-showapps-png-fix"
rm -rf "$WORK"
mkdir -p "$WORK"

MASTER="$WORK/arch-show-apps.png"

log "Using source icon: $SRC"
magick "$SRC" -background none -alpha on -resize 1024x1024 -gravity center -extent 1024x1024 "$MASTER"

log "Writing PNG directly into GNOME Shell extension."
magick "$MASTER" -resize 512x512 "$EXT_DIR/icons/arch-show-apps.png"
magick "$MASTER" -resize 512x512 "$EXT_DIR/arch-show-apps.png"

cat > "$EXT_DIR/metadata.json" <<'EOFJSON'
{
  "uuid": "rice-arch-showapps@local",
  "name": "Rice Arch Show Apps Icon",
  "description": "Forces Dash-to-Dock Show Applications icon to use a custom Arch image.",
  "shell-version": ["50"],
  "version": 2
}
EOFJSON

cat > "$EXT_DIR/stylesheet.css" <<'EOFCSS'
#dashtodockContainer .show-apps .overview-icon,
#dashtodockContainer .show-apps .show-apps-icon,
#dash .show-apps .overview-icon,
#dash .show-apps .show-apps-icon,
.show-apps .overview-icon,
.show-apps .show-apps-icon {
    background-image: url("icons/arch-show-apps.png");
    background-size: contain;
    background-position: center;
    background-repeat: no-repeat;
}
EOFCSS

cat > "$EXT_DIR/extension.js" <<'EOFJS'
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class RiceArchShowAppsIconExtension extends Extension {
    enable() {
        this._timeoutId = 0;
        this._iconFile = this.dir.get_child('icons').get_child('arch-show-apps.png');
        this._gicon = new Gio.FileIcon({file: this._iconFile});
        this._patchAll();

        this._timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            this._patchAll();
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        if (this._timeoutId) {
            GLib.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }
    }

    _patchAll() {
        try { this._walk(Main.uiGroup); } catch (e) {}
        try { this._walk(Main.layoutManager.uiGroup); } catch (e) {}
    }

    _walk(actor) {
        if (!actor)
            return;

        this._maybePatch(actor);

        let children = [];
        try {
            if (typeof actor.get_children === 'function')
                children = actor.get_children();
        } catch (e) {
            children = [];
        }

        for (const child of children)
            this._walk(child);
    }

    _styleClass(actor) {
        try {
            if (typeof actor.get_style_class_name === 'function')
                return actor.get_style_class_name() || '';
        } catch (e) {}
        return '';
    }

    _iconName(actor) {
        try {
            if (typeof actor.get_icon_name === 'function')
                return actor.get_icon_name() || '';
        } catch (e) {}
        try {
            return actor.icon_name || '';
        } catch (e) {}
        return '';
    }

    _hasShowAppsParent(actor) {
        let current = actor;

        for (let i = 0; i < 8 && current; i++) {
            const klass = this._styleClass(current).toLowerCase();

            if (klass.includes('show-apps') || klass.includes('showapps') || klass.includes('show-applications'))
                return true;

            try {
                current = current.get_parent();
            } catch (e) {
                current = null;
            }
        }

        return false;
    }

    _maybePatch(actor) {
        if (!(actor instanceof St.Icon))
            return;

        const name = this._iconName(actor).toLowerCase();
        const parentMatch = this._hasShowAppsParent(actor);

        const nameMatch =
            name.includes('view-app-grid') ||
            name.includes('applications-all') ||
            name.includes('applications-system') ||
            name.includes('start-here');

        if (!parentMatch && !nameMatch)
            return;

        try { actor.set_gicon(this._gicon); } catch (e) { try { actor.gicon = this._gicon; } catch (e2) {} }
        try { actor.set_icon_name(null); } catch (e) {}
        try { actor.set_icon_size(52); } catch (e) {}
        try { actor.visible = true; actor.opacity = 255; } catch (e) {}
    }
}
EOFJS

log "Writing icon-theme PNG fallbacks."

ICON_NAMES=(
    "applications-all"
    "applications-all-symbolic"
    "applications-system-symbolic"
    "view-app-grid"
    "view-app-grid-symbolic"
    "start-here"
    "start-here-symbolic"
    "start-here-archlinux"
    "distributor-logo-archlinux"
)

SIZES=(16 22 24 32 48 64 96 128 256 512)

for size in "${SIZES[@]}"; do
    for context in apps actions categories places panel symbolic/actions symbolic/categories symbolic/places; do
        dir="$ICON_THEME/${size}x${size}/$context"
        mkdir -p "$dir"

        for name in "${ICON_NAMES[@]}"; do
            magick "$MASTER" -resize "${size}x${size}" "$dir/$name.png"
            rm -f "$dir/$name.svg"
        done
    done
done

dconf_write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-apps-at-top true

gs_set org.gnome.shell.extensions.dash-to-dock show-show-apps-button true
gs_set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true
gs_set org.gnome.desktop.interface icon-theme "Rice-Papirus"

gtk-update-icon-cache -f -t "$ICON_THEME" >/dev/null 2>&1 || true

if gnome-extensions list | grep -qx "$EXT_UUID"; then
    gnome-extensions disable "$EXT_UUID" >/dev/null 2>&1 || true
    sleep 1
    gnome-extensions enable "$EXT_UUID" >/dev/null 2>&1 || true
else
    warn "$EXT_UUID installed but GNOME may index it after logout/login."
fi

if gnome-extensions list | grep -qx "dash-to-dock@micxgx.gmail.com"; then
    gnome-extensions disable dash-to-dock@micxgx.gmail.com >/dev/null 2>&1 || true
    sleep 1
    gnome-extensions enable dash-to-dock@micxgx.gmail.com >/dev/null 2>&1 || true
fi

log "Custom Show Applications dock icon patch complete."
log "If it does not appear immediately, log out/in or reboot once."