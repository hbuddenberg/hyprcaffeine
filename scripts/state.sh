#!/usr/bin/env bash
# state.sh — State management for HyprCaffeine
# Part of the HyprCaffeine utility suite

# State file paths (sourced from main binary)
# STATE_DIR and STATE_FILE must be defined by the caller

# Ensure state directory and file exist
state_init() {
    mkdir -p "${STATE_DIR}"
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo '{"status":"inactive","duration":0,"activated_at":"","pid":""}' > "${STATE_FILE}"
    fi
}

# Save state to JSON file
state_save() {
    local status="${1:-inactive}"     # active | inactive
    local duration="${2:-0}"          # seconds (0 = infinite)
    local pid="${3:-}"                # background timer PID

    local activated_at
    if [[ "${status}" == "active" ]]; then
        activated_at="$(date +%s)"
    else
        activated_at=""
    fi

    # Write state as JSON — build manually for portability
    cat > "${STATE_FILE}" <<STATEEOF
{"status":"${status}","duration":${duration},"activated_at":"${activated_at}","pid":"${pid}"}
STATEEOF
}

# Get current status (active|inactive)
state_get_status() {
    state_init
    # Extract status field from JSON
    sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null || echo "inactive"
}

# Get configured duration in seconds
state_get_duration() {
    state_init
    sed -n 's/.*"duration"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "${STATE_FILE}" 2>/dev/null || echo "0"
}

# Get remaining time as human-readable string
state_get_remaining() {
    state_init
    local duration
    duration="$(state_get_duration)"

    # Infinite
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

    local now
    now="$(date +%s)"
    local elapsed=$(( now - activated_at ))
    local remaining=$(( duration - elapsed ))

    if [[ "${remaining}" -le 0 ]]; then
        echo "expired"
        return
    fi

    timer_human "${remaining}"
}

# Initialize state on load
state_init
