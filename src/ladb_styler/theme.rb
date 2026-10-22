# Theme settings -> QSS.
#
# SketchUp 2027 toolbars are not QToolBar : NonCustomizableToolbar < … <
# qtapputils::ToolBar < QFrame, buttons being direct QToolButton children.
# In QSS, '::' is written '--'.
#
# Geometry (measured on macOS 2027) : as soon as a QSS rule applies to a
# QToolButton, QStyleSheetStyle adds 3 px to its size hint (1 px left/top,
# 2 px right/bottom), plus the border width on each side, and drops the menu
# arrow area of MenuButtonPopup buttons (popupMode = 1, 12 px). The custom
# ToolBarLayout only follows sizeHint (min/max-width are ignored), so the only
# lever is a negative padding. Every styled state gets the same geometry,
# otherwise the toolbar jumps on hover.
#
# The bar itself (QFrame, WA_StyledBackground) takes a QSS background and
# border. Its native 1 px frame (frameShape StyledPanel) stays drawn by
# SketchUp's style until a QSS border replaces it. The frame width follows the
# QSS border plus padding, and the toolbar layout follows it on every side
# (measured -1..6 px). Native buttons sit 2 px from the edge : frame 1 px +
# layout margin 1 px. So an edge-to-button space s with a w px border is
# padding s - 1 - w, with s >= w (buttons would cover the border) and w <= 2.
# ToolBarSeparator (6 x 32) paints through
# style()->drawPrimitive(PE_IndicatorToolBarSeparator, …, toolbar), so its rule
# is the toolbar's '::separator', with ':horizontal' / ':vertical' honoured ;
# a 1 px line is its background squeezed by margins. SketchUp's own separator
# color is #979797 (QColor constant read from ToolBarSeparator::paintEvent).
#
# Behind the docked toolbars is CMainFrame's central widget, a plain QWidget
# ('.QWidget' : exact class, CMainFrame's other children are menus, dialogs…)
# laid out by ToolBarContainerLayout, the dock area (KDDW MainWindow) below the
# toolbars. The dock area does not paint its background and would let the color
# through everywhere : it gets palette(window), its own native color, back. A
# style sheet palette does not propagate to children (measured).
#
# Unset means nothing : no separator, no border (1 px transparent, which hides
# the native frame). An unset background emits no rule : a docked bar paints
# none, and 'transparent' would blank the palette a floating toolbar paints its
# rounded background with.

require 'json'

