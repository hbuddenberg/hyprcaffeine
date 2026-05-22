#!/usr/bin/env bash
# =============================================================================
# HyprCaffeine — Post-install script
# Runs as the desktop user (called by pacman hook via hyprcaffeine.install)
# Delegates waybar setup to `hyprcaffeine waybar-setup`
# =============================================================================

set -uo pipefail

SHARE_DIR="/usr/share/hyprcaffeine"

echo "  Auto-configuring for: $(whoami)"

# ── Polkit ──
PolkitFile="${SHARE_DIR}/polkit.rules"
PolkitDir="/etc/polkit-1/actions"
if [[ -f "$PolkitFile" ]] && [[ -d "$PolkitDir" ]]; then
    # Polkit needs root — use the base64 trick from hyprcaffeine.install
    if command -v hyprcaffeine &>/dev/null; then
        hyprcaffeine polkit install 2>/dev/null && \
            echo "  ✅ Polkit rule installed" || true
    fi
fi

# ── Waybar — delegate to CLI ──
if command -v hyprcaffeine &>/dev/null; then
    hyprcaffeine waybar-setup
fi

# ── Systemd ──
if [[ -f "${SHARE_DIR}/systemd/hyprcaffeine.service" ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    cp "${SHARE_DIR}/systemd/hyprcaffeine.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload 2>/dev/null
    # Disable first so a stale link (e.g. graphical-session.target.wants/) is
    # removed and the next enable re-reads the current [Install] section.
    systemctl --user disable hyprcaffeine.service 2>/dev/null
    systemctl --user enable hyprcaffeine.service 2>/dev/null && \
        echo "  ✅ Systemd service enabled" || true
fi

# ── Optional deps check ──
for dep in gum libnotify walker; do
    if pacman -Q "$dep" &>/dev/null; then
        echo "  optdeps: $dep ✓"
    fi
done

# ── Keybinds (opt-in) ──
if command -v hyprcaffeine &>/dev/null; then
    hyprcaffeine keybinds install 2>/dev/null && \
        echo "  ✅ Hyprland keybinds installed" || true
fi
