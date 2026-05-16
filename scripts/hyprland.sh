#!/usr/bin/env bash
# hyprland.sh — Hyprland-specific helpers for HyprCaffeine
# Compatible with Hyprland 0.54.x+
# Uses systemd-inhibit for idle inhibition (hypridle listens to D-Bus inhibitors)
#
# v3.0 Feature Model:
#   - Timer/Infinite: --what=sleep (blocks SUSPEND only)
#   - Keep Display On: --what=idle (blocks dim + DPMS + lock)
#   - Block Lid: --what=handle-lid-switch (blocks lid-close suspend)

# ── PID Files ─────────────────────────────────────────────────────────────────
_IDLE_PID_FILE="${HOME}/.cache/hyprcaffeine/idle_inhibit.pid"
_MONITOR_PID_FILE="${HOME}/.cache/hyprcaffeine/monitor_inhibit.pid"
_LID_PID_FILE="${HOME}/.cache/hyprcaffeine/lid_inhibit.pid"

# ── Sleep Inhibit (Timer/Infinite) ────────────────────────────────────────────
# Blocks SUSPEND ONLY (--what=sleep). Does NOT block dim/dpms/lock.
# This is the primary "caffeine" mode — keeps the system awake but allows
# the display to dim/turn off normally.

hypr_idle_inhibit_on() {
    # Stop any existing inhibitor first
    hypr_idle_inhibit_off

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — sleep inhibition unavailable." >&2
        return 1
    fi

    # Start sleep inhibitor in background — blocks suspend/hibernate only
    # stderr suppressed: polkit may deny in non-interactive sessions
    systemd-inhibit \
        --what=sleep \
        --who=HyprCaffeine \
        --why="Caffeine mode active" \
        --mode=block \
        sleep infinity 2>/dev/null &

    local pid=$!
    echo "${pid}" > "${_IDLE_PID_FILE}"
    disown "${pid}" 2>/dev/null || true

    return 0
}

# Kill all HyprCaffeine sleep inhibitors (avoid zombie accumulation)
# Uses ps+grep instead of pkill for broader compatibility
_kill_all_idle_inhibitors() {
    local pids
    pids="$(ps -eo pid,args 2>/dev/null | grep "systemd-inhibit" | grep "HyprCaffeine" | grep "what=sleep" | grep -v grep | awk '{print $1}')"
    for pid in ${pids}; do
        kill "${pid}" 2>/dev/null || true
    done
}

hypr_idle_inhibit_off() {
    _kill_all_idle_inhibitors
    rm -f "${_IDLE_PID_FILE}"
}

# Check if sleep inhibitor is running
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

# ── Keep Display On (Continuous idle inhibition) ──────────────────────────────
# Uses systemd-inhibit --what=idle to continuously block dim + DPMS + lock.
# Runs as a persistent background process (same pattern as sleep inhibit).
# Persists across reboots via state file.

hypr_monitor_on() {
    # Stop any existing monitor inhibitor first
    hypr_monitor_off

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — monitor inhibition unavailable." >&2
        return 1
    fi

    # Start continuous idle inhibitor — blocks dim + DPMS + lock
    # stderr suppressed: polkit may deny in non-interactive sessions
    systemd-inhibit \
        --what=idle \
        --who=HyprCaffeine \
        --why="Keep Display On" \
        --mode=block \
        sleep infinity 2>/dev/null &

    local pid=$!
    echo "${pid}" > "${_MONITOR_PID_FILE}"
    disown "${pid}" 2>/dev/null || true

    return 0
}

# Kill all HyprCaffeine monitor (idle) inhibitors
_kill_all_monitor_inhibitors() {
    local pids
    pids="$(ps -eo pid,args 2>/dev/null | grep "systemd-inhibit" | grep "HyprCaffeine" | grep "Keep Display On" | grep -v grep | awk '{print $1}')"
    for pid in ${pids}; do
        kill "${pid}" 2>/dev/null || true
    done
}

hypr_monitor_off() {
    _kill_all_monitor_inhibitors
    rm -f "${_MONITOR_PID_FILE}"
}

# Check if monitor inhibitor is running
hypr_monitor_is_active() {
    if [[ -f "${_MONITOR_PID_FILE}" ]]; then
        local pid
        pid="$(cat "${_MONITOR_PID_FILE}" 2>/dev/null || echo "")"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
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
        sleep infinity 2>/dev/null &

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
