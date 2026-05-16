#!/usr/bin/env bash
# ui-engine.sh — Reads ui-dictionary.json and generates UI for both Waybar and Walker
# Single source of truth: config/ui-dictionary.json

UI_DICT="${UI_DICT:-$(dirname "${BASH_SOURCE[0]}")/../config/ui-dictionary.json}"
STATE_FILE="${HOME}/.cache/hyprcaffeine/state.json"

# ── State readers ──────────────────────────────────────────────────────────
_sf() { sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}.*/\1/p" "${STATE_FILE}" 2>/dev/null | head -1; }
_sb() { sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p" "${STATE_FILE}" 2>/dev/null | head -1; }

# ── JSON reader (jq or fallback to python) ────────────────────────────────
_jq() { command -v jq &>/dev/null && jq -r "$1" "${UI_DICT}" || python3 -c "import json,sys;d=json.load(open('${UI_DICT}'));print(${1#'.').replace('.','[').replace('[','[\"').replace(']','\"]')+'()' if False else ''})" 2>/dev/null; }

# Simple json path via python (portable, no jq needed)
_jpath() {
    python3 -c "
import json, sys
d = json.load(open('${UI_DICT}'))
keys = '${1}'.split('.')
v = d
for k in keys:
    if k.isdigit(): v = v[int(k)]
    else: v = v[k]
print(v)
" 2>/dev/null
}

# ── Read state ─────────────────────────────────────────────────────────────
read_state() {
    local status="$(_sf status)"
    local duration="$(_sf duration)"
    local monitor="$(_sb monitor)"
    local lid="$(_sb lid)"

    local idle_type="off"
    if [[ "${status}" == "active" ]]; then
        if [[ "${duration}" -eq 0 ]]; then
            idle_type="infinite"
        else
            idle_type="timer"
        fi
    fi

    echo "${idle_type}|${monitor}|${lid}|${duration}"
}

# ── Get color for current combination ─────────────────────────────────────
get_combo_color() {
    local idle_type="$1" monitor="$2" lid="$3"
    python3 -c "
import json
d = json.load(open('${UI_DICT}'))
idle = '${idle_type}'
mon = ${monitor,,} == 'true'
lid = ${lid,,} == 'true'

# Build combination key
parts = []
if idle in ('infinite', 'timer'):
    parts.append(idle)
if mon: parts.append('monitor')
if lid: parts.append('lid')

key = '+'.join(parts)
if not key:
    s = d['states']['off']
    print(s['color'] + '|' + s['css_class'])
elif key in d.get('combinations', {}):
    c = d['combinations'][key]
    print(c['color'] + '|' + c['css_class'])
elif idle in ('infinite', 'timer'):
    s = d['states'][idle]
    print(s['color'] + '|' + s['css_class'])
elif mon:
    s = d['states']['monitor']
    print(s['color'] + '|' + s['css_class'])
elif lid:
    s = d['states']['lid']
    print(s['color'] + '|' + s['css_class'])
else:
    s = d['states']['off']
    print(s['color'] + '|' + s['css_class'])
" 2>/dev/null
}

# ── Generate Waybar JSON ──────────────────────────────────────────────────
waybar_output() {
    local state_raw
    state_raw="$(read_state)"
    IFS='|' read -r idle_type monitor lid duration <<< "${state_raw}"

    local color_class
    color_class="$(get_combo_color "${idle_type}" "${monitor}" "${lid}")"
    local color="${color_class%|*}"
    local css_class="${color_class#*|}"

    # Icons from dictionary
    local wb_coffee_on wb_coffee_off wb_infinite wb_timer wb_monitor wb_lid sep
    wb_coffee_on="$(_jpath 'waybar.icons.coffee_on')"
    wb_coffee_off="$(_jpath 'waybar.icons.coffee_off')"
    wb_infinite="$(_jpath 'waybar.icons.infinite')"
    wb_timer="$(_jpath 'waybar.icons.timer')"
    wb_monitor="$(_jpath 'waybar.icons.monitor')"
    wb_lid="$(_jpath 'waybar.icons.lid')"
    sep="$(_jpath 'waybar.separator')"

    # Build text
    local idle_active="false"
    [[ "${idle_type}" == "infinite" || "${idle_type}" == "timer" ]] && idle_active="true"

    local cup="${wb_coffee_off}"
    [[ "${idle_active}" == "true" ]] && cup="${wb_coffee_on}"

    local parts=()
    if [[ "${idle_type}" == "infinite" ]]; then
        parts+=("${wb_infinite}")
    fi
    if [[ "${idle_type}" == "timer" ]]; then
        local remaining
        remaining="$(hyprcaffeine status 2>/dev/null | grep -oP '\d+h? ?\d*m' | head -1)"
        parts+=("${wb_timer} ${remaining:-${duration}s}")
    fi
    if [[ "${monitor}" == "true" ]]; then
        parts+=("${wb_monitor}")
    fi
    if [[ "${lid}" == "true" ]]; then
        parts+=("${wb_lid}")
    fi

    local text="${cup}"
    if [[ ${#parts[@]} -gt 0 ]]; then
        text="${cup}${sep}$(IFS="${sep}"; echo "${parts[*]}")"
    fi

    # Build tooltip
    local tooltip_parts=()
    if [[ "${idle_type}" == "infinite" ]]; then
        tooltip_parts+=("∞ Infinite")
    elif [[ "${idle_type}" == "timer" ]]; then
        tooltip_parts+=("⏱ Timer: ${remaining:-active}")
    fi
    if [[ "${monitor}" == "true" ]]; then
        tooltip_parts+=("Display: ON")
    else
        tooltip_parts+=("Display: off")
    fi
    if [[ "${lid}" == "true" ]]; then
        tooltip_parts+=("Lid: Blocked")
    else
        tooltip_parts+=("Lid: normal")
    fi

    local tooltip
    if [[ "${idle_active}" != "true" && "${monitor}" != "true" && "${lid}" != "true" ]]; then
        tooltip="☕ Caffeine: Inactive"
    else
        tooltip="$(IFS=' · '; echo "${tooltip_parts[*]}")"
    fi

    tooltip="$(echo "${tooltip}" | sed 's/\\/\\\\/g; s/"/\\"/g')"

    printf '{"text":"%s","tooltip":"%s","class":"%s","color":"%s"}\n' \
        "${text}" "${tooltip}" "${css_class}" "${color}"
}

# ── Generate Walker Menu ──────────────────────────────────────────────────
walker_menu() {
    local state_raw
    state_raw="$(read_state)"
    IFS='|' read -r idle_type monitor lid duration <<< "${state_raw}"

    # Read icons from dictionary
    local icon_timer icon_infinite icon_monitor icon_lid
    icon_timer="$(_jpath 'states.timer.icon')"
    icon_infinite="$(_jpath 'states.infinite.icon')"
    icon_monitor="$(_jpath 'states.monitor.icon')"
    icon_lid="$(_jpath 'states.lid.icon')"

    # Toggle indicators
    local mon_ind="○" lid_ind="○"
    [[ "${monitor}" == "true" ]] && mon_ind="●"
    [[ "${lid}" == "true" ]] && lid_ind="●"

    # Read presets
    local p15 p30 p1h p2h
    p15="$(_jpath 'presets.15m.label')"
    p30="$(_jpath 'presets.30m.label')"
    p1h="$(_jpath 'presets.1h.label')"
    p2h="$(_jpath 'presets.2h.label')"

    # Build items
    MENU_ITEMS=(
        "${icon_timer} ${p15}"
        "${icon_timer} ${p30}"
        "${icon_timer} ${p1h}"
        "${icon_timer} ${p2h}"
        "${icon_timer} Custom..."
        "${icon_infinite} Infinite"
        "────────────────────────"
        "${icon_monitor} Keep Display On    ${mon_ind}"
        "${icon_lid} Block Lid          ${lid_ind}"
    )

    if [[ "${idle_type}" != "off" ]]; then
        local remaining
        remaining="$(hyprcaffeine status 2>/dev/null | grep -oP '\d+h? ?\d*m' | head -1)"
        MENU_ITEMS+=("────────────────────────")
        MENU_ITEMS+=("󰾪 Turn Off (${remaining:-active})")
    fi

    MENU_TEXT=""
    for item in "${MENU_ITEMS[@]}"; do
        MENU_TEXT="${MENU_TEXT}${item}\\n"
    done
    MENU_TEXT="${MENU_TEXT%\\\\n}"

    _choice=""
    if command -v walker &>/dev/null; then
        _choice=$(echo -e "${MENU_TEXT}" | walker -d -N -H --placeholder="☕ Caffeine" --maxheight=700 --width=330 2>/dev/null)
    elif command -v wofi &>/dev/null; then
        _choice=$(echo -e "${MENU_TEXT}" | wofi -d -p "☕ Caffeine" -W 320 -h 320 --cache-file=/dev/null 2>/dev/null)
    fi

    [[ -z "${_choice}" ]] && exit 0

    case "${_choice}" in
        *Custom*)
            _custom_duration=""
            if command -v walker &>/dev/null; then
                _custom_duration=$(walker -d -I --placeholder="Duration (1:30 or 45m)" 2>/dev/null)
            elif command -v wofi &>/dev/null; then
                _custom_duration=$(wofi -d -p "Duration (1:30 or 45m)" --cache-file=/dev/null 2>/dev/null)
            fi
            [[ -z "${_custom_duration}" ]] && exit 0
            hyprcaffeine on "${_custom_duration}"
            ;;
        *15*min*)   hyprcaffeine on 15m ;;
        *30*min*)   hyprcaffeine on 30m ;;
        *1*hour*)   hyprcaffeine on 1h ;;
        *2*hour*)   hyprcaffeine on 2h ;;
        *Infinite*|*infinite*) hyprcaffeine on infinite ;;
        *Display*|*display*)   hyprcaffeine monitor toggle ;;
        *Lid*|*lid*)           hyprcaffeine lid toggle ;;
        *Turn*Off*|*turn*off*) hyprcaffeine off ;;
        *────*) exit 0 ;;
    esac
}

# ── CLI entry ──────────────────────────────────────────────────────────────
case "${1:-}" in
    waybar) waybar_output ;;
    menu)   walker_menu ;;
    state)  read_state ;;
    color)  shift; get_combo_color "$@" ;;
    *)      echo "Usage: $0 {waybar|menu|state|color <idle_type> <monitor> <lid>}" >&2; exit 1 ;;
esac
