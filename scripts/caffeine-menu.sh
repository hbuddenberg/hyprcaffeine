#!/usr/bin/env bash
# caffeine-menu.sh — Waybar click handler for HyprCaffeine v2.0
# English base, emojis, descriptive toggles

HYPRCAFFEINE="hyprcaffeine"
STATE_FILE="${HOME}/.cache/hyprcaffeine/state.json"

_get_field() {
    sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}.*/\1/p" "${STATE_FILE}" 2>/dev/null | head -1
}
_get_bool() {
    sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p" "${STATE_FILE}" 2>/dev/null | head -1
}
_is_idle_active() { [[ "$(_get_field status)" == "active" ]]; }

if _is_idle_active; then
    "${HYPRCAFFEINE}" off
    exit 0
fi

if [[ "$(_get_bool monitor)" == "true" ]]; then MON="🟢"; else MON="⚫"; fi
if [[ "$(_get_bool lid)" == "true" ]];     then LID="🟢"; else LID="⚫"; fi

MENU_ITEMS=(
    "☕ 15 min"
    "☕ 30 min"
    "☕ 1 hour"
    "☕ 2 hours"
    "♾️ Infinite"
    "${MON} Keep Display On"
    "${LID} Block Lid Suspend"
)

MENU_TEXT=""
for item in "${MENU_ITEMS[@]}"; do
    MENU_TEXT="${MENU_TEXT}${item}\\n"
done
MENU_TEXT="${MENU_TEXT%\\\\n}"

_choice=""
if command -v walker &>/dev/null; then
    _choice=$(echo -e "${MENU_TEXT}" | walker -d --placeholder="☕ Caffeine" --theme=caffeine --maxheight=700 2>/dev/null)
elif command -v wofi &>/dev/null; then
    _choice=$(echo -e "${MENU_TEXT}" | wofi -d -p "☕ Caffeine" -W 320 -h 280 --cache-file=/dev/null 2>/dev/null)
elif command -v gum &>/dev/null; then
    _choice=$(gum choose --header="☕ Caffeine" --header.border="rounded" --cursor="→ " --height=7 "${MENU_ITEMS[@]}" 2>/dev/null)
fi

[[ -z "${_choice}" ]] && exit 0

case "${_choice}" in
    *15*min*)   "${HYPRCAFFEINE}" on 15m ;;
    *30*min*)   "${HYPRCAFFEINE}" on 30m ;;
    *1*hour*)   "${HYPRCAFFEINE}" on 1h ;;
    *2*hour*)   "${HYPRCAFFEINE}" on 2h ;;
    *Infinite* | *infinite*) "${HYPRCAFFEINE}" on infinite ;;
    *Display* | *display*)   "${HYPRCAFFEINE}" monitor toggle ;;
    *Lid* | *lid*)           "${HYPRCAFFEINE}" lid toggle ;;
esac
