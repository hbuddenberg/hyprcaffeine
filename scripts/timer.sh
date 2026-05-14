#!/usr/bin/env bash
# timer.sh — Timer management for HyprCaffeine
# Part of the HyprCaffeine utility suite

# Start a background timer that will deactivate caffeine when duration expires
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

    # Write a standalone timer script and run it fully detached via setsid
    local timer_script="${state_dir}/.timer_worker.sh"
    cat > "${timer_script}" <<EOF
#!/usr/bin/env bash
sleep ${duration_seconds}
hyprctl dispatch idleinhibit off 2>/dev/null || true
echo '{"status":"inactive","duration":0,"activated_at":"","pid":""}' > ${state_file}
notify-send -a HyprCaffeine '☕ Caffeine Expired' 'Idle inhibition timer ended' 2>/dev/null || true
rm -f ${pid_file}
rm -f ${timer_script}
EOF
    chmod +x "${timer_script}"

    # Launch fully detached — setsid creates new session, disowns from process group
    setsid bash "${timer_script}" >/dev/null 2>&1 &
    local timer_pid=$!

    echo "${timer_pid}" > "${pid_file}"

    # Update state file with timer PID
    if [[ -f "${state_file}" ]]; then
        local status duration activated_at
        status="$(grep -oP '"status"\s*:\s*"\K[^"]+' "${state_file}" 2>/dev/null || echo "active")"
        duration="$(grep -oP '"duration"\s*:\s*\K[0-9]+' "${state_file}" 2>/dev/null || echo "0")"
        activated_at="$(grep -oP '"activated_at"\s*:\s*"\K[^"]+' "${state_file}" 2>/dev/null || echo "")"
        echo "{\"status\":\"${status}\",\"duration\":${duration},\"activated_at\":\"${activated_at}\",\"pid\":\"${timer_pid}\"}" > "${state_file}"
    fi

    disown "${timer_pid}" 2>/dev/null || true
}

# Stop any running timer
timer_stop() {
    local state_dir="${HOME}/.cache/hyprcaffeine"
    local pid_file="${state_dir}/timer.pid"

    if [[ -f "${pid_file}" ]]; then
        local pid
        pid="$(cat "${pid_file}" 2>/dev/null || echo "")"
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null || true
        fi
        rm -f "${pid_file}"
    fi
}

# Convert seconds to human-readable duration string
# Args: seconds
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
    if [[ "${hours}" -gt 0 ]]; then
        parts+=("${hours}h")
    fi
    if [[ "${minutes}" -gt 0 ]]; then
        parts+=("${minutes}m")
    fi
    if [[ "${secs}" -gt 0 ]] && [[ "${hours}" -eq 0 ]]; then
        parts+=("${secs}s")
    fi

    local result
    result="$(IFS=' '; echo "${parts[*]}")"

    if [[ -z "${result}" ]]; then
        echo "0s"
    else
        echo "${result}"
    fi
}
