#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Applying GNOME, dock, theme, and keybinding settings."

# Load all dconf configuration files
if [[ -f "$REPO_ROOT/configs/dconf/gnome-interface.ini" ]]; then
    dconf load /org/gnome/desktop/interface/ < "$REPO_ROOT/configs/dconf/gnome-interface.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/gnome-wm.ini" ]]; then
    dconf load /org/gnome/desktop/wm/ < "$REPO_ROOT/configs/dconf/gnome-wm.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/dash-to-dock.ini" ]]; then
    dconf load /org/gnome/shell/extensions/dash-to-dock/ < "$REPO_ROOT/configs/dconf/dash-to-dock.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/media-keys.ini" ]]; then
    dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$REPO_ROOT/configs/dconf/media-keys.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/gnome-shell.ini" ]]; then
    dconf load /org/gnome/shell/ < "$REPO_ROOT/configs/dconf/gnome-shell.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/mutter.ini" ]]; then
    dconf load /org/gnome/mutter/ < "$REPO_ROOT/configs/dconf/mutter.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/app-folders.ini" ]]; then
    dconf load /org/gnome/desktop/app-folders/ < "$REPO_ROOT/configs/dconf/app-folders.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/notifications.ini" ]]; then
    dconf load /org/gnome/desktop/notifications/ < "$REPO_ROOT/configs/dconf/notifications.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/background.ini" ]]; then
    dconf load /org/gnome/desktop/background/ < "$REPO_ROOT/configs/dconf/background.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/screensaver.ini" ]]; then
    dconf load /org/gnome/desktop/screensaver/ < "$REPO_ROOT/configs/dconf/screensaver.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/input-sources.ini" ]]; then
    dconf load /org/gnome/desktop/ < "$REPO_ROOT/configs/dconf/input-sources.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/system-monitor.ini" ]]; then
    dconf load /org/gnome/gnome-system-monitor/ < "$REPO_ROOT/configs/dconf/system-monitor.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/nautilus.ini" ]]; then
    dconf load /org/gnome/nautilus/ < "$REPO_ROOT/configs/dconf/nautilus.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/terminal.ini" ]]; then
    dconf load /org/gnome/terminal/ < "$REPO_ROOT/configs/dconf/terminal.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/control-center.ini" ]]; then
    dconf load /org/gnome/control-center/ < "$REPO_ROOT/configs/dconf/control-center.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/extension-manager.ini" ]]; then
    dconf load /com/mattjakeman/ExtensionManager/ < "$REPO_ROOT/configs/dconf/extension-manager.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/housekeeping.ini" ]]; then
    dconf load /org/gnome/settings-daemon/plugins/housekeeping/ < "$REPO_ROOT/configs/dconf/housekeeping.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/portal.ini" ]]; then
    dconf load /org/gnome/portal/filechooser/ < "$REPO_ROOT/configs/dconf/portal.ini" || true
fi

if [[ -f "$REPO_ROOT/configs/dconf/gtk4.ini" ]]; then
    dconf load /org/gtk/gtk4/ < "$REPO_ROOT/configs/dconf/gtk4.ini" || true
fi

# Apply core settings with gs_set for permanence
log "Applying core gsettings with permanence..."

# [org/gnome/desktop/interface]
gs_set org.gnome.desktop.interface color-scheme "prefer-dark"
gs_set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark-blue"
gs_set org.gnome.desktop.interface icon-theme "Rice-Papirus"

# [org/gnome/desktop/wm/preferences]
gs_set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"

# [org/gnome/mutter]
gs_set org.gnome.mutter overlay-key "Super_L"

# [org/gnome/shell/extensions/user-theme]
if schema_exists org.gnome.shell.extensions.user-theme; then
    gs_set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark-blue"
fi

# [org/gnome/shell/extensions/dash-to-dock]
dconf_write /org/gnome/shell/extensions/dash-to-dock/animation-time 0.16
dconf_write /org/gnome/shell/extensions/dash-to-dock/autohide true
dconf_write /org/gnome/shell/extensions/dash-to-dock/click-action "'minimize-or-previews'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink true
dconf_write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 52
dconf_write /org/gnome/shell/extensions/dash-to-dock/dock-fixed false
dconf_write /org/gnome/shell/extensions/dash-to-dock/dock-position "'BOTTOM'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/extend-height false
dconf_write /org/gnome/shell/extensions/dash-to-dock/force-straight-corner false
dconf_write /org/gnome/shell/extensions/dash-to-dock/hide-delay 0.18
dconf_write /org/gnome/shell/extensions/dash-to-dock/intellihide true
dconf_write /org/gnome/shell/extensions/dash-to-dock/intellihide-mode "'ALL_WINDOWS'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/pressure-threshold 0.0
dconf_write /org/gnome/shell/extensions/dash-to-dock/require-pressure-to-show false
dconf_write /org/gnome/shell/extensions/dash-to-dock/running-indicator-style "'DOTS'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/scroll-action "'cycle-windows'"
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-apps-at-top true
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-delay 0.0
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-mounts false
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-trash true
dconf_write /org/gnome/shell/extensions/dash-to-dock/show-show-apps-button true

