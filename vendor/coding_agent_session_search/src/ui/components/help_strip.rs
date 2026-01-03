//! Contextual help strip rendering.

use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
};

use crate::ui::components::theme::ThemePalette;

/// Render the help strip given a list of (key, label) pairs.
pub fn draw_help_strip(
    f: &mut Frame<'_>,
    area: Rect,
    shortcuts: &[(String, String)],
    palette: ThemePalette,
    pinned: bool,
) {
    let spans: Vec<Span> = shortcuts
        .iter()
        .flat_map(|(key, label)| {
            vec![
                Span::styled(
                    format!(" {key} "),
                    Style::default()
                        .fg(palette.fg)
                        .bg(palette.surface)
                        .add_modifier(Modifier::BOLD),
                ),
                Span::styled(format!("{label}  "), Style::default().fg(palette.hint)),
            ]
        })
        .collect();

    let block = Block::default()
        .borders(Borders::TOP)
        .title(if pinned { "Help (pinned)" } else { "Help" })
        .style(Style::default().fg(palette.hint));

    let para = Paragraph::new(Line::from(spans)).block(block);
    f.render_widget(para, area);
}

/// Compute layout to allocate a single-line help strip at bottom.
pub fn help_strip_area(area: Rect) -> Rect {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(1), Constraint::Length(1)])
        .split(area);
    chunks[1]
}
