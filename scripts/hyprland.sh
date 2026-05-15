#!/usr/bin/env bash
# hyprland.sh — Hyprland-specific helpers for HyprCaffeine
# Compatible with Hyprland 0.54.x+
# Uses systemd-inhibit for idle inhibition (hypridle listens to D-Bus inhibitors)

# ── PID Files ─────────────────────────────────────────────────────────────────
_IDLE_PID_FILE="${HOME}/.cache/hyprcaffeine/idle_inhibit.pid"
_LID_PID_FILE="${HOME}/.cache/hyprcaffeine/lid_inhibit.pid"

# ── Hyprland Idle Inhibit ─────────────────────────────────────────────────────
# Hyprland 0.54.x removed `hyprctl dispatch idleinhibit`.
# The correct approach: systemd-inhibit --what=idle blocks hypridle from triggering.
# hypridle respects org.freedesktop.ScreenSaver and systemd idle inhibitors.

hypr_idle_inhibit_on() {
    # Stop any existing inhibitor first
    hypr_idle_inhibit_off

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — idle inhibition unavailable." >&2
        return 1
    fi

    # Start idle inhibitor in background — blocks hypridle from suspending
    systemd-inhibit \
        --what=idle \
        --who=HyprCaffeine \
        --why="Caffeine mode active" \
        --mode=block \
        sleep infinity &

    local pid=$!
    echo "${pid}" > "${_IDLE_PID_FILE}"
    disown "${pid}" 2>/dev/null || true

    return 0
}

# Kill all HyprCaffeine idle inhibitors (avoid zombie accumulation)
# Uses ps+grep instead of pkill for broader compatibility
_kill_all_idle_inhibitors() {
    local pids
    pids="$(ps -eo pid,args 2>/dev/null | grep "systemd-inhibit" | grep "HyprCaffeine" | grep "what=idle" | grep -v grep | awk '{print $1}')"
    for pid in ${pids}; do
        kill "${pid}" 2>/dev/null || true
    done
}

hypr_idle_inhibit_off() {
    _kill_all_idle_inhibitors
    rm -f "${_IDLE_PID_FILE}"
}

# Check if idle inhibitor is running
hypr_idle_is_active() {
    if [[ -f "${_IDLE_PID_FILE}" ]]; then
        local pid
        pid="$(cat "${_IDLE_PID_FILE}" 2>/dev/null || echo "")"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# ── Monitor DPMS Control ──────────────────────────────────────────────────────

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

hypr_monitor_off() {
    # DPMS resumes normal behavior when idle inhibitor is off
    return 0
}

# ── Lid Close Inhibition ──────────────────────────────────────────────────────

lid_inhibit_start() {
    lid_inhibit_stop

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — lid inhibition unavailable." >&2
        return 1
    fi

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

# Kill all HyprCaffeine lid inhibitors (avoid zombie accumulation)
_kill_all_lid_inhibitors() {
    local pids
    pids="$(ps -eo pid,args 2>/dev/null | grep "systemd-inhibit" | grep "HyprCaffeine" | grep "handle-lid-switch" | grep -v grep | awk '{print $1}')"
    for pid in ${pids}; do
        kill "${pid}" 2>/dev/null || true
    done
}

lid_inhibit_stop() {
    _kill_all_lid_inhibitors
    rm -f "${_LID_PID_FILE}"
}

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
