//! HyprCaffeine Premium TUI — Phase 4
//! Interactive dashboard built with ratatui + crossterm

mod app;
mod event;
mod theme;
mod ui;

use std::io;

use clap::Parser;
use crossterm::event::DisableMouseCapture;
use crossterm::event::EnableMouseCapture;
use crossterm::execute;
use crossterm::terminal::disable_raw_mode;
use crossterm::terminal::enable_raw_mode;
use crossterm::terminal::EnterAlternateScreen;
use crossterm::terminal::LeaveAlternateScreen;
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;

use app::App;
use event::{apply_action, poll_event, EventResult};

#[derive(Parser, Debug)]
#[command(name = "hyprcaffeine-tui")]
#[command(about = "Premium TUI dashboard for HyprCaffeine")]
#[command(version)]
struct Args {
    /// Optional config file path
    #[arg(long)]
    config: Option<String>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let _args = Args::parse();

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Run app
    let result = run_app(&mut terminal);

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = result {
        eprintln!("Error: {}", err);
    }

    Ok(())
}

fn run_app(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> Result<(), Box<dyn std::error::Error>> {
    let mut app = App::new();

    // Initial draw
    terminal.draw(|f| ui::draw(f, &app))?;

    loop {
        // Poll events with 500ms timeout (2 ticks per second for blink)
        match poll_event(500) {
            Some(EventResult::Action(action)) => {
                apply_action(&mut app, action);
            }
            Some(EventResult::Nothing) => {}
            None => {}
        }

        // Always refresh state on each loop iteration
        app.refresh_state();

        // Draw
        terminal.draw(|f| ui::draw(f, &app))?;

        if app.should_quit {
            break;
        }
    }

    Ok(())
}
