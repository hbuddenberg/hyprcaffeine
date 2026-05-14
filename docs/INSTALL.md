# Installation Guide

## Prerequisites

HyprCaffeine requires the following dependencies:

| Dependency | Purpose | Required |
|:---|:---|:---:|
| `bash` | Shell runtime | ✅ |
| `jq` | JSON parsing (Waybar output) | ✅ |
| `hyprctl` | Hyprland IPC / idle control | ✅ |
| `notify-send` | Desktop notifications | ✅ |
| `gum` | Interactive TUI menus | Recommended |

### Installing Dependencies

**Arch Linux:**
```bash
sudo pacman -S bash jq hyprland gum libnotify
```

**With an AUR helper (gum from AUR if not in repos):**
```bash
paru -S gum
```

---

## Method 1: AUR (Arch Linux)

Using `paru`:
```bash
paru -S hyprcaffeine
```

Using `yay`:
```bash
yay -S hyprcaffeine
```

Using `makepkg` directly:
```bash
git clone https://aur.archlinux.org/hyprcaffeine.git
cd hyprcaffeine
makepkg -si
```

---

## Method 2: Manual Install

### Step 1: Clone the Repository

```bash
git clone https://github.com/hyprcaffeine/hyprcaffeine.git
cd hyprcaffeine
```

### Step 2: Run the Installer

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Check all required dependencies
2. Create `~/.config/hyprcaffeine/`
3. Install a default config (won't overwrite existing)
4. Copy the binary to `~/.local/bin/hyprcaffeine`
5. Install scripts to `~/.local/share/hyprcaffeine/`
6. Print Waybar integration instructions

### Step 3: Verify PATH

Make sure `~/.local/bin` is in your `$PATH`:

```bash
echo $PATH | grep -q "$HOME/.local/bin" && echo "OK" || echo "Add it!"
```

If not, add this to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

Then reload:
```bash
source ~/.bashrc  # or ~/.zshrc
```

### Step 4: Verify Installation

```bash
hyprcaffeine status
```

---

## Method 3: Manual File Copy

If you prefer full control:

```bash
# Binary
mkdir -p ~/.local/bin
cp bin/hyprcaffeine ~/.local/bin/
chmod +x ~/.local/bin/hyprcaffeine

# Config
mkdir -p ~/.config/hyprcaffeine
cp config/default.yaml ~/.config/hyprcaffeine/config.yaml

# Data / Scripts
mkdir -p ~/.local/share/hyprcaffeine
cp -r scripts/* ~/.local/share/hyprcaffeine/
```

---

## Uninstalling

### If installed via AUR:
```bash
paru -Rns hyprcaffeine
```

### If installed manually:
```bash
./install.sh --uninstall
```

Or manually:
```bash
rm -f ~/.local/bin/hyprcaffeine
rm -rf ~/.local/share/hyprcaffeine
# Optionally remove config:
rm -rf ~/.config/hyprcaffeine
```

---

## Troubleshooting

### `hyprcaffeine: command not found`
Ensure `~/.local/bin` is in your `PATH`. See Step 3 above.

### `hyprctl` commands fail
Make sure Hyprland is running and `hyprctl` can communicate with it:
```bash
hyprctl version
```

### Gum menus don't appear
Install `gum` or use non-interactive commands:
```bash
hyprcaffeine on 1800   # works without gum
```

### Notifications not appearing
Ensure `notify-send` is installed and a notification daemon is running:
```bash
notify-send "Test" "Hello"
```
