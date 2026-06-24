#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Configuration Loader
# Robust YAML parsing using awk. Handles 2-level nesting, scalars, and lists.
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
_HC_CONFIG_DATA=""

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
# config_reload — Force reload configuration from disk.
# =============================================================================
config_reload() {
    _HC_CONFIG_LOADED=false
    _HC_CONFIG_DATA=""
    config_load
}

# =============================================================================
# _yaml_parse_awk — Core awk-based YAML parser.
#   Parses simple 2-level YAML into flat "parent.child  value" lines.
#   - List items (lines starting with "  - ") are collected under their parent
#     key and emitted as a single comma-separated line.
#   - Inline comments are stripped.
#   - Quotes around values are removed.
#   - Empty list "[]" is treated as an empty value.
#
#   Output format (one line per key):
#     topkey          value            (for top-level scalars)
#     parent.child    value            (for nested scalars)
#     parent.key      v1,v2,v3         (for list values)
# =============================================================================
_yaml_parse_awk() {
    awk '
    function trim(s) {
        sub(/^[[:space:]]+/, "", s)
        sub(/[[:space:]]+$/, "", s)
        return s
    }
    function unquote(s) {
        if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/ ) {
            s = substr(s, 2, length(s) - 2)
        }
        return s
    }
    function strip_comment(s,    out, in_q, q_char, i, ch) {
        # Remove inline # comment, but not inside quotes
        out = ""
        in_q = 0
        q_char = ""
        for (i = 1; i <= length(s); i++) {
            ch = substr(s, i, 1)
            if (!in_q) {
                if (ch == "\"" || ch == "'\''") {
                    in_q = 1
                    q_char = ch
                    out = out ch
                } else if (ch == "#") {
                    break
                } else {
                    out = out ch
                }
            } else {
                out = out ch
                if (ch == q_char) {
                    in_q = 0
                }
            }
        }
        return trim(out)
    }
    function flush_list() {
        if (list_key != "" && list_buf != "") {
            # Remove trailing comma
            sub(/,$/, "", list_buf)
            printf "%s.%s\t%s\n", section, list_key, list_buf
        }
        list_key = ""
        list_buf = ""
    }
    {
        # --- Strip comments (outside quotes) ---
        line = $0

        # Fast path: no # at all
        if (index(line, "#") == 0) {
            stripped = trim(line)
        } else {
            stripped = strip_comment(line)
        }

        if (stripped == "") next

        # Detect indentation
        indent = match($0, /[^ ]/) - 1
        if (indent < 0) indent = 0

        # --- Top-level key: value ---
        if (indent == 0 && stripped ~ /^[a-zA-Z_][a-zA-Z0-9_]*:/) {
            flush_list()

            colon_pos = index(stripped, ":")
            section = substr(stripped, 1, colon_pos - 1)
            val = trim(substr(stripped, colon_pos + 1))
            val = unquote(val)

            if (val == "[]") {
                # Empty list marker
                printf "%s\t\n", section
            } else if (val != "") {
                printf "%s\t%s\n", section, val
            }
            next
        }

        # --- List item: "  - value" ---
        if (stripped ~ /^- /) {
            val = trim(substr(stripped, 3))
            val = unquote(val)

            # If this is a new list key (first item after parent.key:)
            if (list_key != "") {
                list_buf = list_buf val ","
            }
            next
        }

        # --- Nested key: value ---
        if (indent > 0 && stripped ~ /^[a-zA-Z_][a-zA-Z0-9_]*:/) {
            flush_list()

            colon_pos = index(stripped, ":")
            child = substr(stripped, 1, colon_pos - 1)
            val = trim(substr(stripped, colon_pos + 1))
            val = unquote(val)

            if (val == "[]") {
                # Empty list
                printf "%s.%s\t\n", section, child
            } else if (val != "") {
                printf "%s.%s\t%s\n", section, child, val
            } else {
                # Key with no value — could be a list container
                list_key = child
                list_buf = ""
            }
            next
        }
    }
    END {
        flush_list()
    }
    '
}

# =============================================================================
# _hc_lookup <flat_key> — Look up a parsed key in the cached config.
#   Uses awk on the cached YAML data. Returns the raw value (or empty).
# =============================================================================
_hc_lookup() {
    local target_key="$1"
    config_load
    echo "${_HC_CONFIG_DATA}" | _yaml_parse_awk | awk -F'\t' -v k="${target_key}" '
        $1 == k { print $2; exit }
    '
}

# =============================================================================
# config_get <dotted.key> — Get a config scalar value by dotted key path.
#   Example: config_get "theme.accent"  →  #89b4fa
#            config_get "timeouts.default"  →  1800
#   For keys that hold lists, returns the comma-separated string.
#   Returns empty string if key not found.
# =============================================================================
config_get() {
    local key="$1"
    _hc_lookup "${key}"
}

# =============================================================================
# config_get_array <dotted.key> — Get a config list value as separate words.
#   Prints one item per line (newline-separated), suitable for mapfile/readarray.
#   Example:
#     mapfile -t presets < <(config_get_array "timeouts.presets")
#     # presets = (900 1800 3600 7200)
#   Returns nothing (empty output) if key is missing or value is empty.
# =============================================================================
config_get_array() {
    local key="$1"
    local value
    value="$(_hc_lookup "${key}")"

    if [[ -n "${value}" ]]; then
        # Split comma-separated value into one item per line
        local IFS=','
        local -a items
        read -ra items <<< "${value}"
        for item in "${items[@]}"; do
            # Trim whitespace from each item
            item="$(echo "${item}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ -n "${item}" ]] && echo "${item}"
        done
    fi
}

