//! ratatui rendering — all widgets for the HyprCaffeine TUI dashboard

use ratatui::Frame;
use ratatui::layout::Alignment;
use ratatui::layout::Constraint;
use ratatui::layout::Direction;
use ratatui::layout::Layout;
use ratatui::layout::Rect;
use ratatui::style::Modifier;
use ratatui::style::Style;
use ratatui::text::Line;
use ratatui::text::Span;
use ratatui::widgets::Block;
use ratatui::widgets::Borders;
use ratatui::widgets::Gauge;
use ratatui::widgets::Paragraph;

use crate::app::{App, Focus};
use crate::theme::*;

/// Main draw function — renders the entire dashboard
pub fn draw(f: &mut Frame, app: &App) {
    let size = f.area();

    // Background block
    let bg = Block::default()
        .style(Style::default().bg(colors::MANTLE));
    f.render_widget(bg, size);

    // Main layout: header + body + footer
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(5),  // header with title + status
            Constraint::Min(0),     // body
            Constraint::Length(3),  // body row: presets + toggles
            Constraint::Length(8),  // activity log
            Constraint::Length(2),  // footer with key hints
        ])
        .margin(1)
        .split(size);

    draw_header(f, chunks[0], app);
    draw_countdown(f, chunks[1], app);
    draw_controls(f, chunks[2], app);
    draw_activity_log(f, chunks[3], app);
    draw_footer(f, chunks[4], app);
}

/// Header: title + status badge + monitor/lid indicators
fn draw_header(f: &mut Frame, area: Rect, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Min(20), // title
            Constraint::Length(20), // status
            Constraint::Length(14), // monitor
            Constraint::Length(14), // lid
        ])
        .split(area);

    // Title
    let title_block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(border_color_normal())
        .title(Span::styled(" HyprCaffeine ", style_title()))
        .title_alignment(Alignment::Center)
        .style(Style::default().bg(colors::BASE));

    let version = format!("v2.0.0");
    let title_text = vec![
        Line::from(""),
        Line::from(Span::styled(
            format!("  {} Premium TUI  ", ICON_COFFEE),
            style_title(),
        )),
        Line::from(Span::styled(
            format!("       {}", version),
            style_muted(),
        )),
    ];
    let title_para = Paragraph::new(title_text)
        .block(title_block)
        .alignment(Alignment::Center);
    f.render_widget(title_para, chunks[0]);

    // Status widget
    let (status_text, _status_style) = if app.state.is_active() {
        if app.state.is_infinite() {
            (
                vec![
                    Line::from(""),
                    Line::from(Span::styled(
                        format!(" {} ACTIVE", ICON_ACTIVE),
                        style_active(),
                    )),
                    Line::from(Span::styled(
                        format!(" {} Infinite", ICON_INFINITE),
                        style_accent(),
                    )),
                    Line::from(""),
                ],
                style_active(),
            )
        } else {
            (
                vec![
                    Line::from(""),
                    Line::from(Span::styled(
                        format!(" {} ACTIVE", ICON_ACTIVE),
                        style_active(),
                    )),
                    Line::from(Span::styled(
                        format!(" {} Running", ICON_TIMER),
                        style_accent(),
                    )),
                    Line::from(""),
                ],
                style_active(),
            )
        }
    } else {
        (
            vec![
                Line::from(""),
                Line::from(Span::styled(
                    format!(" {} INACTIVE", ICON_INACTIVE),
                    style_inactive(),
                )),
                Line::from(Span::styled("  Disabled", style_muted())),
                Line::from(""),
            ],
            style_inactive(),
        )
    };

    let status_border = if app.state.is_active() {
        border_color_active()
    } else {
        border_color_normal()
    };

    let status_block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(status_border)
        .title(" Status ")
        .title_alignment(Alignment::Center)
        .style(Style::default().bg(colors::BASE));

    let status_para = Paragraph::new(status_text)
        .block(status_block)
        .alignment(Alignment::Center);
    f.render_widget(status_para, chunks[1]);

    // Monitor toggle
    let mon_focused = app.focus == Focus::Monitor;
    let mon_border = if mon_focused {
        border_color_selected()
    } else {
        border_color_normal()
    };
    let mon_style = if app.state.monitor {
        style_monitor_on()
    } else {
        style_muted()
    };
    let mon_block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(mon_border)
        .title(" Monitor ")
        .title_alignment(Alignment::Center)
        .style(Style::default().bg(colors::BASE));
    let mon_text = vec![
        Line::from(""),
        Line::from(Span::styled(
            format!(" {} {}", ICON_MONITOR, if app.state.monitor { "ON" } else { "OFF" }),
            mon_style,
        )),
        Line::from(""),
    ];
    let mon_para = Paragraph::new(mon_text)
        .block(mon_block)
        .alignment(Alignment::Center);
    f.render_widget(mon_para, chunks[2]);

    // Lid toggle
    let lid_focused = app.focus == Focus::Lid;
    let lid_border = if lid_focused {
        border_color_selected()
    } else {
        border_color_normal()
    };
    let lid_style = if app.state.lid {
        style_lid_on()
    } else {
        style_muted()
    };
    let lid_block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(lid_border)
        .title(" Lid ")
        .title_alignment(Alignment::Center)
        .style(Style::default().bg(colors::BASE));
    let lid_text = vec![
        Line::from(""),
        Line::from(Span::styled(
            format!(" {} {}", ICON_LID, if app.state.lid { "ON" } else { "OFF" }),
            lid_style,
        )),
        Line::from(""),
    ];
    let lid_para = Paragraph::new(lid_text)
        .block(lid_block)
        .alignment(Alignment::Center);
    f.render_widget(lid_para, chunks[3]);
}

