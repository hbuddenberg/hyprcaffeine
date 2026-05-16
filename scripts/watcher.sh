#!/usr/bin/env bash
# watcher.sh — Auto-activate daemon for HyprCaffeine
# Listens to Hyprland events via the event socket and auto-activates
# caffeine when fullscreen apps or configured applications are detected.
#
# Part of the HyprCaffeine utility suite

# ── Paths ────────────────────────────────────────────────────────────────────
WATCHER_STATE_DIR="${HOME}/.cache/hyprcaffeine"
WATCHER_PID_FILE="${WATCHER_STATE_DIR}/watcher.pid"
WATCHER_LOG_FILE="${WATCHER_STATE_DIR}/watcher.log"
WATCHER_STATE_FILE="${WATCHER_STATE_DIR}/state.json"
WATCHER_AUTO_FILE="${WATCHER_STATE_DIR}/watcher.auto"

# ── Resolve the Hyprland event socket ────────────────────────────────────────
_watcher_get_socket() {
    local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
    if [[ -z "${sig}" ]]; then
        # Try to get it from the environment of a running Hyprland session
        sig="$(cat /tmp/hypr/.hyprland_instances 2>/dev/null | head -1)"
        if [[ -z "${sig}" ]]; then
            return 1
        fi
    fi
    # Try XDG_RUNTIME_DIR first (Hyprland 0.54.x default), then /tmp
    local xdg_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local socket="${xdg_dir}/hypr/${sig}/.socket2.sock"
    if [[ -S "${socket}" ]]; then
        echo "${socket}"
        return 0
    fi
    # Fallback to /tmp (older Hyprland versions)
    socket="/tmp/hypr/${sig}/.socket2.sock"
    if [[ -S "${socket}" ]]; then
        echo "${socket}"
        return 0
    fi
    return 1
}

# ── Logging ──────────────────────────────────────────────────────────────────
_watcher_log() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] ${msg}" >> "${WATCHER_LOG_FILE}"
}

_watcher_log_error() {
    _watcher_log "ERROR: $1"
}

# ── Check if a binary exists ─────────────────────────────────────────────────
_watcher_has_socat() {
    command -v socat &>/dev/null
}

_watcher_has_hyprctl() {
    command -v hyprctl &>/dev/null
}

# ── Load automation config ───────────────────────────────────────────────────
# Returns the list of app classes that should trigger auto-activation
_watcher_get_trigger_apps() {
    local trigger_apps=""

    # Load from config via config.sh (already sourced by the caller)
    if type config_get &>/dev/null 2>&1; then
        # Check individual named triggers
        local steam discord audio
        steam="$(config_get 'automation.steam' 2>/dev/null)"
        discord="$(config_get 'automation.discord' 2>/dev/null)"
        audio="$(config_get 'automation.audio' 2>/dev/null)"

        [[ "${steam}" == "true" ]] && trigger_apps="${trigger_apps} steam Steam steam_app"
        [[ "${discord}" == "true" ]] && trigger_apps="${trigger_apps} discord Discord"

        # Load custom processes
        local custom
        custom="$(config_get 'automation.custom_processes' 2>/dev/null)"
        if [[ -n "${custom}" ]]; then
            trigger_apps="${trigger_apps} ${custom}"
        fi
    fi

    echo "${trigger_apps}"
}