# =============================================================================
# preset helpers — format timeout-preset seconds (from timeouts.presets).
# Shared by the Bash menu (caffeine-menu.sh / ui-engine.sh) so both render the
# user's configured presets identically.
# =============================================================================

# preset_label <seconds> -> human menu label.
#   900 -> "15 min", 3600 -> "1 hour", 7200 -> "2 hours", 65 -> "65 sec"
preset_label() {
    local sec="$1"
    if (( sec % 3600 == 0 )); then
        local h=$(( sec / 3600 ))
        (( h == 1 )) && echo "1 hour" || echo "${h} hours"
    elif (( sec % 60 == 0 )); then
        echo "$(( sec / 60 )) min"
    else
        echo "${sec} sec"
    fi
}

# preset_arg <seconds> -> a single-unit duration token parse_duration accepts.
#   IMPORTANT: parse_duration treats a BARE number as minutes, so we must never
#   pass raw seconds. Always emit a single unit: Xh / Xm / Xs.
preset_arg() {
    local sec="$1"
    if (( sec % 3600 == 0 )); then echo "$(( sec / 3600 ))h"
    elif (( sec % 60 == 0 )); then echo "$(( sec / 60 ))m"
    else echo "${sec}s"; fi
}

# =============================================================================
# config_set_runtime <key> <value> — Override a config value in memory.
#   Does not write to disk. Useful for CLI overrides.
#   Handles dotted keys (e.g. "theme.accent") and top-level keys.
#   For list keys, accepts a comma-separated value string.
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

    # Build the awk program to perform the replacement
    if [[ -n "${parent}" ]]; then
        # --- Nested key replacement ---
        # We need to find "  child:" under the correct "parent:" section
        # and replace its value. Also handle list keys (child: with no value)
        # by converting to scalar form.
        local escaped_child escaped_value
        escaped_child="${child}"
        escaped_value="${value}"
        # Escape for awk regex
        gawk_escaped_child="$(printf '%s' "${escaped_child}" | sed 's/[.[\*^$()+?{|\\]/\\&/g')"
        # Escape for awk replacement string
        gawk_escaped_value="$(printf '%s' "${escaped_value}" | sed 's/[&\\]/\\&/g')"

        _HC_CONFIG_DATA="$(echo "${_HC_CONFIG_DATA}" | awk -v child="${gawk_escaped_child}" -v val="${gawk_escaped_value}" '
            function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }

            # Match indented child key (scalar or list header)
            /^[[:space:]]+/ && $0 ~ child":" {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                if (line ~ "^" child ":") {
                    # Replace the value part (everything after the colon)
                    sub(/:.*$/, ": \"" val "\"")
                    print
                    # Skip any list items that follow this key
                    skip_list = 1
                    next
                }
            }

            # Skip list items belonging to the replaced key
            skip_list == 1 && /^[[:space:]]+- / {
                next
            }

            # Reset skip flag when we hit a non-list indented line or new section
            {
                skip_list = 0
                print
            }
        ')"
    else
        # --- Top-level key replacement ---
        local escaped_child escaped_value
        escaped_child="${child}"
        escaped_value="${value}"
        gawk_escaped_child="$(printf '%s' "${escaped_child}" | sed 's/[.[\*^$()+?{|\\]/\\&/g')"
        gawk_escaped_value="$(printf '%s' "${escaped_value}" | sed 's/[&\\]/\\&/g')"

        _HC_CONFIG_DATA="$(echo "${_HC_CONFIG_DATA}" | awk -v k="${gawk_escaped_child}" -v val="${gawk_escaped_value}" '
            /^[a-zA-Z_]/ && $0 ~ "^" k ":" {
                sub(/:.*$/, ": \"" val "\"")
            }
            { print }
        ')"
    fi
}

# =============================================================================
# config_set_runtime_array <key> <val1> [<val2> ...] — Override a list in memory.
#   Converts the arguments into a YAML list under the given dotted key.
#   Does not write to disk.
# =============================================================================
config_set_runtime_array() {
    local key="$1"
    shift

    config_load

    local parent="" child="${key}"
    if [[ "${key}" == *"."* ]]; then
        parent="${key%%.*}"
        child="${key#*.}"
    fi

    # Build YAML list text
    local list_yaml=""
    for item in "$@"; do
        list_yaml="${list_yaml}    - ${item}"$'\n'
    done

    if [[ -n "${parent}" ]]; then
        local gawk_escaped_child
        gawk_escaped_child="$(printf '%s' "${child}" | sed 's/[.[\*^$()+?{|\\]/\\&/g')"
        local gawk_list_yaml
        # Escape for awk substitution
        gawk_list_yaml="$(printf '%s' "${list_yaml}" | sed 's/[&\\]/\\&/g')"

        _HC_CONFIG_DATA="$(echo "${_HC_CONFIG_DATA}" | awk -v child="${gawk_escaped_child}" -v listyaml="${gawk_list_yaml}" '
            function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }

            /^[a-zA-Z_]/ && /:$/ {
                current_section = $0
                sub(/:.*$/, "", current_section)
                current_section = trim(current_section)
            }

            /^[[:space:]]+/ && $0 ~ child":" {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                if (line ~ "^" child ":") {
                    # Replace with list header
                    sub(/:.*$/, ":")
                    print
                    print listyaml
                    skip_list = 1
                    next
                }
            }

            skip_list == 1 && /^[[:space:]]+- / { next }
            { skip_list = 0; print }
        ')"
    fi
}
