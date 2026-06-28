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

# 1. Remove from modules-right array (scoped to that block)
if sed -n '/"modules-right"/,/]/p' "$WB_CONFIG" 2>/dev/null | grep -q '"custom/hyprcaffeine"'; then
    sed -i '/"modules-right"/,/]/{/"custom\/hyprcaffeine",/d}' "$WB_CONFIG" 2>/dev/null
    _log "✅ Removed from modules-right"
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

# Reload waybar if changed and running
if [[ "$_changed" == true ]] && pgrep -x waybar &>/dev/null; then
    _log "🔄 Reloading waybar..."
    pkill -SIGUSR2 -x waybar 2>/dev/null || true
fi
