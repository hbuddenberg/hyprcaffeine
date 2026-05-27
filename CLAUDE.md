# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HyprCaffeine** is a lightweight idle inhibition utility for Hyprland (a Wayland compositor). It provides three independent features:
1. **Sleep inhibition** — blocks suspend/sleep (via systemd-inhibit)
2. **Monitor keep-awake** — blocks screen dimming and DPMS (display power management)
3. **Lid-close inhibition** — prevents suspend when laptop lid closes

The project is primarily **Bash-based** with an optional premium **Rust TUI** dashboard. Version 0.7.8.

## Project Structure

### Core Directories

- **`bin/hyprcaffeine`** — Main entry point script (631 lines). Routes subcommands to appropriate functions.
- **`scripts/`** — Modular Bash libraries (~2.5k lines total)
  - `state.sh` — JSON-based state persistence (active/inactive, timers, monitor/lid toggles)
  - `config.sh` — YAML configuration loader with robust awk-based parsing
  - `hyprland.sh` — systemd-inhibit wrapper and Hyprland integration
  - `watcher.sh` — Daemon that auto-activates on fullscreen/audio/custom processes
  - `timer.sh` — Countdown timer and duration parsing
  - `keybinds.sh` — Hyprland keybinding installation/management
  - `notify.sh` — Desktop notifications (notify-send wrapper)
  - `caffeine-menu.sh` — Interactive menu (gum/wofi/rofi)
  - `waybar*.sh` — Waybar JSON output and auto-integration
  - `ui-engine.sh` — UI abstraction layer
- **`src-tui/`** — Premium Rust TUI (ratatui + crossterm)
  - `src/main.rs` — Entry point, event loop, terminal setup
  - `src/app.rs` — State management and business logic
  - `src/ui.rs` — ratatui rendering
  - `src/event.rs` — Input handling and actions
  - `src/theme.rs` — Color and styling
- **`config/`** — Configuration templates
  - `default.yaml` — Default YAML config (theme, timeouts, automation presets)
  - `ui-dictionary.json` — UI text/icon mappings for scripts
  - `polkit.rules` — Polkit rule template (grants sudo-free inhibit access)
- **`tests/`** — Unit tests
  - `run.sh` — 55+ unit tests covering parse_duration, timer_human, state.sh, config.sh
- **`systemd/`** — systemd user service for auto-start on login
- **`waybar/`** — Waybar module template and CSS styling
- **`docs/`** — Additional documentation
  - `CONFIG.md` — Full config reference
  - `INSTALL.md` — Installation guide
  - `WAYBAR.md` — Waybar integration details

### Root Configuration Files

- **`PKGBUILD`** — Arch Linux AUR package definition
- **`install.sh`** — Robust installer script (791 lines). Handles system/user modes, polkit rules, waybar integration, systemd service
- **`hyprcaffeine.install`** — Arch post-install hooks
- **`CHANGELOG.md`** — Version history with feature/fix notes

## Key Architectural Patterns

### 1. State Management (state.sh)
- **Single JSON file**: `~/.cache/hyprcaffeine/state.json`
- **Structure**: `{status, duration, activated_at, pid, monitor, lid}`
- **Pattern**: Three independent toggles (idle/monitor/lid) with separate getters/setters
- **Persistence**: Monitor and lid state survive app close; idle timers are app-instance only

### 2. Inhibition Model (hyprland.sh)
- **Mechanism**: `systemd-inhibit --what=<TYPE> --why=<REASON> <COMMAND>`
- **Three inhibitor types**:
  - `sleep` → blocks suspend (requires polkit rule)
  - `idle` → blocks dim/DPMS/lock via hypridle
  - `handle-lid-switch` → blocks lid-close suspend (requires polkit rule)
- **PID tracking**: Each inhibitor writes its PID to `~/.cache/hyprcaffeine/*.pid` for cleanup
- **Polkit requirement**: `/etc/polkit-1/rules.d/50-hyprcaffeine.rules` grants non-interactive inhibit access

### 3. Configuration Loading (config.sh)
- **YAML parser**: Uses `awk` for robust 2-level nested parsing (no external deps)
- **Cascading defaults**: User config → built-in defaults (no system-wide config)
- **Cache**: Config loaded once per binary invocation (re-parsed if sourced multiple times)
- **Key paths**:
  - User: `~/.config/hyprcaffeine/config.yaml`
  - Default: `<repo>/config/default.yaml`

