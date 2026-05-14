<div align="center">

```
   ╦ ╦╔═╗╦ ╦╔╦╗╦═╗╔═╗ ╔╦╗╔═╗╦ ╦╔╗╔╦╔═╗╦╔═╗╔═╗
   ║║║║ ║╚╦╝║║║╠╦╝║╣   ║ ║ ║║ ║║║║║║ ╦║║╣ ╚═╗
   ╚╩╝╚═╝ ╩ ╩ ╩╩╚═╚═╝  ╩ ╚═╝╚═╝╝╚╝╩╚═╝╩╚═╝╚═╝
```

### ☕ Keep your Hyprland awake — beautifully

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg?style=flat-square)](https://github.com/hbuddenberg/hyprcaffeine/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Hyprland](https://img.shields.io/badge/for-Hyprland-00e09e.svg?style=flat-square)](https://github.com/hyprwm/Hyprland)
[![AUR](https://img.shields.io/badge/AUR-hyprcaffeine-1793D1.svg?style=flat-square&logo=archlinux&logoColor=white)](https://aur.archlinux.org/packages/hyprcaffeine)

**HyprCaffeine** is a lightweight idle inhibition utility for [Hyprland](https://github.com/hyprwm/Hyprland).
It prevents your screen from dimming, locking, or sleeping — on your terms.

[Report a Bug](https://github.com/hbuddenberg/hyprcaffeine/issues) ·
[Request a Feature](https://github.com/hbuddenberg/hyprcaffeine/issues) ·
[Contribute](https://github.com/hbuddenberg/hyprcaffeine/pulls)

</div>

---

## ✨ Features

- 🔄 **Toggle inhibition** with a single command or click
- ⏱️ **Flexible durations** — `5m`, `2h`, `infinite`, or any format you need
- 📊 **Waybar integration** — live status icon with countdown, tooltip, and CSS classes
- 🖥️ **Fullscreen detection** — auto-inhibit during fullscreen apps and games
- 🔊 **Audio detection** — stay awake while media is playing
- 🎮 **Process-aware automation** — stay awake when Steam, Discord, or custom apps run
- 🔔 **Desktop notifications** — get warned before your caffeine runs out
- 🎨 **Catppuccin-themed** — because your tools should match your desktop
- 🍬 **Gum-powered menus** — beautiful interactive terminal UI
- 🪶 **Zero dependencies** — only `bash`, `jq`, `hyprctl`, and `notify-send`

---

## 📦 Installation

### AUR (Arch Linux)

```bash
paru -S hyprcaffeine
# or
yay -S hyprcaffeine
```

Build from AUR manually:

```bash
git clone https://aur.archlinux.org/hyprcaffeine.git
cd hyprcaffeine
makepkg -si
```

### Manual Install

```bash
git clone https://github.com/hbuddenberg/hyprcaffeine.git
cd hyprcaffeine
chmod +x install.sh
./install.sh
```

The installer checks dependencies, installs the binary to `~/.local/bin/`, scripts to `~/.local/share/hyprcaffeine/`, and creates a default config at `~/.config/hyprcaffeine/config.yaml`.

> **Note:** Make sure `~/.local/bin` is in your `$PATH`:
> ```bash
> export PATH="${HOME}/.local/bin:${PATH}"
> ```

### Uninstall

```bash
# If installed via AUR
paru -Rns hyprcaffeine

# If installed manually
./install.sh --uninstall
```

📖 See [docs/INSTALL.md](docs/INSTALL.md) for detailed instructions and troubleshooting.

---

## 🚀 Commands

| Command | Description |
|:---|:---|
| `hyprcaffeine` | Open interactive gum menu with duration presets |
| `hyprcaffeine on [DURATION]` | Activate idle inhibition |
| `hyprcaffeine off` | Deactivate idle inhibition |
| `hyprcaffeine toggle` | Toggle inhibition on/off |
| `hyprcaffeine status` | Show current inhibition state |
| `hyprcaffeine waybar` | Output Waybar-compatible JSON status |
| `hyprcaffeine menu` | Open launcher menu (walker/wofi) |
| `hyprcaffeine --help` | Show help message |
| `hyprcaffeine --version` | Show version |

### Duration Formats

The `on` subcommand accepts flexible duration strings:

| Format | Example | Meaning |
|:---|:---|:---|
| `Ns` | `30s` | 30 seconds |
| `Nm` | `15m` | 15 minutes |
| `Nh` | `2h` | 2 hours |
| `N` (bare number) | `30` | N minutes |
| `infinite` / `inf` | `infinite` | No timeout — stays on until manually turned off |

---

## 📝 Examples

```bash
# Quick toggle
hyprcaffeine toggle

# Activate for 5 minutes
hyprcaffeine on 5m

# Activate for 1 hour
hyprcaffeine on 1h

# Activate indefinitely
hyprcaffeine on infinite

# Turn off
hyprcaffeine off

# Check status
hyprcaffeine status
# 󰒲 Active — remaining: 28m 45s

# Waybar JSON output
hyprcaffeine waybar
# {"text":"󰒲","tooltip":"Caffeine: 28m 45s remaining","class":"active"}
```

---

## 📊 Waybar Integration

### 1. Add the Module

Edit your Waybar config (`~/.config/waybar/config.jsonc`):

```json
"custom/hyprcaffeine": {
    "exec": "hyprcaffeine waybar",
    "on-click": "hyprcaffeine toggle",
    "on-click-right": "hyprcaffeine off",
    "on-click-middle": "hyprcaffeine menu",
    "interval": 1,
    "return-type": "json"
}
```

### 2. Add to Modules List

```json
"modules-right": [
    "custom/hyprcaffeine",
    "pulseaudio",
    "network",
    "clock"
]
```

### 3. Style with CSS

The module outputs three CSS classes depending on state:

- **`hyprcaffeine-active`** — timer-based inhibition running
- **`hyprcaffeine-infinite`** — infinite mode active
- **`hyprcaffeine-inactive`** — caffeine is off

#### Catppuccin Mocha

```css
#custom-hyprcaffeine {
    padding: 0 10px;
    margin: 0 4px;
    border-radius: 8px;
    font-size: 15px;
    color: #cdd6f4;
    background: #1e1e2e;
    transition: all 0.3s ease;
}

#custom-hyprcaffeine.hyprcaffeine-active {
    color: #89b4fa;
    background: #1e1e2e;
    box-shadow: inset 0 -2px 0 #89b4fa;
}

#custom-hyprcaffeine.hyprcaffeine-infinite {
    color: #f5c2e7;
    background: #1e1e2e;
    box-shadow: inset 0 -2px 0 #f5c2e7;
}

#custom-hyprcaffeine.hyprcaffeine-inactive {
    color: #6c7086;
    background: transparent;
}
```

#### Pill / Badge Style

```css
#custom-hyprcaffeine {
    padding: 2px 12px;
    margin: 4px 6px;
    border-radius: 16px;
    font-size: 14px;
    color: #cdd6f4;
    background: #313244;
    border: 1px solid #45475a;
}

#custom-hyprcaffeine.hyprcaffeine-active {
    color: #1e1e2e;
    background: #89b4fa;
    border-color: #89b4fa;
    font-weight: bold;
}

#custom-hyprcaffeine.hyprcaffeine-infinite {
    color: #1e1e2e;
    background: #cba6f7;
    border-color: #cba6f7;
    font-weight: bold;
}

#custom-hyprcaffeine.hyprcaffeine-inactive {
    color: #6c7086;
    background: transparent;
    border-color: #45475a;
}
```

#### Glow Effect

```css
#custom-hyprcaffeine {
    padding: 0 10px;
    font-size: 14px;
    color: #cdd6f4;
    transition: all 0.3s ease;
}

#custom-hyprcaffeine.hyprcaffeine-active {
    color: #89b4fa;
    text-shadow: 0 0 8px rgba(137, 180, 250, 0.5);
}

#custom-hyprcaffeine.hyprcaffeine-infinite {
    color: #cba6f7;
    text-shadow: 0 0 8px rgba(203, 166, 247, 0.5);
}

#custom-hyprcaffeine.hyprcaffeine-inactive {
    color: #585b70;
}
```

### Waybar JSON Output

**Inactive:**
```json
{"text": "☕", "tooltip": "Caffeine: Off", "class": "hyprcaffeine-inactive"}
```

**Active (with timer):**
```json
{"text": "󰒲 29:45", "tooltip": "Caffeine: 29m 45s remaining", "class": "hyprcaffeine-active"}
```

**Infinite:**
```json
{"text": "♾ ∞", "tooltip": "Caffeine: Infinite Mode (∞)", "class": "hyprcaffeine-infinite"}
```

### Click Actions

- **Left click** → `hyprcaffeine toggle` — Toggle on/off
- **Right click** → `hyprcaffeine off` — Turn off immediately
- **Middle click** → `hyprcaffeine menu` — Open interactive menu

> 📖 More styles and troubleshooting: [docs/WAYBAR.md](docs/WAYBAR.md)

---

## ⚙️ Configuration

Config file: `~/.config/hyprcaffeine/config.yaml`

```yaml
theme:
  accent: "#89b4fa"
  border: rounded
  style: catppuccin

timeouts:
  default: 1800          # 30 minutes
  presets:
    - 900                # 15 min
    - 1800               # 30 min
    - 3600               # 1 hour
    - 7200               # 2 hours

automation:
  fullscreen: false
  audio: false
  steam: false
  discord: false
  custom_processes: []

notifications:
  enabled: true
  expire_warning: 60     # warn 60s before expiry

waybar:
  icon_active: "󰒲"
  icon_inactive: "☕"
  icon_infinite: "∞"
```

> Config is re-read on each invocation — no daemon restart needed.
> 📖 Full reference: [docs/CONFIG.md](docs/CONFIG.md)

---

## 🤝 Contributing

Contributions are welcome! Whether it's a bug fix, new feature, or documentation improvement — we'd love your help.

### Quick Start

1. **Fork** the repository
2. **Clone** your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/hyprcaffeine.git
   cd hyprcaffeine
   ```
3. **Create** a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
4. **Make** your changes and commit:
   ```bash
   git commit -m "Add amazing feature"
   ```
5. **Push** and open a Pull Request:
   ```bash
   git push origin feature/amazing-feature
   ```

### Guidelines

- Keep it **Bash** — no additional runtime dependencies
- Follow the existing **code style** and naming conventions
- Test with `--dry-run` mode before submitting
- Update **documentation** if you change behavior

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**󰒲 Made with ☕ for the Hyprland community**

</div>
