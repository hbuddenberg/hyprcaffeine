#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
#  HyprCaffeine Unit Tests
#  Tests core functions without requiring Hyprland running
# ─────────────────────────────────────────────────────────
set -uo pipefail

# Colors
C_GREEN="\033[32m"
C_RED="\033[31m"
C_YELLOW="\033[33m"
C_RESET="\033[0m"

PASS=0
FAIL=0
SKIP=0
TOTAL=0

# ── Test helpers ────────────────────────────────────────
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
        echo -e "  ${C_GREEN}✓${C_RESET} $desc"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${C_RED}✗${C_RESET} $desc"
        echo -e "    expected: '$expected'"
        echo -e "    actual:   '$actual'"
    fi
}

assert_ok() {
    local desc="$1"
    shift
    TOTAL=$((TOTAL + 1))
    if "$@" &>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${C_GREEN}✓${C_RESET} $desc"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${C_RED}✗${C_RESET} $desc (exit code non-zero)"
    fi
}

assert_file_contains() {
    local desc="$1" file="$2" pattern="$3"
    TOTAL=$((TOTAL + 1))
    if grep -q "$pattern" "$file" 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${C_GREEN}✓${C_RESET} $desc"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${C_RED}✗${C_RESET} $desc (pattern '$pattern' not in $file)"
    fi
}

# ── Setup temp state dir ────────────────────────────────
TEST_STATE_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_STATE_DIR"' EXIT

echo ""
echo -e "${C_YELLOW}═══ HyprCaffeine Unit Tests ═══${C_RESET}"
echo ""

# ── Source libraries with mocked state dir ──────────────
export STATE_DIR="$TEST_STATE_DIR"
export STATE_FILE="$TEST_STATE_DIR/state.json"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/scripts"

# Source individual functions we need to test
source "${LIB_DIR}/state.sh"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/notify.sh"

# Source timer_human from timer.sh (only that function)
source "${LIB_DIR}/timer.sh"

# Source keybinds.sh for the Lua/hyprlang detection tests (#4). Its entry-point
# guard skips dispatch when sourced, so this only defines the _kb_* functions.
source "${LIB_DIR}/keybinds.sh"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${C_YELLOW}── parse_duration ──${C_RESET}"

# We need parse_duration from the main binary — extract it
# Create a minimal script that sources it
parse_duration() {
    local duration="${1:-infinite}"
    case "${duration}" in
        infinite|inf) echo "0" ;;
        *s) echo "${duration%s}" ;;
        *m) echo "$(( ${duration%m} * 60 ))" ;;
        *h) echo "$(( ${duration%h} * 3600 ))" ;;
        *)
            if [[ "${duration}" =~ ^([0-9]+):([0-9]{2})$ ]]; then
                local hours="${BASH_REMATCH[1]}"
                local minutes="${BASH_REMATCH[2]}"
                echo "$(( hours * 3600 + minutes * 60 ))"
            elif [[ "${duration}" =~ ^[0-9]+$ ]]; then
                echo "$(( duration * 60 ))"
            else
                echo "-1"
            fi
            ;;
    esac
}

assert_eq "infinite → 0" "0" "$(parse_duration infinite)"
assert_eq "inf → 0" "0" "$(parse_duration inf)"
assert_eq "30s → 30" "30" "$(parse_duration 30s)"
assert_eq "15m → 900" "900" "$(parse_duration 15m)"
assert_eq "2h → 7200" "7200" "$(parse_duration 2h)"
assert_eq "1:30 → 5400" "5400" "$(parse_duration 1:30)"
assert_eq "bare 30 → 1800 (minutes)" "1800" "$(parse_duration 30)"
assert_eq "invalid → -1" "-1" "$(parse_duration invalid)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── timer_human ──${C_RESET}"

assert_eq "0s → infinite" "infinite" "$(timer_human 0)"
assert_eq "30s → 30s" "30s" "$(timer_human 30)"
assert_eq "90s → 1m 30s" "1m 30s" "$(timer_human 90)"
assert_eq "3600s → 1h" "1h" "$(timer_human 3600)"
assert_eq "5400s → 1h 30m" "1h 30m" "$(timer_human 5400)"
assert_eq "1800s → 30m" "30m" "$(timer_human 1800)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── state.sh ──${C_RESET}"

# Init
state_init
assert_eq "state_init creates file" "inactive" "$(state_get_status)"

# Save with full state
state_save "active" "1800" "12345" "true" "false"
assert_eq "status after save" "active" "$(state_get_status)"
assert_eq "duration after save" "1800" "$(state_get_duration)"
assert_eq "monitor after save" "true" "$(state_get_monitor)"
assert_eq "lid after save" "false" "$(state_get_lid)"

# Set monitor independently
state_set_monitor "false"
assert_eq "monitor after set false" "false" "$(state_get_monitor)"
assert_eq "status preserved after monitor change" "active" "$(state_get_status)"
assert_eq "lid preserved after monitor change" "false" "$(state_get_lid)"

# Set lid independently
state_set_lid "true"
assert_eq "lid after set true" "true" "$(state_get_lid)"
assert_eq "monitor preserved after lid change" "false" "$(state_get_monitor)"

