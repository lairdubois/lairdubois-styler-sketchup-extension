# Styler

Prototype SketchUp extension that restyles SketchUp's Qt interface with a Qt style
sheet (QSS), starting with the toolbar buttons (hover / checked / pressed).

**Status: prototype.** Validated on SketchUp 2027 for macOS (arm64) only; reports
itself unsupported elsewhere. Not meant for the Extension Warehouse (it calls Qt
through Fiddle).

## How it works

One native call: `QApplication::setStyleSheet`, reached through Fiddle
(`src/ladb_styler/qt.rb`). The theme is turned into QSS by
`theme.rb`, saved with `Sketchup.write_default` and re-applied at startup.

Toolbar specifics (SketchUp 2027):

- toolbars are `qtapputils::ToolBar` (`qtapputils--ToolBar` in QSS), not `QToolBar`;
- a toolbar is targeted by the name given to `UI::Toolbar.new`:
  `qtapputils--ToolBar[windowTitle^="Name"]`;
- any QSS rule on a `QToolButton` grows it by 3 px + the border width, and the
  toolbar layout ignores `min/max-width`: the generator compensates with a negative
  padding, identical for every styled state so nothing jumps on hover.

Guard: if another extension already set an application style sheet, nothing is
applied (it would be wiped, and it cannot be read back).

## Usage

Extensions > Styler > Settings… — every change is saved and applied live.

Ruby console:

```ruby
Ladb::Styler.apply       # re-apply the saved theme
Ladb::Styler.clear       # native look until the next apply
puts Ladb::Styler.qss    # generated style sheet
```

## Development

Add `src/` as an extra load path with the Extension Sources extension, or build
with `./build.sh` (produces `dist/ladb_styler-<version>.rbz`).
