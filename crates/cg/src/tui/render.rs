use ratatui::{
    layout::{Constraint, Direction, Layout, Margin, Rect},
    style::{Modifier, Style},
    text::{Line, Span, Text},
    widgets::{
        Block, Borders, Cell, Paragraph, Row, Scrollbar, ScrollbarOrientation, ScrollbarState,
        Table, TableState, Wrap,
    },
    Frame,
};

use super::state::{App, FnSortColumn, Focus, InputMode, View};
use super::theme;
use crate::db::Db;

/// Render the full UI.
pub fn draw(f: &mut Frame, app: &App, db: &Db) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1), // tab bar
            Constraint::Min(10),  // main content
            Constraint::Length(1), // status bar
        ])
        .split(f.area());

    draw_tab_bar(f, app, chunks[0]);

    match app.view {
        View::ModuleTree => draw_module_tree(f, app, db, chunks[1]),
        View::FunctionList => draw_function_list(f, app, chunks[1]),
        View::Search => draw_search(f, app, chunks[1]),
    }

    draw_status_bar(f, app, chunks[2]);
}

fn draw_tab_bar(f: &mut Frame, app: &App, area: Rect) {
    let views = [View::ModuleTree, View::FunctionList, View::Search];
    let tabs: Vec<Span> = views
        .iter()
        .enumerate()
        .flat_map(|(i, v)| {
            let mut spans = Vec::new();
            if i > 0 {
                spans.push(Span::styled(" │ ", Style::default().fg(theme::DIM)));
            }
            let label = format!(" {} {} ", i + 1, v.label());
            if *v == app.view {
                spans.push(Span::styled(
                    label,
                    Style::default()
                        .fg(theme::YELLOW)
                        .add_modifier(Modifier::BOLD),
                ));
            } else {
                spans.push(Span::styled(label, Style::default().fg(theme::DIM)));
            }
            spans
        })
        .collect();

    let bar = Paragraph::new(Line::from(tabs))
        .style(Style::default().bg(theme::DARK));
    f.render_widget(bar, area);
}

// ── Module Tree ──────────────────────────────────────────

fn draw_module_tree(f: &mut Frame, app: &App, db: &Db, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(area);

    draw_tree_list(f, app, chunks[0]);
    draw_tree_detail(f, app, db, chunks[1]);
}

fn draw_tree_list(f: &mut Frame, app: &App, area: Rect) {
    let border = if app.tree_focus == Focus::List {
        theme::border_active()
    } else {
        theme::border_inactive()
    };

    let block = Block::default()
        .title(Span::styled(
            format!(" Module Tree ({} nodes) ", app.tree_flat_indices.len()),
            theme::title(),
        ))
        .borders(Borders::ALL)
        .border_style(border);

    let inner = block.inner(area);
    f.render_widget(block, area);

    // Build visible lines from flat indices
    let mut lines: Vec<Line> = Vec::new();
    for (i, path) in app.tree_flat_indices.iter().enumerate() {
        let node = get_tree_node_display(&app.tree_root, path);
        if let Some((tree_node, depth)) = node {
            let is_selected = i == app.tree_cursor;
            let indent = "  ".repeat(depth);

            let icon = match tree_node.node.label.as_str() {
                "Project" => if tree_node.expanded { "v " } else { "> " },
                "Folder" => if tree_node.expanded { "v " } else { "> " },
                "File" => if tree_node.expanded { "v " } else { "  " },
                "Module" => "# ",
                "Function" => "f ",
                "Class" => "C ",
                "Section" => "@ ",
                "Variable" => "$ ",
                _ => "  ",
            };

            let name_style = if is_selected {
                theme::selected().add_modifier(Modifier::BOLD)
            } else {
                theme::label_style(&tree_node.node.label)
            };

            let line = Line::from(vec![
                Span::styled(indent, Style::default()),
                Span::styled(icon, Style::default().fg(theme::DIM)),
                Span::styled(tree_node.node.name.clone(), name_style),
            ]);
            lines.push(line);
        }
    }

    // Calculate scroll offset to keep cursor visible
    let visible_height = inner.height as usize;
    let scroll = if app.tree_cursor >= visible_height {
        app.tree_cursor - visible_height + 1
    } else {
        0
    };

    let paragraph = Paragraph::new(Text::from(lines)).scroll((scroll as u16, 0));
    f.render_widget(paragraph, inner);

    // Scrollbar
    if !app.tree_flat_indices.is_empty() {
        let mut scrollbar_state =
            ScrollbarState::new(app.tree_flat_indices.len()).position(app.tree_cursor);
        f.render_stateful_widget(
            Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .begin_symbol(None)
                .end_symbol(None),
            area.inner(Margin {
                vertical: 1,
                horizontal: 0,
            }),
            &mut scrollbar_state,
        );
    }
}

