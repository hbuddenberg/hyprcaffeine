#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
#  HyprCaffeine Installer
#  Modern idle inhibition utility for Hyprland
# ─────────────────────────────────────────────────────────

set -euo pipefail

# ── Catppuccin Mocha Colors ──────────────────────────────
readonly C_RED="#f38ba8"
readonly C_PEACH="#fab387"
readonly C_YELLOW="#f9e2af"
readonly C_GREEN="#a6e3a1"
readonly C_BLUE="#89b4fa"
readonly C_MAUVE="#cba6f7"
readonly C_TEAL="#94e2d5"
readonly C_TEXT="#cdd6f4"
readonly C_SURFACE0="#313244"
readonly C_RESET="\033[0m"

# ── Paths ────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_DIR="${HOME}/.config/hyprcaffeine"
readonly BIN_DIR="${HOME}/.local/bin"
readonly DATA_DIR="${HOME}/.local/share/hyprcaffeine"

# ── Helpers ──────────────────────────────────────────────
info()    { echo -e "${C_BLUE}[INFO]${C_RESET} ${C_TEXT}$*${C_RESET}"; }
success() { echo -e "${C_GREEN}[OK]${C_RESET}   ${C_TEXT}$*${C_RESET}"; }
warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} ${C_TEXT}$*${C_RESET}"; }
error()   { echo -e "${C_RED}[ERR]${C_RESET}  ${C_TEXT}$*${C_RESET}"; }
header()  { echo -e "\n${C_MAUVE}󰒲 $*${C_RESET}\n${C_SURFACE0}─────────────────────────────────${C_RESET}"; }

# ── Dependency Check ─────────────────────────────────────
check_deps() {
    header "Checking Dependencies"

    local missing=()
    local deps=("bash" "jq" "hyprctl" "notify-send")

    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            success "$dep found"
        else
            error "$dep not found"
            missing+=("$dep")
        fi
    done

    # gum is optional but recommended
    if command -v gum &>/dev/null; then
        success "gum found"
    else
        warn "gum not found — install charmbracelet/gum for the best experience"
        missing+=("gum")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        echo -e "\n${C_TEXT}Install them with:${C_RESET}"
        echo -e "  ${C_TEAL}sudo pacman -S ${missing[*]}${C_RESET}\n"
        exit 1
    fi
}

# ── Uninstall ────────────────────────────────────────────
do_uninstall() {
    header "Uninstalling HyprCaffeine"

    info "Removing binary..."
    rm -f "${BIN_DIR}/hyprcaffeine"

    info "Removing data files..."
    rm -rf "${DATA_DIR}"

    info "Removing config (preserving user settings)..."
    read -rp "Remove ~/.config/hyprcaffeine too? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_DIR}"
        success "Config removed"
    else
        info "Config preserved at ${CONFIG_DIR}"
    fi

    success "HyprCaffeine uninstalled"
    exit 0
}

# ── Install ──────────────────────────────────────────────
do_install() {
    header "Installing HyprCaffeine"

    # 1. Create config directory
    info "Creating config directory..."
    mkdir -p "${CONFIG_DIR}"
    success "Config dir: ${CONFIG_DIR}"

    # 2. Copy default config if none exists
    if [[ ! -f "${CONFIG_DIR}/config.yaml" ]]; then
        info "Installing default configuration..."
        cp "${SCRIPT_DIR}/config/default.yaml" "${CONFIG_DIR}/config.yaml"
        success "Default config installed"
    else
        warn "Existing config found — skipping (your settings are preserved)"
    fi

    # 3. Install binary
    info "Installing hyprcaffeine binary..."
    mkdir -p "${BIN_DIR}"
    cp "${SCRIPT_DIR}/bin/hyprcaffeine" "${BIN_DIR}/hyprcaffeine"
    chmod +x "${BIN_DIR}/hyprcaffeine"
    success "Binary installed to ${BIN_DIR}/hyprcaffeine"

    # 4. Install scripts / data
    info "Installing data files..."
    mkdir -p "${DATA_DIR}"
    if [[ -d "${SCRIPT_DIR}/scripts" ]]; then
        cp -r "${SCRIPT_DIR}/scripts/"* "${DATA_DIR}/"
        success "Scripts installed to ${DATA_DIR}"
    else
        warn "No scripts/ directory found — skipping"
    fi

    # 5. Ensure ~/.local/bin is in PATH
    if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
        warn "${BIN_DIR} is not in your PATH"
        echo -e "  ${C_TEAL}Add this to your shell profile:${C_RESET}"
        echo -e "  ${C_YELLOW}export PATH=\"\${HOME}/.local/bin:\$PATH\"${C_RESET}"
    fi

    # 6. Waybar integration instructions
    header "Waybar Integration"
    echo -e "${C_TEXT}Add to your Waybar config:${C_RESET}"
    echo -e ""
    echo -e "  ${C_TEAL}\"custom/hyprcaffeine\": {${C_RESET}"
    echo -e "  ${C_TEAL}  \"exec\": \"hyprcaffeine waybar\",${C_RESET}"
    echo -e "  ${C_TEAL}  \"on-click\": \"hyprcaffeine toggle\",${C_RESET}"
    echo -e "  ${C_TEAL}  \"interval\": 1,${C_RESET}"
    echo -e "  ${C_TEAL}  \"return-type\": \"json\"${C_RESET}"
    echo -e "  ${C_TEAL}}${C_RESET}"
    echo -e ""
    echo -e "${C_TEXT}Module JSON is at: ${C_YELLOW}waybar/module.json${C_RESET}"
    echo -e "${C_TEXT}CSS examples: ${C_YELLOW}docs/WAYBAR.md${C_RESET}"
    echo -e ""

    success "Installation complete!"
    echo -e "\n${C_TEXT}Run ${C_GREEN}hyprcaffeine${C_RESET}${C_TEXT} to get started.${C_RESET}\n"
}

# ── Main ─────────────────────────────────────────────────
main() {
    if [[ "${1:-}" == "--uninstall" ]]; then
        do_uninstall
    fi

    check_deps
    do_install
}

main "$@"
