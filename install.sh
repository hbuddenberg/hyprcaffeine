#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
#  HyprCaffeine — Robust Installer
#  Modern idle inhibition utility for Hyprland
# ─────────────────────────────────────────────────────────
set -euo pipefail

readonly HC_VERSION="1.0.0"
readonly APP_NAME="HyprCaffeine"

# ── Catppuccin Mocha Colors (truecolor ANSI) ─────────────
readonly C_RED='\033[38;2;243;139;168m'      # #f38ba8  Rose
readonly C_PEACH='\033[38;2;250;179;135m'    # #fab387
readonly C_YELLOW='\033[38;2;249;226;175m'   # #f9e2af
readonly C_GREEN='\033[38;2;166;227;161m'    # #a6e3a1
readonly C_BLUE='\033[38;2;137;180;250m'     # #89b4fa
readonly C_MAUVE='\033[38;2;203;166;247m'    # #cba6f7
readonly C_TEAL='\033[38;2;148;226;213m'     # #94e2d5
readonly C_TEXT='\033[38;2;205;214;244m'     # #cdd6f4
readonly C_SURFACE0='\033[38;2;49;50;68m'    # #313244
readonly C_SUBTEXT='\033[38;2;166;173;200m'  # #a6adc8
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_RESET='\033[0m'

# ── Source Paths ─────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SRC_BIN="${SCRIPT_DIR}/bin/hyprcaffeine"
readonly SRC_SCRIPTS="${SCRIPT_DIR}/scripts"
readonly SRC_CONFIG="${SCRIPT_DIR}/config/default.yaml"
readonly SRC_WAYBAR="${SCRIPT_DIR}/waybar/module.json"

# ── User Config Path (always user-owned) ─────────────────
readonly CONFIG_DIR="${HOME}/.config/hyprcaffeine"
readonly CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# ── Install Destinations (resolved dynamically) ──────────
BIN_DIR=""
DATA_DIR=""
INSTALL_MODE=""   # "system" or "user"

# ── Logging Helpers ──────────────────────────────────────
info()    { echo -e "${C_BLUE}[INFO]${C_RESET}  ${C_TEXT}$*${C_RESET}"; }
success() { echo -e "${C_GREEN}[ OK ]${C_RESET}  ${C_TEXT}$*${C_RESET}"; }
warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET}  ${C_TEXT}$*${C_RESET}"; }
error()   { echo -e "${C_RED}[ERR]${C_RESET}   ${C_TEXT}$*${C_RESET}" >&2; }
step()    { echo -e "  ${C_TEAL}➜${C_RESET}  ${C_TEXT}$*${C_RESET}"; }
header()  {
    echo -e ""
    echo -e "${C_MAUVE}${C_BOLD} 󰒲 $*${C_RESET}"
    echo -e "${C_SURFACE0}  ──────────────────────────────────────────${C_RESET}"
    echo -e ""
}
note()    { echo -e "  ${C_DIM}${C_SUBTEXT}$*${C_RESET}"; }

# ── Argument Parsing ─────────────────────────────────────
ARG_UNINSTALL=false
ARG_FORCE=false
ARG_USER=false
ARG_SYSTEM=false
ARG_HELP=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --uninstall|-u)   ARG_UNINSTALL=true; shift ;;
            --force|-f)       ARG_FORCE=true; shift ;;
            --user)           ARG_USER=true; shift ;;
            --system)         ARG_SYSTEM=true; shift ;;
            --help|-h)        ARG_HELP=true; shift ;;
            --version|-v)     echo "${APP_NAME} Installer v${HC_VERSION}"; exit 0 ;;
            *)                error "Unknown option: $1"; show_usage; exit 1 ;;
        esac
    done
}

show_usage() {
    cat <<EOF
${C_TEXT}${C_BOLD}${APP_NAME} Installer v${HC_VERSION}${C_RESET}

${C_TEXT}Usage:${C_RESET}
  ./install.sh [OPTIONS]

${C_TEXT}Options:${C_RESET}
  ${C_TEAL}--uninstall, -u${C_RESET}   Remove ${APP_NAME} from the system
  ${C_TEAL}--system${C_RESET}          Force system-wide install (/usr/local)
  ${C_TEAL}--user${C_RESET}            Force user-local install (~/.local)
  ${C_TEXT}--force, -f${C_RESET}       Overwrite existing files without prompting
  ${C_TEXT}--help, -h${C_RESET}        Show this help message
  ${C_TEXT}--version, -v${C_RESET}     Show installer version

${C_TEXT}Default behavior:${C_RESET}
  Installs system-wide if ${C_TEAL}sudo${C_RESET} is available, otherwise
  falls back to user-local paths (~/.local).
EOF
}

