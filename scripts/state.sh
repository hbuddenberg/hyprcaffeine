#!/usr/bin/env bash
# state.sh — State management for HyprCaffeine
# Part of the HyprCaffeine utility suite

# State file paths (sourced from main binary)
# STATE_DIR and STATE_FILE must be defined by the caller

# Ensure state directory and file exist
state_init() {
    mkdir -p "${STATE_DIR}"
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo '{"status":"inactive","duration":0,"activated_at":"","pid":"","features":{"idle":false,"monitor":false,"lid":false,"auto":false}}' > "${STATE_FILE}"
    fi
}

# Save state to JSON file
# Args: status duration pid [features_json]
#   features_json (optional): e.g. {"idle":true,"monitor":true,"lid":false}
state_save() {
    local status="${1:-inactive}"     # active | inactive
    local duration="${2:-0}"          # seconds (0 = infinite)
    local pid="${3:-}"                # background timer PID
    local features="${4:-}"           # JSON features object

    local activated_at
    if [[ "${status}" == "active" ]]; then
        activated_at="$(date +%s)"
    else
        activated_at=""
    fi

    # If no features provided, use defaults based on status
    if [[ -z "${features}" ]]; then
        if [[ "${status}" == "inactive" ]]; then
            features='{"idle":false,"monitor":false,"lid":false,"auto":false}'
        else
            # Preserve existing features when not explicitly set
            features="$(state_get_features_raw)"
        fi
    fi

    # Write state as JSON — build manually for portability
    cat > "${STATE_FILE}" <<STATEEOF
{"status":"${status}","duration":${duration},"activated_at":"${activated_at}","pid":"${pid}","features":${features}}
STATEEOF
}

# Get current status (active|inactive)
state_get_status() {
    state_init
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

# ── Features Management ─────────────────────────────────────────────────────

# Get raw features JSON object from state file
state_get_features_raw() {
    state_init
    sed -n 's/.*"features"[[:space:]]*:[[:space:]]*\({[^}]*}\).*/\1/p' "${STATE_FILE}" 2>/dev/null || echo '{"idle":false,"monitor":false,"lid":false,"auto":false}'
}

# Get a specific feature state (returns "true" or "false")
# Args: feature_name (idle|monitor|lid)
state_get_feature() {
    local feature="${1:-idle}"
    local features_raw
    features_raw="$(state_get_features_raw)"
    # Extract the boolean value for the given feature key
    echo "${features_raw}" | sed -n "s/.*\"${feature}\"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p" 2>/dev/null || echo "false"
}

# Check if any feature is active
state_has_active_features() {
    local idle monitor lid
    idle="$(state_get_feature idle)"
    monitor="$(state_get_feature monitor)"
    lid="$(state_get_feature lid)"
    [[ "${idle}" == "true" ]] || [[ "${monitor}" == "true" ]] || [[ "${lid}" == "true" ]]
}

# Build features JSON from individual flags
# Args: idle_bool monitor_bool lid_bool [auto_bool]
state_build_features() {
    local idle="${1:-false}"
    local monitor="${2:-false}"
    local lid="${3:-false}"
    local auto="${4:-false}"
    echo "{\"idle\":${idle},\"monitor\":${monitor},\"lid\":${lid},\"auto\":${auto}}"
}

# Update a single feature in the current state (preserves other fields)
# Args: feature_name true|false
state_set_feature() {
    local feature="${1:-idle}"
    local value="${2:-false}"
    state_init

    # Read current features and modify
    local features_raw
    features_raw="$(state_get_features_raw)"

    # Replace the feature value
    local updated
    updated="$(echo "${features_raw}" | sed "s/\"${feature}\"[[:space:]]*:[[:space:]]*\(true\|false\)/\"${feature}\":${value}/")"

    # Rewrite state file with updated features
    local status duration activated_at pid
    status="$(state_get_status)"
    duration="$(state_get_duration)"
    activated_at="$(sed -n 's/.*"activated_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null)"
    pid="$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" 2>/dev/null)"

    cat > "${STATE_FILE}" <<STATEEOF
{"status":"${status}","duration":${duration},"activated_at":"${activated_at}","pid":"${pid}","features":${updated}}
STATEEOF
}

# Get formatted list of active features for display
state_get_features_display() {
    local parts=()
    local idle monitor lid
    idle="$(state_get_feature idle)"
    monitor="$(state_get_feature monitor)"
    lid="$(state_get_feature lid)"

    [[ "${monitor}" == "true" ]] && parts+=("[monitor]")
    [[ "${lid}" == "true" ]] && parts+=("[lid]")

    local result
    result="$(IFS=' '; echo "${parts[*]}")"
    echo "${result}"
}

# Initialize state on load
state_init
