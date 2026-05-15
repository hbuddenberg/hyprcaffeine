//! Catppuccin Mocha color scheme and TUI styles

use ratatui::style::Modifier;
use ratatui::style::Style;

/// Catppuccin Mocha palette
pub mod colors {
    use ratatui::style::Color;

    pub const BASE: Color = Color::Rgb(30, 30, 46);
    pub const MANTLE: Color = Color::Rgb(17, 17, 27);
    pub const SURFACE0: Color = Color::Rgb(49, 50, 68);
    pub const SURFACE1: Color = Color::Rgb(69, 71, 90);
    pub const SURFACE2: Color = Color::Rgb(88, 91, 112);
    pub const OVERLAY0: Color = Color::Rgb(108, 112, 134);
    pub const TEXT: Color = Color::Rgb(205, 214, 244);
    pub const SUBTEXT0: Color = Color::Rgb(166, 173, 200);
    pub const SUBTEXT1: Color = Color::Rgb(186, 194, 222);
    pub const BLUE: Color = Color::Rgb(137, 180, 250);
    pub const GREEN: Color = Color::Rgb(166, 227, 161);
    pub const RED: Color = Color::Rgb(243, 139, 168);
    pub const MAUVE: Color = Color::Rgb(203, 166, 247);
    pub const PEACH: Color = Color::Rgb(250, 179, 135);
    pub const YELLOW: Color = Color::Rgb(249, 226, 175);
    pub const TEAL: Color = Color::Rgb(148, 226, 213);
    pub const LAVENDER: Color = Color::Rgb(180, 190, 254);
    pub const PINK: Color = Color::Rgb(245, 194, 231);
    pub const FLAMINGO: Color = Color::Rgb(242, 205, 205);
    pub const ROSEWATER: Color = Color::Rgb(245, 224, 220);
}

use colors::*;

// ── Nerd Font icons ──────────────────────────────────────────────────────

pub const ICON_ACTIVE: &str = "\u{f0323}"; // 󰒣
pub const ICON_INACTIVE: &str = "\u{e219}"; //  (coffee outline)
pub const ICON_TIMER: &str = "\u{f0677}"; // ⏱
pub const ICON_INFINITE: &str = "\u{221e}"; // ∞
pub const ICON_MONITOR: &str = "\u{f108}"; // 
pub const ICON_LID: &str = "\u{f0eb}"; // 
pub const ICON_COFFEE: &str = "\u{f0f4}"; // ☕
pub const ICON_POWER: &str = "\u{f011}"; // ⏻
pub const ICON_CLOCK: &str = "\u{f017}"; // 

// ── Reusable Styles ──────────────────────────────────────────────────────

pub fn style_title() -> Style {
    Style::default()
        .fg(MAUVE)
        .add_modifier(Modifier::BOLD)
}

pub fn style_active() -> Style {
    Style::default().fg(GREEN).add_modifier(Modifier::BOLD)
}

pub fn style_inactive() -> Style {
    Style::default().fg(SUBTEXT0)
}

pub fn style_warning() -> Style {
    Style::default().fg(YELLOW).add_modifier(Modifier::BOLD)
}

pub fn style_error() -> Style {
    Style::default().fg(RED).add_modifier(Modifier::BOLD)
}

pub fn style_accent() -> Style {
    Style::default().fg(BLUE)
}

pub fn style_highlight() -> Style {
    Style::default().fg(BASE).bg(BLUE).add_modifier(Modifier::BOLD)
}

pub fn style_selected() -> Style {
    Style::default().fg(BASE).bg(SURFACE2).add_modifier(Modifier::BOLD)
}

pub fn style_muted() -> Style {
    Style::default().fg(SUBTEXT0)
}

pub fn style_text() -> Style {
    Style::default().fg(TEXT)
}

pub fn style_countdown() -> Style {
    Style::default()
        .fg(LAVENDER)
        .add_modifier(Modifier::BOLD)
}

pub fn style_progress_bar() -> Style {
    Style::default().fg(TEAL)
}

pub fn style_progress_bg() -> Style {
    Style::default().fg(SURFACE0)
}

pub fn style_monitor_on() -> Style {
    Style::default().fg(GREEN).add_modifier(Modifier::BOLD)
}

pub fn style_lid_on() -> Style {
    Style::default().fg(PEACH).add_modifier(Modifier::BOLD)
}

pub fn style_key_hint() -> Style {
    Style::default().fg(OVERLAY0)
}

pub fn style_help_text() -> Style {
    Style::default().fg(SUBTEXT1)
}

// Border style uses accent color
pub fn border_style() -> ratatui::widgets::block::BorderType {
    ratatui::widgets::block::BorderType::Rounded
}

pub fn border_color_normal() -> Style {
    Style::default().fg(SURFACE1)
}

pub fn border_color_selected() -> Style {
    Style::default().fg(BLUE)
}

pub fn border_color_active() -> Style {
    Style::default().fg(GREEN)
}
