#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Configuration Loader
# Simple YAML parsing without yq dependency. Uses grep/sed/awk.
# Config path:  ~/.config/hyprcaffeine/config.yaml
# Default path: <repo>/config/default.yaml
# =============================================================================

# --- Paths ---
HYPRCAFFEINE_CONFIG_DIR="${HOME}/.config/hyprcaffeine"
HYPRCAFFEINE_CONFIG_FILE="${HYPRCAFFEINE_CONFIG_DIR}/config.yaml"
HYPRCAFFEINE_CONFIG_DEFAULT=""  # Set dynamically below

# Resolve default config relative to script location
_resolve_config_default() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root="${script_dir}/.."
    local default_path="${repo_root}/config/default.yaml"

    if [[ -f "${default_path}" ]]; then
        HYPRCAFFEINE_CONFIG_DEFAULT="${default_path}"
    fi
}
_resolve_config_default

# --- Internal: loaded config cache ---
_HC_CONFIG_LOADED=false

# =============================================================================
# config_default — Print default configuration values.
#   Used as fallback when no config file exists.
# =============================================================================
config_default() {
    cat <<'DEFAULTS'
theme:
  accent: "#89b4fa"
  border: "rounded"

timeouts:
  default: 1800

notifications:
  enabled: true

automation:
  fullscreen: false
  audio: false
DEFAULTS
}

# =============================================================================
# config_load — Load configuration, falling back to defaults.
#   Caches the result in memory for subsequent calls.
# =============================================================================
_HC_CONFIG_DATA=""

config_load() {
    if [[ "${_HC_CONFIG_LOADED}" == "true" ]]; then
        return 0
    fi

    # Prefer user config, fall back to default config, then built-in defaults
    if [[ -f "${HYPRCAFFEINE_CONFIG_FILE}" ]]; then
        _HC_CONFIG_DATA="$(cat "${HYPRCAFFEINE_CONFIG_FILE}")"
    elif [[ -n "${HYPRCAFFEINE_CONFIG_DEFAULT}" ]] && [[ -f "${HYPRCAFFEINE_CONFIG_DEFAULT}" ]]; then
        _HC_CONFIG_DATA="$(cat "${HYPRCAFFEINE_CONFIG_DEFAULT}")"
    else
        _HC_CONFIG_DATA="$(config_default)"
    fi

    _HC_CONFIG_LOADED=true
}

# =============================================================================
# config_get <dotted.key> — Get a config value by dotted key path.
#   Example: config_get "theme.accent"  →  #89b4fa
#   Simple YAML parsing: handles flat and one-level-nested keys.
#   Returns empty string if key not found.
# =============================================================================
config_get() {
    local key="$1"
    local result=""

    config_load

    # Split key into parent and child
    local parent="" child="${key}"
    if [[ "${key}" == *"."* ]]; then
        parent="${key%%.*}"
        child="${key#*.}"
    fi

    if [[ -n "${parent}" ]]; then
        # Nested key: find the parent section, then the child value
        local in_section=false
        while IFS= read -r line; do
            # Strip comments
            line="${line%%#*}"
            # Trim leading/trailing whitespace
            line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            [[ -z "${line}" ]] && continue

            # Check for section header
            if [[ "${line}" == "${parent}:" ]]; then
                in_section=true
                continue
            fi

            # If in the target section, look for the child key
            if [[ "${in_section}" == "true" ]]; then
                # Detect end of section (new top-level key without indent)
                if [[ "${line}" != *":"* ]] || [[ "${line}" =~ ^[a-zA-Z] ]]; then
                    # This is a new top-level section, we've left our target
                    break
                fi

                # Strip leading whitespace for matching
                local stripped
                stripped="$(echo "${line}" | sed 's/^[[:space:]]*//')"

                if [[ "${stripped}" == "${child}:"* ]]; then
                    result="${stripped#*:}"
                    # Trim whitespace and quotes
                    result="$(echo "${result}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^["'"'"']//;s/["'"'"']$//')"
                    break
                fi
            fi
        done <<< "${_HC_CONFIG_DATA}"
    else
        # Top-level key
        while IFS= read -r line; do
            line="${line%%#*}"
            line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ -z "${line}" ]] && continue

            if [[ "${line}" == "${child}:"* ]]; then
                result="${line#*:}"
                result="$(echo "${result}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^["'"'"']//;s/["'"'"']$//')"
                break
            fi
        done <<< "${_HC_CONFIG_DATA}"
    fi

    echo "${result}"
}

# =============================================================================
# config_set_runtime <key> <value> — Override a config value in memory.
#   Does not write to disk. Useful for CLI overrides.
# =============================================================================
config_set_runtime() {
    local key="$1"
    local value="$2"

    config_load

    local parent="" child="${key}"
    if [[ "${key}" == *"."* ]]; then
        parent="${key%%.*}"
        child="${key#*.}"
    fi

    # Simple find-and-replace in the cached config data
    if [[ -n "${parent}" ]]; then
        # Replace nested key value
        local escaped_child
        escaped_child="$(echo "${child}" | sed 's/[.[\*^$()+?{|\\]/\\&/g')"
        local escaped_value
        escaped_value="$(echo "${value}" | sed 's/[&/\]/\\&/g')"

        _HC_CONFIG_DATA="$(echo "${_HC_CONFIG_DATA}" | \
            sed -E "/^[[:space:]]*${escaped_child}:/s/:.*/: \"${escaped_value}\"/")"
    else
        local escaped_child
        escaped_child="$(echo "${child}" | sed 's/[.[\*^$()+?{|\\]/\\&/g')"
        local escaped_value
        escaped_value="$(echo "${value}" | sed 's/[&/\]/\\&/g')"

        _HC_CONFIG_DATA="$(echo "${_HC_CONFIG_DATA}" | \
            sed -E "/^${escaped_child}:/s/:.*/: \"${escaped_value}\"/")"
    fi
}
