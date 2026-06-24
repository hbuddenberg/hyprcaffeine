#!/usr/bin/env bash
# caffeine-menu.sh — Walker/Wofi menu for HyprCaffeine v3.1
# Icons verified from https://www.nerdfonts.com/cheat-sheet (glyphnames.json)

HYPRCAFFEINE="hyprcaffeine"
STATE_FILE="${HOME}/.cache/hyprcaffeine/state.json"

# Resolve lib dir so we can read the user's duration presets from config.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${LIB_DIR}/config.sh"

_get_field() {
    sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}.*/\1/p" "${STATE_FILE}" 2>/dev/null | head -1
}
_get_bool() {
    sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p" "${STATE_FILE}" 2>/dev/null | head -1
}
_is_idle_active() { [[ "$(_get_field status)" == "active" ]]; }

# Build toggle indicators from state
if [[ "$(_get_bool monitor)" == "true" ]]; then MON="●"; else MON="○"; fi
if [[ "$(_get_bool lid)" == "true" ]];     then LID="●"; else LID="○"; fi

# Build items — verified Nerd Font icons
# Read duration presets from the user config (falls back to defaults).
mapfile -t _PRESET_SECS < <(config_get_array "timeouts.presets")
[[ "${#_PRESET_SECS[@]}" -eq 0 ]] && _PRESET_SECS=(900 1800 3600 7200)

_PRESET_LABELS=()
MENU_ITEMS=()
for _sec in "${_PRESET_SECS[@]}"; do
    _label="$(preset_label "${_sec}")"
    _PRESET_LABELS+=("${_label}")
    MENU_ITEMS+=("󰔛 ${_label}")
done
MENU_ITEMS+=(
    "󰔛 Custom..."
    " Infinite"
    "────────────────────────"
    "󰍹 Keep Display On    ${MON}"
    "󰌢 Block Lid          ${LID}"
)

# If idle is active, add "Turn Off" at the bottom
if _is_idle_active; then
    REMAINING="$(${HYPRCAFFEINE} status 2>/dev/null | grep -oP '\d+h? ?\d*m' | head -1)"
    MENU_ITEMS+=("────────────────────────")
    MENU_ITEMS+=("󰤆 Turn Off (${REMAINING:-active})")
fi

# Render the menu. printf '%s\n' emits exactly one item per line with a single
# trailing newline (no trailing empty line), so dmenu-style launchers
# (walker/wofi/rofi) don't show a spurious blank option at the end of the list.
_choice=""
if command -v walker &>/dev/null; then
    _choice=$(printf '%s\n' "${MENU_ITEMS[@]}" | walker -d -N -H --placeholder="☕ Caffeine" --maxheight=700 --width=330 2>/dev/null)
elif command -v wofi &>/dev/null; then
    _choice=$(printf '%s\n' "${MENU_ITEMS[@]}" | wofi -d -p "☕ Caffeine" -W 320 -H 320 --cache-file=/dev/null 2>/dev/null)
elif command -v rofi &>/dev/null; then
    _choice=$(printf '%s\n' "${MENU_ITEMS[@]}" | rofi -dmenu -p "☕ Caffeine" -i -l 10 2>/dev/null)
elif command -v gum &>/dev/null; then
    _choice=$(gum choose --header="☕ Caffeine" --header.border="rounded" --cursor="→ " --height=10 "${MENU_ITEMS[@]}" 2>/dev/null)
fi

[[ -z "${_choice}" ]] && exit 0

# Handle selection
case "${_choice}" in
    *Custom*)
        # Re-open Walker in input-only mode for custom duration
        _custom_duration=""
        if command -v walker &>/dev/null; then
            _custom_duration=$(walker -d -I --placeholder="Duration (1:30 or 45m)" 2>/dev/null)
        elif command -v wofi &>/dev/null; then
            _custom_duration=$(wofi -d -p "Duration (1:30 or 45m)" --cache-file=/dev/null 2>/dev/null)
        elif command -v rofi &>/dev/null; then
            _custom_duration=$(rofi -dmenu -p "Duration (1:30 or 45m)" 2>/dev/null)
        elif command -v gum &>/dev/null; then
            _custom_duration=$(gum input --placeholder="Duration (1:30 or 45m)" 2>/dev/null)
        fi
        [[ -z "${_custom_duration}" ]] && exit 0
        "${HYPRCAFFEINE}" on "${_custom_duration}"
        ;;
    *Infinite*|*infinite*) "${HYPRCAFFEINE}" on infinite ;;
    *Display*|*display*)   "${HYPRCAFFEINE}" monitor toggle ;;
    *Lid*|*lid*)           "${HYPRCAFFEINE}" lid toggle ;;
    *Turn*Off*|*turn*off*) "${HYPRCAFFEINE}" off ;;
    *────*) exit 0 ;;  # Separator — do nothing
esac

# Dynamic preset match — labels/seconds come from the user config.
for _i in "${!_PRESET_LABELS[@]}"; do
    if [[ "${_choice}" == *"${_PRESET_LABELS[$_i]}"* ]]; then
        "${HYPRCAFFEINE}" on "$(preset_arg "${_PRESET_SECS[$_i]}")"
        exit 0
    fi
done
