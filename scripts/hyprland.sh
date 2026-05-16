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

hypr_idle_inhibit_on() {
    hypr_idle_inhibit_off

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — sleep inhibition unavailable." >&2
        return 1
    fi

    systemd-inhibit \
        --what=sleep \
        --who=HyprCaffeine \
        --why="Caffeine mode active" \
        --mode=block \
        sleep infinity 2>/dev/null &

    local pid=$!
    disown "${pid}" 2>/dev/null || true

    # Verify process survived (give it a moment to start)
    sleep 0.3
    if ! kill -0 "${pid}" 2>/dev/null; then
        echo "Error: Sleep inhibitor process died immediately." >&2
        rm -f "${_IDLE_PID_FILE}"
        return 1
    fi

    echo "${pid}" > "${_IDLE_PID_FILE}"
    return 0
}

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

hypr_monitor_on() {
    hypr_monitor_off

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — monitor inhibition unavailable." >&2
        return 1
    fi

    systemd-inhibit \
        --what=idle \
        --who=HyprCaffeine \
        --why="Keep Display On" \
        --mode=block \
        sleep infinity 2>/dev/null &

    local pid=$!
    disown "${pid}" 2>/dev/null || true

    # Verify process survived
    sleep 0.3
    if ! kill -0 "${pid}" 2>/dev/null; then
        echo "Error: Monitor inhibitor process died immediately." >&2
        rm -f "${_MONITOR_PID_FILE}"
        return 1
    fi

    echo "${pid}" > "${_MONITOR_PID_FILE}"
    return 0
}

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
        --why="Block lid switch" \
        --mode=block \
        sleep infinity 2>/dev/null &

    local lid_pid=$!
    disown "${lid_pid}" 2>/dev/null || true

    # Verify process survived (lid needs polkit — may fail with Access denied)
    sleep 0.3
    if ! kill -0 "${lid_pid}" 2>/dev/null; then
        echo "Error: Lid inhibitor process died — check polkit rules." >&2
        echo "Hint: Create /etc/polkit-1/rules.d/50-hyprcaffeine-lid.rules" >&2
        rm -f "${_LID_PID_FILE}"
        return 1
    fi

    echo "${lid_pid}" > "${_LID_PID_FILE}"
    return 0
}

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