# Save inactive preserving monitor/lid
state_save "inactive" "0" "" "true" "true"
assert_eq "status inactive" "inactive" "$(state_get_status)"
assert_eq "monitor preserved" "true" "$(state_get_monitor)"
assert_eq "lid preserved" "true" "$(state_get_lid)"

# State file content validation
assert_file_contains "state.json has valid status" "$STATE_FILE" '"status"'
assert_file_contains "state.json has monitor" "$STATE_FILE" '"monitor"'
assert_file_contains "state.json has lid" "$STATE_FILE" '"lid"'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── state_get_remaining ──${C_RESET}"

# Test remaining with known activated_at
local_ts=$(date +%s)
echo "{\"status\":\"active\",\"duration\":1800,\"activated_at\":\"${local_ts}\",\"pid\":\"\",\"monitor\":false,\"lid\":false}" > "$STATE_FILE"
remaining=$(state_get_remaining)
# Should be around 30m (give or take 1s)
assert_ok "remaining is not empty" test -n "$remaining"
assert_ok "remaining is not 'unknown'" test "$remaining" != "unknown"
assert_ok "remaining is not 'expired'" test "$remaining" != "expired"

# Test infinite duration
echo '{"status":"active","duration":0,"activated_at":"123","pid":"","monitor":false,"lid":false}' > "$STATE_FILE"
assert_eq "infinite duration → infinite" "infinite" "$(state_get_remaining)"

# Test expired
old_ts=$(( $(date +%s) - 2000 ))
echo "{\"status\":\"active\",\"duration\":1800,\"activated_at\":\"${old_ts}\",\"pid\":\"\",\"monitor\":false,\"lid\":false}" > "$STATE_FILE"
assert_eq "expired timer → expired" "expired" "$(state_get_remaining)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── config.sh ──${C_RESET}"

# Test with default config
config_reload
assert_ok "config_load succeeds" config_load

accent=$(config_get "theme.accent")
assert_ok "theme.accent is not empty" test -n "$accent"

default=$(config_get "timeouts.default")
assert_ok "timeouts.default is not empty" test -n "$default"
assert_eq "timeouts.default = 1800" "1800" "$default"

notifications=$(config_get "notifications.enabled")
assert_eq "notifications.enabled = true" "true" "$notifications"

# Test config_get_array
mapfile -t presets < <(config_get_array "timeouts.presets")
assert_ok "presets has items" test "${#presets[@]}" -gt 0
assert_eq "first preset = 900" "900" "${presets[0]}"
assert_eq "second preset = 1800" "1800" "${presets[1]}"

# preset_label / preset_arg — format configured presets for the Bash menu (#6)
assert_eq "preset_label 900 → 15 min" "15 min" "$(preset_label 900)"
assert_eq "preset_label 1800 → 30 min" "30 min" "$(preset_label 1800)"
assert_eq "preset_label 3600 → 1 hour" "1 hour" "$(preset_label 3600)"
assert_eq "preset_label 7200 → 2 hours" "2 hours" "$(preset_label 7200)"
assert_eq "preset_label 65 → 65 sec" "65 sec" "$(preset_label 65)"
# preset_arg must NEVER emit bare seconds — parse_duration treats a bare int as MINUTES
assert_eq "preset_arg 900 → 15m (not 900!)" "15m" "$(preset_arg 900)"
assert_eq "preset_arg 3600 → 1h" "1h" "$(preset_arg 3600)"
assert_eq "preset_arg 7200 → 2h" "2h" "$(preset_arg 7200)"
assert_eq "preset_arg 65 → 65s" "65s" "$(preset_arg 65)"

# Reporter scenario (#6): a user config that drops the 900 preset must drop "15 min"
_HC_REPORTER_CFG="${TEST_STATE_DIR}/reporter.yaml"
printf 'timeouts:\n  presets:\n    - 1800\n    - 3600\n    - 7200\n' > "${_HC_REPORTER_CFG}"
HYPRCAFFEINE_CONFIG_FILE="${_HC_REPORTER_CFG}" config_reload
mapfile -t _rep < <(config_get_array "timeouts.presets")
assert_eq "reporter presets = 1800 3600 7200 (900 dropped)" "1800 3600 7200" "${_rep[*]}"
rm -f "${_HC_REPORTER_CFG}"
config_reload  # restore default cache for any later reads

# Test missing key
missing=$(config_get "nonexistent.key")
assert_eq "missing key → empty" "" "$missing"