/// Countdown timer — big centered display with progress bar
fn draw_countdown(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(border_color_normal())
        .style(Style::default().bg(colors::BASE));

    let inner = block.inner(area);
    f.render_widget(block, area);

    // Split into countdown display + progress bar
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Min(3), // countdown text
            Constraint::Length(1), // progress bar
            Constraint::Length(1), // blank
        ])
        .split(inner);

    // Big countdown display
    let remaining = app.format_remaining();
    let (countdown_text, countdown_style) = if app.state.is_active() {
        let blink_char = if app.blink_on { ":" } else { " " };
        let display = if app.state.is_infinite() {
            format!("  {} INFINITE  ", ICON_INFINITE)
        } else {
            // Make the colons blink
            let remaining_display = remaining.replace(":", blink_char);
            format!(" {} {}", ICON_TIMER, remaining_display)
        };

        // Color based on remaining time
        let style = if let Some(secs) = app.state.remaining_seconds() {
            if secs == 0 {
                style_countdown()
            } else if secs <= 60 {
                style_error()
            } else if secs <= 300 {
                style_warning()
            } else {
                style_countdown()
            }
        } else {
            style_countdown()
        };
        (display, style)
    } else {
        (format!(" {} Off", ICON_INACTIVE), style_muted())
    };

    let countdown_line = Line::from(Span::styled(
        countdown_text,
        countdown_style.add_modifier(Modifier::BOLD),
    ));
    let countdown_para = Paragraph::new(vec![Line::from(""), countdown_line])
        .alignment(Alignment::Center);
    f.render_widget(countdown_para, chunks[0]);

    // Progress bar
    if let Some(progress) = app.state.progress() {
        let gauge = Gauge::default()
            .gauge_style(
                Style::default()
                    .fg(colors::TEAL)
                    .bg(colors::SURFACE0)
                    .add_modifier(Modifier::BOLD),
            )
            .ratio(progress.min(1.0))
            .label(format!("{:.0}%", progress * 100.0));
        f.render_widget(gauge, chunks[1]);
    } else if app.state.is_infinite() {
        // Animated infinite bar
        let filled: String = if app.blink_on {
            "█".repeat(chunks[1].width as usize)
        } else {
            "▓".repeat(chunks[1].width as usize)
        };
        let gauge = Gauge::default()
            .gauge_style(
                Style::default()
                    .fg(colors::MAUVE)
                    .bg(colors::SURFACE0),
            )
            .ratio(1.0)
            .label("♾ infinite");
        f.render_widget(gauge, chunks[1]);
    } else {
        // Inactive — empty bar
        let gauge = Gauge::default()
            .gauge_style(Style::default().fg(colors::SURFACE0).bg(colors::SURFACE0))
            .ratio(0.0)
            .label("inactive");
        f.render_widget(gauge, chunks[1]);
    }
}

/// Controls row: presets + power toggle
fn draw_controls(f: &mut Frame, area: Rect, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Min(20), // presets
            Constraint::Length(18), // toggle button
        ])
        .split(area);

    draw_presets(f, chunks[0], app);
    draw_toggle_button(f, chunks[1], app);
}

