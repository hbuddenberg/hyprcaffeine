#!/usr/bin/env bash
# timer.sh — Timer management for HyprCaffeine v2.0
# State format: flat {status, duration, activated_at, pid, monitor, lid}

# Start a background timer that will deactivate idle when duration expires
# Args: duration_seconds (0 = infinite, no timer started)
timer_start() {
    local duration_seconds="${1:-0}"

    # Infinite — no timer needed
    if [[ "${duration_seconds}" -eq 0 ]]; then
        return 0
    fi

    # Kill any existing timer
    timer_stop

    local state_dir="${HOME}/.cache/hyprcaffeine"
    local state_file="${state_dir}/state.json"
    local pid_file="${state_dir}/timer.pid"

    # Write a standalone timer script and run it fully detached
    local timer_script="${state_dir}/.timer_worker.sh"

    # Capture current environment for Hyprland connectivity
    local his="${HYPRLAND_INSTANCE_SIGNATURE:-}"
    local xdg="${XDG_RUNTIME_DIR:-}"

    # Calculate pre-warning sleep (60s before expiry)
    local pre_warning_duration=0
    if [[ "${duration_seconds}" -gt 60 ]]; then
        pre_warning_duration=$(( duration_seconds - 60 ))
    fi

    cat > "${timer_script}" <<'WORKER_EOF'
#!/usr/bin/env bash
# HyprCaffeine Timer Worker — auto-generated
export HYPRLAND_INSTANCE_SIGNATURE="__HIS__"
export XDG_RUNTIME_DIR="__XDG__"
export PATH="__PATH__"

PRE_WARNING="__PRE_WARNING__"
FULL_DURATION="__DURATION__"

if [[ "${PRE_WARNING}" -gt 0 ]]; then
    # Duration > 60s: sleep (duration-60), warn, sleep 60, then deactivate
    sleep "${PRE_WARNING}"
    notify-send "HyprCaffeine" "Caffeine expiring in 60s" 2>/dev/null || true
    sleep 60
else
    # Duration <= 60s: just sleep the full duration
    sleep "${FULL_DURATION}"
fi

# Turn off idle only (preserve monitor/lid state)
if command -v hyprcaffeine &>/dev/null; then
    hyprcaffeine off 2>>__STATE_DIR__/timer.log || true
fi

# Fallback: kill sleep inhibitors only
for pid in $(ps -eo pid,args 2>/dev/null | grep "systemd-inhibit" | grep "HyprCaffeine" | grep "what=sleep" | grep -v grep | awk '{print $1}'); do
    kill "$pid" 2>/dev/null || true
done

# Read current monitor/lid state and preserve it
STATE_FILE="__STATE_DIR__/state.json"
MONITOR="false"
LID="false"
if [[ -f "$STATE_FILE" ]]; then
    MONITOR=$(grep -oP '"monitor"\s*:\s*\K(true|false)' "$STATE_FILE" 2>/dev/null || echo "false")
    LID=$(grep -oP '"lid"\s*:\s*\K(true|false)' "$STATE_FILE" 2>/dev/null || echo "false")
fi

echo "{\"status\":\"inactive\",\"duration\":0,\"activated_at\":\"\",\"pid\":\"\",\"monitor\":${MONITOR},\"lid\":${LID}}" > "$STATE_FILE"
rm -f __STATE_DIR__/idle_inhibit.pid __STATE_DIR__/timer.pid
rm -f __STATE_DIR__/.timer_worker.sh
WORKER_EOF

    # Inject real values via sed
    sed -i \
        -e "s|__HIS__|${his}|g" \
        -e "s|__XDG__|${xdg}|g" \
        -e "s|__DURATION__|${duration_seconds}|g" \
        -e "s|__PRE_WARNING__|${pre_warning_duration}|g" \
        -e "s|__STATE_DIR__|${state_dir}|g" \
        -e "s|__PATH__|${PATH}|g" \
        "${timer_script}"
    chmod +x "${timer_script}"

    # Launch fully detached
    ( bash "${timer_script}" >/dev/null 2>&1 & ) &
    local timer_pid=$!
    echo "${timer_pid}" > "${pid_file}"

    # Update state with timer PID (preserve monitor/lid)
    if [[ -f "${state_file}" ]]; then
        local status duration activated_at monitor_val lid_val
        status="$(sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${state_file}" 2>/dev/null || echo "active")"
        duration="$(sed -n 's/.*"duration"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "${state_file}" 2>/dev/null || echo "0")"
        activated_at="$(sed -n 's/.*"activated_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${state_file}" 2>/dev/null || echo "")"
        monitor_val="$(sed -n 's/.*"monitor"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "${state_file}" 2>/dev/null || echo "false")"
        lid_val="$(sed -n 's/.*"lid"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "${state_file}" 2>/dev/null || echo "false")"

        cat > "${state_file}" <<STATEEOF
{"status":"${status}","duration":${duration},"activated_at":"${activated_at}","pid":"${timer_pid}","monitor":${monitor_val},"lid":${lid_val}}
STATEEOF
    fi
}

# Stop any running timer
timer_stop() {
    local state_dir="${HOME}/.cache/hyprcaffeine"
    local pid_file="${state_dir}/timer.pid"

    if [[ -f "${pid_file}" ]]; then
        local pid
        pid="$(cat "${pid_file}" 2>/dev/null || echo "")"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill -- -"$(ps -o pgid= -p "${pid}" 2>/dev/null | tr -d ' ')" 2>/dev/null || \
                kill "${pid}" 2>/dev/null || true
        fi
        rm -f "${pid_file}"
    fi
}

# Convert seconds to human-readable duration string
timer_human() {
    local seconds="${1:-0}"

    if [[ "${seconds}" -eq 0 ]]; then
        echo "infinite"
        return
    fi

    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$(( seconds % 60 ))

    local parts=()
    [[ "${hours}" -gt 0 ]] && parts+=("${hours}h")
    [[ "${minutes}" -gt 0 ]] && parts+=("${minutes}m")
    [[ "${secs}" -gt 0 ]] && [[ "${hours}" -eq 0 ]] && parts+=("${secs}s")

    local result
    result="$(IFS=' '; echo "${parts[*]}")"

    if [[ -z "${result}" ]]; then
        echo "0s"
    else
        echo "${result}"
    fi
}
