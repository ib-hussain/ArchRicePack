# Rice Shell Extensions 1.0.0

This standalone bundle installs Ibrahim Hussain's two cross-distribution GNOME
Shell extensions on Ubuntu or Arch Linux with GNOME Shell 50:

- `rice-dock@ib-hussain`: Ubuntu Dock / Dash-to-Dock 106 with one built-in
  `media/logo.png` Show Applications icon.
- `rice-top-bar@ib-hussain`: Hide Top Bar 126 plus a deterministic, reversible
  transparent-panel controller.

The installer disables the conflicting Ubuntu Dock, upstream Dash-to-Dock,
retired Arch icon patch, and upstream Hide Top Bar UUID before enabling these
two products. It backs up existing user installations and writes reports and
logs beneath `~/.local/state/rice-shell-extensions/` and to journald.

## Validate

```bash
bash tests/validate-extensions.sh
```

## Install

Run as the logged-in GNOME user, without `sudo`:

```bash
bash scripts/install-rice-shell-extensions.sh
```

Then log out and back in once. Verify:

```bash
gnome-extensions info rice-dock@ib-hussain
gnome-extensions info rice-top-bar@ib-hussain
journalctl --user -b -o cat |
  grep -E '\[(rice-dock|rice-top-bar)@ib-hussain\]'
```

To install the code without changing extension states:

```bash
bash scripts/install-rice-shell-extensions.sh --install-only
```

To reapply only enabled/disabled state:

```bash
bash scripts/install-rice-shell-extensions.sh --state-only
```

See `ENGINEERING-AUDIT.md` and each extension's `UPSTREAM.md` for root-cause
analysis, upstream provenance, and the validation boundary.