gs_set org.gnome.shell.extensions.dash-to-dock animation-time 0.16
gs_set org.gnome.shell.extensions.dash-to-dock autohide true
gs_set org.gnome.shell.extensions.dash-to-dock hide-delay 0.18
gs_set org.gnome.shell.extensions.dash-to-dock intellihide true
gs_set org.gnome.shell.extensions.dash-to-dock intellihide-mode "ALL_WINDOWS"
gs_set org.gnome.shell.extensions.dash-to-dock pressure-threshold 0.0
gs_set org.gnome.shell.extensions.dash-to-dock require-pressure-to-show false
gs_set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true
gs_set org.gnome.shell.extensions.dash-to-dock show-delay 0.0
gs_set org.gnome.shell.extensions.dash-to-dock show-show-apps-button true

# [org/gnome/shell/keybindings]
gs_set org.gnome.shell.keybindings toggle-overview "['<Super>', '<Super>s']"
gs_set org.gnome.shell.keybindings toggle-application-view "['<Super>a', '<Super>Tab']"

# [org/gnome/desktop/wm/keybindings]
gs_set org.gnome.desktop.wm.keybindings close "['<Super>q', '<Ctrl>w']"
gs_set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']"
gs_set org.gnome.desktop.wm.keybindings show-desktop "['<Super>d']"
gs_set org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
gs_set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"
gs_set org.gnome.desktop.wm.keybindings unmaximize "['<Super>Down']"

# [org/gnome/desktop/background]
gs_set org.gnome.desktop.background color-shading-type "solid"
gs_set org.gnome.desktop.background picture-options "scaled"
gs_set org.gnome.desktop.background picture-uri "file://$HOME/archRicePack/assets/bg.png"
gs_set org.gnome.desktop.background picture-uri-dark "file://$HOME/archRicePack/assets/bg.png"
gs_set org.gnome.desktop.background primary-color "#000000"
gs_set org.gnome.desktop.background secondary-color "#000000"

# [org/gnome/desktop/screensaver]
gs_set org.gnome.desktop.screensaver picture-options "scaled"
gs_set org.gnome.desktop.screensaver picture-uri "file://$HOME/archRicePack/assets/bg.png"
gs_set org.gnome.desktop.screensaver primary-color "#000000"
gs_set org.gnome.desktop.screensaver secondary-color "#000000"

# [org/gnome/desktop/input-sources]
gs_set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"

# [org/gnome/desktop/peripherals/keyboard]
gs_set org.gnome.desktop.peripherals.keyboard numlock-state true

# [org/gnome/desktop/notifications]
gs_set org.gnome.desktop.notifications application-children "['gnome-about-panel', 'org-gnome-systemmonitor', 'firefox']"

# [org/gnome/desktop/notifications/application/firefox]
dconf_write /org/gnome/desktop/notifications/application/firefox/application-id "'firefox.desktop'"
gs_set org.gnome.desktop.notifications.application.firefox application-id "firefox.desktop"

# [org/gnome/desktop/notifications/application/gnome-about-panel]
dconf_write /org/gnome/desktop/notifications/application/gnome-about-panel/application-id "'gnome-about-panel.desktop'"
gs_set org.gnome.desktop.notifications.application.gnome-about-panel application-id "gnome-about-panel.desktop"

# [org/gnome/desktop/notifications/application/org-gnome-systemmonitor]
dconf_write /org/gnome/desktop/notifications/application/org-gnome-systemmonitor/application-id "'org.gnome.SystemMonitor.desktop'"
gs_set org.gnome.desktop.notifications.application.org-gnome-systemmonitor application-id "org.gnome.SystemMonitor.desktop"

# [org/gnome/desktop/app-folders]
gs_set org.gnome.desktop.app-folders folder-children "['System', 'Utilities']"

