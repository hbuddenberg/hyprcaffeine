<div align="center">

# HyprCaffeine

### ☕ Keep your Hyprland awake — beautifully

[![Version](https://img.shields.io/badge/version-0.4.2-blue.svg?style=flat-square)](https://github.com/hbuddenberg/hyprcaffeine/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Hyprland](https://img.shields.io/badge/for-Hyprland-00e09e.svg?style=flat-square)](https://github.com/hyprwm/Hyprland)

**HyprCaffeine** is a lightweight idle inhibition utility for [Hyprland](https://github.com/hyprwm/Hyprland).
It prevents your screen from dimming, locking, or sleeping — on your terms.

[Report a Bug](https://github.com/hbuddenberg/hyprcaffeine/issues) ·
[Request a Feature](https://github.com/hbuddenberg/hyprcaffeine/issues) ·
[Contribute](https://github.com/hbuddenberg/hyprcaffeine/pulls)

</div>

---

## ✨ Features

Each feature is **independent** — use them individually or combine them:

- ⏱️ **Timer / Infinite** — blocks suspend for a set duration or indefinitely
- 🖥️ **Keep Display On** — blocks dim, DPMS, and screen lock (persists across reboots)
- 💻 **Block Lid** — prevents lid-close suspend (persists across reboots)
- 📊 **Waybar integration** — live status with countdown, tooltip, and Catppuccin Mocha CSS classes
- 🎮 **Walker menu** — interactive launcher menu via Walker (or wofi fallback)
- ⏳ **Countdown timer** — live countdown with desktop notifications before expiry
- 🔔 **Desktop notifications** — warned before caffeine runs out
- 🔄 **systemd service** — auto-start with the watcher daemon
- 🔐 **polkit auto-configure** — lid-blocking rules installed automatically
- 🪶 **Minimal deps** — only `bash`, `jq`, `hyprctl`, and `notify-send`

---

## 📦 Installation

### AUR (Arch Linux)

> **Coming soon** — the package is not yet published on the AUR.

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
./install.sh --uninstall
```

---

## 🚀 Commands

| Command | Description |
|:---|:---|
| `hyprcaffeine` | Open interactive Walker/wofi menu |
| `hyprcaffeine on [DURATION]` | Activate sleep inhibition (suspend blocker) |
| `hyprcaffeine off` | Deactivate sleep inhibition |
| `hyprcaffeine off --all` | Deactivate **all** features (sleep + monitor + lid) |
| `hyprcaffeine status` | Show current inhibition state |
| `hyprcaffeine toggle` | Toggle sleep inhibition on/off |
| `hyprcaffeine waybar` | Output Waybar-compatible JSON status |
| `hyprcaffeine menu` | Open Walker/wofi launcher menu |
| `hyprcaffeine monitor on\|off\|toggle` | Keep Display On — blocks dim + DPMS + lock |
| `hyprcaffeine lid on\|off\|toggle` | Block lid-close suspend |
| `hyprcaffeine watcher start\|stop\|status` | Auto-activate daemon |
| `hyprcaffeine --help` | Show help message |
| `hyprcaffeine --version` | Show version |

### Duration Formats

The `on` subcommand accepts flexible duration strings:

| Format | Example | Meaning |
|:---|:---|:---|
| `Ns` | `30s` | 30 seconds |
| `Nm` | `15m` | 15 minutes |
| `Nh` | `2h` | 2 hours |
| `H:MM` | `1:30` | 1 hour 30 minutes |
| `N` (bare number) | `30` | N minutes |
| `infinite` / `inf` | `infinite` | No timeout — stays on until manually turned off |

---

## 📝 Examples

```bash
# Block suspend for 30 minutes
hyprcaffeine on 30m

# Block suspend for 1h 30min
hyprcaffeine on 1:30

# Block suspend indefinitely
hyprcaffeine on infinite

# Quick toggle
hyprcaffeine toggle

# Turn off sleep inhibition only
hyprcaffeine off

# Turn off everything
hyprcaffeine off --all

# Check status
hyprcaffeine status

# Toggle display keep-awake
hyprcaffeine monitor toggle

# Enable lid-close inhibit
hyprcaffeine lid on

# Waybar JSON output
hyprcaffeine waybar
# {"text":"󰒲","tooltip":"Caffeine: 28m 45s remaining","class":"active"}
```

---

## 📊 Waybar Integration

### 1. Add the Module

Edit your Waybar config (`~/.config/waybar/config.jsonc`):

```jsonc
"custom/hyprcaffeine": {
    "exec": "hyprcaffeine waybar",
    "on-click": "hyprcaffeine menu",
    "on-click-right": "hyprcaffeine toggle",
    "interval": 1,
    "return-type": "json"
}
```

### 2. Add to Modules List

```jsonc
"modules-right": [
    "custom/hyprcaffeine",
    "pulseaudio",
    "network",
    "clock"
]
```

### 3. Style with CSS

The module outputs CSS classes depending on state:

| CSS Class | State |
|:---|:---|
| `hyprcaffeine-active` | Timer-based inhibition running |
| `hyprcaffeine-infinite` | Infinite mode active |
| `hyprcaffeine-inactive` | Caffeine is off |

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

---

## ⚙️ Configuration

Config file: `~/.config/hyprcaffeine/config.yaml`

```yaml
theme:
  accent: "#89b4fa"
  border: rounded

timeouts:
  default: 1800          # 30 minutes (seconds)

notifications:
  enabled: true
```

> Config is re-read on each invocation — no daemon restart needed.

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
