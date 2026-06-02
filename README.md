<h1 align="center">ArchRicePack</h1>

<p align="center">
  <strong>A reproducible Arch Linux GNOME rice pack with MacTahoe styling, Dash-to-Dock, Fastfetch, VS Code sync, Google Chrome, and optional local AI tooling.</strong>
</p>

<p align="center">
  <em>Designed for the user's Arch install workflow: run the system-level stage from <code>arch-chroot</code>, then let the user-session stage finish automatically after first GNOME login.</em>
</p>

---

## Table of Contents

- [Overview](#overview)
- [Current Status](#current-status)
- [Installation Modes](#installation-modes)
- [Recommended Full Install Flow](#recommended-full-install-flow)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Script Map](#script-map)
- [Assets](#assets)
- [VS Code Sync](#vs-code-sync)
- [Local AI: Ollama + Open WebUI](#local-ai-ollama--open-webui)
- [Keybindings](#keybindings)
- [Chroot Workflow Details](#chroot-workflow-details)
- [Manual Post-Login Install](#manual-post-login-install)
- [Updating the Pack](#updating-the-pack)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)
- [Notes](#notes)

---

## Overview

**ArchRicePack** is a portable post-install rice pack for Arch Linux systems using GNOME Shell. It is built to reproduce a polished macOS/Tahoe-inspired desktop on top of a clean Arch base installation.

It handles:

- GNOME Shell theming
- Dash-to-Dock behaviour
- Hide Top Bar behaviour
- terminal and Fastfetch setup
- package installation
- AUR package installation
- Google Chrome
- Visual Studio Code
- VS Code settings/extensions sync
- Nautilus “Open with Code”
- GRUB and GDM assets
- dynamic wallpaper rotation
- power mode integration
- optional Ollama + Open WebUI local AI setup
- final custom Arch Show Applications icon patch

The pack is intentionally split into **system-level setup** and **GNOME user-session setup**. This matters because many GNOME settings require a real user session with DBus, `gsettings`, `dconf`, GNOME Shell, and extensions available.

---

## Current Status

The live rice this repository captures has the following stable behaviour:

- MacTahoe-Dark-blue GTK and Shell theme
- right-side window controls in the order `minimize,maximize,close`
- bottom Dash-to-Dock with reveal-on-hover behaviour
- dock stays out of the way when windows overlap/fullscreen
- Hide Top Bar behaviour preserved
- Rice-Papirus icon theme
- custom Arch-style Show Applications dock icon support
- Google Chrome pinned
- VS Code pinned
- Terminal pinned
- Files pinned
- Nautilus context menu:
  - `Open with Code`
  - `Open Folder with Code`
- blue Arch Fastfetch terminal banner
- `power-profiles-daemon` power modes
- VS Code configuration sync from `assets/vscode/`
- optional Open WebUI pinned to dock when local AI setup is enabled

---

## Installation Modes

ArchRicePack supports three practical modes.

### 1. Chroot Mode

Use this from inside `arch-chroot /mnt` during your Arch installation.

```bash
bash install-rice.sh --chroot --target-user ibrahim
```

This mode performs system-safe work that can be done before the first graphical login:

- installs required pacman packages
- installs AUR helper where needed
- installs AUR packages where possible
- copies assets/configuration into the target user’s home
- sets up services
- applies GRUB/GDM assets
- creates a first-login user-session hook

It does **not** assume GNOME Shell is currently running.

### 2. User Session Mode

Use this after logging into GNOME as the regular user.

```bash
bash install-rice.sh --user-session
```

This applies user-session dependent settings:

- `gsettings`
- `dconf`
- GNOME Shell extension enablement
- Dash-to-Dock settings
- keybindings
- final dock icon patch
- Nautilus reload
- Open WebUI launcher/dock pinning where applicable

### 3. Normal Mode

Use this when already logged into GNOME and you want to run everything from a terminal.

```bash
./install-rice.sh
```

This runs the regular installer sequence and then final verification.

---

## Recommended Full Install Flow

The intended full flow is:

```text
1. Boot Arch ISO
2. Run your base partition/install script
3. arch-chroot /mnt
4. Run the correct chroot script
5. Chroot script clones ArchRicePack
6. Chroot script runs:
   bash install-rice.sh --chroot --target-user "$USER_NAME"
7. Reboot
8. Log into GNOME as the regular user
9. First-login user-session stage completes GNOME settings
10. Reboot once if icon/theme cache needs a clean reload
```

The chroot files in `assets/` are intended to call ArchRicePack like this:

```bash
su - "$USER_NAME" -c "cd ~ && rm -rf ArchRicePack && git clone https://github.com/ib-hussain/ArchRicePack"
cd "/home/${USER_NAME}/ArchRicePack"
chmod +x install-rice.sh scripts/*.sh
bash install-rice.sh --chroot --target-user "$USER_NAME"
```

---

## Features

### Desktop Environment

- GNOME Shell rice
- MacTahoe-Dark-blue GTK theme
- MacTahoe-Dark-blue Shell theme
- right-side macOS-style window buttons, ordered like Windows:
  - minimize
  - maximize/restore
  - close
- Dash-to-Dock bottom dock
- dock reveal-on-hover
- dock hides when overlapped by applications
- Hide Top Bar extension behaviour
- Rice-Papirus icon theme
- custom Arch Show Applications dock icon patch
- optional 5-second wallpaper rotation

### Applications

- Google Chrome from AUR
- Visual Studio Code from `visual-studio-code-bin`
- Nautilus
- GNOME Terminal
- GNOME System Monitor
- Extension Manager / GNOME extensions support
- optional Open WebUI web app launcher

### Terminal

- blue Arch Fastfetch banner
- `ff` and `fastfetch` routed through the custom blue Arch wrapper
- modern CLI tools:
  - `eza`
  - `bat`
  - `btop`
  - `fd`
  - `ripgrep`
  - `fzf`
  - `zoxide`
  - `jq`
  - `tree`
  - `ncdu`
  - `tldr`
  - `chafa`

### System

- `power-profiles-daemon`
- UPower
- GRUB background support
- GDM login background support
- Docker support for Open WebUI
- optional Ollama local model support

---

## Repository Structure

```text
ArchRicePack/
├── install-rice.sh
├── README.md
├── .gitattributes
├── .gitignore
├── assets/
│   ├── arch-icons/
│   │   ├── arch-logo.png
│   │   └── arch-logo.webp
│   ├── icons/
│   │   └── show-apps/
│   │       └── arch-show-apps.png
│   ├── vscode/
│   │   ├── User/
│   │   └── extensions/
│   ├── wallpapers/
│   ├── bg.png
│   ├── ib.png
│   ├── install-uefi.txt
│   ├── install-bios.txt
│   ├── chroot-uefi.txt
│   └── chroot-bios.txt
├── configs/
│   ├── autostart/
│   ├── dconf/
│   ├── fastfetch/
│   ├── gnome-shell/
│   ├── gtk-3.0/
│   ├── gtk-4.0/
│   ├── icons/
│   ├── local-bin/
│   ├── nautilus-python/
│   └── themes/
├── docs/
├── packages/
│   ├── pacman-packages.txt
│   ├── aur-packages.txt
│   ├── rice-pacman-core.txt
│   └── rice-aur-core.txt
└── scripts/
    ├── 00-common.sh
    ├── 01-install-packages.sh
    ├── 02-restore-themes-and-configs.sh
    ├── 03-setup-terminal.sh
    ├── 04-setup-extensions.sh
    ├── 05-apply-gnome-settings.sh
    ├── 06-setup-nautilus-code.sh
    ├── 07-setup-assets-grub-gdm-wallpaper.sh
    ├── 08-finalize-and-verify.sh
    ├── 09-setup-vscode.sh
    ├── 10-setup-local-ai-ollama-openwebui.sh
    ├── 11-apply-custom-showapps-icon.sh
    ├── 12-chroot-preinstall.sh
    └── 13-user-session-apply.sh
```

---

## Script Map

| Script | Purpose |
|---|---|
| `install-rice.sh` | Main entry point. Supports chroot, user-session, and normal modes. |
| `scripts/00-common.sh` | Shared helpers, logging, package helpers, safety checks. |
| `scripts/01-install-packages.sh` | Installs pacman and AUR packages. |
| `scripts/02-restore-themes-and-configs.sh` | Restores themes, icons, GTK config, shell config, local scripts. |
| `scripts/03-setup-terminal.sh` | Sets up Fastfetch, terminal aliases, modern CLI tooling. |
| `scripts/04-setup-extensions.sh` | Restores and enables GNOME Shell extensions. |
| `scripts/05-apply-gnome-settings.sh` | Applies keybindings, GNOME settings, dock settings, favourite apps. |
| `scripts/06-setup-nautilus-code.sh` | Adds Nautilus “Open with Code” context menu. |
| `scripts/07-setup-assets-grub-gdm-wallpaper.sh` | Applies GRUB background, GDM background, wallpaper rotation. |
| `scripts/08-finalize-and-verify.sh` | Reloads extensions and prints a verification report. |
| `scripts/09-setup-vscode.sh` | Installs VS Code from AUR and restores VS Code settings/extensions. |
| `scripts/10-setup-local-ai-ollama-openwebui.sh` | Optional Ollama + Gemma 3 1B + Open WebUI setup. |
| `scripts/11-apply-custom-showapps-icon.sh` | Final custom dock Show Applications icon patch. |
| `scripts/12-chroot-preinstall.sh` | Chroot-safe system setup and first-login hook creation. |
| `scripts/13-user-session-apply.sh` | First-login GNOME user-session stage. |

---

## Assets

### GRUB Background

Put your GRUB background here:

```text
assets/bg.png
```

Installer destination:

```text
/boot/grub/bg.png
```

The installer also updates `/etc/default/grub` and regenerates:

```text
/boot/grub/grub.cfg
```

### Login Screen / GDM Background

Put your login image here:

```text
assets/ib.png
```

Installer destination:

```text
/usr/share/backgrounds/rice/ib.png
```

### Wallpaper Rotation

Put wallpaper files here:

```text
assets/wallpapers/
```

Supported extensions:

```text
.png
.jpg
.jpeg
.webp
```

If the directory contains images, the installer enables a user-level wallpaper rotator with 5-second intervals.

### Dock Show Applications Icon

The final dock icon patch uses the first available file from this list:

```text
assets/icons/show-apps/arch-show-apps.png
assets/icons/show-apps/arch-show-apps.webp
assets/icons/show-apps/arch-show-apps.svg
assets/arch-icons/arch-logo.png
assets/arch-icons/arch-logo.webp
assets/arch-icons/arch-logo.svg
```

Best recommended file:

```text
assets/icons/show-apps/arch-show-apps.png
```

Recommended format:

- transparent PNG
- 512×512 or larger
- square canvas
- visible against dark/translucent dock background

The final icon patch must run **after** theme/icon setup because earlier icon operations can overwrite the Show Applications icon.

---

## VS Code Sync

VS Code is installed from:

```text
visual-studio-code-bin
```

VS Code settings are restored from:

```text
assets/vscode/User/
```

to:

```text
~/.config/Code/User/
```

VS Code extensions are restored from:

```text
assets/vscode/extensions/
```

to:

```text
~/.vscode/extensions/
```

The installer replaces those destination directories if the repo assets exist.

---

## Local AI: Ollama + Open WebUI

ArchRicePack includes optional local AI setup.

The script is:

```text
scripts/10-setup-local-ai-ollama-openwebui.sh
```

It installs/configures:

- `ollama`
- `ollama-cuda` when NVIDIA is detected
- Docker
- Open WebUI container
- `gemma3:1b`
- Open WebUI desktop launcher
- Open WebUI dock pin

Open WebUI URL:

```text
http://localhost:3000
```

Skip local AI during install:

```bash
SKIP_LOCAL_AI=1 ./install-rice.sh
```

or in chroot mode:

```bash
SKIP_LOCAL_AI=1 bash install-rice.sh --chroot --target-user ibrahim
```

This is useful on low-storage VMs, slow internet, or systems where Docker/model downloads should be postponed.

---

## Keybindings

| Shortcut | Action |
|---|---|
| `Super` | GNOME overview via Mutter overlay key |
| `Super+A` | Applications grid |
| `Super+S` | Overview/search |
| `Super+Tab` | Overview/search |
| `Alt+Tab` | Standard app switching |
| `Shift+Alt+Tab` | Reverse app switching |
| `Ctrl+Alt+T` | Terminal |
| `Ctrl+Shift+Esc` | GNOME System Monitor |
| `Super+Return` | Terminal |
| `Super+E` | Files / Nautilus |
| `Super+C` | VS Code |
| `Super+B` | Browser |
| `Super+D` | Show desktop |
| `Super+F` | Toggle fullscreen |
| `Super+Q` / `Alt+F4` | Close window |
| `Super+Up` | Maximize |
| `Super+Down` | Unmaximize |

---

## Chroot Workflow Details

The chroot stage should be run as root inside:

```bash
arch-chroot /mnt
```

The pack is cloned into the target user’s home:

```bash
su - "$USER_NAME" -c "cd ~ && rm -rf ArchRicePack && git clone https://github.com/ib-hussain/ArchRicePack"
```

Then the chroot stage is run:

```bash
cd "/home/${USER_NAME}/ArchRicePack"
chmod +x install-rice.sh scripts/*.sh
bash install-rice.sh --chroot --target-user "$USER_NAME"
```

The chroot stage should not try to apply live GNOME user-session settings directly. Instead, it prepares the system and creates the first-login session stage.

After reboot and first GNOME login, the user-session stage completes:

- GNOME settings
- Dash-to-Dock settings
- keybindings
- extension activation
- dock icon patch
- Nautilus refresh
- Open WebUI launcher integration

---

## Manual Post-Login Install

If Arch and GNOME are already installed, use:

```bash
cd ~
git clone https://github.com/ib-hussain/ArchRicePack
cd ArchRicePack
chmod +x install-rice.sh scripts/*.sh
./install-rice.sh | tee install-output.txt
```

Then log out:

```bash
gnome-session-quit --logout --no-prompt
```

Recommended final reboot:

```bash
sudo reboot
```

---

## Updating the Pack

Pull changes:

```bash
cd ~/ArchRicePack
git pull
chmod +x install-rice.sh scripts/*.sh
```

Run only the final user-session stage:

```bash
./install-rice.sh --user-session | tee update-output.txt
```

Run only the custom dock icon patch:

```bash
bash scripts/11-apply-custom-showapps-icon.sh
```

Run local AI setup later:

```bash
bash scripts/10-setup-local-ai-ollama-openwebui.sh
```

---

## Troubleshooting

### Installer says DBus or GNOME session variables are missing

You are trying to run a user-session stage outside GNOME.

Use chroot mode if inside `arch-chroot`:

```bash
bash install-rice.sh --chroot --target-user ibrahim
```

Use user-session mode only after logging into GNOME:

```bash
bash install-rice.sh --user-session
```

### Dock icon does not change immediately

Run:

```bash
bash scripts/11-apply-custom-showapps-icon.sh
```

Then log out and log in again.

If still stale:

```bash
sudo reboot
```

GNOME Shell and icon themes can cache symbolic icons aggressively.

### Dock does not reveal from bottom edge

Run:

```bash
bash scripts/05-apply-gnome-settings.sh
```

Then log out/in.

Important settings are:

```text
dock-fixed=false
intellihide=true
autohide=true
require-pressure-to-show=false
show-delay=0.0
```

### Super key opens Settings instead of Overview

Run:

```bash
bash scripts/05-apply-gnome-settings.sh
```

or:

```bash
bash scripts/13-user-session-apply.sh
```

Then log out/in.

The intended setting is:

```text
org.gnome.mutter overlay-key = 'Super_L'
```

### Nautilus “Open with Code” is missing

Run:

```bash
bash scripts/06-setup-nautilus-code.sh
nautilus -q
```

Then reopen Files.

### VS Code settings did not sync

Run:

```bash
bash scripts/09-setup-vscode.sh
```

Expected destinations:

```text
~/.config/Code/User/
~/.vscode/extensions/
```

### Open WebUI does not open

Check services:

```bash
systemctl status ollama
systemctl status docker
```

Check container:

```bash
sudo docker ps -a
```

Open manually:

```text
http://localhost:3000
```

If the user was just added to the Docker group, log out and back in.

### Ollama model is missing

Pull it manually:

```bash
ollama pull gemma3:1b
```

List models:

```bash
ollama list
```

### GRUB background did not apply

Check:

```bash
ls -l /boot/grub/bg.png
grep GRUB_BACKGROUND /etc/default/grub
```

Regenerate GRUB:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

---

## Development Notes

### Windows line endings

The repo includes `.gitattributes` to keep Linux scripts as LF.

If editing from Windows, after changes run:

```powershell
git add --renormalize .
```

Then ensure scripts are executable:

```powershell
git update-index --chmod=+x install-rice.sh scripts/*.sh
```

### Recommended commit pattern

```powershell
git status
git add .
git update-index --chmod=+x install-rice.sh scripts/*.sh
git commit -m "Describe change"
git push
```

### Testing strategy

Use a fresh VM and test in this order:

```text
1. UEFI install path
2. BIOS install path
3. chroot mode
4. first GNOME login autostart/user-session mode
5. manual rerun of --user-session
6. local AI setup with and without SKIP_LOCAL_AI=1
```

---

## Credits

This project is inspired by:

- r/unixporn GNOME macOS/Tahoe-style Arch rice
- MacTahoe GTK Theme by vinceliuice
- MacTahoe Icon Theme by vinceliuice
- Vapor55 Fastfetch Dotfiles
- Noto Sans
- Papirus Icon Theme
- Dash-to-Dock
- Hide Top Bar
- GNOME Shell extensions ecosystem
- Open WebUI
- Ollama

---

## Notes

This repository is specific to an Arch Linux + GNOME workflow. It is intended to be reproducible, but desktop ricing depends on GNOME Shell version, extension compatibility, icon theme caching, graphics drivers, and whether the install is running in a real GNOME session or in chroot.

For the most reliable result:

```text
Run system setup in chroot.
Reboot.
Log into GNOME.
Let the user-session stage complete.
Reboot once.
```
