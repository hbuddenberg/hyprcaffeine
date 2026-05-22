#!/usr/bin/env bash
# hyprland.sh — Hyprland-specific helpers for HyprCaffeine
# Compatible with Hyprland 0.54.x+
# Uses systemd-inhibit for idle/sleep/lid inhibition
#
# Hypridle 0.1.7 inhibition model:
#   - --what=idle      → blocks dim + DPMS + lock (hypridle listeners)
#   - --what=sleep     → blocks SUSPEND (hypridle suspend listener)
#   - --what=handle-lid-switch → blocks lid-close suspend
#
# NOTE: --what=sleep and --what=handle-lid-switch require polkit rules
#       for non-interactive use. See polkit-setup.sh.

# ── PID Files ─────────────────────────────────────────────────────────────────
_IDLE_PID_FILE="${HOME}/.cache/hyprcaffeine/idle_inhibit.pid"
_MONITOR_PID_FILE="${HOME}/.cache/hyprcaffeine/monitor_inhibit.pid"
_LID_PID_FILE="${HOME}/.cache/hyprcaffeine/lid_inhibit.pid"

# ── Generic inhibitor launcher ───────────────────────────────────────────────
# Args: what who why pid_file
# Returns: 0 on success, 1 on failure (with error message to stderr)
_start_inhibitor() {
    local what="${1}"
    local who="${2}"
    local why="${3}"
    local pid_file="${4}"

    # Kill any existing inhibitor of this type first
    _stop_inhibitor_by_what "${what}" "${pid_file}"

    if ! command -v systemd-inhibit &>/dev/null; then
        echo "Warning: systemd-inhibit not found — inhibition unavailable." >&2
        return 1
    fi

    # Capture stderr to detect "Access denied" and similar failures
    local err_file
    err_file="$(mktemp)"

    systemd-inhibit \
        --what="${what}" \
        --who="${who}" \
        --why="${why}" \
        --mode=block \
        sleep infinity 2>"${err_file}" &

    local pid=$!
    disown "${pid}" 2>/dev/null || true

    # Verify process survived (give it a moment to start)
    sleep 0.3
    if ! kill -0 "${pid}" 2>/dev/null; then
        local err_msg
        err_msg="$(cat "${err_file}" 2>/dev/null)"
        rm -f "${err_file}" "${pid_file}"

        echo "Error: Inhibitor (--what=${what}) died immediately." >&2
        if [[ "${err_msg}" == *"Access denied"* ]]; then
            echo "Reason: Polkit denied access. Install polkit rules:" >&2
            echo "  sudo bash scripts/polkit-setup.sh" >&2
        elif [[ -n "${err_msg}" ]]; then
            echo "Reason: ${err_msg}" >&2
        fi
        return 1
    fi

    rm -f "${err_file}"
    echo "${pid}" > "${pid_file}"
    return 0
}

# Kill inhibitor(s) by --what value and clean PID file
_stop_inhibitor_by_what() {
    local what="${1}"
    local pid_file="${2}"
    local pids

    # Try PID file first
    if [[ -f "${pid_file}" ]]; then
        local pid
        pid="$(cat "${pid_file}" 2>/dev/null || echo "")"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null || true
        fi
        rm -f "${pid_file}"
    fi

    # Also kill any orphaned processes matching the what flag
    pids="$(ps -eo pid,args 2>/dev/null | grep "systemd-inhibit" | grep "HyprCaffeine" | grep "what=${what}" | grep -v grep | awk '{print $1}')"
    for pid in ${pids}; do
        kill "${pid}" 2>/dev/null || true
    done
}

# ── Sleep Inhibit (Timer/Infinite) ────────────────────────────────────────────
# Blocks SUSPEND (--what=sleep). Requires polkit for non-active sessions.

hypr_idle_inhibit_on() {
    _start_inhibitor "sleep" "HyprCaffeine" "Caffeine mode active" "${_IDLE_PID_FILE}"
}

hypr_idle_inhibit_off() {
    _stop_inhibitor_by_what "sleep" "${_IDLE_PID_FILE}"
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

# ── Keep Display On (idle inhibition) ─────────────────────────────────────────
# Blocks dim + DPMS + lock (--what=idle). Works without polkit.

hypr_monitor_on() {
    _start_inhibitor "idle" "HyprCaffeine" "Keep Display On" "${_MONITOR_PID_FILE}"
}

hypr_monitor_off() {
    _stop_inhibitor_by_what "idle" "${_MONITOR_PID_FILE}"
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
# Blocks lid-close suspend (--what=handle-lid-switch). Requires polkit.

lid_inhibit_start() {
    _start_inhibitor "handle-lid-switch" "HyprCaffeine" "Block lid switch" "${_LID_PID_FILE}"
}

lid_inhibit_stop() {
    _stop_inhibitor_by_what "handle-lid-switch" "${_LID_PID_FILE}"
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
