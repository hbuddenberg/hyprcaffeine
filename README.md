<div align="center">

```
   ╦ ╦╔═╗╦ ╦╔╦╗╦═╗╔═╗ ╔╦╗╔═╗╦ ╦╔╗╔╦╔═╗╦╔═╗╔═╗
   ║║║║ ║╚╦╝║║║╠╦╝║╣   ║ ║ ║║ ║║║║║║ ╦║║╣ ╚═╗
   ╚╩╝╚═╝ ╩ ╩ ╩╩╚═╚═╝  ╩ ╚═╝╚═╝╝╚╝╩╚═╝╩╚═╝╚═╝
```

### ☕ Keep your Hyprland awake — beautifully

[![License: MIT](https://img.shields.io/badge/License-MIT-mauve.svg)](LICENSE)
[![Hyprland](https://img.shields.io/badge/For-Hyprland-blue.svg)](https://github.com/hyprwm/Hyprland)

**HyprCaffeine** is a modern idle inhibition utility for [Hyprland](https://github.com/hyprwm/Hyprland).
It prevents your screen from dimming, locking, or sleeping — on your terms.

</div>

---

## ✨ Features

- **Toggle inhibition** with a single command or click
- **Preset timeouts** — 15 min, 30 min, 1 hour, 2 hours, or infinite
- **Waybar integration** — live status icon with click controls
- **Process-aware automation** — stay awake when Steam, Discord, or custom apps are running
- **Fullscreen detection** — auto-inhibit during fullscreen apps and games
- **Audio detection** — stay awake while media is playing
- **Notifications** — get warned before your caffeine runs out
- **Catppuccin-themed** — because your tools should match your desktop
- **Gum-powered menus** — beautiful interactive terminal UI

---

## 📸 Screenshots

> *Coming soon — placeholders for now*

| Waybar Module | TUI Menu |
|:---:|:---:|
| *Waybar showing active inhibition* | *Gum-based preset selector* |

---

## 📦 Installation

### AUR (Arch Linux)

```bash
paru -S hyprcaffeine
# or
yay -S hyprcaffeine
```

### Manual Install

```bash
git clone https://github.com/hyprcaffeine/hyprcaffeine.git
cd hyprcaffeine
chmod +x install.sh
./install.sh
```

### Uninstall

```bash
./install.sh --uninstall
```

> 📖 See [docs/INSTALL.md](docs/INSTALL.md) for detailed instructions.

---

## 🚀 Usage

### Basic Commands

```bash
# Toggle caffeine on/off
hyprcaffeine toggle

# Activate with a specific duration
hyprcaffeine on 3600      # 1 hour
hyprcaffeine on infinite   # forever

# Turn off
hyprcaffeine off

# Check current status
hyprcaffeine status

# Open interactive menu (requires gum)
hyprcaffeine menu
```

### Waybar Integration

Add to your Waybar `config.jsonc`:

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

See [docs/WAYBAR.md](docs/WAYBAR.md) for CSS styling examples.

---

## ⚙️ Configuration

Config file: `~/.config/hyprcaffeine/config.yaml`

```yaml
theme:
  accent: "#89b4fa"
  border: rounded
  style: catppuccin

timeouts:
  default: 1800  # 30 minutes
  presets:
    - 900   # 15 min
    - 1800  # 30 min
    - 3600  # 1 hour
    - 7200  # 2 hours

automation:
  fullscreen: false
  audio: false
  steam: false
  discord: false
  custom_processes: []

notifications:
  enabled: true
  expire_warning: 60  # warn 60s before expiry

waybar:
  icon_active: "󰒲"
  icon_inactive: "☕"
  icon_infinite: "∞"
```

> 📖 Full reference: [docs/CONFIG.md](docs/CONFIG.md)

---

## 🗺️ Roadmap

- [ ] Clipboard integration (copy status)
- [ ] D-Bus interface for other tools
- [ ] Multiple named profiles
- [ ] Per-application timeout rules
- [ ] Animated Waybar module with countdown
- [ ] Hyprland plugin (hyprlang bindings)
- [ ] Nix flake support

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**󰒲 Made with ☕ for the Hyprland community**

[Report a Bug](https://github.com/hyprcaffeine/hyprcaffeine/issues) ·
[Request a Feature](https://github.com/hyprcaffeine/hyprcaffeine/issues) ·
[Contribute](https://github.com/hyprcaffeine/hyprcaffeine/pulls)

</div>
