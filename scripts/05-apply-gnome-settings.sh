#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Applying GNOME, dock, theme, and keybinding settings."

if [[ -f "$REPO_ROOT/configs/dconf/gnome-interface.ini" ]]; then
    dconf load /org/gnome/desktop/interface/ < "$REPO_ROOT/configs/dconf/gnome-interface.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/gnome-wm.ini" ]]; then
    dconf load /org/gnome/desktop/wm/ < "$REPO_ROOT/configs/dconf/gnome-wm.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/dash-to-dock.ini" ]]; then
    dconf load /org/gnome/shell/extensions/dash-to-dock/ < "$REPO_ROOT/configs/dconf/dash-to-dock.ini" || true
fi

gs_set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark-blue"
gs_set org.gnome.desktop.interface color-scheme "prefer-dark"
gs_set org.gnome.desktop.interface icon-theme "Rice-Papirus"
gs_set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
gs_set org.gnome.mutter overlay-key "Super_L"

if schema_exists org.gnome.shell.extensions.user-theme; then
    gs_set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark-blue"
fi

dconf_write /org/gnome/shell/extensions/dash-to-dock/dock-position "'BOTTOM'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/extend-height false
dconf_write /org/gnome/shell/extensions/dash-to-dock/dock-fixed false
dconf_write /org/gnome/shell/extensions/dash-to-dock/intellihide true
dconf_write /org/gnome/shell/extensions/dash-to-dock/autohide true
dconf_write /org/gnome/shell/extensions/dash-to-dock/require-pressure-to-show false
dconf_write /org/gnome/shell/extensions/dash-to-dock/pressure-threshold 0.0
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-delay 0.0
dconf_write /org/gnome/shell/extensions/dash-to-dock/hide-delay 0.18
dconf_write /org/gnome/shell/extensions/dash-to-dock/animation-time 0.16
dconf_write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 52
dconf_write /org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink true
dconf_write /org/gnome/shell/extensions/dash-to-dock/force-straight-corner false
dconf_write /org/gnome/shell/extensions/dash-to-dock/running-indicator-style "'DOTS'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-apps-at-top true
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-trash true
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-mounts false
dconf_write /org/gnome/shell/extensions/dash-to-dock/click-action "'minimize-or-previews'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/scroll-action "'cycle-windows'"

gs_set org.gnome.shell.extensions.dash-to-dock intellihide true
gs_set org.gnome.shell.extensions.dash-to-dock autohide true
gs_set org.gnome.shell.extensions.dash-to-dock require-pressure-to-show false
gs_set org.gnome.shell.extensions.dash-to-dock pressure-threshold 0.0
gs_set org.gnome.shell.extensions.dash-to-dock show-delay 0.0
gs_set org.gnome.shell.extensions.dash-to-dock hide-delay 0.18
gs_set org.gnome.shell.extensions.dash-to-dock animation-time 0.16
gs_set org.gnome.shell.extensions.dash-to-dock intellihide-mode "ALL_WINDOWS"
gs_set org.gnome.shell.extensions.dash-to-dock show-show-apps-button true
gs_set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true

gs_set org.gnome.shell.keybindings toggle-overview "['<Super>s', '<Super>Tab']"
gs_set org.gnome.shell.keybindings toggle-application-view "['<Super>a']"
gs_set org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
gs_set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Alt>Tab']"
gs_set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d']"
gs_set org.gnome.desktop.wm.keybindings close "['<Super>q', '<Alt>F4']"
gs_set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"
gs_set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']"
gs_set org.gnome.desktop.wm.keybindings unmaximize "['<Super>Down']"

python - <<'PY'
from pathlib import Path
import ast
import subprocess

def run(cmd, check=False):
    return subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)

def out(cmd, default=""):
    r = run(cmd)
    return r.stdout.strip() if r.returncode == 0 else default

def gv(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

media = "org.gnome.settings-daemon.plugins.media-keys"
base = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
prefix = "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"

raw = out(["gsettings", "get", media, "custom-keybindings"], "[]").replace("@as ", "")
try:
    paths = ast.literal_eval(raw)
    if not isinstance(paths, list):
        paths = []
except Exception:
    paths = []

clean = []
for path in paths:
    schema = prefix + path
    binding = out(["gsettings", "get", schema, "binding"], "''").strip("'").strip('"')
    command = out(["gsettings", "get", schema, "command"], "''").strip("'").strip('"').lower()
    bad = binding in {"<Super>", "Super", "Super_L", "<Super_L>"} or ("gnome-control-center" in command and "super" in binding.lower())
    if not bad:
        clean.append(path)

entries = {
    base + "rice-terminal/": ("Open Terminal", "gnome-terminal", "<Super>Return"),
    base + "rice-terminal-open/": ("Open Terminal Alt Ctrl T", "gnome-terminal", "<Control><Alt>t"),
    base + "rice-files/": ("Open Files", "nautilus", "<Super>e"),
    base + "rice-browser/": ("Open Browser", "google-chrome-stable", "<Super>b"),
    base + "rice-code/": ("Open VS Code", "code", "<Super>c"),
    base + "rice-task-manager/": ("Open System Monitor", "rice-task-manager", "<Control><Shift>Escape"),
}

for path in entries:
    if path not in clean:
        clean.append(path)

value = "[" + ", ".join("'" + p + "'" for p in clean) + "]"
run(["gsettings", "set", media, "custom-keybindings", value], check=True)

for path, (name, command, binding) in entries.items():
    schema = prefix + path
    run(["gsettings", "set", schema, "name", gv(name)], check=True)
    run(["gsettings", "set", schema, "command", gv(command)], check=True)
    run(["gsettings", "set", schema, "binding", gv(binding)], check=True)

dirs = [Path.home() / ".local/share/applications", Path("/usr/share/applications")]

def exists(name):
    return any((d / name).exists() for d in dirs)

def pick(*names):
    for name in names:
        if exists(name):
            return name
    return None

apps = [
    pick("org.gnome.Nautilus.desktop", "nautilus.desktop"),
    pick("code.desktop", "visual-studio-code.desktop", "com.visualstudio.code.desktop"),
    pick("org.gnome.Terminal.desktop", "gnome-terminal.desktop"),
    pick("google-chrome.desktop", "google-chrome-stable.desktop", "firefox.desktop"),
]

apps = [x for x in apps if x]
fav = "[" + ", ".join("'" + x + "'" for x in apps) + "]"
run(["gsettings", "set", "org.gnome.shell", "favorite-apps", fav], check=True)
print(fav)
PY
