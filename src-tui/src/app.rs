//! Application state and HyprCaffeine CLI interaction

use serde::Deserialize;
use serde::Serialize;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;

// ── State from JSON ──────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CaffeineState {
    pub status: String,
    pub duration: u64,
    pub activated_at: String,
    pub pid: String,
    pub monitor: bool,
    pub lid: bool,
}

impl Default for CaffeineState {
    fn default() -> Self {
        Self {
            status: "inactive".to_string(),
            duration: 0,
            activated_at: String::new(),
            pid: String::new(),
            monitor: false,
            lid: false,
        }
    }
}

impl CaffeineState {
    pub fn is_active(&self) -> bool {
        self.status == "active"
    }

    pub fn is_infinite(&self) -> bool {
        self.is_active() && self.duration == 0
    }

    /// Returns remaining seconds. None if inactive, Some(0) if infinite.
    pub fn remaining_seconds(&self) -> Option<u64> {
        if !self.is_active() {
            return None;
        }
        if self.duration == 0 {
            return Some(0); // infinite
        }
        let activated: i64 = self.activated_at.parse().unwrap_or(0);
        if activated == 0 {
            return Some(self.duration);
        }
        let now = chrono::Local::now().timestamp();
        let elapsed = (now - activated).max(0) as u64;
        let remaining = self.duration.saturating_sub(elapsed);
        Some(remaining)
    }

    /// Returns progress 0.0..1.0. None if inactive, None if infinite.
    pub fn progress(&self) -> Option<f64> {
        if !self.is_active() {
            return None;
        }
        if self.duration == 0 {
            return None; // infinite
        }
        let remaining = self.remaining_seconds()?;
        if self.duration == 0 {
            return None;
        }
        Some(1.0 - (remaining as f64 / self.duration as f64))
    }
}

// ── Config ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Default, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub theme: ThemeConfig,
    #[serde(default)]
    pub timeouts: TimeoutConfig,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ThemeConfig {
    #[serde(default = "default_accent")]
    pub accent: String,
}

impl Default for ThemeConfig {
    fn default() -> Self {
        Self {
            accent: default_accent(),
        }
    }
}

fn default_accent() -> String {
    "#89b4fa".to_string()
}

#[derive(Debug, Clone, Deserialize)]
pub struct TimeoutConfig {
    #[serde(default = "default_timeout")]
    pub default: u64,
    #[serde(default = "default_presets")]
    pub presets: Vec<u64>,
}

impl Default for TimeoutConfig {
    fn default() -> Self {
        Self {
            default: default_timeout(),
            presets: default_presets(),
        }
    }
}

fn default_timeout() -> u64 {
    1800
}

fn default_presets() -> Vec<u64> {
    vec![900, 1800, 3600, 7200]
}

// ── UI Focus ─────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Focus {
    Presets,
    Monitor,
    Lid,
    Toggle,
}

impl Focus {
    pub fn next(self) -> Self {
        match self {
            Focus::Presets => Focus::Toggle,
            Focus::Toggle => Focus::Monitor,
            Focus::Monitor => Focus::Lid,
            Focus::Lid => Focus::Presets,
        }
    }

    pub fn prev(self) -> Self {
        match self {
            Focus::Presets => Focus::Lid,
            Focus::Lid => Focus::Monitor,
            Focus::Monitor => Focus::Toggle,
            Focus::Toggle => Focus::Presets,
        }
    }
}

// ── App ──────────────────────────────────────────────────────────────────

pub struct App {
    pub state: CaffeineState,
    pub config: Config,
    pub focus: Focus,
    pub selected_preset: usize,
    pub should_quit: bool,
    pub last_refresh: Instant,
    pub activity_log: Vec<String>,
    pub blink_on: bool,
    pub cli_path: String,
}

impl App {
    pub fn new() -> Self {
        let state = CaffeineState::read().unwrap_or_default();
        let config = Config::read().unwrap_or_default();
        let cli_path = find_cli_path();

        let mut app = Self {
            state,
            config,
            focus: Focus::Presets,
            selected_preset: 0,
            should_quit: false,
            last_refresh: Instant::now(),
            activity_log: Vec::new(),
            blink_on: true,
            cli_path,
        };
        app.log("TUI started");
        app
    }

    /// Refresh state from disk (called every tick)
    pub fn refresh_state(&mut self) {
        let old_status = self.state.status.clone();
        let old_monitor = self.state.monitor;
        let old_lid = self.state.lid;

        if let Ok(new_state) = CaffeineState::read() {
            self.state = new_state;
        }

        // Log changes
        if self.state.status != old_status {
            self.log(&format!(
                "Status: {} → {}",
                old_status, self.state.status
            ));
        }
        if self.state.monitor != old_monitor {
            self.log(&format!(
                "Monitor: {} → {}",
                old_monitor, self.state.monitor
            ));
        }
        if self.state.lid != old_lid {
            self.log(&format!("Lid: {} → {}", old_lid, self.state.lid));
        }

        self.last_refresh = Instant::now();
        self.blink_on = !self.blink_on;
    }

    /// Toggle blink state (for cursor blink)
    pub fn tick(&mut self) {
        self.blink_on = !self.blink_on;
    }

    // ── Actions ──────────────────────────────────────────────────────────

