use ratatui::style::{Color, Modifier, Style};

// Gundam-derived palette (shared across dispatch, zaku, ledger, cg)
pub const RED: Color = Color::Rgb(204, 34, 34);
pub const BLUE: Color = Color::Rgb(43, 79, 129);
pub const YELLOW: Color = Color::Rgb(245, 197, 24);
pub const WHITE: Color = Color::Rgb(240, 240, 240);
pub const DARK: Color = Color::Rgb(30, 30, 35);
pub const DIM: Color = Color::Rgb(80, 80, 90);
pub const CYAN: Color = Color::Rgb(40, 180, 180);
pub const GREEN: Color = Color::Rgb(80, 200, 80);
pub const SELECTED_BG: Color = Color::Rgb(50, 50, 60);

pub fn border_active() -> Style {
    Style::default().fg(CYAN)
}

pub fn border_inactive() -> Style {
    Style::default().fg(DIM)
}

pub fn title() -> Style {
    Style::default().fg(YELLOW).add_modifier(Modifier::BOLD)
}

pub fn header() -> Style {
    Style::default().fg(WHITE).add_modifier(Modifier::BOLD)
}

pub fn hint() -> Style {
    Style::default().fg(DIM)
}

pub fn selected() -> Style {
    Style::default().bg(SELECTED_BG).fg(WHITE)
}

pub fn label_style(label: &str) -> Style {
    match label {
        "Project" => Style::default().fg(YELLOW),
        "Folder" => Style::default().fg(BLUE),
        "File" => Style::default().fg(WHITE),
        "Module" => Style::default().fg(CYAN),
        "Function" => Style::default().fg(GREEN),
        "Class" => Style::default().fg(RED),
        "Section" => Style::default().fg(DIM),
        "Variable" => Style::default().fg(Color::Rgb(180, 140, 255)),
        _ => Style::default().fg(WHITE),
    }
}

pub fn status_bar() -> Style {
    Style::default().bg(Color::Rgb(30, 30, 30)).fg(GREEN)
}

pub fn editing() -> Style {
    Style::default().fg(YELLOW)
}