# [org/gnome/desktop/app-folders/folders/System]
dconf_write /org/gnome/desktop/app-folders/folders/System/apps "['nm-connection-editor.desktop', 'org.gnome.tweaks.desktop']"
dconf_write /org/gnome/desktop/app-folders/folders/System/name "'X-GNOME-Shell-System.directory'"
dconf_write /org/gnome/desktop/app-folders/folders/System/translate true
gs_set org.gnome.desktop.app-folders.folders.System apps "['nm-connection-editor.desktop', 'org.gnome.tweaks.desktop']"
gs_set org.gnome.desktop.app-folders.folders.System name "X-GNOME-Shell-System.directory"
gs_set org.gnome.desktop.app-folders.folders.System translate true

# [org/gnome/desktop/app-folders/folders/Utilities]
dconf_write /org/gnome/desktop/app-folders/folders/Utilities/name "'X-GNOME-Shell-Utilities.directory'"
dconf_write /org/gnome/desktop/app-folders/folders/Utilities/translate true
gs_set org.gnome.desktop.app-folders.folders.Utilities name "X-GNOME-Shell-Utilities.directory"
gs_set org.gnome.desktop.app-folders.folders.Utilities translate true

# [org/gnome/shell] - core settings
gs_set org.gnome.shell disabled-extensions "@as []"
gs_set org.gnome.shell enabled-extensions "['user-theme@gnome-shell-extensions.gcampax.github.com', 'hidetopbar@mathieu.bidon.ca', 'start-overlay-in-application-view@Hex_cz', 'dash-to-dock@micxgx.gmail.com', 'arch-dock-icon@ib-hussain']"
gs_set org.gnome.shell last-selected-power-profile "power-saver"
gs_set org.gnome.shell welcome-dialog-last-shown-version "50.2"

# [org/gnome/gnome-system-monitor]
gs_set org.gnome.gnome-system-monitor current-tab "resources"
gs_set org.gnome.gnome-system-monitor maximized true
gs_set org.gnome.gnome-system-monitor show-dependencies false
gs_set org.gnome.gnome-system-monitor show-whose-processes "user"
gs_set org.gnome.gnome-system-monitor window-height 720
gs_set org.gnome.gnome-system-monitor window-width 1080

# [org/gnome/gnome-system-monitor/proctree]
dconf_write /org/gnome/gnome-system-monitor/proctree/col-0-visible true
dconf_write /org/gnome/gnome-system-monitor/proctree/col-0-width 472
dconf_write /org/gnome/gnome-system-monitor/proctree/col-24-visible true
dconf_write /org/gnome/gnome-system-monitor/proctree/col-24-width 407
dconf_write /org/gnome/gnome-system-monitor/proctree/col-26-visible false
dconf_write /org/gnome/gnome-system-monitor/proctree/col-26-width 0
dconf_write /org/gnome/gnome-system-monitor/proctree/col-8-visible true
dconf_write /org/gnome/gnome-system-monitor/proctree/col-8-width 111

# [org/gnome/nautilus/preferences]
gs_set org.gnome.nautilus.preferences migrated-gtk-settings true

# [org/gnome/nautilus/window-state]
dconf_write /org/gnome/nautilus/window-state/initial-size "(1080, 1080)"
dconf_write /org/gnome/nautilus/window-state/initial-size-file-chooser "(1080, 720)"
dconf_write /org/gnome/nautilus/window-state/maximized true
gs_set org.gnome.nautilus.window-state initial-size "(1080, 1080)"
gs_set org.gnome.nautilus.window-state initial-size-file-chooser "(1080, 720)"
gs_set org.gnome.nautilus.window-state maximized true

# [org/gnome/control-center]
gs_set org.gnome.control-center last-panel "network"
dconf_write /org/gnome/control-center/window-state "(980, 640, false)"
gs_set org.gnome.control-center window-state "(980, 640, false)"

# [com/mattjakeman/ExtensionManager]
gs_set com.mattjakeman.ExtensionManager is-maximized true
gs_set com.mattjakeman.ExtensionManager width 555

# [org/gnome/portal/filechooser/org.chromium.Chromium]
gs_set org.gnome.portal.filechooser.org-chromium-Chromium last-folder-path "$HOME"

# [org/gnome/settings-daemon/plugins/housekeeping]
dconf_write /org/gnome/settings-daemon/plugins/housekeeping/donation-reminder-last-shown 1780349069241737
gs_set org.gnome.settings-daemon.plugins.housekeeping donation-reminder-last-shown 1780349069241737

# [org/gnome/terminal/legacy/profiles:]
gs_set org.gnome.terminal.legacy.profiles default "'fc74a141-e2ae-4f89-8a21-5b02e8cd73aa'"
gs_set org.gnome.terminal.legacy.profiles list "['fc74a141-e2ae-4f89-8a21-5b02e8cd73aa']"

