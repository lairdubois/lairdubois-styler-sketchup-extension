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
- `src/ladb_styler/qt.rb` — the Qt native layer (Fiddle → Qt)
- `src/ladb_styler/macos.rb` — the AppKit native layer (Fiddle → `objc_msgSend`): main window title bar color
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

- **Never an application style sheet.** SketchUp does `qobject_cast<SketchUpProxyStyle*>(QApplication::style())`
  without a null check in 11 places (Measurements toolbar `sizeHint`, Ruby toolbar creation,
  icon size…); `QApplication::setStyleSheet` makes that style a `QStyleSheetStyle` → SIGSEGV
  (crash seen 2026-09-22). The sheet goes on the main window (`CMainFrame`) with
  `QWidget::setStyleSheet`: it covers every descendant and leaves the application style alone.
- **Minimal native surface.** One Qt call that matters: `QWidget::setStyleSheet` on `CMainFrame`; on the
  AppKit side, only `NSWindow` property setters/getters (`macos.rb`), no native callback (a Ruby
  exception in one kills SketchUp — use a Ruby timer instead). Never
  call a Qt function returning a value type by value (`QString`, `QPalette`, `QVariant`…):
  on arm64 the result goes through x8 and Fiddle cannot receive it. Small PODs that fit
  in x0 (`QSize`) are fine. Build `QString` arguments by hand (`{nullptr, utf16*, size}`).
- **Never `QWidget::render` into a `QImage` through Fiddle**: it killed SketchUp instantly.
  No native experiment in the live SketchUp before a headless check.
- **Foreign style sheet guard.** A style sheet we did not set reaching the main window (its
  `QWidget::style()` class is `QStyleSheetStyle` while `Qt.owned?` is false) is never
  overwritten: it cannot be read back to merge.
- **Toolbar geometry.** Toolbars are `qtapputils::ToolBar` (`qtapputils--ToolBar` in QSS),
  not `QToolBar`. Any QSS rule on a `QToolButton` grows it by 3 px + border width and drops
  the menu-arrow area of `popupMode = 1` buttons; the toolbar layout ignores `min/max-width`.
  Compensate with negative padding, identical for every styled state. Verify any new
  toolbar property by measuring `sizeHint` / geometry before exposing it.
- Never put `qproperty-*` on a sub-control (`::close-button`…): Qt crashes.
- Ruby runs inside SketchUp 2027 (Ruby 3.4); inside `Ladb::…` always write `::Fiddle`.
- Native-layer module state that must survive a `load` (`@keep`, `@owned`, `@timer`) is
  initialized with `unless defined?(…)`: resetting `@keep` would let the GC free buffers Qt reads.
