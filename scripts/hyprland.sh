#!/usr/bin/env bash
# hyprland.sh — Hyprland-specific helpers for HyprCaffeine
# Provides monitor control and lid-close inhibition functions.

# ── Monitor DPMS Control ────────────────────────────────────────────────────

# Force monitor on (prevent DPMS timeout)
# Uses 'hyprctl dispatch dpms on' to keep the screen awake
hypr_monitor_on() {
    if ! command -v hyprctl &>/dev/null; then
        echo "Warning: hyprctl not found — monitor control unavailable." >&2
        return 1
    fi

    hyprctl dispatch dpms on 2>/dev/null || {
        echo "Warning: Could not force monitor on via hyprctl." >&2
        return 1
    }
    return 0
}

# Restore monitor to normal DPMS behavior
hypr_monitor_off() {
    if ! command -v hyprctl &>/dev/null; then
        return 0
    fi

    # No explicit "dpms auto" — Hyprland resumes normal DPMS when idle inhibitor is off
    hyprctl dispatch dpms on 2>/dev/null || true
    return 0
}

# ── Hyprland Idle Inhibit ───────────────────────────────────────────────────

# Activate Hyprland idle inhibitor
hypr_idle_inhibit_on() {
    if ! command -v hyprctl &>/dev/null; then
        echo "Warning: hyprctl not found — idle inhibition unavailable." >&2
        return 1
    fi

    hyprctl dispatch idleinhibit on 2>/dev/null || {
        echo "Warning: Could not activate idle inhibitor via hyprctl." >&2
        return 1
    }
    return 0
}

# Deactivate Hyprland idle inhibitor
hypr_idle_inhibit_off() {
    if ! command -v hyprctl &>/dev/null; then
        return 0
    fi

    hyprctl dispatch idleinhibit off 2>/dev/null || true
    return 0
}

# ── Lid Close Inhibition ────────────────────────────────────────────────────

# PID file for the lid inhibitor background process
_LID_PID_FILE="${HOME}/.cache/hyprcaffeine/lid_inhibit.pid"

# Start lid-close inhibitor via systemd-inhibit
# Runs 'sleep infinity' in the background, blocked by systemd-inhibit
lid_inhibit_start() {
    # Stop any existing lid inhibitor first
    lid_inhibit_stop

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — lid inhibition unavailable." >&2
        return 1
    fi

    # Start the inhibitor in background
    systemd-inhibit \
        --what=handle-lid-switch \
        --who=HyprCaffeine \
        --why="User requested" \
        --mode=block \
        sleep infinity &

    local lid_pid=$!
    echo "${lid_pid}" > "${_LID_PID_FILE}"
    disown "${lid_pid}" 2>/dev/null || true

    return 0
}

# Stop lid-close inhibitor (kill the background process)
lid_inhibit_stop() {
    if [[ -f "${_LID_PID_FILE}" ]]; then
        local pid
        pid="$(cat "${_LID_PID_FILE}" 2>/dev/null || echo "")"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            # Kill the systemd-inhibit process; the sleep child dies with it
            kill "${pid}" 2>/dev/null || true
            # Also kill any remaining sleep infinity children
            local pgid
            pgid="$(ps -o pgid= -p "${pid}" 2>/dev/null | tr -d ' ')"
            if [[ -n "${pgid}" ]]; then
                kill -- -"${pgid}" 2>/dev/null || true
            fi
        fi
        rm -f "${_LID_PID_FILE}"
    fi
}

# Check if lid inhibitor is running
lid_inhibit_is_active() {
    if [[ -f "${_LID_PID_FILE}" ]]; then
        local pid
        pid="$(cat "${_LID_PID_FILE}" 2>/dev/null || echo "")"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}