/// Preset selector
fn draw_presets(f: &mut Frame, area: Rect, app: &App) {
    let focused = app.focus == Focus::Presets;
    let border = if focused {
        border_color_selected()
    } else {
        border_color_normal()
    };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(border)
        .title(Span::styled(
            if focused { " > Presets < " } else { " Presets " },
            if focused { style_accent() } else { style_muted() },
        ))
        .style(Style::default().bg(colors::BASE));

    let inner = block.inner(area);
    f.render_widget(block, area);

    // Build preset buttons as a line
    let presets = &app.config.timeouts.presets;
    let mut spans: Vec<Span> = Vec::new();
    let spacing = "  ";

    for (i, secs) in presets.iter().enumerate() {
        let label = App::preset_label(*secs);
        let is_selected = i == app.selected_preset && focused;
        let is_current = app.state.is_active()
            && ((*secs == 0 && app.state.is_infinite())
                || (*secs != 0 && app.state.duration == *secs));

        let span = if is_selected {
            Span::styled(
                format!(" {} {} ", if app.blink_on { "▸" } else { "▹" }, label),
                style_highlight(),
            )
        } else if is_current {
            Span::styled(format!(" ● {} ", label), style_active())
        } else {
            Span::styled(format!("   {} ", label), style_text())
        };

        spans.push(span);
        if i < presets.len() - 1 {
            spans.push(Span::raw(spacing));
        }
    }

    // Add infinite preset if not in presets
    if !presets.contains(&0) {
        spans.push(Span::raw(spacing));
        let label = "♾ Inf";
        let is_selected = app.selected_preset >= presets.len() && focused;
        if is_selected {
            spans.push(Span::styled(
                format!(" {} {} ", if app.blink_on { "▸" } else { "▹" }, label),
                style_highlight(),
            ));
        } else {
            spans.push(Span::styled(
                format!("   {} ", label),
                style_text(),
            ));
        }
    }

    let line = Line::from(spans);
    let para = Paragraph::new(vec![Line::from(""), line])
        .alignment(Alignment::Center);
    f.render_widget(para, inner);
}

/// Power toggle button
fn draw_toggle_button(f: &mut Frame, area: Rect, app: &App) {
    let focused = app.focus == Focus::Toggle;
    let border = if focused {
        border_color_selected()
    } else {
        border_color_normal()
    };

    let is_active = app.state.is_active();
    let (label, label_style) = if is_active {
        (" DEACTIVATE ", style_error())
    } else {
        (" ACTIVATE ", style_active())
    };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(border)
        .title(Span::styled(
            if focused { " > Power < " } else { " Power " },
            if focused { style_accent() } else { style_muted() },
        ))
        .style(Style::default().bg(colors::BASE));

    let inner = block.inner(area);
    f.render_widget(block, area);

    let icon = if is_active { ICON_POWER } else { ICON_ACTIVE };
    let btn_text = vec![
        Line::from(""),
        Line::from(Span::styled(
            format!("{}{}", icon, label),
            label_style.add_modifier(Modifier::BOLD),
        )),
    ];
    let para = Paragraph::new(btn_text).alignment(Alignment::Center);
    f.render_widget(para, inner);
}

/// Activity log
fn draw_activity_log(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(border_style())
        .border_style(border_color_normal())
        .title(Span::styled(" Activity Log ", style_muted()))
        .style(Style::default().bg(colors::BASE));

    let inner = block.inner(area);
    f.render_widget(block, area);

    // Show last N entries that fit
    let max_lines = inner.height as usize;
    let entries: Vec<Line> = app
        .activity_log
        .iter()
        .rev()
        .take(max_lines)
        .map(|e| Line::from(Span::styled(e.clone(), style_muted())))
        .collect();

    let para = Paragraph::new(entries.into_iter().rev().collect::<Vec<_>>());
    f.render_widget(para, inner);
}

/// Footer with key hints
fn draw_footer(f: &mut Frame, area: Rect, app: &App) {
    let hints = "hjkl/↑↓←→ Navigate  ·  Enter/Space Toggle  ·  1-4 Presets  ·  m Monitor  ·  d Lid  ·  r Refresh  ·  q/Esc Quit";
    let line = Line::from(Span::styled(
        format!(" {} ", hints),
        style_key_hint(),
    ));
    let para = Paragraph::new(line)
        .alignment(Alignment::Center)
        .style(Style::default().bg(colors::SURFACE0));
    f.render_widget(para, area);
}
