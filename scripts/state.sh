#!/usr/bin/env bash
# state.sh — State management for HyprCaffeine
# Part of the HyprCaffeine utility suite
#
# State model:
#   - status (active/inactive) = idle inhibition only
#   - monitor (on/off) = independent toggle
#   - lid (on/off) = independent toggle

# State file paths (sourced from main binary)
# STATE_DIR and STATE_FILE must be defined by the caller

# Ensure state directory and file exist
state_init() {
    mkdir -p "${STATE_DIR}"
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo '{"status":"inactive","duration":0,"activated_at":"","pid":"","monitor":false,"lid":false}' > "${STATE_FILE}"
    fi
}

# Save state to JSON file
# Args: status duration pid [monitor_bool] [lid_bool]
state_save() {
    local status="${1:-inactive}"
    local duration="${2:-0}"
    local pid="${3:-}"
    local monitor="${4:-false}"
    local lid="${5:-false}"

    local activated_at
    if [[ "${status}" == "active" ]]; then
        activated_at="$(date +%s)"
    else
        activated_at=""
    fi

    # If monitor/lid not provided, preserve current values
    if [[ "${monitor}" == "preserve" || -z "${monitor}" ]]; then
        monitor="$(state_get_monitor)"
    fi
    if [[ "${lid}" == "preserve" || -z "${lid}" ]]; then
        lid="$(state_get_lid)"
    fi

    cat > "${STATE_FILE}" <<STATEEOF
{"status":"${status}","duration":${duration},"activated_at":"${activated_at}","pid":"${pid}","monitor":${monitor},"lid":${lid}}
STATEEOF
}

# ── Idle State ─────────────────────────────────────────────────────────────

state_get_status() {
    state_init
    sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null || echo "inactive"
}

state_get_duration() {
    state_init
    sed -n 's/.*"duration"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "${STATE_FILE}" 2>/dev/null || echo "0"
}

state_get_remaining() {
    state_init
    local duration
    duration="$(state_get_duration)"

    if [[ "${duration}" -eq 0 ]]; then
        echo "infinite"
        return
    fi

    local activated_at
    activated_at="$(sed -n 's/.*"activated_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null)"

    if [[ -z "${activated_at}" ]] || [[ "${activated_at}" == "0" ]]; then
        echo "unknown"
        return
    fi

    local now elapsed remaining
    now="$(date +%s)"
    elapsed=$(( now - activated_at ))
    remaining=$(( duration - elapsed ))

    if [[ "${remaining}" -le 0 ]]; then
        echo "expired"
        return
    fi

    timer_human "${remaining}"
}

# ── Independent Toggles ───────────────────────────────────────────────────

state_get_monitor() {
    state_init
    sed -n 's/.*"monitor"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "${STATE_FILE}" 2>/dev/null || echo "false"
}

state_get_lid() {
    state_init
    sed -n 's/.*"lid"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "${STATE_FILE}" 2>/dev/null || echo "false"
}

# Set monitor toggle (preserves everything else)
state_set_monitor() {
    local value="${1:-true}"
    state_init
    local status duration activated_at pid lid
    status="$(state_get_status)"
    duration="$(state_get_duration)"
    activated_at="$(sed -n 's/.*"activated_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null)"
    pid="$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null)"
    lid="$(state_get_lid)"

    cat > "${STATE_FILE}" <<STATEEOF
{"status":"${status}","duration":${duration},"activated_at":"${activated_at}","pid":"${pid}","monitor":${value},"lid":${lid}}
STATEEOF
}

# Set lid toggle (preserves everything else)
state_set_lid() {
    local value="${1:-true}"
    state_init
    local status duration activated_at pid monitor
    status="$(state_get_status)"
    duration="$(state_get_duration)"
    activated_at="$(sed -n 's/.*"activated_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null)"
    pid="$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null)"
    monitor="$(state_get_monitor)"

    cat > "${STATE_FILE}" <<STATEEOF
{"status":"${status}","duration":${duration},"activated_at":"${activated_at}","pid":"${pid}","monitor":${monitor},"lid":${value}}
STATEEOF
}

# Initialize state on load
state_init
