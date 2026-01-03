//! Filter pill rendering helpers.

use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    widgets::{Block, BorderType, Borders, Paragraph},
};

use crate::ui::components::theme::ThemePalette;

#[derive(Clone, Debug)]
pub struct Pill {
    pub label: String,
    pub value: String,
    pub active: bool,
    pub editable: bool,
}

/// Render pills in a single row. Caller controls focus/interaction; returns rects for click hit-testing.
pub fn draw_pills(
    f: &mut Frame<'_>,
    area: Rect,
    pills: &[Pill],
    palette: ThemePalette,
) -> Vec<Rect> {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints(
            pills
                .iter()
                .map(|_| Constraint::Length(20))
                .chain(std::iter::once(Constraint::Min(0)))
                .collect::<Vec<_>>(),
        )
        .split(area);

    let mut rects = Vec::new();
    for (idx, pill) in pills.iter().enumerate() {
        if idx >= chunks.len() {
            break;
        }
        let bg = if pill.active {
            palette.surface
        } else {
            palette.bg
        };
        let border_color = if pill.active {
            palette.accent
        } else {
            palette.border
        };
        let text_color = if pill.active {
            palette.fg
        } else {
            palette.hint
        };
        let content = format!("{}: {}", pill.label, pill.value);
        let para = Paragraph::new(content).block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(if pill.active {
                    BorderType::Rounded
                } else {
                    BorderType::Plain
                })
                .border_style(Style::default().fg(border_color))
                .style(
                    Style::default()
                        .fg(text_color)
                        .bg(bg)
                        .add_modifier(if pill.editable {
                            Modifier::ITALIC
                        } else {
                            Modifier::empty()
                        }),
                ),
        );
        f.render_widget(para, chunks[idx]);
        rects.push(chunks[idx]);
    }
    rects
}
