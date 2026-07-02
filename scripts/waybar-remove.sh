#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Waybar Remove
# Removes all waybar integration: definition, modules-* placement, CSS
# Usage: waybar-remove.sh
# =============================================================================

set -uo pipefail

WB_CONFIG="${HOME}/.config/waybar/config.jsonc"
WB_STYLE="${HOME}/.config/waybar/style.css"

_log() { echo "  $1"; }

if [[ ! -f "$WB_CONFIG" ]]; then
    echo "  ⚠️  Waybar config not found at $WB_CONFIG" >&2
    exit 1
fi

_changed=false

# 1. Remove the placement from ANY modules-* array (sibling-safe; never the ": {" def line).
if grep -qE '"custom/hyprcaffeine"[[:space:]]*([],]|$)' "$WB_CONFIG" 2>/dev/null; then
    sed -E -i \
        -e '/^[[:space:]]*"custom\/hyprcaffeine"[[:space:]]*,?[[:space:]]*$/d' \
        -e 's/"custom\/hyprcaffeine"[[:space:]]*,[[:space:]]*//g' \
        -e 's/,[[:space:]]*"custom\/hyprcaffeine"//g' \
        -e 's/\[[[:space:]]*"custom\/hyprcaffeine"[[:space:]]*\]/[]/g' \
        "$WB_CONFIG" 2>/dev/null
    _log "✅ Removed module placement"
    _changed=true
fi

# 2. Remove module definition (python3 for reliable removal)
if grep -q '"custom/hyprcaffeine"' "$WB_CONFIG" 2>/dev/null; then
    python3 -c "
import re
with open('$WB_CONFIG', 'r') as f:
    content = f.read()
content = re.sub(r',?\s*\"custom/hyprcaffeine\"\s*:\s*\{[^}]*\}', '', content)
content = content.replace(',,', ',')
with open('$WB_CONFIG', 'w') as f:
    f.write(content)
" 2>/dev/null
    _log "✅ Removed module definition"
    _changed=true
fi

# 3. Remove CSS
if [[ -f "$WB_STYLE" ]] && grep -q 'custom-hyprcaffeine' "$WB_STYLE" 2>/dev/null; then
    sed -i '/#custom-hyprcaffeine/,/^}/d' "$WB_STYLE" 2>/dev/null
    sed -i '/HyprCaffeine Waybar/d' "$WB_STYLE" 2>/dev/null
    sed -i '/\/\* HyprCaffeine/,/^STYLE$/d' "$WB_STYLE" 2>/dev/null
    _log "✅ Removed CSS"
    _changed=true
fi

if [[ "$_changed" == false ]]; then
    _log "ℹ️  No hyprcaffeine integration found in waybar"
fi

# Restart waybar if changed and running
if [[ "$_changed" == true ]] && pgrep -x waybar &>/dev/null; then
    _log "🔄 Restarting waybar..."
    SIG="$(ls /run/user/1000/hypr/ 2>/dev/null | head -1)"
    pkill -x waybar 2>/dev/null || true
    sleep 0.5
    if [[ -n "$SIG" ]]; then
        HYPRLAND_INSTANCE_SIGNATURE="$SIG" WAYLAND_DISPLAY=wayland-1 \
            XDG_RUNTIME_DIR="/run/user/$(id -u)" hyprctl dispatch exec waybar 2>/dev/null || true
    fi
fi