fn draw_tree_detail(f: &mut Frame, app: &App, db: &Db, area: Rect) {
    let border = if app.tree_focus == Focus::Detail {
        theme::border_active()
    } else {
        theme::border_inactive()
    };

    let block = Block::default()
        .title(Span::styled(" Detail ", theme::title()))
        .borders(Borders::ALL)
        .border_style(border);

    match app.selected_tree_node() {
        Some(tree_node) => {
            let node = &tree_node.node;
            let mut lines: Vec<Line> = vec![
                Line::from(vec![
                    Span::styled("Name:  ", Style::default().fg(theme::DIM)),
                    Span::styled(&node.name, theme::label_style(&node.label)),
                ]),
                Line::from(vec![
                    Span::styled("Type:  ", Style::default().fg(theme::DIM)),
                    Span::styled(&node.label, theme::label_style(&node.label)),
                ]),
            ];

            if !node.file_path.is_empty() {
                lines.push(Line::from(vec![
                    Span::styled("Path:  ", Style::default().fg(theme::DIM)),
                    Span::raw(&node.file_path),
                ]));
            }

            if node.start_line > 0 {
                lines.push(Line::from(vec![
                    Span::styled("Lines: ", Style::default().fg(theme::DIM)),
                    Span::raw(format!("{}-{}", node.start_line, node.end_line)),
                ]));
            }

            if !node.properties.docstring.is_empty() {
                lines.push(Line::from(""));
                lines.push(Line::from(Span::styled(
                    "── Docstring ──",
                    Style::default().fg(theme::DIM),
                )));
                for l in node.properties.docstring.lines() {
                    lines.push(Line::from(Span::raw(l.to_string())));
                }
            }

            // Show defined symbols for File nodes
            if node.label == "File" {
                if let Ok(symbols) = db.symbols_in_file(node.id) {
                    if !symbols.is_empty() {
                        lines.push(Line::from(""));
                        lines.push(Line::from(Span::styled(
                            format!("── Symbols ({}) ──", symbols.len()),
                            Style::default().fg(theme::DIM),
                        )));
                        for sym in &symbols {
                            let icon = match sym.label.as_str() {
                                "Function" => "f",
                                "Class" => "C",
                                "Variable" => "$",
                                _ => " ",
                            };
                            lines.push(Line::from(vec![
                                Span::styled(
                                    format!("  {icon} "),
                                    Style::default().fg(theme::DIM),
                                ),
                                Span::styled(sym.name.clone(), theme::label_style(&sym.label)),
                                Span::styled(
                                    format!("  L{}", sym.start_line),
                                    Style::default().fg(theme::DIM),
                                ),
                            ]));
                        }
                    }
                }

                // Show co-changed files
                if let Ok(co_changed) = db.co_changed_files(node.id) {
                    if !co_changed.is_empty() {
                        lines.push(Line::from(""));
                        lines.push(Line::from(Span::styled(
                            format!("── Co-changed ({}) ──", co_changed.len()),
                            Style::default().fg(theme::DIM),
                        )));
                        for (name, _props) in &co_changed {
                            lines.push(Line::from(vec![
                                Span::styled("  ~ ", Style::default().fg(theme::DIM)),
                                Span::raw(name.clone()),
                            ]));
                        }
                    }
                }
            }

            let paragraph = Paragraph::new(Text::from(lines))
                .block(block)
                .wrap(Wrap { trim: false })
                .scroll((app.tree_detail_scroll, 0));
            f.render_widget(paragraph, area);
        }
        None => {
            let paragraph = Paragraph::new("No node selected")
                .block(block)
                .style(Style::default().fg(theme::DIM));
            f.render_widget(paragraph, area);
        }
    }
}

