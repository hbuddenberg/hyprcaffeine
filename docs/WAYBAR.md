# Waybar Integration Guide

HyprCaffeine integrates with [Waybar](https://github.com/Alexays/Waybar) as a custom module,
showing live caffeine status with click-to-toggle controls.

---

## Setup

### 1. Add the Module

Edit your Waybar config (usually `~/.config/waybar/config.jsonc`) and add:

```json
"custom/hyprcaffeine": {
    "exec": "hyprcaffeine waybar",
    "on-click": "hyprcaffeine menu",
    "on-click-right": "hyprcaffeine toggle",
    "interval": 1,
    "return-type": "json"
}
```

> The pre-built module JSON is also available at `waybar/module.json` in the repo.

### 2. Add to Your Bar Modules

Include `"custom/hyprcaffeine"` in your modules list:

```json
"modules-right": [
    "custom/hyprcaffeine",
    "pulseaudio",
    "network",
    "clock"
]
```

### 3. Style It (Optional)

Add CSS to your `~/.config/waybar/style.css`. Examples below.

---

## Waybar Output Format

The `hyprcaffeine waybar` command outputs JSON:

**Inactive:**
```json
{"text": "☕", "tooltip": "Caffeine: inactive", "class": "inactive"}
```

**Active (with timer):**
```json
{"text": "󰒲 29:45", "tooltip": "Caffeine: 29m 45s remaining", "class": "active"}
```

**Infinite:**
```json
{"text": "∞", "tooltip": "Caffeine: infinite", "class": "infinite"}
```

---

## CSS Styling Examples

### Minimal (Default)

```css
#custom-hyprcaffeine {
    padding: 0 8px;
    color: #cdd6f4;
    font-size: 14px;
}
```

### Catppuccin Mocha

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

#custom-hyprcaffeine.active {
    color: #89b4fa;
    background: #1e1e2e;
    box-shadow: inset 0 -2px 0 #89b4fa;
}

#custom-hyprcaffeine.infinite {
    color: #f5c2e7;
    background: #1e1e2e;
    box-shadow: inset 0 -2px 0 #f5c2e7;
}

#custom-hyprcaffeine.inactive {
    color: #6c7086;
    background: transparent;
}
```

### Pill / Badge Style

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

#custom-hyprcaffeine.active {
    color: #1e1e2e;
    background: #89b4fa;
    border-color: #89b4fa;
    font-weight: bold;
}

#custom-hyprcaffeine.infinite {
    color: #1e1e2e;
    background: #cba6f7;
    border-color: #cba6f7;
    font-weight: bold;
}

#custom-hyprcaffeine.inactive {
    color: #6c7086;
    background: transparent;
    border-color: #45475a;
}
```

### Underline Accent

```css
#custom-hyprcaffeine {
    padding: 0 12px;
    color: #cdd6f4;
    font-size: 14px;
    border-bottom: 2px solid transparent;
    transition: border-color 0.2s;
}

#custom-hyprcaffeine.active {
    border-bottom-color: #a6e3a1;
}

#custom-hyprcaffeine.infinite {
    border-bottom-color: #f9e2af;
}

#custom-hyprcaffeine.inactive {
    border-bottom-color: transparent;
    color: #585b70;
}

#custom-hyprcaffeine:hover {
    border-bottom-color: #89b4fa;
}
```

### Glow Effect

```css
#custom-hyprcaffeine {
    padding: 0 10px;
    font-size: 14px;
    color: #cdd6f4;
    transition: all 0.3s ease;
}

#custom-hyprcaffeine.active {
    color: #89b4fa;
    text-shadow: 0 0 8px rgba(137, 180, 250, 0.5);
}

#custom-hyprcaffeine.infinite {
    color: #cba6f7;
    text-shadow: 0 0 8px rgba(203, 166, 247, 0.5);
}

#custom-hyprcaffeine.inactive {
    color: #585b70;
}
```

---

## Click Actions

| Button | Action | Description |
|:---|:---|:---|
| Left click | `hyprcaffeine toggle` | Toggle on/off with default timeout |
| Right click | `hyprcaffeine off` | Turn off immediately |
| Middle click | `hyprcaffeine menu` | Open the interactive gum menu |

You can customize these in your Waybar config by changing the `on-click*` values.

---

## Tooltip

The tooltip shows the remaining time when active, or "inactive" when off.
It updates every second (matching the `interval: 1` setting).

---

## Troubleshooting

### Module doesn't appear
- Verify `"custom/hyprcaffeine"` is in your modules list
- Check Waybar logs: `waybar 2>&1 | grep hyprcaffeine`

### Icons show as boxes
- Install a [Nerd Font](https://www.nerdfonts.com/) and set it in Waybar CSS:
  ```css
  #custom-hyprcaffeine {
      font-family: "JetBrainsMono Nerd Font";
  }
  ```

### Module doesn't update
- Ensure `interval` is set to `1`
- Check that `hyprcaffeine waybar` works in a terminal

### Clicks don't work
- Verify the `on-click` commands run correctly from a terminal
- Waybar must be able to execute `hyprcaffeine` (check `PATH`)
