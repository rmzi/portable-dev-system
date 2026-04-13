pub mod render;
pub mod state;
pub mod theme;

use anyhow::{Context, Result};
use crossterm::event::{self, DisableMouseCapture, EnableMouseCapture, Event};
use crossterm::execute;
use crossterm::terminal::{self, EnterAlternateScreen, LeaveAlternateScreen};
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use std::io;
use std::path::Path;
use std::time::Duration;

use crate::db::Db;
use state::App;

pub fn run(db_path: &Path, project: &str) -> Result<()> {
    // Set up panic hook to restore terminal
    let original_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let _ = terminal::disable_raw_mode();
        let _ = execute!(io::stdout(), LeaveAlternateScreen, DisableMouseCapture);
        original_hook(info);
    }));

    terminal::enable_raw_mode().context("Failed to enable raw mode")?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;

    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = run_loop(&mut terminal, db_path, project);

    // Restore terminal
    terminal::disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    result
}

fn run_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    db_path: &Path,
    project: &str,
) -> Result<()> {
    let db = Db::open(db_path, project)?;
    let mut app = App::new(&db, project, &db_path.display().to_string());

    loop {
        terminal.draw(|f| {
            render::draw(f, &app, &db);
        })?;

        // 100ms poll — no animations, just responsive input
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                app.handle_key(key, &db);
            }
        }

        if app.should_quit {
            break;
        }
    }

    Ok(())
}