### 4. Watcher Daemon (watcher.sh)
- **Auto-activation**: Listens to Hyprland event socket, auto-inhibits on conditions
- **Conditions**: Fullscreen window, audio playing, specific processes (Steam, Discord, custom)
- **Socket resolution**: Dynamically finds Hyprland socket from `HYPRLAND_INSTANCE_SIGNATURE` or runtime dirs
- **Persistent state**: Writes auto-active state to separate file for restoration
- **Systemd integration**: Runs as `hyprcaffeine.service` (user-level)

### 5. Waybar Integration
- **Module output**: JSON with text, tooltip, class, color
- **CSS classes**: Different for each feature combo (hc-timer, hc-infinite, hc-monitor, hc-lid, hc-all, etc.)
- **Auto-injection**: `install.sh` injects module definition and CSS into existing waybar config
- **Update check**: Detects existing module and preserves position/config on reinstall

### 6. Dual CLI Modes
- **Bash CLI** (`bin/hyprcaffeine`) — Fast, minimal deps, all features
- **Rust TUI** (`src-tui/hyprcaffeine-tui`) — Rich interactive dashboard, optional

## Development Commands

### Testing
```bash
# Run all 55+ unit tests (no Hyprland required)
bash tests/run.sh

# Tests cover:
# - parse_duration (30s, 15m, 2h, 1:30, infinite)
# - timer_human (human-readable countdown)
# - state.sh (JSON persistence)
# - config.sh (YAML parsing)
```

### Building the TUI (Rust)
```bash
# Build release binary
cd src-tui
cargo build --release
# Binary: target/release/hyprcaffeine-tui

# Run in dev mode
cargo run
```

### Installation for Development
```bash
# Install from source (system or user)
./install.sh

# User-local install (no sudo)
./install.sh --user

# Force system-wide (requires sudo)
./install.sh --system

# Inspect install.sh directly to preview changes (no --dry-run flag exists)
```

### Manual Testing
```bash
# Dry-run mode (no actual inhibition)
/path/to/bin/hyprcaffeine --dry-run on 30m

# Check current state
hyprcaffeine status

# Test individual features
hyprcaffeine on 5m          # Timer
hyprcaffeine monitor on     # Display keep-awake
hyprcaffeine lid on         # Lid-close inhibit
hyprcaffeine watcher start  # Auto-activate daemon

# View config being used
cat ~/.config/hyprcaffeine/config.yaml

# Check state file
cat ~/.cache/hyprcaffeine/state.json
```

### Code Quality
- **Linting**: Use `shellcheck` on bash scripts (no CI currently enforces this)
- **Style**: Follow existing patterns (source order, variable naming, comments)
- **Format**: Bash: 4-space indents; Rust: `cargo fmt`

## Important Implementation Details

### Duration Parsing (bin/hyprcaffeine, parse_duration)
- `infinite`/`inf` → 0 (special sentinel for infinite mode)
- `30s` → 30 seconds
- `15m` → 900 seconds
- `2h` → 7200 seconds
- `1:30` → 5400 seconds (HH:MM format)
- Bare `30` → 1800 seconds (interpreted as minutes)

### State File Format
```json
{
  "status": "active|inactive",
  "duration": 0,
  "activated_at": "1716388800",
  "pid": "",
  "monitor": true|false,
  "lid": true|false
}
```
- `activated_at` is Unix timestamp (seconds); used to calculate remaining time
- `duration == 0` when status is `active` means infinite mode

### Inhibitor Cleanup
- PID files stored in `~/.cache/hyprcaffeine/` are read and `kill`-ed when toggling off
- Stale PIDs (process no longer running) are silently skipped
- systemd-inhibit auto-cleans when the inhibitor process exits

### Keybinding Auto-Install
- `install.sh` calls `hyprcaffeine keybinds install` post-install
- Keybindings are written to `~/.config/hypr/hyprcaffeine-keybinds.conf`
- User must source this file in their `hyprland.conf`: `source = ~/.config/hypr/hyprcaffeine-keybinds.conf`
- Defaults: `$mainMod CTRL I` (toggle infinite), `$mainMod CTRL+Shift I` (menu), etc.

### Polkit Rule Requirement
- Both `sleep` and `handle-lid-switch` inhibit types require polkit to work without sudo
- If rule is missing or wrong user, systemd-inhibit will fail silently
- `install.sh` always installs/overwrites the rule; user-local installs may fail if `/etc/polkit-1/` is not writable

