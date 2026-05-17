#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Waybar Remove
# Removes all waybar integration: definition, modules-right entry, CSS
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

# Remove from modules-right array
if grep -q '"custom/hyprcaffeine",' "$WB_CONFIG" 2>/dev/null; then
    # Only remove from the modules-right block, not definitions
    sed -i '/"modules-right"/,/]/{/"custom\/hyprcaffeine",/d}' "$WB_CONFIG" 2>/dev/null
    _log "✅ Removed from modules-right"
    _changed=true
fi

# Remove module definition block
if grep -q '"custom/hyprcaffeine"' "$WB_CONFIG" 2>/dev/null; then
    sed -i '/"custom\/hyprcaffeine"/,/}/d' "$WB_CONFIG" 2>/dev/null
    _log "✅ Removed module definition"
    _changed=true
fi

# Remove CSS
if [[ -f "$WB_STYLE" ]] && grep -q 'custom-hyprcaffeine' "$WB_STYLE" 2>/dev/null; then
    sed -i '/#custom-hyprcaffeine/,/}/d' "$WB_STYLE" 2>/dev/null
    sed -i '/HyprCaffeine Waybar/d' "$WB_STYLE" 2>/dev/null
    _log "✅ Removed CSS"
    _changed=true
fi

if [[ "$_changed" == false ]]; then
    _log "ℹ️  No hyprcaffeine integration found in waybar"
fi

# Restart waybar if running
if [[ "$_changed" == true ]] && pgrep -x waybar &>/dev/null; then
    _log "🔄 Restarting waybar..."
    pkill -x waybar 2>/dev/null || true
    sleep 0.5
    if command -v hyprctl &>/dev/null; then
        hyprctl dispatch exec waybar 2>/dev/null || true
    fi
fi
