#!/usr/bin/env bash
# keybinds.sh — HyprCaffeine keybinding management for Hyprland
# Creates/removes keybinds with version-aware config format:
#   Hyprland < 0.55 → Hyprlang (.conf + source =)
#   Hyprland ≥ 0.55 → Lua (.lua + require())
#
# Keybinds:
#   SUPER + CTRL + I       → hyprcaffeine toggle        (toggle infinite idle)
#   SUPER + CTRL + SHIFT + I → hyprcaffeine menu        (show Walker menu)
#   SUPER + CTRL + SHIFT + D → hyprcaffeine lid toggle   (toggle tapa)
#   SUPER + CTRL + D       → hyprcaffeine monitor toggle (toggle pantalla)

set -uo pipefail

# ── Hyprland Version Detection (informational only) ──────────────────────────
# The version is shown in install/status output for diagnostics only. It does NOT
# decide the config format anymore — format is chosen by which config the user
# actually has on disk (see _kb_is_lua). Tracking version for the decision broke
# users on Hyprland ≥0.55 who still use hyprland.conf (issue #4).

# Returns: 0.54, 0.55, 0.56, etc. or "0.0" if not found
_kb_get_version() {
    local ver=""
    # Try hyprctl version first (needs running instance)
    if command -v hyprctl &>/dev/null; then
        ver="$(hyprctl version 2>/dev/null | grep -oP 'Hyprland \K[0-9]+\.[0-9]+' | head -1)"
    fi
    # Fallback to hyprland --version (binary, no running instance needed)
    if [[ -z "${ver}" ]] && command -v hyprland &>/dev/null; then
        ver="$(hyprland --version 2>/dev/null | grep -oP 'Hyprland \K[0-9]+\.[0-9]+' | head -1)"
    fi
    echo "${ver:-0.0}"
}

# ── Config Format Detection ───────────────────────────────────────────────────
# Decide hyprlang vs Lua based on which config the user ACTUALLY has on disk,
# NOT on the Hyprland version. A user on Hyprland ≥0.55 who still uses
# hyprland.conf must NOT be forced onto the Lua path: that writes
# hyprcaffeine-keybinds.lua plus a require() line into a hyprland.lua that
# Hyprland never reads, so the keybinds silently fail to load (issue #4).
#
# Hyprland's Lua entry point is hyprland.lua (mirrors hyprland.conf); extra
# modules are pulled in with require(), e.g. require("hyprcaffeine-keybinds").

_KB_HYPRLAND_DIR="${HOME}/.config/hypr"

# Returns: success (0) if the user has a Lua config (hyprland.lua), fail (1) otherwise.
_kb_is_lua() {
    [[ -f "${_KB_HYPRLAND_DIR}/hyprland.lua" ]]
}

# ── Determine Paths ───────────────────────────────────────────────────────────

_kb_get_paths() {
    if _kb_is_lua; then
        KEYBINDS_FILE="${_KB_HYPRLAND_DIR}/hyprcaffeine-keybinds.lua"
        HYPRLAND_CONF="${_KB_HYPRLAND_DIR}/hyprland.lua"
        SOURCE_LINE='require("hyprcaffeine-keybinds")'
        FORMAT="lua"
    else
        KEYBINDS_FILE="${_KB_HYPRLAND_DIR}/hyprcaffeine-keybinds.conf"
        HYPRLAND_CONF="${_KB_HYPRLAND_DIR}/hyprland.conf"
        SOURCE_LINE="source = ~/.config/hypr/hyprcaffeine-keybinds.conf"
        FORMAT="hyprlang"
    fi
}

# ── Generate Keybinding Content ──────────────────────────────────────────────
# Uses full path to hyprcaffeine so Hyprland can find it regardless of PATH

