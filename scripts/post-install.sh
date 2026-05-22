#!/usr/bin/env bash
# HyprCaffeine — Post-install script (runs as desktop user via hyprcaffeine.install)
# Delegates all setup to `hyprcaffeine setup` which handles polkit-skip, waybar,
# systemd, and keybinds in one canonical flow.

set -uo pipefail

if command -v hyprcaffeine &>/dev/null; then
    hyprcaffeine setup
else
    echo "  hyprcaffeine not found in PATH — setup skipped"
    echo "  Add $(dirname "$(command -v hyprcaffeine 2>/dev/null || echo /usr/bin)") to PATH and run: hyprcaffeine setup"
fi
