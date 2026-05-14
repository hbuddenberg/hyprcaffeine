#!/usr/bin/env bash
# notify.sh — Notification helpers for HyprCaffeine
# Part of the HyprCaffeine utility suite

# Send a desktop notification
# Args: title [body]
notify_send() {
    local title="${1:-HyprCaffeine}"
    local body="${2:-}"

    if [[ "${HC_NOTIFICATIONS_ENABLED:-true}" != "true" ]]; then
        return 0
    fi

    if command -v notify-send &>/dev/null; then
        notify-send -a "HyprCaffeine" "${title}" "${body}" 2>/dev/null || true
    fi
}

# Send an error notification
# Args: message
notify_error() {
    local message="${1:-An error occurred}"

    if command -v notify-send &>/dev/null; then
        notify-send -a "HyprCaffeine" -u critical "⚠ HyprCaffeine Error" "${message}" 2>/dev/null || true
    fi
}
