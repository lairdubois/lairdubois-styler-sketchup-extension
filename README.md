# Styler

Prototype SketchUp extension that restyles SketchUp's Qt interface with a Qt style
sheet (QSS): toolbar buttons (hover / checked / pressed), the toolbars themselves
(background, border, padding, separators), the area behind them, the document
tabs above the 3D view, the scene tabs, the status bar, and the main window title bar.

**Status: prototype.** Validated on SketchUp 2027 for macOS (arm64) only; reports
itself unsupported elsewhere. Not meant for the Extension Warehouse (it calls Qt
through Fiddle).

## How it works

One Qt call that matters: `QWidget::setStyleSheet` on the main window
(`CMainFrame`), reached through Fiddle (`src/ladb_styler/qt.rb`). Never an
application style sheet: SketchUp casts `QApplication::style()` to its own proxy
style without checking in 11 places, and crashes as soon as that style is a
`QStyleSheetStyle` (showing the Measurements toolbar, creating a Ruby toolbar…). The theme is turned into QSS by
`theme.rb`, saved with `Sketchup.write_default` and re-applied at startup.

The title bar of the main window is AppKit, not Qt: `src/ladb_styler/macos.rb`
makes it transparent over the window background color, and a 1 s timer re-applies
it when Qt resets it (leaving full screen).

Toolbar specifics (SketchUp 2027):

- toolbars are `qtapputils::ToolBar` (`qtapputils--ToolBar` in QSS), not `QToolBar`;
- a toolbar is targeted by the name given to `UI::Toolbar.new`:
  `qtapputils--ToolBar[windowTitle^="Name"]`;
- any QSS rule on a `QToolButton` grows it by 3 px + the border width, and the
  toolbar layout ignores `min/max-width`: the generator compensates with a negative
  padding, identical for every styled state so nothing jumps on hover;
- separators paint through the style: `qtapputils--ToolBar::separator`
  (`:horizontal` / `:vertical`), native color `#979797`;
- the bar's native 1 px frame stays until a QSS border replaces it, and its
  border + padding push the buttons: the generator keeps the native geometry
  unless a padding is asked for.

Document tabs (SketchUp 2027):

- they are the KDDockWidgets tab bar of the viewer (`SketchUpTabBarWidget`, a
  `QTabBar`); tray tab bars sit at the bottom, so `SketchUpTabBarWidget::tab:top`
  only reaches the document tabs;
- a text color keeps the native tab, a background replaces its frame but keeps its
  size and centered title; a border, radius or padding makes Qt lay the tab out
  itself (smaller, title off-center), so they are not offered;
- the strip behind the tabs is the dock area (KDDW `MainWindow`) showing through;
  it also shows through the tray title bars and the dock separators, which get
  `palette(window)` back.
- the `+` is a `QToolButton` of the viewer's stack
  (`SketchUpStackWidget[tabPosition="North"] > QToolButton`), sized 27 x 27 by
  KDDW: a QSS border does not move it, unlike toolbar buttons. Its width follows
  `min-width` though. It is the stack's top-right corner widget, sized from its
  `sizeHint` and clamped by min/max: its box is pinned with min = max, the gap
  after the tabs is a `margin-left`. SketchUp raises it as its font grows, so a
  `margin-top` (measured table) keeps the box centered.
- the frame around the 3D view is the stack's `::pane`: natively 2 px (gray +
  white) left, right and bottom; a QSS border replaces it on every side and the
  view follows (`border: none` = edge to edge). Right of the tabs, KDDW's
  `Group` draws an outline in a hard-coded color; with no frame, the pane is
  stretched up under the tab bar (`margin-top: -32px; border-top: 32px`, the
  content does not move) and that border covers it;
- the close cross is Qt's `CloseButton` (20 x 20), styled with
  `SketchUpTabBarWidget::close-button` (background, radius, `:hover`, `:pressed`,
  `image`); a colored cross is an SVG written to `Sketchup.temp_dir/ladb_styler`
  on every apply, since QSS `url()` only reads files. SketchUp shows the cross
  on the active tab only.

Scene tabs (SketchUp 2027), below the document tabs when the model has scenes:
`CPageTabs` holds a `QTabBar` (`CPageTabs > QTabBar::tab`), the search
`QPushButton` and the `+` `QToolButton`. Tabs take a background and a text color
(a border relays them out, as for document tabs); both buttons take background,
border and radius without moving, each with its own colors (`QPushButton` and
`QToolButton` tell them apart). The `+` also takes a gap (`margin-left`, which
pushes the painted box right of its widget), a box size (`min` = `max`) and a
glyph size, like the document `+`; `CPageTabs` keeps the box bottom on the tab
line, so a `margin-bottom` of half the height lost lifts a smaller box back to
the center. The
search button takes its own box (native 38 x 26, 24 x 18 to 56 x 32, centered
on the 32 px band, the tabs following its width); a border would otherwise
shrink it to its icon, so `min` = `max` is emitted as soon as one is set. Its
icon is a pixmap: no text color. The strip around them is the frame's `::pane`
background: it needs a frame color or none (it stays white over the native frame);
with no frame, a 32 px top border in the document strip color now covers the KDDW
outline. The line under the strip is `CPageTabs`' palette painted `darker(140)`:
the generator lightens the asked color by 1.4. The band itself is 33 px, sized
by `ViewerWidget`: `min` = `max` on `CPageTabs` moves it (28 to 64 px) and the
3D view follows, the tabs keeping their bottom on it and the search button
staying centered.

Status bar (SketchUp 2027): the viewer's `QStatusBar` (`ViewerWidget > QStatusBar`)
takes a background and a text color, its two buttons `:hover` / `:pressed`
(fixed 28 x 27 by the layout). The Measurements box and the separators are plain
`QWidget`s no selector isolates (`.QWidget` would also paint the container over
the help text): they stay native.

Guard: if a style sheet from another extension already reaches the main window,
nothing is applied (it would be wiped, and it cannot be read back).

## Usage

Extensions > Styler > Settings… — every change is saved and applied live. Each
panel folds (its state is kept per viewer in `localStorage`; the `.open` property
is unreliable in SketchUp's CEF, the `open` attribute is not) and has its own
switch: a section turned off emits no rule at all, the title bar one also
releasing the AppKit color.

Ruby console:

```ruby
Ladb::Styler.apply       # re-apply the saved theme
Ladb::Styler.clear       # native look until the next apply
puts Ladb::Styler.qss    # generated style sheet
```

## Development

Add `src/` as an extra load path with the Extension Sources extension, or build
with `./build.sh` (produces `dist/ladb_styler-<version>.rbz`).
