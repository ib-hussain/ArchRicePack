import os
import subprocess
import urllib.parse
from gi.repository import GObject, Nautilus


def uri_to_path(uri):
    if not uri:
        return None
    if uri.startswith("file://"):
        return urllib.parse.unquote(uri[7:])
    return None


class OpenWithCodeExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        pass

    def _open_paths(self, menu, paths):
        clean_paths = [p for p in paths if p and os.path.exists(p)]
        if not clean_paths:
            return

        try:
            subprocess.Popen(
                ["code", "--reuse-window"] + clean_paths,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except Exception:
            pass

    def _selected_paths(self, files):
        paths = []
        for file_info in files:
            try:
                path = uri_to_path(file_info.get_uri())
                if path:
                    paths.append(path)
            except Exception:
                pass
        return paths

    def get_file_items(self, files):
        paths = self._selected_paths(files)
        if not paths:
            return []

        item = Nautilus.MenuItem(
            name="OpenWithCode::selected",
            label="Open with Code",
            tip="Open selected file or folder in Visual Studio Code",
            icon="code",
        )
        item.connect("activate", self._open_paths, paths)
        return [item]

    def get_background_items(self, current_folder):
        path = None
        try:
            path = uri_to_path(current_folder.get_uri())
        except Exception:
            pass

        if not path:
            return []

        item = Nautilus.MenuItem(
            name="OpenWithCode::background",
            label="Open Folder with Code",
            tip="Open this folder in Visual Studio Code",
            icon="code",
        )
        item.connect("activate", self._open_paths, [path])
        return [item]