/// Navigate tree and return (node, depth).
fn get_tree_node_display<'a>(
    root: &'a super::state::TreeNode,
    path: &[usize],
) -> Option<(&'a super::state::TreeNode, usize)> {
    let mut current = root;
    for &idx in path {
        current = current.children.get(idx)?;
    }
    Some((current, path.len()))
}

// ── Function List ────────────────────────────────────────

fn draw_function_list(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(60), Constraint::Percentage(40)])
        .split(area);

    draw_fn_table(f, app, chunks[0]);
    draw_fn_detail(f, app, chunks[1]);
}

fn draw_fn_table(f: &mut Frame, app: &App, area: Rect) {
    let border = if app.fn_focus == Focus::List {
        theme::border_active()
    } else {
        theme::border_inactive()
    };

    let sort_indicator = |col: FnSortColumn| -> &'static str {
        if col == app.fn_sort_col {
            if app.fn_sort_asc { " ▲" } else { " ▼" }
        } else {
            ""
        }
    };

    let header = Row::new(vec![
        Cell::from(format!("Name{}", sort_indicator(FnSortColumn::Name))),
        Cell::from(format!("File{}", sort_indicator(FnSortColumn::File))),
        Cell::from(format!("Ln{}", sort_indicator(FnSortColumn::Lines))),
        Cell::from(format!("In{}", sort_indicator(FnSortColumn::Callers))),
        Cell::from(format!("Out{}", sort_indicator(FnSortColumn::Callees))),
        Cell::from(format!("Exp{}", sort_indicator(FnSortColumn::Exported))),
    ])
    .style(theme::header())
    .height(1);

    let rows: Vec<Row> = app
        .fn_sorted
        .iter()
        .enumerate()
        .map(|(display_idx, &fn_idx)| {
            let func = &app.functions[fn_idx];
            let (callers, callees) = app
                .fn_call_counts
                .get(&func.id)
                .copied()
                .unwrap_or((0, 0));

            let style = if display_idx == app.fn_selected {
                theme::selected().add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(theme::WHITE)
            };

            Row::new(vec![
                Cell::from(func.name.as_str()),
                Cell::from(func.file_path.as_str()),
                Cell::from(format!("{}", func.properties.lines)),
                Cell::from(format!("{callers}")),
                Cell::from(format!("{callees}")),
                Cell::from(if func.properties.is_exported {
                    "yes"
                } else {
                    ""
                }),
            ])
            .style(style)
        })
        .collect();

    let widths = [
        Constraint::Fill(2),
        Constraint::Fill(3),
        Constraint::Length(4),
        Constraint::Length(4),
        Constraint::Length(4),
        Constraint::Length(4),
    ];

    let table = Table::new(rows, widths)
        .header(header)
        .block(
            Block::default()
                .title(Span::styled(
                    format!(" Functions ({}) ", app.functions.len()),
                    theme::title(),
                ))
                .borders(Borders::ALL)
                .border_style(border),
        )
        .row_highlight_style(theme::selected().add_modifier(Modifier::BOLD));

    let mut state = TableState::default();
    state.select(Some(app.fn_selected));
    f.render_stateful_widget(table, area, &mut state);

    // Scrollbar
    if !app.fn_sorted.is_empty() {
        let mut scrollbar_state =
            ScrollbarState::new(app.fn_sorted.len()).position(app.fn_selected);
        f.render_stateful_widget(
            Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .begin_symbol(None)
                .end_symbol(None),
            area.inner(Margin {
                vertical: 1,
                horizontal: 0,
            }),
            &mut scrollbar_state,
        );
    }
}

