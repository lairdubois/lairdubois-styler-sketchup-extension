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
# Document tabs (above the 3D view) are the KDDW tab bar of the viewer's stack
# (SketchUpTabBarWidget, a QTabBar, tabs on top) ; tray tab bars have their
# tabs at the bottom, hence '::tab:top'. A color alone keeps the native tab ;
# a background replaces its frame but keeps its geometry and centered title ;
# a border, radius or padding makes QStyleSheetStyle lay the tab out itself
# (bar 205 x 32 -> 201 x 21, title no longer centered) : not exposed. The
# strip behind the tabs is the dock area (KDDW MainWindow) showing through ;
# it also shows through the tray title bars and the dock separators, which
# get palette(window) back (the separator paints as a splitter handle).
# The '+' (new document) is a QToolButton child of that stack, placed by KDDW
# at a fixed 27 x 27 : unlike toolbar buttons, a QSS border does not move it
# (measured). A background alone keeps its native border ; a border color
# (or 'transparent') replaces it on every state, with the radius, and also
# drops the native background. It is the stack's top-right corner widget : Qt
# sizes it from its sizeHint (a font-size grows it), clamped by min/max size.
# So the box is pinned with min = max = size - 2 (its frame) and moved away
# from the tabs with margin-left : native or styled, it keeps that size
# (measured 17..31). Its top is y = 3, but SketchUp raises it with the font
# size alone (PLUS_FONT_TOP, measured) : margin-top brings the box back to the
# center of the native 27 px one. A margin on the last tab would move it too, but relays that tab out.
# The frame around the 3D view is the stack's '::pane' (PE_FrameTabWidget) :
# natively 2 px (a gray line and a white one) left, right and bottom. A QSS
# border w replaces it on every side, the content moving by w (measured :
# none = edge to edge, the view growing by 2 px left, right and bottom).
# Right of the tabs, KDDW's Group paints its outline (hard-coded color, out of
# QSS reach) ; the tabs cover it on the left. With no frame, the pane is
# stretched up under the 32 px tab bar (negative margin, a 32 px top border in
# the strip color : the content does not move, measured), covering that outline.
# The close cross is Qt's CloseButton (20 x 20, fixed), painted through
# PE_IndicatorTabClose : '::close-button' takes background, border, radius,
# :hover, :pressed and an image, which replaces SketchUp's boxed cross. The
# image is an SVG file (QSS url() reads files only) written by the caller in
# assets_dir, see #assets ; padding shrinks it. SketchUp hides the cross of
# inactive tabs, whatever the style sheet.
# 'transparent' is the dialog's "none" for the
# colors whose unset means native (tab background, '+' background / border).
#
# Scene tabs (below the document tabs, when the model has scenes) are
# CPageTabs (CTabBar < QWidget) : a QTabBar, the search QPushButton (40 x 32)
# and the '+' QToolButton (27 x 27). As for document tabs, a background or a
# color keeps the tab geometry (bar 108 x 27), a border makes Qt lay tabs out
# itself (-> 92 x 17) : not exposed. Both buttons keep their size with a
# background, border and radius ; a background alone keeps the native frame.
# CPageTabs places them itself : min / max size pins the '+' box to size + 2
# and keeps its bottom on the tab line (y + h = 32, measured 19..29), a
# font-size grows the box unless it is pinned, and margin-left pushes the
# painted box right of its widget : a real gap after the tabs (measured). The
# search button is 38 x 26 : a background keeps it, but a border shrinks it to
# 26 x 22 (QSS sizes it from its icon), so min = max = size - 2 pins it (its
# own size, measured 24 x 18 .. 56 x 32, centered on the 32 px band, the tabs
# following its width). Both buttons take their own colors ('QPushButton' and
# 'QToolButton' tell them apart).
# The band is 33 px, its height set by ViewerWidget : min = max moves it and
# the 3D view follows, the tabs keeping their bottom on it (below 28 px the
# tab bar itself shrinks, measured). The search button stays centered in it.
# CPageTabs paints no QSS background, only its 1 px bottom line : the
# palette color darker(140) (native #f2f2f2 -> #acacb0, measured), so the
# asked color is lightened by 1.4 first (up to white : a light line comes out darker). The strip around the tabs is the stack's '::pane'
# background : it takes a color with a frame color or none, but stays white
# over the native frame (measured), so it needs a frame. With no frame, the
# pane is stretched up under the tab bar by a 32 px top border in the
# document strip color (content does not move, measured), the background
# being the scene strip.
#
# The status bar is the viewer's QStatusBar (SketchUpStatusBar, no Q_OBJECT :
# 'QStatusBar' in QSS), painting the help text itself, over which a plain
# QWidget container holds the two buttons, separators and the Measurements
# box. Background and text color apply ; the buttons (QToolButton, 28 x 27
# fixed by the layout : QSS does not move them) take :hover / :pressed. The
# Measurements box and separators are plain QWidgets that no selector isolates
# ('.QWidget' also paints the container over the help text) : left native.
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
      PLUS_SIZE = 27 # native '+' box (measured)
      PLUS_TOP = 3   # its native top
      SEARCH_BOX = [38, 26].freeze # native box of the scene search button (measured)
      SCENE_BAND = 33 # native height of the scene tab bar (measured)
      # font-size px -> top of the '+' widget (measured, box size has no effect) ; below 10 it would need a negative margin.
      PLUS_FONT_TOP = { 10 => 3, 11 => 3, 12 => 2, 13 => 2, 14 => 1, 15 => 1, 16 => 1, 17 => 0, 18 => 0, 19 => -1, 20 => -1 }.freeze

      DEFAULTS = {
        'enabled' => true,
        'toolbar' => {
          'enabled' => true,
          'scope' => 'all',     # 'all' | 'titles'
          'titles' => [],       # toolbar names (UI::Toolbar.new) matched by prefix when scope = 'titles'
          'radius' => 4,
          'border_width' => 1,  # 0..2 (0 and 1 measured)
          'hover' => { 'background' => '#dfecf8', 'border' => '#3e7ab6' },
          'checked' => { 'background' => '#c7ddf2', 'border' => '#3e7ab6' },
          'pressed' => { 'background' => '#c7ddf2', 'border' => '#3e7ab6' },
          'bar' => { 'background' => '#f2f2f2', 'border' => '', 'border_width' => 1, 'radius' => 0,  # '' = none ; width 1..2
                     'padding' => 8 },                                                                 # edge to buttons, 2 = native
          'area' => { 'background' => '#f2f2f2' },  # behind the toolbars, whatever the scope ; '' = native
          'separator' => { 'color' => '#cfcfcf', 'inset' => 6 },           # '' = hidden ; inset at each end, 0..12
        },
        'tabs' => {                      # document tabs above the 3D view ; '' = native
          'enabled' => true,
          'strip' => '#f2f2f2',          # behind the tabs
          'normal' => { 'background' => '#f2f2f2', 'text' => '#000000' },
          'hover' => { 'background' => '#c2c2c2', 'text' => '' },
          'selected' => { 'background' => '#c7ddf2', 'text' => '' },
          'plus' => {           # the '+' button after the tabs
            'radius' => 4,      # with a border color only
            'gap' => 7,         # px between the last tab and the button, 0..16
            'size' => 22,       # box, 17..29 px (PLUS_SIZE = native)
            'font_size' => 15,  # the '+' glyph, 0 = native, 10..20 px
            'normal' => { 'background' => 'transparent', 'border' => 'transparent', 'text' => '#4a4a4a' },
            'hover' => { 'background' => '#666666', 'border' => '', 'text' => '#ffffff' },
            'pressed' => { 'background' => '#333333', 'border' => '', 'text' => '' },
          },
          'frame' => {          # around the 3D view
            'color' => 'transparent', # '' = native, 'transparent' = none (edge to edge)
            'width' => 1,       # 1..2 px, with a color
          },
          'close' => {          # the tab close cross
            'color' => '#8c8c8c', # '#rrggbb' draws a plain cross ; '' = SketchUp's boxed cross
            'size' => 10,       # cross box in the 20 px button, 6..18 px
            'radius' => 4,      # of a hover / pressed background
            'hover' => { 'background' => '#d00000', 'color' => '#ffffff' },
            'pressed' => { 'background' => '#700000', 'color' => '#ffffff' },
          },
        },
        'scenes' => {                    # scene tabs below the document tabs ; '' = native
          'enabled' => true,
          'strip' => '#c7ddf2',          # around the tabs (the frame's background) : with a frame color or none only
          'line' => '#3e7ab6',           # 1 px line under the strip
          'height' => 28,                # of the band, 28..64 px ; the 3D view follows (SCENE_BAND = native)
          'normal' => { 'background' => 'transparent', 'text' => '' },
          'hover' => { 'background' => '#474747', 'text' => '#ffffff' },
          'selected' => { 'background' => '#3e7ab6', 'text' => '#ffffff' },
          'plus' => {           # the '+' (add scene)
            'radius' => 4,      # with a border color only
            'gap' => 0,         # px between the last tab and the '+', 0..16
            'size' => 22,       # box, 17..29 px (PLUS_SIZE = native)
            'font_size' => 15,  # the '+' glyph, 0 = native, 10..20 px
            'normal' => { 'background' => 'transparent', 'border' => 'transparent', 'text' => '' },
            'hover' => { 'background' => '#3e7ac0', 'border' => '', 'text' => '#ffffff' },
            'pressed' => { 'background' => '#3e7ab6', 'border' => '', 'text' => '' },
          },
          'search' => {         # the search button, left of the tabs ; its icon is a pixmap, no text color
            'radius' => 4,      # with a border color only
            'width' => 31,      # 24..56 px, the tabs follow (SEARCH_BOX = native)
            'height' => 28,     # 18..32 px
            'normal' => { 'background' => 'transparent', 'border' => 'transparent' },
            'hover' => { 'background' => '', 'border' => '' },
            'pressed' => { 'background' => '', 'border' => '' },
          },
        },
        'statusbar' => {        # below the 3D view ; '' = native
          'enabled' => true,
          'background' => '#f2f2f2',
          'text' => '',
          'radius' => 4,        # of the buttons' hover / pressed background
          'hover' => { 'background' => '', 'border' => '' },
          'pressed' => { 'background' => '', 'border' => '' },
        },
        'window' => {
          'enabled' => true,
          'title_bar' => '#1e4069', # '#rrggbb' main window title bar (AppKit, see macos.rb) ; '' = native
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

      # assets_dir : where the caller writes #assets (the close cross SVG files).
      def self.to_qss(theme, assets_dir = '.')
        theme = normalize(theme)
        return '' unless theme['enabled']
        [_toolbar_qss(theme['toolbar']), _tabs_qss(theme['tabs'], assets_dir, theme['scenes']['enabled'] ? theme['scenes']['strip'] : ''), _scenes_qss(theme['scenes']),
         _statusbar_qss(theme['statusbar']), theme['extra_qss'].to_s.strip].reject(&:empty?).join("\n\n")
      end

      # { file name => SVG } the style sheet refers to (close cross colors).
      def self.assets(theme)
        theme = normalize(theme)
        return {} unless theme['tabs']['enabled']
        close = theme['tabs']['close']
        [close['color'], close['hover']['color'], close['pressed']['color']].filter_map { |c| _hex(c) }.uniq
          .to_h { |c| [_cross_name(c), _cross_svg(c)] }
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
          "#{DOCK_AREA} {\n  background-color: palette(window);\n}",
        ]
      end

      TAB_STATES = %w[normal hover selected].freeze # selected last : wins over hover
      TAB = 'SketchUpTabBarWidget::tab:top'
      DOCK_AREA = 'CMainFrame > .QWidget > KDDockWidgets--QtWidgets--MainWindow'
      PLUS_STATES = %w[normal hover pressed].freeze
      PLUS = 'SketchUpStackWidget[tabPosition="North"] > QToolButton'

      # After the toolbar area rule : its DOCK_AREA palette(window) is overridden by the strip.
      # scene_strip : the scenes' strip, the frame's background.
      def self._tabs_qss(tabs, assets_dir, scene_strip = '')
        return '' unless tabs.is_a?(Hash) && tabs['enabled']
        css = _tab_states_qss(TAB, tabs, 'Document tabs')
        css.concat(_plus_qss(tabs['plus']))
        css.concat(_close_qss(tabs['close'], assets_dir))
        css.concat(_frame_qss(tabs['frame'], _color(tabs['strip']), _color(scene_strip)))
        strip = _color(tabs['strip'])
        if strip
          css << "/* Document tabs: strip (the dock area), given back to tray titles and dock separators */\n#{DOCK_AREA} {\n  background-color: #{strip};\n}"
          css << "SketchUpTitleBarWidget,\nKDDockWidgets--QtWidgets--Separator::handle {\n  background-color: palette(window);\n}"
        end
        css.join("\n\n")
      end

      # tab : the '::tab' selector ; h : { state => { background, text } }.
      def self._tab_states_qss(tab, h, title)
        css = TAB_STATES.filter_map do |st|
          next unless h[st].is_a?(Hash)
          decl = []
          bg = _color(h[st]['background'])
          fg = _color(h[st]['text'])
          decl << "background-color: #{bg};" if bg
          decl << "color: #{fg};" if fg
          "#{st == 'normal' ? tab : "#{tab}:#{st}"} {\n  #{decl.join("\n  ")}\n}" unless decl.empty?
        end
        css[0] = "/* #{title} */\n#{css[0]}" unless css.empty?
        css
      end

      def self._plus_qss(plus)
        return [] unless plus.is_a?(Hash)
        _button_states_qss([PLUS], plus, _plus_box(plus), "Document tabs: the '+' button")
      end

      # A border color (or 'transparent') on any state replaces the native frame on every state,
      # and drops the native background. box : declarations added to the normal state.
      def self._button_states_qss(selectors, btn, box, title)
        states = PLUS_STATES.map { |st| [st, btn[st].is_a?(Hash) ? btn[st] : {}] }
        bordered = states.any? { |_, h| _color(h['border']) }
        css = states.filter_map do |st, h|
          decl = []
          bg = _color(h['background'])
          bd = _color(h['border'])
          fg = _color(h['text'])
          decl << "background-color: #{bg};" if bg
          decl.concat(box) if st == 'normal'
          if st == 'normal' && bordered
            decl << "border: 1px solid #{bd || 'transparent'};"
            decl << "border-radius: #{btn['radius'].to_i.clamp(0, 12)}px;"
          elsif bd
            decl << "border-color: #{bd};"
          end
          decl << "color: #{fg};" if fg
          "#{selectors.map { |s| st == 'normal' ? s : "#{s}:#{st}" }.join(",\n")} {\n  #{decl.join("\n  ")}\n}" unless decl.empty?
        end
        css[0] = "/* #{title} */\n#{css[0]}" unless css.empty?
        css
      end

      SCENES = 'CPageTabs'
      LINE_DARKER = 1.4 # CPageTabs paints its line with QColor::darker(140)
      SCENE_TAB = 'CPageTabs > QTabBar::tab'
      SCENE_PLUS = 'CPageTabs > QToolButton'
      SCENE_SEARCH = 'CPageTabs > QPushButton'

      def self._scenes_qss(sc)
        return '' unless sc.is_a?(Hash) && sc['enabled']
        css = _tab_states_qss(SCENE_TAB, sc, 'Scene tabs')
        # Both on CPageTabs : its palette paints the line, its min / max size the band.
        decl = []
        line = _hex(sc['line'])
        decl << "background-color: #{_lighter(line, LINE_DARKER)};" if line
        height = sc['height'].to_i.clamp(28, 64)
        decl.concat(["min-height: #{height}px;", "max-height: #{height}px;"]) unless height == SCENE_BAND
        css << "/* Scene tabs: the band (the 3D view follows) and its bottom line (painted darker(140)) */\n#{SCENES} {\n  #{decl.join("\n  ")}\n}" unless decl.empty?
        if sc['plus'].is_a?(Hash)
          css.concat(_button_states_qss([SCENE_PLUS], sc['plus'], _scene_plus_box(sc['plus']), "Scene tabs: the '+' button (box bottom kept on the tab line)"))
        end
        if sc['search'].is_a?(Hash)
          css.concat(_button_states_qss([SCENE_SEARCH], sc['search'], _search_box(sc['search']), 'Scene tabs: the search button (the tabs follow its width)'))
        end
        css.join("\n\n")
      end

      STATUS_BAR = 'ViewerWidget > QStatusBar'

      def self._statusbar_qss(sb)
        return '' unless sb.is_a?(Hash) && sb['enabled']
        css = []
        decl = []
        bg = _color(sb['background'])
        fg = _color(sb['text'])
        decl << "background-color: #{bg};" if bg
        decl << "color: #{fg};" if fg
        css << "#{STATUS_BAR} {\n  #{decl.join("\n  ")}\n}" unless decl.empty?
        %w[hover pressed].each do |st|
          h = sb[st].is_a?(Hash) ? sb[st] : {}
          decl = []
          bg = _color(h['background'])
          bd = _color(h['border'])
          decl << "background-color: #{bg};" if bg
          decl << "border: 1px solid #{bd};" if bd
          next if decl.empty?
          decl << "border-radius: #{sb['radius'].to_i.clamp(0, 10)}px;"
          css << "#{STATUS_BAR} QToolButton:#{st} {\n  #{decl.join("\n  ")}\n}"
        end
        css[0] = "/* Status bar */\n#{css[0]}" unless css.empty?
        css.join("\n\n")
      end

      PANE = 'SketchUpStackWidget[tabPosition="North"]::pane'

      TAB_BAR_HEIGHT = 32 # px (measured)

      # scene_strip : its background, what shows around the scene tabs.
      def self._frame_qss(frame, strip, scene_strip = nil)
        return [] unless frame.is_a?(Hash)
        c = _color(frame['color'])
        return [] unless c
        decl = if c == 'transparent'
          ['border: none;', "border-top: #{TAB_BAR_HEIGHT}px solid #{strip || 'palette(window)'};", "margin-top: -#{TAB_BAR_HEIGHT}px;",
           "background-color: #{scene_strip || strip || 'palette(window)'};"]
        else
          ["border: #{frame['width'].to_i.clamp(1, 2)}px solid #{c};"] + (scene_strip ? ["background-color: #{scene_strip};"] : [])
        end
        ["/* Document tabs: frame around the 3D view (none : also covers the dock outline behind the tabs) */\n#{PANE} {\n  #{decl.join("\n  ")}\n}"]
      end

      CLOSE = 'SketchUpTabBarWidget::close-button'
      CLOSE_BUTTON = 20 # px, Qt's CloseButton (measured)

      def self._close_qss(close, assets_dir)
        return [] unless close.is_a?(Hash)
        image = ->(c) { (c = _hex(c)) && %Q{image: url("#{File.join(assets_dir, _cross_name(c))}");} }
        normal = [image.(close['color'])].compact
        normal << "padding: #{(CLOSE_BUTTON - close['size'].to_i.clamp(6, 18)) / 2}px;" if normal.any?
        states = %w[hover pressed].map { |st| [st, close[st].is_a?(Hash) ? close[st] : {}] }
        normal << "border-radius: #{close['radius'].to_i.clamp(0, 10)}px;" if states.any? { |_, h| _color(h['background']) }
        css = []
        css << "#{CLOSE} {\n  #{normal.join("\n  ")}\n}" if normal.any?
        states.each do |st, h|
          decl = []
          bg = _color(h['background'])
          decl << "background-color: #{bg};" if bg
          decl << image.(h['color']) if _hex(h['color'])
          css << "#{CLOSE}:#{st} {\n  #{decl.join("\n  ")}\n}" unless decl.empty?
        end
        css[0] = "/* Document tabs: the close cross */\n#{css[0]}" unless css.empty?
        css
      end

      def self._hex(c)
        v = c.to_s.strip.downcase
        v =~ /\A#\h{6}\z/ ? v : nil
      end

      # '#rrggbb' whose QColor::darker(f * 100) is hex : HSV value times f, hue and saturation kept
      # (all channels scaled), clamped at full value.
      def self._lighter(hex, f)
        rgb = hex.delete('#').scan(/\h\h/).map(&:hex)
        k = [f, 255.0 / [rgb.max, 1].max].min
        format('#%02x%02x%02x', *rgb.map { |c| (c * k).round.clamp(0, 255) })
      end

      def self._cross_name(hex)
        "close-#{hex.delete('#')}.svg"
      end

      def self._cross_svg(hex)
        %Q{<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M3.5 3.5l9 9M12.5 3.5l-9 9" stroke="#{hex}" stroke-width="1.6" stroke-linecap="round"/></svg>\n}
      end

      def self._plus_box(plus)
        gap = plus['gap'].to_i.clamp(0, 16)
        size = plus['size'].to_i.clamp(17, 29)
        font = plus['font_size'].to_i
        font = font > 0 ? font.clamp(10, 20) : 0
        return [] if gap == 0 && size == PLUS_SIZE && font == 0
        c = size - 2
        top = PLUS_TOP + (PLUS_SIZE - size) / 2 - (font > 0 ? PLUS_FONT_TOP[font] : PLUS_TOP)
        decl = %w[min-width max-width min-height max-height].map { |p| "#{p}: #{c}px;" }
        decl << "margin-left: #{gap}px;" if gap > 0
        decl << "margin-top: #{top}px;" if top > 0
        decl << "font-size: #{font}px;" if font > 0
        decl
      end

      # The search button : min / max pin its box, which a border would otherwise shrink
      # to its icon. Emitted as soon as a border is set, even at the native size.
      def self._search_box(search)
        w = search['width'].to_i.clamp(24, 56)
        h = search['height'].to_i.clamp(18, 32)
        bordered = PLUS_STATES.any? { |st| search[st].is_a?(Hash) && _color(search[st]['border']) }
        return [] unless bordered || [w, h] != SEARCH_BOX
        [['width', w], ['height', h]].flat_map { |p, v| ["min-#{p}: #{v - 2}px;", "max-#{p}: #{v - 2}px;"] }
      end

      # The '+' of the scene tabs : min / max pin the box whatever the glyph, margin-left
      # is the gap (CPageTabs paints the box inside it, measured). CPageTabs keeps the box
      # bottom on the tab line, so a smaller one hangs low : margin-bottom lifts it back to
      # the center of the native 27 px box (measured 21 -> 3, 25 -> 1).
      def self._scene_plus_box(btn)
        gap = btn['gap'].to_i.clamp(0, 16)
        size = btn['size'].to_i.clamp(17, 29)
        font = btn['font_size'].to_i
        font = font > 0 ? font.clamp(10, 20) : 0
        return [] if gap == 0 && size == PLUS_SIZE && font == 0
        decl = %w[min-width max-width min-height max-height].map { |p| "#{p}: #{size - 2}px;" }
        decl << "margin-left: #{gap}px;" if gap > 0
        lift = _plus_lift(size)
        decl << "margin-bottom: #{lift}px;" if lift > 0
        decl << "font-size: #{font}px;" if font > 0
        decl
      end

      # Half the height the box lost, rounded up : its top then matches the native box's.
      def self._plus_lift(size)
        [(PLUS_SIZE - size + 1) / 2, 0].max
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
