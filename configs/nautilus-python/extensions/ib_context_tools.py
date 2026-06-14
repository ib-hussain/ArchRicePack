from gi.repository import Nautilus, GObject
import os
import shutil
import subprocess


class IBContextTools(GObject.GObject, Nautilus.MenuProvider):
    def _path_from_file(self, file_obj):
        try:
            location = file_obj.get_location()
            if location is None:
                return os.path.expanduser("~")
            path = location.get_path()
            if path is None:
                return os.path.expanduser("~")
            return path
        except Exception:
            return os.path.expanduser("~")

    def _directory_for_selection(self, files):
        if not files:
            return os.path.expanduser("~")

        path = self._path_from_file(files[0])

        if os.path.isdir(path):
            return path

        return os.path.dirname(path)

    def _open_terminal(self, menu, path):
        terminal = shutil.which("gnome-terminal")

        if terminal:
            subprocess.Popen([terminal, "--working-directory", path])
        else:
            subprocess.Popen(["sh", "-lc", "x-terminal-emulator"], cwd=path)

    def _open_code(self, menu, path):
        code = shutil.which("code") or shutil.which("codium")

        if code:
            subprocess.Popen([code, path])
        else:
            subprocess.Popen(["notify-send", "Open in Code", "VS Code/Codium command was not found."])

    def _new_text_file(self, menu, path):
        base = "New Text File"
        candidate = os.path.join(path, base + ".txt")
        i = 1

        while os.path.exists(candidate):
            candidate = os.path.join(path, f"{base} {i}.txt")
            i += 1

        open(candidate, "w").close()

    def _items_for_path(self, path):
        terminal_item = Nautilus.MenuItem(
            name="IBContextTools::OpenInTerminal",
            label="Open in Terminal",
            tip="Open GNOME Terminal in this folder",
            icon="utilities-terminal"
        )
        terminal_item.connect("activate", self._open_terminal, path)

        code_item = Nautilus.MenuItem(
            name="IBContextTools::OpenInCode",
            label="Open with Code",
            tip="Open selected file or folder in Visual Studio Code",
            icon="code"
        )
        code_item.connect("activate", self._open_code, path)

        new_file_item = Nautilus.MenuItem(
            name="IBContextTools::NewTextFile",
            label="New File",
            tip="Create a new empty text file",
            icon="text-x-generic"
        )
        new_file_item.connect("activate", self._new_text_file, path)

        return [new_file_item, terminal_item, code_item]

    def get_background_items(self, current_folder):
        path = self._path_from_file(current_folder)
        return self._items_for_path(path)

    def get_file_items(self, files):
        path = self._directory_for_selection(files)
        return self._items_for_path(path)