### Waybar Module Interval
- Default interval: 2 seconds (config in `install.sh`, module definition)
- Lower intervals (1s) can be heavy; 2s is a good balance for countdown updates

## Dependencies

### Required (checked by install.sh)
- `bash` 4.0+
- `hyprctl` (from Hyprland)
- `jq` (JSON parsing)
- `notify-send` (libnotify)

### Runtime (strongly recommended)
- `hypridle` — Required for `--what=idle` (display keep-awake)
- `socat` — Required for watcher daemon socket communication

### Optional
- `gum` (charmbracelet) — For interactive menus (fallback: wofi)
- `walker` — Alternative launcher menu

### Build Dependencies (Rust TUI only)
- `cargo` + `rustc` (Rust 1.56+)
- Dependencies managed by Cargo.toml (ratatui, crossterm, serde, chrono, clap, dirs)

## Common Workflows

### Adding a New Inhibitor Type
1. Add new `--what` case to `hyprland.sh` (function `hypr_<type>_on/off`)
2. Create PID file variable (e.g., `_NEW_TYPE_PID_FILE`)
3. Implement getter/setter in main `bin/hyprcaffeine` (e.g., `do_<type>_on`)
4. Add CSS class to waybar output
5. Test with `hyprcaffeine --dry-run`

### Extending Configuration
1. Add YAML section to `config/default.yaml`
2. Add parser functions to `scripts/config.sh` (follow `config_get_*` pattern)
3. Update `docs/CONFIG.md` with reference
4. Test via `tests/run.sh` or manual `hyprcaffeine status`

### Modifying Waybar Integration
1. Edit template in `install.sh` (`WB_CSS_BLOCK`, `module_block`)
2. Test with existing waybar config: `./install.sh --force`
3. Verify CSS classes match `do_waybar` output in `bin/hyprcaffeine`

### Adding Unit Tests
1. Add test function to `tests/run.sh`
2. Use `assert_eq`, `assert_ok`, or `assert_file_contains` helpers
3. Run: `bash tests/run.sh`
4. Aim for 100% pass rate before committing

## Troubleshooting for Developers

### "scripts/ not found" error
- Binary is resolving wrong `LIB_DIR`
- Check: `bin/hyprcaffeine` lines 12-18 (path resolution)
- In installed mode, `PKGBUILD` patches `LIB_DIR` to absolute path

### Inhibitor fails silently
- Check polkit rule exists: `ls /etc/polkit-1/rules.d/50-hyprcaffeine.rules`
- Check rule contains your username: `grep "$(whoami)" /etc/polkit-1/rules.d/50-hyprcaffeine.rules`
- Test directly: `systemd-inhibit --what=sleep echo "test"` (should not prompt)

### Watcher doesn't auto-activate
- Check service is enabled: `systemctl --user status hyprcaffeine.service`
- Check socket resolution: `echo $HYPRLAND_INSTANCE_SIGNATURE`
- Check watcher log: `tail ~/.cache/hyprcaffeine/watcher.log`

### Waybar module doesn't update
- Check interval in waybar config: should be `1` or `2` (seconds)
- Restart waybar: `killall waybar && waybar &`
- Check state file: `cat ~/.cache/hyprcaffeine/state.json`

## Design Principles

1. **Independence**: Each feature (idle, monitor, lid) toggles independently; no cascading side effects
2. **Stateless CLI**: The `hyprcaffeine` binary is stateless; all state in `~/.cache/hyprcaffeine/state.json`
3. **Minimal deps**: Bash + jq + basic CLI tools; no extra runtimes
4. **User-first**: Respects `~/.local/bin` for installations; avoids system dirs when possible
5. **Hyprland-native**: Uses `hyprctl` and Hyprland event socket; tight integration
6. **Backward compatibility**: Config defaults ensure old configs don't break; polkit/keybind updates are non-destructive

## References

- **Hyprland docs**: https://wiki.hyprland.org/ (event socket, hyprctl, inhibit actions)
- **systemd-inhibit**: `man systemd-inhibit` (inhibit types, polkit integration)
- **Polkit rules**: https://www.freedesktop.org/software/polkit/docs/latest/ (rule syntax)
- **ratatui**: https://github.com/ratatui-org/ratatui (TUI framework docs)
