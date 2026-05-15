//! Keyboard event handling for the TUI

use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind};
use std::time::Duration;

use crate::app::{App, Focus};

/// Poll for a terminal event with the given timeout (in ms).
/// Returns None if no event within timeout.
pub fn poll_event(timeout_ms: u64) -> Option<EventResult> {
    if event::poll(Duration::from_millis(timeout_ms)).unwrap_or(false) {
        if let Ok(Event::Key(key)) = event::read() {
            // Only process key press events (not release)
            if key.kind == KeyEventKind::Press {
                return Some(handle_key(key));
            }
        }
    }
    None
}

pub enum EventResult {
    Action(Action),
    Nothing,
}

pub enum Action {
    Quit,
    Refresh,
    ToggleActivate,
    ToggleMonitor,
    ToggleLid,
    NextFocus,
    PrevFocus,
    NextPreset,
    PrevPreset,
    ActivatePreset(usize),
}

fn handle_key(key: KeyEvent) -> EventResult {
    let action = match key.code {
        // Quit
        KeyCode::Char('q') | KeyCode::Esc => Some(Action::Quit),

        // Navigation
        KeyCode::Tab => Some(Action::NextFocus),
        KeyCode::BackTab => Some(Action::PrevFocus),
        KeyCode::Down | KeyCode::Char('j') => Some(Action::NextFocus),
        KeyCode::Up | KeyCode::Char('k') => Some(Action::PrevFocus),
        KeyCode::Right | KeyCode::Char('l') => Some(Action::NextPreset),
        KeyCode::Left | KeyCode::Char('h') => Some(Action::PrevPreset),

        // Actions
        KeyCode::Enter => Some(Action::ToggleActivate),
        KeyCode::Char('m') => Some(Action::ToggleMonitor),
        KeyCode::Char('d') => Some(Action::ToggleLid),
        KeyCode::Char(' ') => Some(Action::ToggleActivate),

        // Number shortcuts for presets
        KeyCode::Char('1') => Some(Action::ActivatePreset(0)),
        KeyCode::Char('2') => Some(Action::ActivatePreset(1)),
        KeyCode::Char('3') => Some(Action::ActivatePreset(2)),
        KeyCode::Char('4') => Some(Action::ActivatePreset(3)),

        // Refresh
        KeyCode::Char('r') => Some(Action::Refresh),

        _ => None,
    };

    match action {
        Some(a) => EventResult::Action(a),
        None => EventResult::Nothing,
    }
}

/// Apply an action to the app state
pub fn apply_action(app: &mut App, action: Action) {
    match action {
        Action::Quit => app.quit(),
        Action::Refresh => app.refresh_state(),
        Action::ToggleActivate => {
            if app.focus == Focus::Presets {
                // Activate with selected preset
                let presets = &app.config.timeouts.presets;
                if let Some(&dur) = presets.get(app.selected_preset) {
                    app.activate(dur);
                }
            } else if app.focus == Focus::Toggle {
                app.toggle();
            } else {
                app.toggle();
            }
        }
        Action::ToggleMonitor => app.toggle_monitor(),
        Action::ToggleLid => app.toggle_lid(),
        Action::NextFocus => app.next_focus(),
        Action::PrevFocus => app.prev_focus(),
        Action::NextPreset => {
            if app.focus == Focus::Presets {
                app.next_preset();
            }
        }
        Action::PrevPreset => {
            if app.focus == Focus::Presets {
                app.prev_preset();
            }
        }
        Action::ActivatePreset(idx) => {
            let presets = &app.config.timeouts.presets;
            if idx < presets.len() {
                app.selected_preset = idx;
                app.activate(presets[idx]);
            }
        }
    }
}
