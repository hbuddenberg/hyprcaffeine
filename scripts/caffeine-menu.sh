#!/usr/bin/env bash
# caffeine-menu.sh — Walker/Wofi menu for HyprCaffeine v3.0
# Uses Nerd Font icons (monospace-width) for proper alignment

HYPRCAFFEINE="hyprcaffeine"
STATE_FILE="${HOME}/.cache/hyprcaffeine/state.json"

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

# Build items — Nerd Font icons for monospace alignment
MENU_ITEMS=(
    "󱎫 15 min"
    "󱎫 30 min"
    "󱎫 1 hour"
    "󱎫 2 hours"
    "󱎫 Custom..."
    "󰜉 Infinite"
    "────────────────────────"
    "󰍹 Keep Display On   ${MON}"
    "󰍺 Block Lid           ${LID}"
)

# If idle is active, add "Turn Off" at the bottom
if _is_idle_active; then
    REMAINING="$(${HYPRCAFFEINE} status 2>/dev/null | grep -oP '\d+h? ?\d*m' | head -1)"
    MENU_ITEMS+=("────────────────────────")
    MENU_ITEMS+=("󰾪 Turn Off (${REMAINING:-active})")
fi

MENU_TEXT=""
for item in "${MENU_ITEMS[@]}"; do
    MENU_TEXT="${MENU_TEXT}${item}\\n"
done
MENU_TEXT="${MENU_TEXT%\\\\n}"

_choice=""
if command -v walker &>/dev/null; then
    _choice=$(echo -e "${MENU_TEXT}" | walker -d -N -H --placeholder="☕ Caffeine" --maxheight=700 2>/dev/null)
elif command -v wofi &>/dev/null; then
    _choice=$(echo -e "${MENU_TEXT}" | wofi -d -p "☕ Caffeine" -W 320 -h 320 --cache-file=/dev/null 2>/dev/null)
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
        elif command -v gum &>/dev/null; then
            _custom_duration=$(gum input --placeholder="Duration (1:30 or 45m)" 2>/dev/null)
        fi
        [[ -z "${_custom_duration}" ]] && exit 0
        "${HYPRCAFFEINE}" on "${_custom_duration}"
        ;;
    *15*min*)   "${HYPRCAFFEINE}" on 15m ;;
    *30*min*)   "${HYPRCAFFEINE}" on 30m ;;
    *1*hour*)   "${HYPRCAFFEINE}" on 1h ;;
    *2*hour*)   "${HYPRCAFFEINE}" on 2h ;;
    *Infinite*|*infinite*) "${HYPRCAFFEINE}" on infinite ;;
    *Display*|*display*)   "${HYPRCAFFEINE}" monitor toggle ;;
    *Lid*|*lid*)           "${HYPRCAFFEINE}" lid toggle ;;
    *Turn*Off*|*turn*off*) "${HYPRCAFFEINE}" off ;;
    *────*) exit 0 ;;  # Separator — do nothing
esac
