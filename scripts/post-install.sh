#!/bin/bash
# post-install.sh — runs as the desktop user (called by pacman hook)
# Configures waybar module, CSS, and systemd service

WB_CONFIG="$HOME/.config/waybar/config.jsonc"
WB_STYLE="$HOME/.config/waybar/style.css"

# ── Waybar ──
if [ -f "$WB_CONFIG" ]; then
    # Migrate old hardcoded paths
    sed -i 's|bash [^"]*caffeine-menu\.sh|hyprcaffeine menu|g' "$WB_CONFIG" 2>/dev/null

    # Add module definition if not present
    if ! grep -q '"custom/hyprcaffeine"' "$WB_CONFIG" 2>/dev/null; then
        # Backup
        cp "$WB_CONFIG" "${WB_CONFIG}.bak.$(date +%s)"

        # Insert before last closing brace
        head -n -1 "$WB_CONFIG" > /tmp/_hc_wb_tmp
        cat >> /tmp/_hc_wb_tmp << 'MODULE'
,
  "custom/hyprcaffeine": {
    "exec": "hyprcaffeine waybar",
    "on-click": "hyprcaffeine toggle",
    "on-click-right": "hyprcaffeine menu",
    "interval": 2,
    "return-type": "json"
  }
}
MODULE
        mv /tmp/_hc_wb_tmp "$WB_CONFIG"

        # Add to modules-right
        sed -i '/"modules-right"/{n;s/\[/[\n    "custom\/hyprcaffeine",/}' "$WB_CONFIG" 2>/dev/null
        echo "  ✅ Waybar module added"
    else
        echo "  ✅ Waybar module already configured"
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
