# Configuration Reference

HyprCaffeine uses YAML for configuration. The default config is installed to:

```
~/.config/hyprcaffeine/config.yaml
```

If the file doesn't exist, HyprCaffeine uses built-in defaults.

---

## Full Example

```yaml
theme:
  accent: "#89b4fa"
  border: rounded
  style: catppuccin

timeouts:
  default: 1800
  presets:
    - 900
    - 1800
    - 3600
    - 7200

automation:
  fullscreen: false
  audio: false
  steam: false
  discord: false
  custom_processes: []

notifications:
  enabled: true
  expire_warning: 60

waybar:
  icon_active: "󰒲"
  icon_inactive: "☕"
  icon_infinite: "∞"
```

---

## `theme` — Visual Settings

Controls the appearance of TUI menus and notifications.

| Key | Type | Default | Description |
|:---|:---|:---|:---|
| `accent` | string | `"#89b4fa"` | Accent color (hex) for highlights and active states |
| `border` | string | `"rounded"` | Border style for gum menus: `none`, `single`, `double`, `rounded`, `thick` (ignored by `wofi`/`rofi`) |
| `style` | string | `"catppuccin"` | Color palette preset (for future theming support) |

### Example

```yaml
theme:
  accent: "#f5c2e7"   # Pink accent
  border: double
  style: catppuccin
```

---

## `timeouts` — Duration Presets

Controls default and available timeout durations.

| Key | Type | Default | Description |
|:---|:---|:---|:---|
| `default` | integer | `1800` | Default timeout in seconds when running `hyprcaffeine on` with no argument |
| `presets` | list[int] | `[900, 1800, 3600, 7200]` | Durations shown in the interactive menu (seconds) |

### Example

```yaml
timeouts:
  default: 3600  # 1 hour default
  presets:
    - 600    # 10 min
    - 1800   # 30 min
    - 3600   # 1 hour
    - 7200   # 2 hours
    - 14400  # 4 hours
```

---

## `automation` — Process-Aware Inhibition

Automatically inhibit idle when certain conditions are met.

| Key | Type | Default | Description |
|:---|:---|:---|:---|
| `fullscreen` | boolean | `false` | Inhibit when any window is fullscreen |
| `audio` | boolean | `false` | Inhibit while audio is playing (requires PipeWire/PulseAudio) |
| `steam` | boolean | `false` | Inhibit while Steam is running |
| `discord` | boolean | `false` | Inhibit while Discord is running |
| `custom_processes` | list[string] | `[]` | Inhibit while any of these process names are running |

### Example

```yaml
automation:
  fullscreen: true
  audio: true
  steam: true
  discord: false
  custom_processes:
    - "obs"
    - "firefox"
    - "mpv"
    - "LeagueClient.exe"
```

> **Note:** Automation checks run periodically. They complement (not replace) manual toggling.

---

## `notifications` — Desktop Notifications

Controls when and how desktop notifications appear.

| Key | Type | Default | Description |
|:---|:---|:---|:---|
| `enabled` | boolean | `true` | Enable or disable all notifications |
| `expire_warning` | integer | `60` | Seconds before expiry to show a warning notification |

### Example

```yaml
notifications:
  enabled: true
  expire_warning: 120  # warn 2 minutes early
```

---

## `waybar` — Waybar Module Icons

Customize the icons shown in the Waybar custom module.

| Key | Type | Default | Description |
|:---|:---|:---|:---|
| `icon_active` | string | `"󰒲"` | Icon while caffeine is active |
| `icon_inactive` | string | `"☕"` | Icon while caffeine is inactive |
| `icon_infinite` | string | `"∞"` | Icon while infinite inhibition is active |

### Example

```yaml
waybar:
  icon_active: "☕"
  icon_inactive: "💤"
  icon_infinite: "♾️"
```

> Requires a [Nerd Font](https://www.nerdfonts.com/) for the default icons to render correctly.

---

## Reloading Configuration

HyprCaffeine reads the config file on each invocation. To apply changes:

```bash
# Simply run any command — config is re-read automatically
hyprcaffeine status
```

No daemon restart is needed.

---

## Config File Priority

1. `~/.config/hyprcaffeine/config.yaml` — user config
2. Built-in defaults — if user config is missing or incomplete

HyprCaffeine does **not** install a system-wide config. Each user has their own.
