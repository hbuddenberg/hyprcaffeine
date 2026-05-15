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
readonly _HC_ICON_TIMER="󱎫"           # Nerd Font: timer
readonly _HC_ICON_INFINITE="󰜉"        # Nerd Font: infinite loop
readonly _HC_ICON_MONITOR="󰍹"         # Nerd Font: monitor
readonly _HC_ICON_LID="󰍺"            # Nerd Font: lid
readonly _HC_ICON_OFF="☕"            # Coffee cup (inactive)

# =============================================================================
# waybar_class — Return CSS class based on active toggles.
#   Priority combinations → unique Catppuccin Mocha color per state.
# =============================================================================
waybar_class() {
    local status monitor lid timer_on infinite_on

    status="$(state_get_status)"
    monitor="$(state_get_monitor)"
    lid="$(state_get_lid)"

    timer_on="false"
    infinite_on="false"
    local duration
    duration="$(state_get_duration)"
    if [[ "${status}" == "active" ]]; then
        if [[ "${duration}" -eq 0 ]]; then
            infinite_on="true"
        else
            timer_on="true"
        fi
    fi

    # Build class based on combination
    # All OFF → inactive
    if [[ "${timer_on}" == "false" && "${infinite_on}" == "false" && "${monitor}" == "false" && "${lid}" == "false" ]]; then
        echo "hc-off"
        return
    fi

    # Single toggle states
    if [[ "${timer_on}" == "true" && "${monitor}" == "false" && "${lid}" == "false" ]]; then
        echo "hc-timer"           # Peach #fab387
        return
    fi
    if [[ "${infinite_on}" == "true" && "${monitor}" == "false" && "${lid}" == "false" ]]; then
        echo "hc-infinite"        # Yellow #f9e2af
        return
    fi
    if [[ "${monitor}" == "true" && "${timer_on}" == "false" && "${infinite_on}" == "false" && "${lid}" == "false" ]]; then
        echo "hc-monitor"         # Teal #94e2d5
        return
    fi
    if [[ "${lid}" == "true" && "${timer_on}" == "false" && "${infinite_on}" == "false" && "${monitor}" == "false" ]]; then
        echo "hc-lid"             # Mauve #cba6f7
        return
    fi

    # Dual combinations
    if [[ "${timer_on}" == "true" && "${monitor}" == "true" && "${lid}" == "false" ]]; then
        echo "hc-timer-monitor"   # Green #a6e3a1
        return
    fi
    if [[ "${timer_on}" == "true" && "${lid}" == "true" && "${monitor}" == "false" ]]; then
        echo "hc-timer-lid"       # Pink #f5c2e7
        return
    fi
    if [[ "${infinite_on}" == "true" && "${monitor}" == "true" && "${lid}" == "false" ]]; then
        echo "hc-infinite-monitor" # Green #a6e3a1
        return
    fi
    if [[ "${infinite_on}" == "true" && "${lid}" == "true" && "${monitor}" == "false" ]]; then
        echo "hc-infinite-lid"    # Pink #f5c2e7
        return
    fi
    if [[ "${monitor}" == "true" && "${lid}" == "true" && "${timer_on}" == "false" && "${infinite_on}" == "false" ]]; then
        echo "hc-monitor-lid"     # Blue #89b4fa
        return
    fi

    # Triple — everything on
    echo "hc-all"                 # Red #f38ba8
}

# =============================================================================
# waybar_text — Build icon + text for the waybar module.
# =============================================================================
waybar_text() {
    local status monitor lid duration
    status="$(state_get_status)"
    monitor="$(state_get_monitor)"
    lid="$(state_get_lid)"
    duration="$(state_get_duration)"

    # Inactive — just coffee icon
    if [[ "${status}" != "active" && "${monitor}" == "false" && "${lid}" == "false" ]]; then
        echo "${_HC_ICON_OFF}"
        return
    fi

    local parts=()

    # Timer or infinite
    if [[ "${status}" == "active" ]]; then
        if [[ "${duration}" -eq 0 ]]; then
            parts+=("${_HC_ICON_INFINITE}")
        else
            parts+=("${_HC_ICON_TIMER} $(timer_display "$(timer_remaining)")")
        fi
    fi

    # Monitor indicator
    if [[ "${monitor}" == "true" ]]; then
        parts+=("${_HC_ICON_MONITOR}")
    fi

    # Lid indicator
    if [[ "${lid}" == "true" ]]; then
        parts+=("${_HC_ICON_LID}")
    fi

    # Join with space
    local IFS=" "
    echo "${parts[*]}"
}