# [org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa]
PROFILE_PATH="org.gnome.terminal.legacy.profiles:/fc74a141-e2ae-4f89-8a21-5b02e8cd73aa"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/background-color "'#2e3440'"
gs_set "$PROFILE_PATH" background-color "#2e3440"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/bold-is-bright true
gs_set "$PROFILE_PATH" bold-is-bright true
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/cursor-blink-mode "'on'"
gs_set "$PROFILE_PATH" cursor-blink-mode "on"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/cursor-shape "'ibeam'"
gs_set "$PROFILE_PATH" cursor-shape "ibeam"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/default-size-columns 110
gs_set "$PROFILE_PATH" default-size-columns 110
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/default-size-rows 28
gs_set "$PROFILE_PATH" default-size-rows 28
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/font "'Noto Sans Mono 12'"
gs_set "$PROFILE_PATH" font "Noto Sans Mono 12"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/foreground-color "'#eceff4'"
gs_set "$PROFILE_PATH" foreground-color "#eceff4"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/palette "['#2e3440', '#bf616a', '#a3be8c', '#ebcb8b', '#81a1c1', '#b48ead', '#88c0d0', '#eceff4', '#4c566a', '#bf616a', '#a3be8c', '#ebcb8b', '#81a1c1', '#b48ead', '#8fbcbb', '#eceff4']"
gs_set "$PROFILE_PATH" palette "['#2e3440', '#bf616a', '#a3be8c', '#ebcb8b', '#81a1c1', '#b48ead', '#88c0d0', '#eceff4', '#4c566a', '#bf616a', '#a3be8c', '#ebcb8b', '#81a1c1', '#b48ead', '#8fbcbb', '#eceff4']"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/scroll-on-output false
gs_set "$PROFILE_PATH" scroll-on-output false
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/scrollback-unlimited true
gs_set "$PROFILE_PATH" scrollback-unlimited true
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/scrollbar-policy "'always'"
gs_set "$PROFILE_PATH" scrollbar-policy "always"
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/use-system-font false
gs_set "$PROFILE_PATH" use-system-font false
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/use-theme-colors false
gs_set "$PROFILE_PATH" use-theme-colors false
dconf_write /org/gnome/terminal/legacy/profiles:/:fc74a141-e2ae-4f89-8a21-5b02e8cd73aa/visible-name "'IB Glass Terminal'"
gs_set "$PROFILE_PATH" visible-name "IB Glass Terminal"

# [org/gtk/gtk4/settings/file-chooser]
gs_set org.gtk.gtk4.settings.file-chooser show-hidden false
gs_set org.gtk.gtk4.settings.file-chooser sort-directories-first false
# All settings now loaded via dconf load from individual .ini files
# This approach is more robust as dconf load gracefully skips missing keys/schemas

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
    base + "browser/": ("Open Browser", "google-chrome-stable", "<Super>b"),
    base + "code/": ("Open VS Code", "code", "<Super>c"),
    base + "files/": ("Open Files", "nautilus", "<Super>e"),
    base + "settings/": ("Open Settings", "gnome-control-center", "<Super>i"),
    base + "terminal/": ("Open Terminal", "gnome-terminal", "<Control><Alt>t"),
    base + "task-manager/": ("Open System Monitor", "gnome-system-monitor", "<Control><Shift>Escape"),
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

# Set app-picker-layout from dconf-complete
picker_layout = "[{'ib-arch-menu.desktop': <{'position': <0>}>, 'blueman-manager.desktop': <{'position': <1>}>, 'ca.desrt.dconf-editor.desktop': <{'position': <2>}>, 'com.mattjakeman.ExtensionManager.desktop': <{'position': <3>}>, 'org.flameshot.Flameshot.desktop': <{'position': <4>}>, 'htop.desktop': <{'position': <5>}>, 'ib-power-modes.desktop': <{'position': <6>}>, 'org.gnome.Screenshot.desktop': <{'position': <7>}>, 'btop.desktop': <{'position': <8>}>, 'org.pulseaudio.pavucontrol.desktop': <{'position': <9>}>, 'System': <{'position': <10>}>, 'conky.desktop': <{'position': <11>}>, 'org.gnome.Settings.desktop': <{'position': <12>}>, 'org.gnome.SystemMonitor.desktop': <{'position': <13>}>, 'firefox.desktop': <{'position': <14>}>, 'audacious.desktop': <{'position': <15>}>}]"
run(["gsettings", "set", "org.gnome.shell", "app-picker-layout", picker_layout], check=True)

print(fav)
PY