fn draw_fn_detail(f: &mut Frame, app: &App, area: Rect) {
    let border = if app.fn_focus == Focus::Detail {
        theme::border_active()
    } else {
        theme::border_inactive()
    };

    let block = Block::default()
        .title(Span::styled(" Detail ", theme::title()))
        .borders(Borders::ALL)
        .border_style(border);

    match app.selected_function() {
        Some(func) => {
            let (callers, callees) = app
                .fn_call_counts
                .get(&func.id)
                .copied()
                .unwrap_or((0, 0));

            let mut lines: Vec<Line> = vec![
                Line::from(vec![
                    Span::styled("Name:     ", Style::default().fg(theme::DIM)),
                    Span::styled(&func.name, Style::default().fg(theme::GREEN)),
                ]),
                Line::from(vec![
                    Span::styled("File:     ", Style::default().fg(theme::DIM)),
                    Span::raw(&func.file_path),
                ]),
                Line::from(vec![
                    Span::styled("Lines:    ", Style::default().fg(theme::DIM)),
                    Span::raw(format!(
                        "{}-{} ({} lines)",
                        func.start_line, func.end_line, func.properties.lines
                    )),
                ]),
                Line::from(vec![
                    Span::styled("Callers:  ", Style::default().fg(theme::DIM)),
                    Span::raw(format!("{callers}")),
                ]),
                Line::from(vec![
                    Span::styled("Callees:  ", Style::default().fg(theme::DIM)),
                    Span::raw(format!("{callees}")),
                ]),
                Line::from(vec![
                    Span::styled("Exported: ", Style::default().fg(theme::DIM)),
                    Span::raw(if func.properties.is_exported {
                        "yes"
                    } else {
                        "no"
                    }),
                ]),
                Line::from(vec![
                    Span::styled("Test:     ", Style::default().fg(theme::DIM)),
                    Span::raw(if func.properties.is_test {
                        "yes"
                    } else {
                        "no"
                    }),
                ]),
            ];

            if !func.properties.docstring.is_empty() {
                lines.push(Line::from(""));
                lines.push(Line::from(Span::styled(
                    "── Docstring ──",
                    Style::default().fg(theme::DIM),
                )));
                for l in func.properties.docstring.lines() {
                    lines.push(Line::from(Span::raw(l.to_string())));
                }
            }

            let paragraph = Paragraph::new(Text::from(lines))
                .block(block)
                .wrap(Wrap { trim: false })
                .scroll((app.fn_detail_scroll, 0));
            f.render_widget(paragraph, area);
        }
        None => {
            let paragraph = Paragraph::new("No function selected")
                .block(block)
                .style(Style::default().fg(theme::DIM));
            f.render_widget(paragraph, area);
        }
    }
}

// ── Search ───────────────────────────────────────────────

fn draw_search(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // search input
            Constraint::Min(5),   // results + detail
        ])
        .split(area);

    draw_search_input(f, app, chunks[0]);

    let result_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(chunks[1]);

    draw_search_results(f, app, result_chunks[0]);
    draw_search_detail(f, app, result_chunks[1]);
}

fn draw_search_input(f: &mut Frame, app: &App, area: Rect) {
    let border = if app.search_mode == InputMode::Editing {
        theme::editing()
    } else {
        theme::border_inactive()
    };

    let title = if app.search_mode == InputMode::Editing {
        " Search (typing...) "
    } else {
        " Search (/ to type) "
    };

    let block = Block::default()
        .title(Span::styled(title, theme::title()))
        .borders(Borders::ALL)
        .border_style(border);

    let input = Paragraph::new(app.search_input.as_str())
        .block(block)
        .style(Style::default().fg(theme::WHITE));
    f.render_widget(input, area);

    if app.search_mode == InputMode::Editing {
        f.set_cursor_position((
            area.x + app.search_input.len() as u16 + 1,
            area.y + 1,
        ));
    }
}

fn draw_search_results(f: &mut Frame, app: &App, area: Rect) {
    let border = if app.search_focus == Focus::List && app.search_mode == InputMode::Normal {
        theme::border_active()
    } else {
        theme::border_inactive()
    };

    let header = Row::new(vec![
        Cell::from("Type"),
        Cell::from("Name"),
        Cell::from("File"),
    ])
    .style(theme::header())
    .height(1);

    let rows: Vec<Row> = app
        .search_results
        .iter()
        .enumerate()
        .map(|(i, result)| {
            let style = if i == app.search_selected {
                theme::selected().add_modifier(Modifier::BOLD)
            } else {
                theme::label_style(&result.node.label)
            };
            Row::new(vec![
                Cell::from(result.node.label.as_str()),
                Cell::from(result.node.name.as_str()),
                Cell::from(result.node.file_path.as_str()),
            ])
            .style(style)
        })
        .collect();

    let widths = [
        Constraint::Length(10),
        Constraint::Fill(1),
        Constraint::Fill(1),
    ];

    let table = Table::new(rows, widths)
        .header(header)
        .block(
            Block::default()
                .title(Span::styled(
                    format!(" Results ({}) ", app.search_results.len()),
                    theme::title(),
                ))
                .borders(Borders::ALL)
                .border_style(border),
        )
        .row_highlight_style(theme::selected().add_modifier(Modifier::BOLD));

    let mut state = TableState::default();
    state.select(Some(app.search_selected));
    f.render_stateful_widget(table, area, &mut state);

    if !app.search_results.is_empty() {
        let mut scrollbar_state =
            ScrollbarState::new(app.search_results.len()).position(app.search_selected);
        f.render_stateful_widget(
            Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .begin_symbol(None)
                .end_symbol(None),
            area.inner(Margin {
                vertical: 1,
                horizontal: 0,
            }),
            &mut scrollbar_state,
        );
    }
}