# =============================================================================
# waybar_tooltip — Generate detailed status text for tooltip.
# =============================================================================
waybar_tooltip() {
    local status monitor lid duration
    status="$(state_get_status)"
    monitor="$(state_get_monitor)"
    lid="$(state_get_lid)"
    duration="$(state_get_duration)"

    local lines=()

    if [[ "${status}" != "active" && "${monitor}" == "false" && "${lid}" == "false" ]]; then
        echo "☕ Caffeine: Inactive"
        return
    fi

    if [[ "${status}" == "active" ]]; then
        if [[ "${duration}" -eq 0 ]]; then
            lines+=("󰜉 Infinite mode")
        else
            local remaining
            remaining="$(timer_remaining)"
            lines+=("󱎫 Timer: $(timer_display "${remaining}")")
        fi
    fi

    if [[ "${monitor}" == "true" ]]; then
        lines+=("󰍹 Display: ON")
    fi

    if [[ "${lid}" == "true" ]]; then
        lines+=("󰍺 Lid: Blocked")
    fi

    # Join with newline
    local IFS=$'\n'
    echo "${lines[*]}"
}

# =============================================================================
# waybar_status — Output single-line JSON for Waybar custom module.
# =============================================================================
waybar_status() {
    local text class tooltip

    text="$(waybar_text)"
    class="$(waybar_class)"
    tooltip="$(waybar_tooltip)"

    # Escape JSON special characters
    tooltip="$(echo "${tooltip}" | sed 's/\\/\\\\/g; s/"/\\"/g')"

    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
        "${text}" "${tooltip}" "${class}"
}

# =============================================================================
# waybar_style — Print CSS for the Waybar module.
#   Catppuccin Mocha palette.
# =============================================================================
waybar_style() {
    cat <<'STYLE'
/* HyprCaffeine Waybar — Catppuccin Mocha */

/* Base module */
#custom-hyprcaffeine {
    padding: 0 10px;
    border-radius: 8px;
    color: #6c7086;              /* overlay0 — dimmed */
    background: transparent;
    margin: 0 7.5px;
    font-size: 12px;
}

/* Off / Inactive */
#custom-hyprcaffeine.hc-off {
    color: #6c7086;
    background: transparent;
}

/* Single toggles */
#custom-hyprcaffeine.hc-timer {
    color: #fab387;              /* Peach */
    background: rgba(250,179,135,0.1);
    border-bottom: 2px solid #fab387;
}

#custom-hyprcaffeine.hc-infinite {
    color: #f9e2af;              /* Yellow */
    background: rgba(249,226,175,0.1);
    border-bottom: 2px solid #f9e2af;
}

#custom-hyprcaffeine.hc-monitor {
    color: #94e2d5;              /* Teal */
    background: rgba(148,226,213,0.1);
    border-bottom: 2px solid #94e2d5;
}

#custom-hyprcaffeine.hc-lid {
    color: #cba6f7;              /* Mauve */
    background: rgba(203,166,247,0.1);
    border-bottom: 2px solid #cba6f7;
}

/* Dual combinations */
#custom-hyprcaffeine.hc-timer-monitor,
#custom-hyprcaffeine.hc-infinite-monitor {
    color: #a6e3a1;              /* Green — protected */
    background: rgba(166,227,161,0.1);
    border-bottom: 2px solid #a6e3a1;
}

#custom-hyprcaffeine.hc-timer-lid,
#custom-hyprcaffeine.hc-infinite-lid {
    color: #f5c2e7;              /* Pink */
    background: rgba(245,194,231,0.1);
    border-bottom: 2px solid #f5c2e7;
}

#custom-hyprcaffeine.hc-monitor-lid {
    color: #89b4fa;              /* Blue */
    background: rgba(137,180,250,0.1);
    border-bottom: 2px solid #89b4fa;
}

/* Everything active */
#custom-hyprcaffeine.hc-all {
    color: #f38ba8;              /* Red — max lockdown */
    background: rgba(243,139,168,0.1);
    border-bottom: 2px solid #f38ba8;
}
STYLE
}