    pub fn activate(&mut self, duration_seconds: u64) {
        let duration_str = if duration_seconds == 0 {
            "infinite".to_string()
        } else if duration_seconds % 3600 == 0 {
            format!("{}h", duration_seconds / 3600)
        } else if duration_seconds % 60 == 0 {
            format!("{}m", duration_seconds / 60)
        } else {
            format!("{}s", duration_seconds)
        };
        self.run_cli(&["on", &duration_str]);
        self.log(&format!("Activated: {}", duration_str));
        // Immediate refresh
        std::thread::sleep(std::time::Duration::from_millis(100));
        if let Ok(s) = CaffeineState::read() {
            self.state = s;
        }
    }

    pub fn deactivate(&mut self) {
        self.run_cli(&["off"]);
        self.log("Deactivated");
        std::thread::sleep(std::time::Duration::from_millis(100));
        if let Ok(s) = CaffeineState::read() {
            self.state = s;
        }
    }

    pub fn toggle(&mut self) {
        if self.state.is_active() {
            self.deactivate();
        } else {
            // Use selected preset
            let presets = &self.config.timeouts.presets;
            let dur = presets.get(self.selected_preset).copied().unwrap_or(1800);
            self.activate(dur);
        }
    }

    pub fn toggle_monitor(&mut self) {
        self.run_cli(&["monitor", "toggle"]);
        self.log("Toggled monitor");
        std::thread::sleep(std::time::Duration::from_millis(100));
        if let Ok(s) = CaffeineState::read() {
            self.state = s;
        }
    }

    pub fn toggle_lid(&mut self) {
        self.run_cli(&["lid", "toggle"]);
        self.log("Toggled lid");
        std::thread::sleep(std::time::Duration::from_millis(100));
        if let Ok(s) = CaffeineState::read() {
            self.state = s;
        }
    }

    pub fn quit(&mut self) {
        self.should_quit = true;
    }

    // ── Navigation ───────────────────────────────────────────────────────

    pub fn next_focus(&mut self) {
        self.focus = self.focus.next();
    }

    pub fn prev_focus(&mut self) {
        self.focus = self.focus.prev();
    }

    pub fn next_preset(&mut self) {
        let max = self.config.timeouts.presets.len().saturating_sub(1);
        if self.selected_preset < max {
            self.selected_preset += 1;
        }
    }

    pub fn prev_preset(&mut self) {
        if self.selected_preset > 0 {
            self.selected_preset -= 1;
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    fn run_cli(&self, args: &[&str]) {
        let _ = Command::new(&self.cli_path).args(args).output();
    }

    fn log(&mut self, msg: &str) {
        let timestamp = chrono::Local::now().format("%H:%M:%S").to_string();
        let entry = format!("[{}] {}", timestamp, msg);
        self.activity_log.push(entry);
        // Keep only last 20 entries
        if self.activity_log.len() > 20 {
            self.activity_log.remove(0);
        }
    }

    /// Format remaining seconds as human-readable string
    pub fn format_remaining(&self) -> String {
        match self.state.remaining_seconds() {
            None => "—".to_string(),
            Some(0) => "♾ infinite".to_string(),
            Some(secs) => {
                let h = secs / 3600;
                let m = (secs % 3600) / 60;
                let s = secs % 60;
                if h > 0 {
                    format!("{:02}:{:02}:{:02}", h, m, s)
                } else {
                    format!("{:02}:{:02}", m, s)
                }
            }
        }
    }

    /// Format duration as preset label
    pub fn preset_label(secs: u64) -> String {
        if secs == 0 {
            "♾ Inf".to_string()
        } else if secs % 3600 == 0 {
            format!("{}h", secs / 3600)
        } else {
            format!("{}m", secs / 60)
        }
    }
}

// ── State File I/O ───────────────────────────────────────────────────────

impl CaffeineState {
    fn state_path() -> PathBuf {
        dirs::cache_dir()
            .unwrap_or_else(|| PathBuf::from("/tmp"))
            .join("hyprcaffeine")
            .join("state.json")
    }

    pub fn read() -> Result<Self, String> {
        let path = Self::state_path();
        let data =
            fs::read_to_string(&path).map_err(|e| format!("Cannot read state: {}", e))?;
        serde_json::from_str(&data).map_err(|e| format!("Cannot parse state: {}", e))
    }
}

impl Config {
    fn config_path() -> PathBuf {
        dirs::config_dir()
            .unwrap_or_else(|| PathBuf::from("/tmp"))
            .join("hyprcaffeine")
            .join("config.yaml")
    }

    pub fn read() -> Result<Self, String> {
        let path = Self::config_path();
        let data =
            fs::read_to_string(&path).map_err(|e| format!("Cannot read config: {}", e))?;
        serde_yaml::from_str(&data).map_err(|e| format!("Cannot parse config: {}", e))
    }
}

/// Find the hyprcaffeine CLI binary
fn find_cli_path() -> String {
    // 1. Check ~/.local/bin/
    let local = dirs::home_dir()
        .map(|h| h.join(".local/bin/hyprcaffeine"))
        .unwrap_or_default();
    if local.exists() {
        return local.to_string_lossy().to_string();
    }
    // 2. Check PATH
    if let Ok(output) = Command::new("which").arg("hyprcaffeine").output() {
        if output.status.success() {
            return String::from_utf8_lossy(&output.stdout).trim().to_string();
        }
    }
    // 3. Fallback
    "hyprcaffeine".to_string()
}