# ── Dependency Check ─────────────────────────────────────
check_deps() {
    header "Checking Dependencies"

    local -a required=("hyprctl" "jq" "notify-send")
    local -a optional=("gum")
    local -a missing=()

    # Required deps
    for dep in "${required[@]}"; do
        if command -v "$dep" &>/dev/null; then
            success "${dep} found"
        else
            error "${dep} NOT found"
            missing+=("$dep")
        fi
    done

    # Optional deps
    for dep in "${optional[@]}"; do
        if command -v "$dep" &>/dev/null; then
            success "${dep} found (optional)"
        else
            warn "${dep} not found — interactive menu will be unavailable"
            note "Install charmbracelet/gum for the full experience"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        error "Missing required dependencies: ${missing[*]}"
        echo ""
        echo -e "  ${C_TEXT}Install on Arch:${C_RESET}"
        echo -e "  ${C_TEAL}sudo pacman -S ${missing[*]}${C_RESET}"
        echo ""
        echo -e "  ${C_TEXT}Install on Ubuntu/Debian:${C_RESET}"
        echo -e "  ${C_TEAL}sudo apt install ${missing[*]}${C_RESET}"
        echo ""
        exit 1
    fi
}

# ── Validate Source Files ────────────────────────────────
validate_source() {
    header "Validating Source Files"

    local ok=true

    if [[ -f "${SRC_BIN}" ]]; then
        success "bin/hyprcaffeine"
    else
        error "bin/hyprcaffeine — NOT FOUND"
        ok=false
    fi

    if [[ -d "${SRC_SCRIPTS}" ]]; then
        local script_count
        script_count=$(find "${SRC_SCRIPTS}" -name "*.sh" | wc -l)
        if [[ "${script_count}" -gt 0 ]]; then
            success "scripts/ (${script_count} libraries)"
        else
            warn "scripts/ — empty directory"
        fi
    else
        error "scripts/ — NOT FOUND"
        ok=false
    fi

    if [[ -f "${SRC_CONFIG}" ]]; then
        success "config/default.yaml"
    else
        warn "config/default.yaml — NOT FOUND (defaults will be used)"
    fi

    if [[ -f "${SRC_WAYBAR}" ]]; then
        success "waybar/module.json"
    else
        note "waybar/module.json — not found (optional)"
    fi

    if [[ "${ok}" == false ]]; then
        echo ""
        error "Required source files are missing."
        error "Make sure you run this from the HyprCaffeine repository root."
        exit 1
    fi
}

# ── Detect Install Mode ──────────────────────────────────
detect_install_mode() {
    if [[ "${ARG_SYSTEM}" == true ]]; then
        INSTALL_MODE="system"
    elif [[ "${ARG_USER}" == true ]]; then
        INSTALL_MODE="user"
    elif [[ "$(id -u)" -eq 0 ]]; then
        INSTALL_MODE="system"
    elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        INSTALL_MODE="system"
    else
        INSTALL_MODE="user"
    fi

    case "${INSTALL_MODE}" in
        system)
            BIN_DIR="/usr/local/bin"
            DATA_DIR="/usr/local/share/hyprcaffeine"
            info "Install mode: ${C_BOLD}system-wide${C_RESET}  (requires sudo)"
            note "Binary:  ${BIN_DIR}/hyprcaffeine"
            note "Data:    ${DATA_DIR}/"
            note "Config:  ${CONFIG_DIR}/  (per-user)"
            ;;
        user)
            BIN_DIR="${HOME}/.local/bin"
            DATA_DIR="${HOME}/.local/share/hyprcaffeine"
            info "Install mode: ${C_BOLD}user-local${C_RESET}  (no sudo required)"
            note "Binary:  ${BIN_DIR}/hyprcaffeine"
            note "Data:    ${DATA_DIR}/"
            note "Config:  ${CONFIG_DIR}/"
            ;;
    esac
}

# ── Helper: elevated copy ────────────────────────────────
elevated_cp() {
    local src="$1"
    local dest="$2"
    if [[ "${INSTALL_MODE}" == "system" ]] && [[ "$(id -u)" -ne 0 ]]; then
        sudo cp "$src" "$dest"
    else
        cp "$src" "$dest"
    fi
}

elevated_mkdir() {
    local dir="$1"
    if [[ "${INSTALL_MODE}" == "system" ]] && [[ "$(id -u)" -ne 0 ]]; then
        sudo mkdir -p "$dir"
    else
        mkdir -p "$dir"
    fi
}

elevated_chmod() {
    local mode="$1"
    local target="$2"
    if [[ "${INSTALL_MODE}" == "system" ]] && [[ "$(id -u)" -ne 0 ]]; then
        sudo chmod "$mode" "$target"
    else
        chmod "$mode" "$target"
    fi
}

elevated_rm() {
    local target="$1"
    if [[ "${INSTALL_MODE}" == "system" ]] && [[ "$(id -u)" -ne 0 ]]; then
        sudo rm -rf "$target"
    else
        rm -rf "$target"
    fi
}