_kb_generate() {
    _kb_get_paths

    # Resolve full path to hyprcaffeine
    local hc_path
    if command -v hyprcaffeine &>/dev/null; then
        hc_path="$(command -v hyprcaffeine)"
    else
        # Fallback: check common locations
        for p in "${HOME}/.local/bin/hyprcaffeine" "/usr/bin/hyprcaffeine"; do
            if [[ -x "${p}" ]]; then
                hc_path="${p}"
                break
            fi
        done
    fi
    hc_path="${hc_path:-hyprcaffeine}"

    if [[ "${FORMAT}" == "lua" ]]; then
        cat << LUA
-- HyprCaffeine Keybinds (v0.9.0) ──────────────────────────────────────────
-- SUPER + CTRL + I       → Toggle infinite idle (on/off)
-- SUPER + CTRL + SHIFT + I → Show Walker menu
-- SUPER + CTRL + SHIFT + D → Toggle lid inhibit
-- SUPER + CTRL + D       → Toggle monitor keep-awake

hl.bind("SUPER + CTRL + I",         hl.dsp.exec_cmd("${hc_path} toggle"))
hl.bind("SUPER + CTRL + SHIFT + I", hl.dsp.exec_cmd("${hc_path} menu"))
hl.bind("SUPER + CTRL + SHIFT + D", hl.dsp.exec_cmd("${hc_path} lid toggle"))
hl.bind("SUPER + CTRL + D",         hl.dsp.exec_cmd("${hc_path} monitor toggle"))
LUA
    else
        cat << CONF
# ── HyprCaffeine Keybinds (v0.9.0) ──────────────────────────────────────────
# SUPER + CTRL + I       → Toggle infinite idle (on/off)
# SUPER + CTRL + SHIFT + I → Show Walker menu
# SUPER + CTRL + SHIFT + D → Toggle lid inhibit
# SUPER + CTRL + D       → Toggle monitor keep-awake
#
# NOTE: inserted at END of hyprland.conf so these take priority over
# any pre-existing binds with the same key combinations.
# ─────────────────────────────────────────────────────────────────────────────

bind = SUPER CTRL, I, exec, ${hc_path} toggle
bind = SUPER CTRL SHIFT, I, exec, ${hc_path} menu
bind = SUPER CTRL SHIFT, D, exec, ${hc_path} lid toggle
bind = SUPER CTRL, D, exec, ${hc_path} monitor toggle
CONF
    fi
}

# ── Add source/require to hyprland config ────────────────────────────────────
# Appends at the end so HyprCaffeine keybinds take priority

_kb_add_source() {
    # Remove any existing source/require line to avoid duplicates
    if grep -qF "${SOURCE_LINE}" "${HYPRLAND_CONF}" 2>/dev/null; then
        sed -i "\|${SOURCE_LINE}|d" "${HYPRLAND_CONF}"
    fi

    # Append at the end
    echo "" >> "${HYPRLAND_CONF}"
    echo "${SOURCE_LINE}" >> "${HYPRLAND_CONF}"
    echo "  ✓ Appended to end of ${HYPRLAND_CONF}"
}

# ── Remove source/require from hyprland config ───────────────────────────────

_kb_remove_source() {
    if [[ -f "${HYPRLAND_CONF}" ]] && grep -qF "${SOURCE_LINE}" "${HYPRLAND_CONF}" 2>/dev/null; then
        sed -i "\|${SOURCE_LINE}|d" "${HYPRLAND_CONF}"
        return 0
    fi
    return 1
}

# ── Omarchy Conflict Resolution ─────────────────────────────────────────────
# If Omarchy has conflicting keybinds, comment them so HyprCaffeine takes over

_KB_OMARCHY_CONFLICTS=(
    "SUPER CTRL, I"
    "SUPER CTRL SHIFT, I"
    "SUPER CTRL SHIFT, D"
    "SUPER CTRL, D"
)