module Ladb
  module Styler
    module Theme

      STATES = %w[hover checked pressed].freeze # later states win when combined (checked:hover…)

      DEFAULTS = {
        'enabled' => true,
        'toolbar' => {
          'enabled' => true,
          'scope' => 'all',     # 'all' | 'titles'
          'titles' => [],       # toolbar names (UI::Toolbar.new) matched by prefix when scope = 'titles'
          'radius' => 4,
          'border_width' => 1,  # 0..2 (0 and 1 measured)
          'hover' => { 'background' => '#dfecf8', 'border' => '#3e7ab6' },
          'checked' => { 'background' => '#dfecf8', 'border' => '#3e7ab6' },
          'pressed' => { 'background' => '#c7ddf2', 'border' => '#3e7ab6' },
          'bar' => { 'background' => '', 'border' => '', 'border_width' => 1, 'radius' => 6,  # '' = none ; width 1..2
                     'padding' => 2 },                                                          # edge to buttons, 2 = native
          'area' => { 'background' => '#f2f2f2' },  # behind the toolbars, whatever the scope ; '' = native
          'separator' => { 'color' => '#979797', 'inset' => 6 },           # '' = hidden ; inset at each end, 0..12
        },
        'extra_qss' => '',
      }.freeze

      def self.defaults
        JSON.parse(JSON.generate(DEFAULTS))
      end

      # Missing keys (older saved theme) fall back to defaults.
      def self.normalize(theme)
        _deep_merge(defaults, theme.is_a?(Hash) ? theme : {})
      end

      def self.to_qss(theme)
        theme = normalize(theme)
        return '' unless theme['enabled']
        [_toolbar_qss(theme['toolbar']), theme['extra_qss'].to_s.strip].reject(&:empty?).join("\n\n")
      end

      # -----

      def self._toolbar_qss(tb)
        return '' unless tb['enabled']

        bars = _toolbar_selectors(tb)
        buttons = bars.map { |s| "#{s} QToolButton" }
        w = tb['border_width'].to_i.clamp(0, 2)
        r = tb['radius'].to_i.clamp(0, 16)

        states = STATES.select { |st| tb[st].is_a?(Hash) }
        all = ->(suffix = '') { states.flat_map { |st| buttons.map { |b| "#{b}:#{st}#{suffix}" } }.join(",\n") }

        css = []
        css << "/* Toolbars: geometry shared by every styled state */"
        css << "#{all.call} {\n  border: #{w > 0 ? "#{w}px solid transparent" : 'none'};\n  border-radius: #{r}px;\n  padding: #{-(1 + w)}px #{-(2 + w)}px #{-(2 + w)}px #{-(1 + w)}px;\n}"
        css << "#{all.call('[popupMode="1"]')} {\n  padding-right: #{10 - w}px;\n}"
        states.each do |st|
          decl = []
          bg = _color(tb[st]['background'])
          bd = _color(tb[st]['border'])
          decl << "background-color: #{bg};" if bg
          decl << "border-color: #{bd};" if bd && w > 0
          next if decl.empty?
          css << "#{buttons.map { |b| "#{b}:#{st}" }.join(",\n")} {\n  #{decl.join("\n  ")}\n}"
        end
        css.concat(_bar_qss(bars, tb['bar']), _separator_qss(bars, tb['separator']), _area_qss(tb['area']))
        css.join("\n\n")
      end

      def self._bar_qss(bars, bar)
        return [] unless bar.is_a?(Hash)
        bg = _color(bar['background'])
        bd = _color(bar['border'])
        w = bd ? bar['border_width'].to_i.clamp(1, 2) : 1
        pad = bar['padding'].to_i.clamp(w, 8) - 1 - w
        decl = []
        decl << "background-color: #{bg};" if bg
        decl << "border: #{w}px solid #{bd || 'transparent'};"
        decl << "padding: #{pad}px;" unless pad == 0
        decl << "border-radius: #{bar['radius'].to_i.clamp(0, 12)}px;" if bg || bd
        ["/* Toolbars: the bar itself */\n#{bars.join(",\n")} {\n  #{decl.join("\n  ")}\n}"]
      end

      def self._area_qss(area)
        bg = area.is_a?(Hash) && _color(area['background'])
        return [] unless bg
        [
          "/* Toolbar area */\nCMainFrame > .QWidget {\n  background-color: #{bg};\n}",
          "CMainFrame > .QWidget > KDDockWidgets--QtWidgets--MainWindow {\n  background-color: palette(window);\n}",
        ]
      end

      # Horizontal toolbar : 6 px wide separator -> margins 3 + 2 leave a 1 px vertical line.
      def self._separator_qss(bars, sep)
        return [] unless sep.is_a?(Hash)
        seps = bars.map { |b| "#{b}::separator" }
        c = _color(sep['color'])
        return ["/* Toolbars: separators hidden */\n#{seps.join(",\n")} {\n  background: transparent;\n  border: none;\n}"] unless c
        i = sep['inset'].to_i.clamp(0, 12)
        [
          "/* Toolbars: separators */\n#{seps.map { |s| "#{s}:horizontal" }.join(",\n")} {\n  background-color: #{c};\n  margin: #{i}px 2px #{i}px 3px;\n}",
          "#{seps.map { |s| "#{s}:vertical" }.join(",\n")} {\n  background-color: #{c};\n  margin: 3px #{i}px 2px #{i}px;\n}",
        ]
      end

      def self._toolbar_selectors(tb)
        titles = Array(tb['titles']).map { |t| t.to_s.strip }.reject(&:empty?)
        if tb['scope'] == 'titles' && !titles.empty?
          titles.map { |t| %Q{qtapputils--ToolBar[windowTitle^="#{t.gsub(/["\\]/) { |c| "\\#{c}" }}"]} }
        else
          ['qtapputils--ToolBar']
        end
      end

      # '#rrggbb', 'rgb(…)', 'rgba(…)', 'transparent' or a palette(role) ; anything else is dropped.
      def self._color(value)
        v = value.to_s.strip
        return nil if v.empty?
        return v if v =~ /\A(#\h{3}|#\h{6}|#\h{8}|rgba?\([\d\s,.%]+\)|palette\(\s*[a-z-]+\s*\)|transparent)\z/i
        nil
      end

      def self._deep_merge(base, over)
        base.merge(over) { |_, a, b| a.is_a?(Hash) && b.is_a?(Hash) ? _deep_merge(a, b) : b }
      end

    end
  end
end