# ── Check if caffeine is currently active ────────────────────────────────────
_watcher_is_active() {
    if [[ -f "${WATCHER_STATE_FILE}" ]]; then
        local status
        status="$(grep -oP '"status"\s*:\s*"\K[^"]+' "${WATCHER_STATE_FILE}" 2>/dev/null || echo "inactive")"
        [[ "${status}" == "active" ]]
        return $?
    fi
    return 1
}

# ── Check if current activation is auto (not manual) ─────────────────────────
_watcher_is_auto() {
    if [[ -f "${WATCHER_AUTO_FILE}" ]]; then
        local auto_val
        auto_val="$(cat "${WATCHER_AUTO_FILE}" 2>/dev/null || echo "false")"
        [[ "${auto_val}" == "true" ]]
        return $?
    fi
    return 1
}

# ── Auto-activate caffeine ───────────────────────────────────────────────────
_watcher_activate() {
    local reason="${1:-auto}"
    _watcher_log "Auto-activating caffeine (reason: ${reason})"

    # Mark activation as auto (separate file to keep state.json clean)
    mkdir -p "${WATCHER_STATE_DIR}"
    echo "true" > "${WATCHER_AUTO_FILE}"

    # Use the CLI directly — simplest and most reliable
    if command -v hyprcaffeine &>/dev/null; then
        hyprcaffeine on infinite 2>/dev/null
    else
        # Fallback: direct hyprctl calls
        hyprctl dispatch idleinhibit on 2>/dev/null || true
        hyprctl dispatch dpms on 2>/dev/null || true
        # Write state in flat format (matching state.sh model)
        local ts
        ts="$(date +%s)"
        echo "{\"status\":\"active\",\"duration\":0,\"activated_at\":\"${ts}\",\"pid\":\"\",\"monitor\":true,\"lid\":false}" > "${WATCHER_STATE_FILE}"
    fi
}

# ── Auto-deactivate caffeine (only if auto-activated) ────────────────────────
_watcher_deactivate() {
    local reason="${1:-auto-exit}"

    # Only deactivate if we auto-activated (don't touch manual activation)
    if ! _watcher_is_auto; then
        _watcher_log "Skipping deactivation — caffeine was activated manually"
        return 0
    fi

    _watcher_log "Auto-deactivating caffeine (reason: ${reason})"

    # Clear auto flag
    mkdir -p "${WATCHER_STATE_DIR}"
    echo "false" > "${WATCHER_AUTO_FILE}"

    if command -v hyprcaffeine &>/dev/null; then
        hyprcaffeine off 2>/dev/null
    else
        hyprctl dispatch idleinhibit off 2>/dev/null || true
        mkdir -p "${WATCHER_STATE_DIR}"
        echo '{"status":"inactive","duration":0,"activated_at":"","pid":"","monitor":false,"lid":false}' > "${WATCHER_STATE_FILE}"
    fi
}

# ── Get active window class ──────────────────────────────────────────────────
_watcher_get_active_class() {
    if _watcher_has_hyprctl; then
        hyprctl -j activewindow 2>/dev/null | grep -oP '"initialClass"\s*:\s*"\K[^"]+' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# ── Check if a window class matches any trigger app ──────────────────────────
_watcher_class_matches_trigger() {
    local class="$1"
    local triggers="$2"

    # Normalize class to lowercase for comparison
    local class_lower
    class_lower="$(echo "${class}" | tr '[:upper:]' '[:lower:]')"

    for trigger in ${triggers}; do
        local trigger_lower
        trigger_lower="$(echo "${trigger}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${class_lower}" == "${trigger_lower}" ]]; then
            return 0
        fi
    done
    return 1
}

# ── Main event loop ──────────────────────────────────────────────────────────
_watcher_event_loop() {
    local socket
    socket="$(_watcher_get_socket)" || {
        _watcher_log_error "Cannot find Hyprland event socket"
        return 1
    }

    _watcher_log "Connecting to Hyprland event socket: ${socket}"

    if ! _watcher_has_socat; then
        _watcher_log_error "socat not found — watcher requires socat"
        return 1
    fi

    # Read configuration
    local fullscreen_enabled="false"
    if type config_get &>/dev/null 2>&1; then
        fullscreen_enabled="$(config_get 'automation.fullscreen' 2>/dev/null || echo "false")"
    fi

    local trigger_apps
    trigger_apps="$(_watcher_get_trigger_apps)"

    _watcher_log "Configuration: fullscreen=${fullscreen_enabled}, trigger_apps=[${trigger_apps}]"

    local last_class=""
    local app_auto_active=false  # Track if we auto-activated for an app

    # Read events from socat with a timeout
    # Using timeout on socat so we can periodically reconnect if needed
    while IFS= read -r event_line; do
        # Skip empty lines
        [[ -z "${event_line}" ]] && continue

        local event_name event_data
        event_name="${event_line%%>>*}"
        event_data="${event_line#*>>}"

        _watcher_log "Event: ${event_name} >> ${event_data}"

        case "${event_name}" in
            fullscreen)
                if [[ "${fullscreen_enabled}" != "true" ]]; then
                    continue
                fi

                if [[ "${event_data}" == "1" ]]; then
                    # Entered fullscreen
                    _watcher_log "Fullscreen entered"
                    if ! _watcher_is_active; then
                        _watcher_activate "fullscreen"
                    fi
                elif [[ "${event_data}" == "0" ]]; then
                    # Exited fullscreen
                    _watcher_log "Fullscreen exited"
                    if _watcher_is_active && _watcher_is_auto && ! ${app_auto_active}; then
                        _watcher_deactivate "fullscreen-exit"
                    fi
                fi
                ;;

            activewindow)
                # Event format: activewindow>>class,title
                local class="${event_data%%,*}"
                local title="${event_data#*,}"

                _watcher_log "Active window changed: class=${class} title=${title}"

                # Check if this class matches trigger apps
                if [[ -n "${trigger_apps}" ]] && [[ -n "${class}" ]]; then
                    if _watcher_class_matches_trigger "${class}" "${trigger_apps}"; then
                        _watcher_log "Trigger app detected: ${class}"
                        if ! _watcher_is_active; then
                            _watcher_activate "app:${class}"
                            app_auto_active=true
                        fi
                    else
                        # Window changed to a non-trigger app
                        if ${app_auto_active} && _watcher_is_auto; then
                            _watcher_log "Left trigger app — deactivating auto-activation"
                            _watcher_deactivate "app-exit:${class}"
                            app_auto_active=false
                        fi
                    fi
                fi

                last_class="${class}"
                ;;

            *)
                # Ignore other events
                ;;
        esac
    done < <(socat -u UNIX-CONNECT:"${socket}" - 2>>"${WATCHER_LOG_FILE}")

    _watcher_log "Event stream ended (socat exited)"
    return 1
}

