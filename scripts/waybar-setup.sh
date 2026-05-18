#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Waybar Setup
# Smart integration: creates definition, positions in modules-right, injects CSS
# Usage: waybar-setup.sh          (smart — only adds what's missing)
#        waybar-setup.sh --force   (removes everything first, then recreates)
# =============================================================================

set -uo pipefail

WB_CONFIG="${HOME}/.config/waybar/config.jsonc"
WB_STYLE="${HOME}/.config/waybar/style.css"
SHARE_DIR="/usr/share/hyprcaffeine"

# Fallback: find share dir relative to script
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -d "${SHARE_DIR}" ]]; then
    SHARE_DIR="${SCRIPT_DIR}/.."
fi

CSS_FILE="${SHARE_DIR}/waybar-css.css"

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

# ── Helpers ──────────────────────────────────────────────────────────────────

_log() { echo "  $1"; }

# Extract modules-right block from config
_get_modules_right_block() {
    sed -n '/"modules-right"/,/]/p' "$WB_CONFIG" 2>/dev/null
}

# Check if module definition exists anywhere in config
_has_definition() {
    grep -c '"custom/hyprcaffeine"' "$WB_CONFIG" 2>/dev/null | grep -qv '^0$'
}

# Check if module is positioned in modules-right array (not in definition)
_in_modules_right() {
    _get_modules_right_block | grep -q '"custom/hyprcaffeine"' 2>/dev/null
}

# Check if CSS is injected in style.css
_has_css() {
    grep -q '#custom-hyprcaffeine' "$WB_STYLE" 2>/dev/null
}

# ── Remove ───────────────────────────────────────────────────────────────────

_remove_all() {
    # 1. Remove from modules-right array only (scoped to that block)
    if _in_modules_right; then
        sed -i '/"modules-right"/,/]/{/"custom\/hyprcaffeine",/d}' "$WB_CONFIG" 2>/dev/null
        _log "✅ Removed from modules-right"
    fi

    # 2. Remove module definition block — use python for reliable JSON-aware removal
    if _has_definition; then
        python3 -c "
import re, sys
with open('$WB_CONFIG', 'r') as f:
    content = f.read()
# Remove the block: optional leading comma, whitespace, the key, and its { ... } value
content = re.sub(r',?\s*\"custom/hyprcaffeine\"\s*:\s*\{[^}]*\}', '', content)
# Clean up any double commas left behind
content = content.replace(',,', ',')
with open('$WB_CONFIG', 'w') as f:
    f.write(content)
" 2>/dev/null
        _log "✅ Removed module definition"
    fi

    # 3. Remove CSS — match from the HyprCaffeine marker to end comment
    if _has_css; then
        # Remove everything between our markers — match whole block
        sed -i '/\/\* HyprCaffeine Waybar Module/,/\* END HyprCaffeine \*\//d' "$WB_STYLE" 2>/dev/null
        _log "✅ Removed CSS"
    fi
}

# ── Add Definition ───────────────────────────────────────────────────────────

_add_definition() {
    # Backup
    cp "$WB_CONFIG" "${WB_CONFIG}.bak.$(date +%s)"

    # Insert before last closing brace
    local tmp="/tmp/_hc_wb_$$"
    head -n -1 "$WB_CONFIG" > "$tmp"
    cat >> "$tmp" << 'MODULEDEF'
,
  "custom/hyprcaffeine": {
    "exec": "hyprcaffeine waybar",
    "on-click": "hyprcaffeine menu",
    "on-click-right": "hyprcaffeine toggle",
    "interval": 2,
    "return-type": "json"
  }
}
MODULEDEF
    mv "$tmp" "$WB_CONFIG"
    _log "✅ Waybar module definition added"
}

# ── Position in modules-right ────────────────────────────────────────────────

_position_module() {
    # Smart: after group/tray-expander if it exists in modules-right
    if grep -q '"group/tray-expander",' "$WB_CONFIG" 2>/dev/null; then
        sed -i '/"group\/tray-expander",/a\    "custom/hyprcaffeine",' "$WB_CONFIG"
        _log "✅ Positioned after tray-expander in modules-right"
    else
        # Fallback: as first item in modules-right array
        # Use python for reliable insertion
        python3 -c "
with open('$WB_CONFIG', 'r') as f:
    content = f.read()
content = content.replace(
    '\"modules-right\": [',
    '\"modules-right\": [\\n    \"custom/hyprcaffeine\",',
    1
)
with open('$WB_CONFIG', 'w') as f:
    f.write(content)
" 2>/dev/null
        _log "✅ Positioned as first item in modules-right"
    fi
}

# ── Add CSS ──────────────────────────────────────────────────────────────────

_add_css() {
    if [[ -f "$CSS_FILE" ]]; then
        {
            echo ""
            cat "$CSS_FILE"
        } >> "$WB_STYLE"
        _log "✅ Waybar CSS injected"
    else
        _log "⚠️  CSS file not found at $CSS_FILE"
    fi
}

# ── Restart waybar ───────────────────────────────────────────────────────────

_restart_waybar() {
    if pgrep -x waybar &>/dev/null; then
        _log "🔄 Restarting waybar..."
        # Get Hyprland instance signature dynamically
        local SIG
        SIG="$(ls /run/user/1000/hypr/ 2>/dev/null | head -1)"
        pkill -x waybar 2>/dev/null || true
        sleep 0.5
        if [[ -n "$SIG" ]]; then
            HYPRLAND_INSTANCE_SIGNATURE="$SIG" WAYLAND_DISPLAY=wayland-1 \
                XDG_RUNTIME_DIR="/run/user/$(id -u)" hyprctl dispatch exec waybar 2>/dev/null || true
        fi
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    if [[ ! -f "$WB_CONFIG" ]]; then
        echo "  ⚠️  Waybar config not found at $WB_CONFIG" >&2
        exit 1
    fi

    # Force mode: remove everything first
    if [[ "$FORCE" == true ]]; then
        _log "🔄 Force mode — removing existing integration"
        _remove_all
    fi

    # ── Definition ──
    if _has_definition; then
        _log "✅ Module definition already exists"
    else
        _add_definition
    fi

    # ── Position ──
    if _in_modules_right; then
        _log "✅ Module already in modules-right"
    else
        _position_module
    fi

    # ── CSS ──
    if _has_css; then
        _log "✅ CSS already injected"
    else
        _add_css
    fi

    # ── Restart waybar ──
    _restart_waybar
}

main
