#!/bin/bash
# post-install.sh — runs as the desktop user (called by pacman hook)
# Configures waybar module, CSS, and systemd service

WB_CONFIG="$HOME/.config/waybar/config.jsonc"
WB_STYLE="$HOME/.config/waybar/style.css"

# ── Waybar ──
if [ -f "$WB_CONFIG" ]; then
    # Migrate old hardcoded paths
    sed -i 's|bash [^"]*caffeine-menu\.sh|hyprcaffeine menu|g' "$WB_CONFIG" 2>/dev/null

    # Check if module definition exists
    _has_def=false
    grep -q '"custom/hyprcaffeine"' "$WB_CONFIG" 2>/dev/null && _has_def=true

    # Check if module is in modules-right array
    # Extract modules-right block (up to closing bracket) and search within
    _in_array=false
    _mr_block=$(sed -n '/"modules-right"/,/]/p' "$WB_CONFIG" 2>/dev/null)
    echo "$_mr_block" | grep -q '"custom/hyprcaffeine"' 2>/dev/null && _in_array=true

    # Add module definition if not present
    if [ "$_has_def" = false ]; then
        # Backup
        cp "$WB_CONFIG" "${WB_CONFIG}.bak.$(date +%s)"

        # Insert before last closing brace
        head -n -1 "$WB_CONFIG" > /tmp/_hc_wb_tmp
        cat >> /tmp/_hc_wb_tmp << 'MODULE'
,
  "custom/hyprcaffeine": {
    "exec": "hyprcaffeine waybar",
    "on-click": "hyprcaffeine menu",
    "on-click-right": "hyprcaffeine toggle",
    "interval": 2,
    "return-type": "json"
  }
}
MODULE
        mv /tmp/_hc_wb_tmp "$WB_CONFIG"
        echo "  ✅ Waybar module definition added"
    fi

    # Add to modules-right if not already there
    if [ "$_in_array" = false ]; then
        # Smart positioning: after tray-expander if it exists
        if grep -q '"group/tray-expander",' "$WB_CONFIG" 2>/dev/null; then
            sed -i '/"group\/tray-expander",/a\    "custom/hyprcaffeine",' "$WB_CONFIG"
        else
            # Fallback: as first item after opening bracket
            sed -i '/"modules-right"/{/"/{s/\[/[\n    "custom\/hyprcaffeine",/}' "$WB_CONFIG" 2>/dev/null
        fi
        echo "  ✅ Waybar module positioned in modules-right"
    else
        echo "  ✅ Waybar module already in modules-right"
    fi

    # Add CSS
    if [ -f "$WB_STYLE" ] && ! grep -q 'HyprCaffeine Waybar Module' "$WB_STYLE" 2>/dev/null; then
        if [ -f /usr/share/hyprcaffeine/waybar-css.css ]; then
            cat /usr/share/hyprcaffeine/waybar-css.css >> "$WB_STYLE"
            echo "  ✅ Waybar CSS added"
        fi
    fi
fi

# ── Systemd ──
if [ -f /usr/share/hyprcaffeine/systemd/hyprcaffeine.service ]; then
    mkdir -p "$HOME/.config/systemd/user"
    cp /usr/share/hyprcaffeine/systemd/hyprcaffeine.service "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable hyprcaffeine.service 2>/dev/null && \
        echo "  ✅ Systemd service enabled" || true
fi
