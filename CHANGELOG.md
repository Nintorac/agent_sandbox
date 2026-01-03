# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.31] - 2025-12-01

### Added
- **Vim-style Navigation**: Use `h`/`j`/`k`/`l` (or `Alt`+keys) to navigate between panes and select items in the TUI.
- **Manual Refresh**: Press `Ctrl+Shift+R` to trigger a background re-index without restarting the application.
- **Hidden Pane Indicators**: Visual arrows (`◀ +2`, `+3 ▶`) now show when agent panes are scrolled out of view.
- **Autocomplete**: Agent filter (`F3`) now shows a dropdown with matching agent names.
- **Line Number Navigation**: Search results now track exact line numbers, allowing precise jumps when opening in an editor (`F8`).
- **Time Chips**: Filter chips now display human-readable dates (e.g., "Nov 25") instead of raw timestamps.
- **Reset State**: `Ctrl+Shift+Del` now resets the TUI state (clears history, filters, layout preferences) to defaults.

### Fixed
- **Binary Name**: Fixed error messages referencing incorrect binary name (`coding-agent-search` -> `cass`).
- **Unsafe Code**: Removed unsafe `transmute` usage in UI rendering code.
- **Editor Fallback**: Removed fragile snippet parsing for line numbers; now uses robust index data.
- **Status Bar**: Cleaned up status bar layout to prevent text overflow and improve readability.

### Changed
- **Help**: Updated help strip and F1 help overlay with new shortcuts.
