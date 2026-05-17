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

# Extract modules-right block from config (line range)
_get_modules_right_block() {
    sed -n '/"modules-right"/,/]/p' "$WB_CONFIG" 2>/dev/null
}

# Check if module definition exists in config
_has_definition() {
    grep -q '"custom/hyprcaffeine"' "$WB_CONFIG" 2>/dev/null
}

# Check if module is positioned in modules-right array
_in_modules_right() {
    _get_modules_right_block | grep -q '"custom/hyprcaffeine"' 2>/dev/null
}

# Check if CSS is injected in style.css
_has_css() {
    grep -q 'HyprCaffeine Waybar Module' "$WB_STYLE" 2>/dev/null
}

# ── Remove ───────────────────────────────────────────────────────────────────

_remove_all() {
    # Remove from modules-right array
    if _in_modules_right; then
        sed -i '/"custom\/hyprcaffeine",/d' "$WB_CONFIG" 2>/dev/null
        _log "✅ Removed from modules-right"
    fi

    # Remove module definition (multi-line block)
    if _has_definition; then
        # Use sed to remove the block: "custom/hyprcaffeine": { ... }
        # Works with both comma-separated and standalone blocks
        sed -i '/"custom\/hyprcaffeine"/,/}/d' "$WB_CONFIG" 2>/dev/null
        # Clean trailing comma before closing brace if needed
        sed -i 's/,\s*$//' "$WB_CONFIG" 2>/dev/null
        _log "✅ Removed module definition"
    fi

    # Remove CSS block
    if _has_css; then
        sed -i '/HyprCaffeine Waybar Module/,/STYLE/d' "$WB_STYLE" 2>/dev/null
        sed -i '/HyprCaffeine Waybar — Catppuccin/d' "$WB_STYLE" 2>/dev/null
        # Remove all hc-* class blocks
        sed -i '/#custom-hyprcaffeine/,/}/d' "$WB_STYLE" 2>/dev/null
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
    # Smart: after group/tray-expander if it exists
    if grep -q '"group/tray-expander",' "$WB_CONFIG" 2>/dev/null; then
        sed -i '/"group\/tray-expander",/a\    "custom/hyprcaffeine",' "$WB_CONFIG"
        _log "✅ Positioned after tray-expander in modules-right"
    else
        # Fallback: as first item in modules-right array
        # Find the opening bracket of modules-right and insert after it
        sed -i '/"modules-right"/{n;s/\[/[\n    "custom\/hyprcaffeine",/}' "$WB_CONFIG" 2>/dev/null
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

    # ── Restart waybar if running ──
    if pgrep -x waybar &>/dev/null; then
        _log "🔄 Restarting waybar..."
        pkill -x waybar 2>/dev/null || true
        sleep 0.5
        if command -v hyprctl &>/dev/null; then
            hyprctl dispatch exec waybar 2>/dev/null || true
        fi
    fi
}

main
