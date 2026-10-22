# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**Styler** is a prototype SketchUp extension that restyles SketchUp's Qt interface
with a Qt style sheet (QSS), starting with the toolbar buttons (hover / checked /
pressed). It is a prototype: Extension Warehouse validation is not a concern yet.

Validated on **SketchUp 2027 for macOS (arm64)** only. Anywhere else the extension
reports itself unsupported and does nothing.

## Layout

- `src/ladb_styler.rb` — extension registrar (`Ladb::Styler`, version in `ex.version`)
- `src/ladb_styler/main.rb` — theme persistence (`Sketchup.write_default('ladb_styler', 'theme')`), menu, re-apply at startup
- `src/ladb_styler/qt.rb` — the **only** native layer (Fiddle → Qt)
- `src/ladb_styler/theme.rb` — theme settings → QSS generator
- `src/ladb_styler/dialog.rb` + `html/settings.html` — settings dialog, every change saved and applied live
- `./build.sh` → `dist/ladb_styler-<version>.rbz`

## Testing live

Through the Claude Bridge (see the global instructions): ask the user to start it, then
`load '…/src/ladb_styler/main.rb'` (or `dialog.rb` / `theme.rb` alone to reload one part).
`Ladb::Styler.apply`, `.clear`, `.qss` are the console helpers.

The QSS generator is pure Ruby: check it headless with plain `ruby` (`require './theme'`).
The dialog page can be rendered in headless Chrome with a stub `window.sketchup` object.
Headless harnesses and stub pages go in the scratchpad, never in the repo.

## Rules

- **Minimal native surface.** One call that matters: `QApplication::setStyleSheet`. Never
  call a Qt function returning a value type by value (`QString`, `QPalette`, `QVariant`…):
  on arm64 the result goes through x8 and Fiddle cannot receive it. Small PODs that fit
  in x0 (`QSize`) are fine. Build `QString` arguments by hand (`{nullptr, utf16*, size}`).
- **Never `QWidget::render` into a `QImage` through Fiddle**: it killed SketchUp instantly.
  No native experiment in the live SketchUp before a headless check.
- **Foreign style sheet guard.** An application style sheet we did not set (style class
  `QStyleSheetStyle` while `Qt.owned?` is false) is never overwritten: it cannot be read
  back to merge.
- **Toolbar geometry.** Toolbars are `qtapputils::ToolBar` (`qtapputils--ToolBar` in QSS),
  not `QToolBar`. Any QSS rule on a `QToolButton` grows it by 3 px + border width and drops
  the menu-arrow area of `popupMode = 1` buttons; the toolbar layout ignores `min/max-width`.
  Compensate with negative padding, identical for every styled state. Verify any new
  toolbar property by measuring `sizeHint` / geometry before exposing it.
- Never put `qproperty-*` on a sub-control (`::close-button`…): Qt crashes.
- Ruby runs inside SketchUp 2027 (Ruby 3.4); inside `Ladb::…` always write `::Fiddle`.
