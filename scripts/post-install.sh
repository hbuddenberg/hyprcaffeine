#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Post-install script
# Runs as the desktop user (called by pacman hook via hyprcaffeine.install)
# Delegates waybar setup to waybar-setup.sh
# =============================================================================

set -uo pipefail

SHARE_DIR="/usr/share/hyprcaffeine"
SCRIPTS_DIR="${SHARE_DIR}/scripts"

echo "  Auto-configuring for: $(whoami)"

# ── Polkit ──
if [[ -f "${SHARE_DIR}/polkit/org.hyprcaffeine.policy" ]]; then
    PolkitDir="/etc/polkit-1/actions"
    if [[ -d "$PolkitDir" ]]; then
        cp "${SHARE_DIR}/polkit/org.hyprcaffeine.policy" "$PolkitDir/" 2>/dev/null && \
            echo "  ✅ Polkit rule installed" || echo "  ⚠️  Polkit install failed (needs root)"
    fi
fi

# ── Waybar — delegate to waybar-setup.sh ──
if [[ -f "${SCRIPTS_DIR}/waybar-setup.sh" ]]; then
    bash "${SCRIPTS_DIR}/waybar-setup.sh"
fi

# ── Systemd ──
if [[ -f "${SHARE_DIR}/systemd/hyprcaffeine.service" ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    cp "${SHARE_DIR}/systemd/hyprcaffeine.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable hyprcaffeine.service 2>/dev/null && \
        echo "  ✅ Systemd service enabled" || true
fi

# ── Optional deps check ──
for dep in gum libnotify walker; do
    if pacman -Q "$dep" &>/dev/null; then
        echo "  optdeps: $dep ✓"
    fi
done