_kb_resolve_omarchy_conflicts() {
    local omarchy_dir="${HOME}/.local/share/omarchy"
    local resolved=0

    # Check multiple Omarchy binding locations
    for conf in \
        "${omarchy_dir}/default/hypr/bindings/"*.conf \
        "${omarchy_dir}/config/hypr/bindings.conf" \
        "${omarchy_dir}/config/hypr/hyprland.conf"; do

        [[ -f "${conf}" ]] || continue

        local modified=false
        for combo in "${_KB_OMARCHY_CONFLICTS[@]}"; do
            # Match lines like: bindd = SUPER CTRL, I, ... or bind = SUPER CTRL, I, ...
            # But NOT already commented lines or hyprcaffeine's own binds
            while IFS= read -r line; do
                local lineno
                lineno=$(echo "$line" | cut -d: -f1)
                local content
                content=$(echo "$line" | cut -d: -f2-)

                # Skip if already commented or is hyprcaffeine's own file
                if echo "$content" | grep -qE '^\s*#' || echo "$content" | grep -qi 'hyprcaffeine'; then
                    continue
                fi

                # Comment it out
                sed -i "${lineno}s/^/# /" "${conf}"
                echo "  🔄 Commented Omarchy bind at ${conf##*/}:${lineno} (${combo})"
                modified=true
                resolved=$((resolved + 1))
            done < <(grep -n "bind.*${combo}," "${conf}" 2>/dev/null || true)
        done

        if [[ "${modified}" == true ]]; then
            echo "  ✓ Conflicts resolved: ${conf}"
        fi
    done

    return "${resolved}"
}

# ── Install ───────────────────────────────────────────────────────────────────

_kb_install() {
    _kb_get_paths
    local version
    version="$(_kb_get_version)"

    echo "  Hyprland: ${version} → ${FORMAT} format"

    mkdir -p "$(dirname "${KEYBINDS_FILE}")"

    # ALWAYS resolve Omarchy conflicts, regardless of whether keybinds are up-to-date
    _kb_resolve_omarchy_conflicts

    # Check if already installed and up-to-date
    if [[ -f "${KEYBINDS_FILE}" ]]; then
        local current
        current="$(_kb_generate)"
        if [[ "$(cat "${KEYBINDS_FILE}")" == "${current}" ]]; then
            echo "  ✓ Keybinds already installed and up-to-date"
            return 0
        fi
    fi

    _kb_generate > "${KEYBINDS_FILE}"
    echo "  ✓ Created ${KEYBINDS_FILE}"

    # Source/require from hyprland config
    if [[ -f "${HYPRLAND_CONF}" ]]; then
        _kb_add_source
    else
        echo "  ⚠ ${HYPRLAND_CONF} not found — keybinds file created but not sourced"
        echo "    Add this line to the END of your hyprland config:"
        echo "    ${SOURCE_LINE}"
    fi

    # Reload Hyprland config
    if command -v hyprctl &>/dev/null; then
        # Ensure HYPRLAND_INSTANCE_SIGNATURE is set (workaround for SSH sessions)
        if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            local hypr_sig
            hypr_sig="$(ls /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)"
            if [[ -n "${hypr_sig}" ]]; then
                export HYPRLAND_INSTANCE_SIGNATURE="${hypr_sig}"
            fi
        fi
        hyprctl reload 2>/dev/null && echo "  ✓ Hyprland config reloaded" || echo "  ⚠ Could not reload Hyprland (session not running?)"
    fi

    echo ""
    echo "  Keybinds installed (${FORMAT}):"
    echo "    SUPER + CTRL + I         → Toggle infinite idle"
    echo "    SUPER + CTRL + SHIFT + I → Show Walker menu"
    echo "    SUPER + CTRL + SHIFT + D → Toggle lid inhibit"
    echo "    SUPER + CTRL + D         → Toggle monitor keep-awake"
}

# ── Remove ────────────────────────────────────────────────────────────────────

