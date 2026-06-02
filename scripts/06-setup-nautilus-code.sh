#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-common.sh"

require_user_session

log "Setting up Nautilus Open with Code."

mkdir -p "$HOME/.local/share/nautilus-python/extensions"

if [[ -d "$REPO_ROOT/configs/nautilus-python/extensions" ]]; then
    copy_dir_contents "$REPO_ROOT/configs/nautilus-python/extensions" "$HOME/.local/share/nautilus-python/extensions"
fi

cat > "$HOME/.local/share/nautilus-python/extensions/open-with-code.py" <<'PYEXT'
import os
import subprocess
import urllib.parse
from gi.repository import GObject, Nautilus


def uri_to_path(uri):
    if uri and uri.startswith("file://"):
        return urllib.parse.unquote(uri[7:])
    return None


class OpenWithCodeExtension(GObject.GObject, Nautilus.MenuProvider):
    def _open_paths(self, menu, paths):
        clean = [p for p in paths if p and os.path.exists(p)]
        if not clean:
            return
        subprocess.Popen(["code", "--reuse-window"] + clean, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def get_file_items(self, files):
        paths = []
        for f in files:
            path = uri_to_path(f.get_uri())
            if path:
                paths.append(path)
        if not paths:
            return []
        item = Nautilus.MenuItem(name="OpenWithCode::selected", label="Open with Code", tip="Open selected item in Visual Studio Code", icon="code")
        item.connect("activate", self._open_paths, paths)
        return [item]

    def get_background_items(self, current_folder):
        path = uri_to_path(current_folder.get_uri())
        if not path:
            return []
        item = Nautilus.MenuItem(name="OpenWithCode::background", label="Open Folder with Code", tip="Open current folder in Visual Studio Code", icon="code")
        item.connect("activate", self._open_paths, [path])
        return [item]
PYEXT

chmod 644 "$HOME/.local/share/nautilus-python/extensions/open-with-code.py"
nautilus -q >/dev/null 2>&1 || true