# Test config_set_runtime
config_set_runtime "theme.accent" "#ff0000"
new_accent=$(config_get "theme.accent")
assert_eq "runtime override accent" "#ff0000" "$new_accent"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── menu render (#5: no trailing blank option) ──${C_RESET}"

_count_empty() { awk '/^$/{c++} END{print c+0}'; }

# The menu renders items with `printf '%s\n' "${arr[@]}"`. That must emit exactly
# N lines with NO trailing empty line — a trailing empty line becomes a blank,
# selectable dmenu option (the bug in #5).
_HC_ITEMS=("󰔛 15 min" "󰔛 30 min" "󰔛 1 hour" "󰔛 Infinite" "────" "󰍹 Display" "󰌢 Lid")
assert_eq "render: total lines == items" "${#_HC_ITEMS[@]}" "$(printf '%s\n' "${_HC_ITEMS[@]}" | wc -l)"
assert_eq "render: 0 empty lines (no blank option)" "0" "$(printf '%s\n' "${_HC_ITEMS[@]}" | _count_empty)"
assert_eq "single item: 0 empty lines" "0" "$(printf '%s\n' "solo" | _count_empty)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── keybinds detection (#4: by config file, not version) ──${C_RESET}"

# _kb_get_paths reads the _KB_HYPRLAND_DIR global at call time, so override it
# per scenario to simulate each config-file state. The decision must NOT depend
# on the Hyprland version: a hyprland.conf user on Hyprland ≥0.55 must stay on
# the hyprlang path (the bug in #4).
_KD="$(mktemp -d)"

: > "$_KD/hyprland.conf"
_KB_HYPRLAND_DIR="$_KD"; _kb_get_paths
assert_eq "only hyprland.conf → hyprlang" "hyprlang" "${FORMAT}"
assert_eq "  → writes .conf" "hyprcaffeine-keybinds.conf" "$(basename "${KEYBINDS_FILE}")"

: > "$_KD/hyprland.lua"
_KB_HYPRLAND_DIR="$_KD"; _kb_get_paths
assert_eq "hyprland.lua added → lua" "lua" "${FORMAT}"
assert_eq "  → writes .lua" "hyprcaffeine-keybinds.lua" "$(basename "${KEYBINDS_FILE}")"

rm -f "$_KD/hyprland.conf"
_KB_HYPRLAND_DIR="$_KD"; _kb_get_paths
assert_eq "only hyprland.lua → lua" "lua" "${FORMAT}"

rm -f "$_KD/hyprland.lua"
_KB_HYPRLAND_DIR="$_KD"; _kb_get_paths
assert_eq "no config file → hyprlang (safe default)" "hyprlang" "${FORMAT}"

rm -rf "$_KD"
_KB_HYPRLAND_DIR="${HOME}/.config/hypr"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── notify.sh ──${C_RESET}"

# These just need to not error
assert_ok "notify_send no error" notify_send "Test" "Body"
assert_ok "notify_error no error" notify_error "Test error"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── watcher.auto file ──${C_RESET}"

# Simulate watcher auto flag file
AUTO_FILE="$TEST_STATE_DIR/watcher.auto"
echo "true" > "$AUTO_FILE"
assert_eq "auto file reads true" "true" "$(cat "$AUTO_FILE")"
echo "false" > "$AUTO_FILE"
assert_eq "auto file reads false" "false" "$(cat "$AUTO_FILE")"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── polkit rules template ──${C_RESET}"

POLKIT_TEMPLATE="${SCRIPT_DIR}/config/polkit.rules"
assert_ok "polkit template exists" test -f "$POLKIT_TEMPLATE"
assert_file_contains "polkit has inhibit action" "$POLKIT_TEMPLATE" "org.freedesktop.login1.inhibit"
assert_file_contains "polkit has placeholder" "$POLKIT_TEMPLATE" "USER_PLACEHOLDER"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── PKGBUILD version check ──${C_RESET}"

PKGBUILD="${SCRIPT_DIR}/PKGBUILD"
assert_ok "PKGBUILD exists" test -f "$PKGBUILD"
assert_file_contains "PKGBUILD has pkgver" "$PKGBUILD" "pkgver="
assert_file_contains "PKGBUILD has socat dep" "$PKGBUILD" "socat"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "${C_YELLOW}── docs & scripts mention rofi ──${C_RESET}"

README_FILE="${SCRIPT_DIR}/README.md"
CLAUDE_FILE="${SCRIPT_DIR}/CLAUDE.md"
assert_file_contains "README mentions rofi" "$README_FILE" "rofi"
assert_file_contains "CLAUDE mentions rofi" "$CLAUDE_FILE" "rofi"

SCRIPT_CM="${SCRIPT_DIR}/scripts/caffeine-menu.sh"
SCRIPT_UI="${SCRIPT_DIR}/scripts/ui-engine.sh"
assert_file_contains "caffeine-menu.sh references rofi" "$SCRIPT_CM" "command -v rofi"
assert_file_contains "ui-engine.sh references rofi" "$SCRIPT_UI" "command -v rofi"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
echo ""
echo -e "${C_YELLOW}═══════════════════════════════════${C_RESET}"
echo -e "  Total:  ${TOTAL}"
echo -e "  ${C_GREEN}Pass:   ${PASS}${C_RESET}"
echo -e "  ${C_RED}Fail:   ${FAIL}${C_RESET}"
echo -e "${C_YELLOW}═══════════════════════════════════${C_RESET}"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo -e "${C_RED}Some tests failed!${C_RESET}"
    exit 1
fi

echo ""
echo -e "${C_GREEN}All tests passed!${C_RESET}"
exit 0