_kb_restore_omarchy() {
    local omarchy_dir="${HOME}/.local/share/omarchy"
    local restored=0

    for conf in \
        "${omarchy_dir}/default/hypr/bindings/"*.conf \
        "${omarchy_dir}/config/hypr/bindings.conf" \
        "${omarchy_dir}/config/hypr/hyprland.conf"; do

        [[ -f "${conf}" ]] || continue

        local modified=false
        for combo in "${_KB_OMARCHY_CONFLICTS[@]}"; do
            # Uncomment lines that were commented by hyprcaffeine
            while IFS= read -r line; do
                local lineno
                lineno=$(echo "$line" | cut -d: -f1)
                local content
                content=$(echo "$line" | cut -d: -f2-)

                # Only uncomment if it's a commented bind line (added by us)
                if echo "$content" | grep -qE '^\s*#\s+bind'; then
                    sed -i "${lineno}s/^\s*#\s*//" "${conf}"
                    echo "  🔄 Restored Omarchy bind at ${conf##*/}:${lineno}"
                    modified=true
                    restored=$((restored + 1))
                fi
            done < <(grep -n "#.*bind.*${combo}," "${conf}" 2>/dev/null || true)
        done

        if [[ "${modified}" == true ]]; then
            echo "  ✓ Restored: ${conf}"
        fi
    done

    return "${restored}"
}

_kb_remove() {
    _kb_get_paths
    local removed=false

    if [[ -f "${KEYBINDS_FILE}" ]]; then
        rm "${KEYBINDS_FILE}"
        echo "  ✓ Removed ${KEYBINDS_FILE}"
        removed=true
    fi

    if _kb_remove_source; then
        echo "  ✓ Removed source line from ${HYPRLAND_CONF}"
        removed=true
    fi

    # Restore Omarchy binds that were commented by hyprcaffeine
    _kb_restore_omarchy

    if [[ "${removed}" == false ]]; then
        echo "  ℹ No HyprCaffeine keybinds found to remove"
        return 0
    fi

    if command -v hyprctl &>/dev/null; then
        # Ensure HYPRLAND_INSTANCE_SIGNATURE is set (workaround for SSH sessions)
        if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            local hypr_sig
            hypr_sig="$(ls /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)"
            if [[ -n "${hypr_sig}" ]]; then
                export HYPRLAND_INSTANCE_SIGNATURE="${hypr_sig}"
            fi
        fi
        hyprctl reload 2>/dev/null && echo "  ✓ Hyprland config reloaded" || echo "  ⚠ Could not reload Hyprland (session not running?)"
    fi

    echo ""
    echo "  Keybinds removed."
}

# ── Status ────────────────────────────────────────────────────────────────────

_kb_status() {
    _kb_get_paths
    local version
    version="$(_kb_get_version)"

    echo "  HyprCaffeine Keybindings Status"
    echo "  Hyprland: ${version} (${FORMAT})"
    echo ""

    if [[ -f "${KEYBINDS_FILE}" ]]; then
        echo "  Config file: ${KEYBINDS_FILE} ✓"
    else
        echo "  Config file: not installed ✗"
    fi

    if [[ -f "${HYPRLAND_CONF}" ]]; then
        if grep -qF "${SOURCE_LINE}" "${HYPRLAND_CONF}" 2>/dev/null; then
            echo "  Sourced from: ${HYPRLAND_CONF} ✓ (at end — takes priority)"
        else
            echo "  Sourced from: not sourced ✗"
        fi
    else
        echo "  Sourced from: ${HYPRLAND_CONF} not found ✗"
    fi

    echo ""
    echo "  Expected keybinds:"
    echo "    SUPER + CTRL + I         → hyprcaffeine toggle"
    echo "    SUPER + CTRL + SHIFT + I → hyprcaffeine menu"
    echo "    SUPER + CTRL + SHIFT + D → hyprcaffeine lid toggle"
    echo "    SUPER + CTRL + D         → hyprcaffeine monitor toggle"
}

# ── Entry Point ──────────────────────────────────────────────────────────────
# When sourced from bin/hyprcaffeine, functions above are available.
# When called directly as a script, dispatch based on first arg.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-status}" in
        install) _kb_install ;;
        remove)  _kb_remove ;;
        status)  _kb_status ;;
        *)
            echo "Usage: $(basename "${0}") <install|remove|status>"
            exit 1
            ;;
    esac
fi
