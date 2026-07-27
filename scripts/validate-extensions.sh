#!/usr/bin/env bash
# Static validation for the standalone Rice Shell extension bundle.

set -Eeuo pipefail
IFS=$'\n\t'

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(cd -- "$TEST_DIR/.." && pwd)"
DOCK_DIR="$BUNDLE_ROOT/configs/extensions/rice-dock@ib-hussain"
TOP_BAR_DIR="$BUNDLE_ROOT/configs/extensions/rice-top-bar@ib-hussain"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rice-extensions-test.XXXXXX")"
SCHEMA_COMPILER="$(command -v glib-compile-schemas 2>/dev/null || true)"

if [[ -z "$SCHEMA_COMPILER" &&
    -x /usr/lib/x86_64-linux-gnu/glib-2.0/glib-compile-schemas ]]
then
    SCHEMA_COMPILER=/usr/lib/x86_64-linux-gnu/glib-2.0/glib-compile-schemas
fi

cleanup() {
    [[ "$TEMP_DIR" == "${TMPDIR:-/tmp}"/rice-extensions-test.* ]] || return 0
    rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

bash -n "$BUNDLE_ROOT/scripts/install-rice-shell-extensions.sh"

python3 - "$BUNDLE_ROOT" <<'PY'
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
extensions = {
    "rice-dock@ib-hussain": root / "configs/extensions/rice-dock@ib-hussain",
    "rice-top-bar@ib-hussain": root / "configs/extensions/rice-top-bar@ib-hussain",
}
relative_import = re.compile(r"""(?:from\s+|import\s*)['"](\.[^'"]+)['"]""")

for uuid, directory in extensions.items():
    metadata = json.loads((directory / "metadata.json").read_text())
    if metadata.get("uuid") != uuid:
        raise SystemExit(f"{uuid}: metadata UUID mismatch")
    if "50" not in {str(value) for value in metadata.get("shell-version", [])}:
        raise SystemExit(f"{uuid}: GNOME Shell 50 is not declared")

    for source in directory.rglob("*.js"):
        text = source.read_text(encoding="utf-8")
        for target in relative_import.findall(text):
            if not (source.parent / target).resolve().is_file():
                raise SystemExit(f"{source}: missing import {target}")

for path in list(root.rglob("*.xml")) + list(root.rglob("*.ui")):
    ET.parse(path)
PY

[[ -n "$SCHEMA_COMPILER" ]] ||
    fail "glib-compile-schemas is required"

for extension_dir in "$DOCK_DIR" "$TOP_BAR_DIR"; do
    schema_dir="$TEMP_DIR/$(basename "$extension_dir")"
    mkdir -p -- "$schema_dir"
    find "$extension_dir/schemas" -maxdepth 1 -type f \
        ! -name gschemas.compiled \
        -exec cp -a -- {} "$schema_dir/" \;
    "$SCHEMA_COMPILER" --strict "$schema_dir"
done

mapfile -t logos < <(
    find "$DOCK_DIR/media" -maxdepth 1 -type f -name 'logo.*' -printf '%f\n'
)
[[ "${#logos[@]}" -eq 1 && "${logos[0]}" == "logo.png" ]] ||
    fail "Rice Dock must contain exactly one media/logo.png"
grep -Fq 'media/logo.png' "$DOCK_DIR/appIcons.js" ||
    fail "Rice Dock does not construct its Show Applications icon from logo.png"
if grep -Eq 'background-image:[^;]*(logo\.png|arch-logo)' \
    "$DOCK_DIR/stylesheet.css" \
    "$DOCK_DIR/_stylesheet.scss" \
    "$DOCK_DIR/appIconIndicators.js"
then
    fail "the logo is layered as a CSS background"
fi

grep -Fq 'TransparentPanelController' "$TOP_BAR_DIR/extension.js" ||
    fail "Rice Top Bar does not start its transparency controller"
grep -Fq 'background-color: rgba(0, 0, 0, 0)' \
    "$TOP_BAR_DIR/transparentPanel.js" ||
    fail "Rice Top Bar lacks the inline transparency fallback"

if command -v node >/dev/null 2>&1; then
    while IFS= read -r -d '' source; do
        node --input-type=module --check <"$source"
    done < <(find "$DOCK_DIR" "$TOP_BAR_DIR" -type f -name '*.js' -print0)
fi

printf 'PASS: Rice Shell extension bundle validates\n'