# ── Patch Binary for Correct Script Path ─────────────────
patch_binary_lib_path() {
    local installed_bin="$1"
    local target_data_dir="$2"

    # The binary contains: LIB_DIR="${SCRIPT_DIR}/../scripts"
    # We replace it with the absolute path to the installed data directory
    if [[ "${INSTALL_MODE}" == "system" ]] && [[ "$(id -u)" -ne 0 ]]; then
        sudo sed -i "s|^LIB_DIR=\"\${SCRIPT_DIR}/\.\./scripts\"|LIB_DIR=\"${target_data_dir}\"|" "${installed_bin}"
    else
        sed -i "s|^LIB_DIR=\"\${SCRIPT_DIR}/\.\./scripts\"|LIB_DIR=\"${target_data_dir}\"|" "${installed_bin}"
    fi
}

# ── Install ──────────────────────────────────────────────
do_install() {
    header "Installing ${APP_NAME}"

    # 1. Create directories
    step "Creating directories..."
    elevated_mkdir "${BIN_DIR}"
    elevated_mkdir "${DATA_DIR}"
    mkdir -p "${CONFIG_DIR}"
    success "Directories ready"

    # 2. Install binary
    step "Installing CLI binary..."
    elevated_cp "${SRC_BIN}" "${BIN_DIR}/hyprcaffeine"
    elevated_chmod 755 "${BIN_DIR}/hyprcaffeine"

    # Patch the LIB_DIR so the binary finds its libraries at the installed location
    patch_binary_lib_path "${BIN_DIR}/hyprcaffeine" "${DATA_DIR}"
    success "Binary installed → ${BIN_DIR}/hyprcaffeine"

    # 3. Install script libraries
    step "Installing script libraries..."
    if [[ -d "${SRC_SCRIPTS}" ]]; then
        # Clean old scripts to avoid stale files
        if [[ "${INSTALL_MODE}" == "system" ]] && [[ "$(id -u)" -ne 0 ]]; then
            sudo rm -f "${DATA_DIR}"/*.sh
            sudo cp -r "${SRC_SCRIPTS}/."* "${DATA_DIR}/"
        else
            rm -f "${DATA_DIR}"/*.sh
            cp -r "${SRC_SCRIPTS}/."* "${DATA_DIR}/"
        fi
        local count
        count=$(find "${DATA_DIR}" -name "*.sh" | wc -l)
        success "Scripts installed → ${DATA_DIR}/ (${count} files)"
    fi

    # 4. Install default config (only if none exists)
    step "Installing configuration..."
    if [[ -f "${SRC_CONFIG}" ]]; then
        if [[ ! -f "${CONFIG_FILE}" ]] || [[ "${ARG_FORCE}" == true ]]; then
            cp "${SRC_CONFIG}" "${CONFIG_FILE}"
            success "Config installed → ${CONFIG_FILE}"
        else
            warn "Existing config found at ${CONFIG_FILE} — ${C_BOLD}preserved${C_RESET}"
            note "Use --force to overwrite, or edit manually"
        fi
    else
        note "No default config in source — app will use built-in defaults"
    fi

    # 5. Check PATH
    step "Checking PATH..."
    if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
        warn "${BIN_DIR} is NOT in your PATH"
        echo ""
        echo -e "  ${C_TEXT}Add this to your shell profile (~/.bashrc or ~/.zshrc):${C_RESET}"
        echo -e "  ${C_TEAL}export PATH=\"\${HOME}/.local/bin:\$PATH\"${C_RESET}"
        echo ""
        echo -e "  ${C_TEXT}Then reload:${C_RESET} ${C_TEAL}source ~/.bashrc${C_RESET}"
    else
        success "${BIN_DIR} is in PATH"
    fi

    # 6. Summary
    echo ""
    echo -e "${C_GREEN}${C_BOLD}  ✅ ${APP_NAME} installed successfully!${C_RESET}"
    echo ""
    echo -e "  ${C_TEXT}Run:${C_RESET}  ${C_TEAL}hyprcaffeine --help${C_RESET}"
    echo -e "  ${C_TEXT}Quick:${C_RESET} ${C_TEAL}hyprcaffeine on 30m${C_RESET}"

    # 7. Waybar integration hint
    header "Waybar Integration"
    echo -e "  ${C_TEXT}Add to your Waybar config:${C_RESET}"
    echo ""
    echo -e "  ${C_TEAL}\"custom/hyprcaffeine\": {${C_RESET}"
    echo -e "  ${C_TEAL}  \"exec\": \"hyprcaffeine waybar\",${C_RESET}"
    echo -e "  ${C_TEAL}  \"on-click\": \"hyprcaffeine toggle\",${C_RESET}"
    echo -e "  ${C_TEAL}  \"on-click-right\": \"hyprcaffeine off\",${C_RESET}"
    echo -e "  ${C_TEAL}  \"on-click-middle\": \"hyprcaffeine menu\",${C_RESET}"
    echo -e "  ${C_TEAL}  \"interval\": 1,${C_RESET}"
    echo -e "  ${C_TEAL}  \"return-type\": \"json\"${C_RESET}"
    echo -e "  ${C_TEAL}}${C_RESET}"
    echo ""
    note "Module JSON: waybar/module.json"
    note "CSS examples: docs/WAYBAR.md"
    echo ""
}

# ── Uninstall ────────────────────────────────────────────
do_uninstall() {
    header "Uninstalling ${APP_NAME}"

    # Detect where it's installed
    local found=false
    local uninstalled_bin=""

    for candidate_bin in "/usr/local/bin/hyprcaffeine" "${HOME}/.local/bin/hyprcaffeine"; do
        if [[ -f "${candidate_bin}" ]]; then
            found=true
            uninstalled_bin="${candidate_bin}"

            # Determine mode from detected path
            if [[ "${candidate_bin}" == "/usr/local/"* ]]; then
                INSTALL_MODE="system"
                BIN_DIR="/usr/local/bin"
                DATA_DIR="/usr/local/share/hyprcaffeine"
            else
                INSTALL_MODE="user"
                BIN_DIR="${HOME}/.local/bin"
                DATA_DIR="${HOME}/.local/share/hyprcaffeine"
            fi
            break
        fi
    done

    if [[ "${found}" == false ]]; then
        warn "${APP_NAME} does not appear to be installed"
        note "Checked: /usr/local/bin/hyprcaffeine, ~/.local/bin/hyprcaffeine"
        exit 0
    fi

    info "Found installation: ${uninstalled_bin}"
    note "Install mode: ${INSTALL_MODE}"

    # Confirm uninstall
    if [[ "${ARG_FORCE}" != true ]]; then
        echo ""
        echo -en "  ${C_YELLOW}Remove ${APP_NAME}? [y/N]${C_RESET} "
        local answer
        read -r answer
        if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
            info "Uninstall cancelled"
            exit 0
        fi
    fi

    # Remove binary
    step "Removing binary..."
    elevated_rm "${BIN_DIR}/hyprcaffeine"
    success "Removed ${BIN_DIR}/hyprcaffeine"

    # Remove data/scripts
    step "Removing data files..."
    elevated_rm "${DATA_DIR}"
    success "Removed ${DATA_DIR}/"

    # Ask about config
    if [[ -d "${CONFIG_DIR}" ]]; then
        if [[ "${ARG_FORCE}" == true ]]; then
            rm -rf "${CONFIG_DIR}"
            success "Removed ${CONFIG_DIR}/"
        else
            echo ""
            echo -en "  ${C_YELLOW}Remove config at ${CONFIG_DIR}? [y/N]${C_RESET} "
            local config_answer
            read -r config_answer
            if [[ "${config_answer}" =~ ^[Yy]$ ]]; then
                rm -rf "${CONFIG_DIR}"
                success "Removed ${CONFIG_DIR}/"
            else
                note "Config preserved at ${CONFIG_DIR}/"
            fi
        fi
    fi

    # Remove state cache
    local state_dir="${HOME}/.cache/hyprcaffeine"
    if [[ -d "${state_dir}" ]]; then
        step "Removing state cache..."
        rm -rf "${state_dir}"
        success "Removed ${state_dir}/"
    fi

    echo ""
    echo -e "${C_GREEN}${C_BOLD}  ✅ ${APP_NAME} uninstalled successfully${C_RESET}"
    echo ""
}

# ── Main ─────────────────────────────────────────────────
main() {
    parse_args "$@"

    if [[ "${ARG_HELP}" == true ]]; then
        show_usage
        exit 0
    fi

    # Banner
    echo ""
    echo -e "${C_MAUVE}${C_BOLD}  󰒲 ${APP_NAME} Installer v${HC_VERSION}${C_RESET}"
    echo -e "${C_SURFACE0}  ──────────────────────────────────────────${C_RESET}"

    if [[ "${ARG_UNINSTALL}" == true ]]; then
        do_uninstall
        exit 0
    fi

    # Pre-flight checks
    validate_source
    check_deps
    detect_install_mode

    # Confirm before installing (unless --force)
    if [[ "${ARG_FORCE}" != true ]]; then
        echo ""
        echo -en "  ${C_TEXT}Proceed with installation? [Y/n]${C_RESET} "
        local proceed
        read -r proceed
        if [[ "${proceed}" =~ ^[Nn]$ ]]; then
            info "Installation cancelled"
            exit 0
        fi
    fi

    do_install
}

main "$@"
