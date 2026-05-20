#!/usr/bin/env bash
# test-inhibit.sh — Diagnostic test for HyprCaffeine inhibition
set -uo pipefail

export HYPRLAND_INSTANCE_SIGNATURE=521ece463c4a9d3d128670688a34756805a4328f_1778775791_1749324412
HC=~/.local/bin/hyprcaffeine

separator() { echo ""; echo "───────────────────────────────────────"; }
status_block() {
    echo "  State:       $($HC status)"
    local procs
    procs=$(ps -eo pid,args | grep 'systemd-inhibit.*HyprCaffeine' | grep -v grep | wc -l)
    echo "  Inhibitors:  ${procs} systemd-inhibit process(es)"
    echo "  BlockInh:    $(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager BlockInhibited 2>/dev/null)"
    local hypr_log
    hypr_log=$(journalctl --user -u hypridle --since "10 sec ago" --no-pager 2>&1 | grep -E "inhibit|lock" | tail -2)
    if [[ -n "${hypr_log}" ]]; then
        echo "  hypridle log:"
        while IFS= read -r line; do
            echo "    ${line##*hypridle[}: "
        done <<< "${hypr_log}"
    fi
}

# Clean baseline
echo "Cleaning state..."
$HC off --all 2>/dev/null
sleep 1

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║  HYPRCAFFEINE DIAGNOSTIC TEST        ║"
echo "╚═══════════════════════════════════════╝"

echo ""
echo "── BASELINE ──"
status_block

# ── Test 1: monitor on ──
separator
echo "── TEST 1: monitor on ──"
$HC monitor on 2>&1
sleep 0.5
status_block

# ── Test 2: on infinite ──
separator
echo "── TEST 2: on infinite ──"
$HC on infinite 2>&1
sleep 0.5
status_block

# ── Test 3: lid on ──
separator
echo "── TEST 3: lid on ──"
$HC lid on 2>&1
sleep 0.5
status_block

# ── Test 4: all on (menu "all") ──
separator
echo "── TEST 4: all on ──"
$HC monitor on 2>&1
$HC on infinite 2>&1
$HC lid on 2>&1
sleep 0.5
status_block

# ── Test 5: monitor off ──
separator
echo "── TEST 5: monitor off (keep idle + lid) ──"
$HC monitor off 2>&1
sleep 0.5
status_block

# ── Test 6: all off ──
separator
echo "── TEST 6: off --all ──"
$HC off --all 2>&1
sleep 0.5
status_block

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║  TEST COMPLETE                        ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "Polkit rule status:"
if [[ -f /etc/polkit-1/rules.d/50-hyprcaffeine.rules ]]; then
    echo "  INSTALLED: /etc/polkit-1/rules.d/50-hyprcaffeine.rules"
else
    echo "  NOT INSTALLED — run: sudo cp /tmp/50-hyprcaffeine.rules /etc/polkit-1/rules.d/"
fi
