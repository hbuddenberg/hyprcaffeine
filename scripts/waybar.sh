#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Waybar Module
# Outputs JSON for a custom Waybar module showing inhibition status.
# Format: {"text":"icon text","tooltip":"details","class":"css-class"}
# =============================================================================

# Source dependencies (if not already sourced)
if declare -f state_get &>/dev/null; then
    : # already sourced
else
    # shellcheck source=state.sh
    source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
fi
if declare -f timer_remaining &>/dev/null; then
    : # already sourced
else
    # shellcheck source=timer.sh
    source "$(dirname "${BASH_SOURCE[0]}")/timer.sh"
fi

# --- Icons (Nerd Font + Unicode) ---
readonly _HC_ICON_ACTIVE="󰒲"       # Nerd Font: caffeine/active
readonly _HC_ICON_INACTIVE="☕"      # Coffee cup (inactive)
readonly _HC_ICON_INFINITE="♾"      # Infinity symbol

# --- CSS classes ---
readonly _HC_CLASS_ACTIVE="hyprcaffeine-active"
readonly _HC_CLASS_INACTIVE="hyprcaffeine-inactive"
readonly _HC_CLASS_INFINITE="hyprcaffeine-infinite"

# =============================================================================
# waybar_class — Return CSS class based on current state.
#   Output: hyprcaffeine-active | hyprcaffeine-inactive | hyprcaffeine-infinite
# =============================================================================
waybar_class() {
    local mode
    mode="$(state_get "mode")"

    case "${mode}" in
        timer)
            echo "${_HC_CLASS_ACTIVE}"
            ;;
        infinite)
            echo "${_HC_CLASS_INFINITE}"
            ;;
        *)
            echo "${_HC_CLASS_INACTIVE}"
            ;;
    esac
}

# =============================================================================
# waybar_tooltip — Generate detailed status text for tooltip.
#   Includes mode, remaining time, and profile.
# =============================================================================
waybar_tooltip() {
    local active mode remaining profile started_at
    active="$(state_get "active")"
    mode="$(state_get "mode")"
    remaining="$(timer_remaining)"
    profile="$(state_get "profile")"
    started_at="$(state_get "started_at")"

    local tooltip=""

    if [[ "${active}" != "true" ]]; then
        tooltip="HyprCaffeine: Inactive"
        echo "${tooltip}"
        return 0
    fi

    local time_text
    time_text="$(timer_display "${remaining}")"

    case "${mode}" in
        timer)
            tooltip="HyprCaffeine: Active (${time_text})"
            ;;
        infinite)
            tooltip="HyprCaffeine: Infinite Mode (∞)"
            ;;
        *)
            tooltip="HyprCaffeine: Unknown"
            ;;
    esac

    # Append profile if non-default
    if [[ -n "${profile}" && "${profile}" != "default" ]]; then
        tooltip="${tooltip} [${profile}]"
    fi

    # Append uptime
    if [[ "${started_at}" -gt 0 ]]; then
        local now elapsed
        now="$(date +%s)"
        elapsed=$(( now - started_at ))
        local elapsed_text
        elapsed_text="$(timer_display "${elapsed}")"
        tooltip="${tooltip}\nUptime: ${elapsed_text}"
    fi

    echo -e "${tooltip}"
}

# =============================================================================
# waybar_status — Output single-line JSON for Waybar custom module.
#   Called on each Waybar refresh tick.
#
#   Output format:
#     {"text":"icon text","tooltip":"details","class":"css-class"}
# =============================================================================
waybar_status() {
    local active mode remaining icon text class tooltip

    active="$(state_get "active")"
    mode="$(state_get "mode")"
    remaining="$(timer_remaining)"
    class="$(waybar_class)"
    tooltip="$(waybar_tooltip)"

    # Select icon and build display text
    case "${mode}" in
        timer)
            icon="${_HC_ICON_ACTIVE}"
            local time_text
            time_text="$(timer_display "${remaining}")"
            text="${icon} ${time_text}"
            ;;
        infinite)
            icon="${_HC_ICON_INFINITE}"
            text="${icon} ∞"
            ;;
        *)
            icon="${_HC_ICON_INACTIVE}"
            text="${icon}"
            ;;
    esac

    # Escape JSON special characters in tooltip
    tooltip="$(echo "${tooltip}" | sed 's/\\/\\\\/g; s/"/\\"/g')"

    # Output compact JSON on a single line
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
        "${text}" "${tooltip}" "${class}"
}

# =============================================================================
# waybar_style — Print example CSS for the Waybar module.
#   Uses Catppuccin Mocha colors.
# =============================================================================
waybar_style() {
    cat <<'STYLE'
/* HyprCaffeine Waybar Module — Catppuccin Mocha */
#custom-hyprcaffeine {
    padding: 0 8px;
    border-radius: 8px;
    color: #cdd6f4;          /* text */
    background: #313244;     /* surface0 */
    margin: 0 2px;
}

#custom-hyprcaffeine.hyprcaffeine-active {
    color: #89b4fa;          /* blue */
    background: #1e1e2e;     /* base */
    border-bottom: 2px solid #89b4fa;
}

#custom-hyprcaffeine.hyprcaffeine-infinite {
    color: #f9e2af;          /* yellow */
    background: #1e1e2e;     /* base */
    border-bottom: 2px solid #f9e2af;
}

#custom-hyprcaffeine.hyprcaffeine-inactive {
    color: #6c7086;          /* overlay0 */
    background: transparent;
}
STYLE
}
