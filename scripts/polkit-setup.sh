#!/usr/bin/env bash
# polkit-setup.sh — Install polkit rules for HyprCaffeine
# Allows sleep and lid-switch inhibition without interactive authentication
#
# Usage: sudo bash polkit-setup.sh

set -uo pipefail

RULES_FILE="/etc/polkit-1/rules.d/50-hyprcaffeine.rules"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: This script must be run as root (use sudo)." >&2
    exit 1
fi

mkdir -p "$(dirname "${RULES_FILE}")"
cat > "${RULES_FILE}" <<'EOF'
// HyprCaffeine polkit rules
// Allow the active user to inhibit sleep and lid-switch without authentication
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.inhibit-block-sleep" ||
        action.id == "org.freedesktop.login1.inhibit-handle-lid-switch" ||
        action.id == "org.freedesktop.login1.inhibit-delay-sleep") {
        if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    }
});
EOF

echo "Polkit rules installed to ${RULES_FILE}"
echo "Sleep and lid-switch inhibition now allowed without authentication."
