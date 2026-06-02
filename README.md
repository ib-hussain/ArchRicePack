# ArchRicePack

Portable post-install rice pack for the Arch GNOME MacTahoe-style setup.

This repository is designed to be run **after** a clean Arch installation and first GNOME login.

## What it installs/configures

- GNOME Shell rice based on MacTahoe-Dark-blue
- Dash-to-Dock bottom dock with reveal-on-hover behaviour
- Hide Top Bar behaviour
- Papirus/Rice-Papirus icons
- Google Chrome from AUR
- Visual Studio Code from `visual-studio-code-bin`
- Nautilus `Open with Code`
- Power modes through `power-profiles-daemon`
- Blue Arch Fastfetch terminal startup
- Modern terminal tools: `eza`, `bat`, `btop`, `fd`, `ripgrep`, `fzf`, `zoxide`, `jq`, `tree`, `ncdu`, `tldr`, `chafa`
- Keybindings:
  - Super: GNOME overview through Mutter overlay key
  - Super+A: applications grid
  - Super+S / Super+Tab: overview/search
  - Ctrl+Alt+T: terminal
  - Ctrl+Shift+Esc: system monitor
  - Super+E: Files
  - Super+C: VS Code
  - Super+B: browser
- Optional GRUB background from `assets/bg.png`
- Optional GDM/login background from `assets/ib.png`
- Optional 5-second wallpaper rotation from `assets/wallpapers/`

## Required files

Optional but expected:

```text
assets/bg.png  -> copied to /boot/grub/bg.png
assets/ib.png  -> copied to /usr/share/backgrounds/rice/ib.png
````

If these files are missing, the installer skips those parts safely.

## Install

Run from inside GNOME Terminal as your normal user:

```bash
cd ~/ArchRicePack
chmod +x install-rice.sh scripts/*.sh
./install-rice.sh | tee install-output.txt
```

Then log out and back in:

```bash
gnome-session-quit --logout --no-prompt
```

A reboot is recommended after the first install:

```bash
sudo reboot
```

## Transport to Windows

From the VM:

```bash
7z a -t7z -mx=9 ~/ArchRicePack.7z ~/ArchRicePack
```

Then transfer `~/ArchRicePack.7z` to Windows and push to GitHub there.

## Notes

The current live system reached a stable visual state except the Dash-to-Dock Show Applications icon. This pack includes the local Rice-Papirus icon override and a best-effort GNOME Shell extension for the Arch icon, but GNOME Shell/Dash-to-Dock can aggressively cache or override the Show Applications symbolic icon. The rest of the rice is fully captured and reproducible.