# ── Watcher Main Process (background daemon) ─────────────────────────────────
_watcher_daemon() {
    _watcher_log "=== HyprCaffeine Watcher Daemon Started (PID: $$) ==="

    # Write our PID
    mkdir -p "${WATCHER_STATE_DIR}"
    echo "$$" > "${WATCHER_PID_FILE}"

    # Trap signals for clean shutdown
    trap '_watcher_log "Received signal — shutting down"; rm -f "${WATCHER_PID_FILE}"; exit 0' SIGTERM SIGINT SIGQUIT

    local retry_count=0
    local max_retries=0  # 0 = infinite retries

    while true; do
        # Check if we should stop
        if [[ -f "${WATCHER_STATE_DIR}/watcher.stop" ]]; then
            rm -f "${WATCHER_STATE_DIR}/watcher.stop"
            _watcher_log "Stop file detected — shutting down"
            break
        fi

        # Run the event loop
        _watcher_event_loop
        local exit_code=$?

        retry_count=$((retry_count + 1))

        if [[ -f "${WATCHER_STATE_DIR}/watcher.stop" ]]; then
            rm -f "${WATCHER_STATE_DIR}/watcher.stop"
            _watcher_log "Stop file detected during reconnect — shutting down"
            break
        fi

        _watcher_log "Event loop exited (code: ${exit_code}). Reconnecting in 5s... (attempt ${retry_count})"
        sleep 5
    done

    rm -f "${WATCHER_PID_FILE}"
    _watcher_log "=== HyprCaffeine Watcher Daemon Stopped ==="
}

# ── Public API ───────────────────────────────────────────────────────────────

# Start the watcher daemon
watcher_start() {
    mkdir -p "${WATCHER_STATE_DIR}"

    # Check if already running
    if [[ -f "${WATCHER_PID_FILE}" ]]; then
        local existing_pid
        existing_pid="$(cat "${WATCHER_PID_FILE}" 2>/dev/null || echo "")"
        if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
            echo "⚠ Watcher already running (PID: ${existing_pid})"
            return 0
        fi
        # Stale PID file — clean it up
        rm -f "${WATCHER_PID_FILE}"
    fi

    # Ensure we have socat
    if ! _watcher_has_socat; then
        echo "Error: socat is required for the watcher daemon." >&2
        echo "Install it with: sudo pacman -S socat (or equivalent)" >&2
        return 1
    fi

    # Ensure we can find the Hyprland socket
    if ! _watcher_get_socket &>/dev/null; then
        echo "Error: Cannot find Hyprland event socket." >&2
        echo "Make sure HYPRLAND_INSTANCE_SIGNATURE is set or Hyprland is running." >&2
        return 1
    fi

    # Clear any stop file
    rm -f "${WATCHER_STATE_DIR}/watcher.stop"

    # Resolve the scripts directory for sourcing
    local scripts_dir
    scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Write a standalone daemon script and launch it detached
    local daemon_script="${WATCHER_STATE_DIR}/.watcher_daemon.sh"
    cat > "${daemon_script}" <<DAEMON_EOF
#!/usr/bin/env bash
# HyprCaffeine Watcher Daemon — auto-generated launcher
set -uo pipefail

# Preserve Hyprland environment
export HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}"