fn draw_search_detail(f: &mut Frame, app: &App, area: Rect) {
    let border = if app.search_focus == Focus::Detail {
        theme::border_active()
    } else {
        theme::border_inactive()
    };

    let block = Block::default()
        .title(Span::styled(" Detail ", theme::title()))
        .borders(Borders::ALL)
        .border_style(border);

    match app.selected_search_result() {
        Some(result) => {
            let node = &result.node;
            let mut lines: Vec<Line> = vec![
                Line::from(vec![
                    Span::styled("Name:      ", Style::default().fg(theme::DIM)),
                    Span::styled(&node.name, theme::label_style(&node.label)),
                ]),
                Line::from(vec![
                    Span::styled("Type:      ", Style::default().fg(theme::DIM)),
                    Span::styled(&node.label, theme::label_style(&node.label)),
                ]),
                Line::from(vec![
                    Span::styled("Qualified: ", Style::default().fg(theme::DIM)),
                    Span::raw(&node.qualified_name),
                ]),
            ];

            if !node.file_path.is_empty() {
                lines.push(Line::from(vec![
                    Span::styled("File:      ", Style::default().fg(theme::DIM)),
                    Span::raw(&node.file_path),
                ]));
            }

            if node.start_line > 0 {
                lines.push(Line::from(vec![
                    Span::styled("Lines:     ", Style::default().fg(theme::DIM)),
                    Span::raw(format!("{}-{}", node.start_line, node.end_line)),
                ]));
            }

            lines.push(Line::from(vec![
                Span::styled("Rank:      ", Style::default().fg(theme::DIM)),
                Span::raw(format!("{:.2}", result.rank)),
            ]));

            if !node.properties.docstring.is_empty() {
                lines.push(Line::from(""));
                lines.push(Line::from(Span::styled(
                    "── Docstring ──",
                    Style::default().fg(theme::DIM),
                )));
                for l in node.properties.docstring.lines() {
                    lines.push(Line::from(Span::raw(l.to_string())));
                }
            }

            let paragraph = Paragraph::new(Text::from(lines))
                .block(block)
                .wrap(Wrap { trim: false })
                .scroll((app.search_detail_scroll, 0));
            f.render_widget(paragraph, area);
        }
        None => {
            let hint = if app.search_input.is_empty() {
                "Press / to search across all nodes"
            } else {
                "No results"
            };
            let paragraph = Paragraph::new(hint)
                .block(block)
                .style(Style::default().fg(theme::DIM));
            f.render_widget(paragraph, area);
        }
    }
}

// ── Status Bar ───────────────────────────────────────────

fn draw_status_bar(f: &mut Frame, app: &App, area: Rect) {
    let help = match app.view {
        View::ModuleTree => "j/k:nav  Enter:expand  h:collapse  L:detail  Tab:view  q:quit",
        View::FunctionList => {
            "j/k:nav  s/S:sort col  r:reverse  L:detail  Tab:view  q:quit"
        }
        View::Search => {
            if app.search_mode == InputMode::Editing {
                "type to search  Enter/Esc:done"
            } else {
                "/:search  j/k:nav  L:detail  Tab:view  q:quit"
            }
        }
    };

    let bar = Paragraph::new(Line::from(vec![
        Span::styled("● ", Style::default().fg(theme::GREEN)),
        Span::styled(&app.project_name, Style::default().fg(theme::CYAN)),
        Span::styled(
            format!("  │  {} nodes  {} edges  │  ", app.node_count, app.edge_count),
            Style::default().fg(theme::DIM),
        ),
        Span::styled(help, Style::default().fg(theme::DIM)),
    ]))
    .style(Style::default().bg(theme::DARK));

    f.render_widget(bar, area);
}
