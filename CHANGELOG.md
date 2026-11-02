# Changelog

All notable changes to Styler are documented in this file.

Styler is a prototype, validated on SketchUp 2027 for macOS (Apple Silicon) only.

## [0.1.4] - 2026-11-02

### Added

- **Built-in presets**: five ready-made themes in the Presets card: Styler BlueSky (the default look),
  Styler Graphite, Styler Steel, Styler Night and Styler Sand. They are read-only, and a saved preset
  cannot take one of their names.
- **Preset state**: the last applied or saved preset is marked *applied*, then *● modified* as soon as a
  setting changes.
- **Preset actions**: a ⋯ menu on each saved preset with *Update with current settings*, *Rename*
  (in place), *Export…* and *Delete*. *+ Save current…* saves the current settings as a new preset.
- **Toolbars — normal button color**: background and border for buttons at rest, not only the hover,
  checked and pressed states.
- **Toolbars — move handle**: the grip of docked toolbars can stay *Native*, be redrawn as *Dots* in a
  chosen color, or be hidden (*None*).
- **Scene tabs — search lens color**: the magnifier left of the scene tabs can be recolored (normal and
  hover), with a faded version while the model has no scene.
- **Color text fields**: every swatch now has a text field that accepts `#rgb` or `#rrggbb` (the `#`
  optional), `none` / `transparent` where offered, or empty to unset.

### Changed

- Applying a preset always turns styling on.
- The toolbar background is now native by default.
- The palette is on by default in the base theme.
- The document and scene tab "strip" settings are renamed *Background*. Presets from earlier versions
  are converted automatically.
- The settings dialog's minimum width is slightly larger.

### Fixed

- Image assets are written as binary files, so the PNG lens icon is no longer corrupted.

[0.1.4]: https://github.com/lairdubois/lairdubois-styler-sketchup-extension/releases/tag/v0.1.4