# Source required libraries
source "${scripts_dir}/watcher.sh"
source "${scripts_dir}/config.sh"

# Load config
config_load

# Run the daemon
_watcher_daemon
DAEMON_EOF
    chmod +x "${daemon_script}"

    # Launch as a detached background process
    ( bash "${daemon_script}" >/dev/null 2>&1 & ) &
    local daemon_pid=$!

    echo "󰒲 Watcher daemon started (PID: ${daemon_pid})"
    echo "   Log: ${WATCHER_LOG_FILE}"
}

# Stop the watcher daemon
watcher_stop() {
    if [[ ! -f "${WATCHER_PID_FILE}" ]]; then
        echo "☕ Watcher is not running"
        return 0
    fi

    local pid
    pid="$(cat "${WATCHER_PID_FILE}" 2>/dev/null || echo "")"

    if [[ -z "${pid}" ]]; then
        echo "☕ Watcher is not running (empty PID file)"
        rm -f "${WATCHER_PID_FILE}"
        return 0
    fi

    # Create stop file to signal graceful shutdown
    touch "${WATCHER_STATE_DIR}/watcher.stop"

    if kill -0 "${pid}" 2>/dev/null; then
        kill -TERM "${pid}" 2>/dev/null || true

        # Wait up to 5 seconds for graceful shutdown
        local waited=0
        while kill -0 "${pid}" 2>/dev/null && [[ ${waited} -lt 5 ]]; do
            sleep 1
            waited=$((waited + 1))
        done

        # Force kill if still running
        if kill -0 "${pid}" 2>/dev/null; then
            kill -9 "${pid}" 2>/dev/null || true
        fi
        echo "☕ Watcher stopped (killed PID: ${pid})"
    else
        echo "☕ Watcher was not running (stale PID: ${pid})"
    fi

    rm -f "${WATCHER_PID_FILE}"
    rm -f "${WATCHER_STATE_DIR}/watcher.stop"
}

# Show watcher status
watcher_status() {
    if [[ ! -f "${WATCHER_PID_FILE}" ]]; then
        echo "☕ Watcher: not running"
        return 0
    fi

    local pid
    pid="$(cat "${WATCHER_PID_FILE}" 2>/dev/null || echo "")"

    if [[ -z "${pid}" ]] || ! kill -0 "${pid}" 2>/dev/null; then
        echo "☕ Watcher: not running (stale PID)"
        rm -f "${WATCHER_PID_FILE}"
        return 0
    fi

    echo "󰒲 Watcher: running (PID: ${pid})"

    # Show automation config
    local fullscreen steam discord audio custom
    if type config_get &>/dev/null 2>&1; then
        fullscreen="$(config_get 'automation.fullscreen' 2>/dev/null || echo "false")"
        steam="$(config_get 'automation.steam' 2>/dev/null || echo "false")"
        discord="$(config_get 'automation.discord' 2>/dev/null || echo "false")"
        audio="$(config_get 'automation.audio' 2>/dev/null || echo "false")"
        custom="$(config_get 'automation.custom_processes' 2>/dev/null || echo "")"

        echo "   Automation config:"
        echo "     fullscreen: ${fullscreen}"
        echo "     steam:      ${steam}"
        echo "     discord:    ${discord}"
        echo "     audio:      ${audio}"
        [[ -n "${custom}" ]] && echo "     custom:     ${custom}"
    fi

    echo "   Log: ${WATCHER_LOG_FILE}"
}
