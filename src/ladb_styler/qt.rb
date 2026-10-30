# The Qt native layer: pushes a style sheet to SketchUp's main window.
# (macos.rb is the other native layer, for the AppKit title bar.)
#
# Validated on SketchUp 2027 / macOS arm64 (Qt 6.9.1). Other platforms and
# versions are reported unsupported until measured.
#
# The sheet goes on the main window (CMainFrame), NEVER on the application :
# SketchUp does qobject_cast<SketchUpProxyStyle*>(QApplication::style()) in 11
# places without a null check (VCB button sizeHint, Ruby toolbar creation, icon
# size…), and an application style sheet turns QApplication::style() into a
# QStyleSheetStyle : null, SIGSEGV (crash seen 2026-09-22). A widget style sheet
# leaves the application style alone and still covers every descendant :
# toolbars (floating ones stay children), the area behind them, the docks.
#
# The application palette (set_palette) is the second lever : it reaches the
# native widgets no selector isolates (panels, fields, lists), and it leaves
# QApplication::style() alone (measured : SketchUpProxyStyle kept). Under the
# main window style sheet, descendants keep the palette QStyleSheetStyle pinned
# at polish time : the sheet must be set again after the palette (Styler.apply
# does both, palette first ; re-setting the same string is enough, measured).
#
# Rules kept deliberately:
# - two Qt calls that matter, QWidget::setStyleSheet(QString const&) and
#   QApplication::setPalette(QPalette const&, const char*) ;
# - no call returning a Qt value type by value (QString, QPalette… come back
#   through x8 on arm64, out of reach of Fiddle) ;
# - no QWidget::render into a QImage (it killed SketchUp on 2026-09-22).

require 'fiddle'

module Ladb
  module Styler
    module Qt

      F = ::Fiddle
      V = F::TYPE_VOIDP
      VOID = F::TYPE_VOID

      SYM_SET_STYLE_SHEET = '_ZN7QWidget13setStyleSheetERK7QString'
      SYM_WIDGET_STYLE = '_ZNK7QWidget5styleEv'
      SYM_CLASS_NAME = '_ZNK11QMetaObject9classNameEv'
      SYM_WIDGET_FIND = '_ZN7QWidget4findEy'

      MAIN_FRAME_CLASS = 'CMainFrame'

      SYM_APP_PAL = '_ZN22QGuiApplicationPrivate7app_palE' # static QPalette * : the application palette
      SYM_APP_SET_PALETTE = '_ZN12QApplication10setPaletteERK8QPalettePKc'
      SYM_PALETTE_COPY = '_ZN8QPaletteC1ERKS_'
      SYM_PALETTE_DTOR = '_ZN8QPaletteD1Ev'
      SYM_PALETTE_SET_BRUSH = '_ZN8QPalette8setBrushENS_10ColorGroupENS_9ColorRoleERK6QBrush'
      SYM_COLOR_RGB = '_ZN6QColorC1Ej'
      SYM_BRUSH_CTOR = '_ZN6QBrushC1ERK6QColorN2Qt10BrushStyleE'
      SYM_BRUSH_DTOR = '_ZN6QBrushD1Ev'
      PALETTE_SYMS = [SYM_APP_PAL, SYM_APP_SET_PALETTE, SYM_PALETTE_COPY, SYM_PALETTE_DTOR,
                      SYM_PALETTE_SET_BRUSH, SYM_COLOR_RGB, SYM_BRUSH_CTOR, SYM_BRUSH_DTOR].freeze

      # QPalette::ColorRole values (Qt 6).
      ROLES = {
        'window_text' => 0, 'button' => 1, 'light' => 2, 'midlight' => 3, 'dark' => 4, 'mid' => 5,
        'text' => 6, 'bright_text' => 7, 'button_text' => 8, 'base' => 9, 'window' => 10, 'shadow' => 11,
        'highlight' => 12, 'highlighted_text' => 13, 'link' => 14, 'link_visited' => 15,
        'alternate_base' => 16, 'tool_tip_base' => 18, 'tool_tip_text' => 19, 'placeholder_text' => 20,
      }.freeze

      @fns = {}
      # Both survive a reload : dropping @keep would let the GC free buffers Qt still reads.
      @keep = [] unless defined?(@keep)     # QString buffers Qt may still point to (d = nullptr => not owned by Qt)
      @owned = false unless defined?(@owned) # true while the main window style sheet is ours
      # SketchUp's palette, copied before our first change (nil while it is in place), and the roles we set.
      @original_palette = nil unless defined?(@original_palette)
      @palette = nil unless defined?(@palette)

      def self.supported?
        return @supported unless @supported.nil?
        @supported = Sketchup.platform == :platform_osx &&
                     Sketchup.version.to_i >= 27 &&
                     [SYM_SET_STYLE_SHEET, SYM_WIDGET_STYLE, SYM_CLASS_NAME, SYM_WIDGET_FIND].all? { |s| _sym(s) }
      end

      # The CMainFrame widget, looked up on every call (never a cached pointer).
      def self.main_frame
        window = supported? && MacOS.main_window
        window ? _widget_for_view(MacOS.content_view(window)) : nil
      end

      # Class name of the style the main window uses : 'QStyleSheetStyle' as soon
      # as a style sheet applies to it (its own or the application's).
      def self.style_class_name(widget = main_frame)
        return nil unless widget
        _qt_class_name(_fn(SYM_WIDGET_STYLE, [V], V).call(widget).to_i)
      end

      # A style sheet we did not set is in place (another extension): writing
      # ours would wipe it, and it cannot be read back to merge.
      def self.foreign_style_sheet?(widget = main_frame)
        !@owned && style_class_name(widget) == 'QStyleSheetStyle'
      end

      # Returns :ok, :cleared, :unsupported, :no_window or :foreign.
      def self.set_style_sheet(css)
        return :unsupported unless supported?
        widget = main_frame
        return :no_window unless widget
        return :foreign if foreign_style_sheet?(widget)
        css = css.to_s
        _fn(SYM_SET_STYLE_SHEET, [V, V], VOID).call(widget, _qstring(css))
        @owned = !css.empty?
        # Fiddle::Pointer.malloc without a free function is never released, so
        # this only bounds the Ruby side: each sheet leaks a few KB, fine for a prototype.
        @keep = @keep.last(2)
        @owned ? :ok : :cleared
      end

      def self.clear
        set_style_sheet('')
      end

      def self.owned?
        @owned
      end

      def self.palette_supported?
        return @palette_supported unless @palette_supported.nil?
        @palette_supported = supported? && PALETTE_SYMS.all? { |s| _sym(s) }
      end

      # colors : { role name (ROLES) => '#rrggbb' } over SketchUp's palette ; empty or nil puts
      # SketchUp's palette back. Returns true when the application palette changed : the main
      # window style sheet must then be set again for its descendants to follow.
      def self.set_palette(colors)
        return false unless palette_supported?
        colors = (colors || {}).filter_map { |role, c| ROLES[role] && c =~ /\A#\h{6}\z/ && [ROLES[role], c.delete('#').hex] }.to_h
        return false if colors == (@palette || {})
        if colors.empty?
          _restore_palette
        else
          @original_palette ||= _copy_palette(_read_ptr(F::Handle::DEFAULT[SYM_APP_PAL]))
          pal = _copy_palette(@original_palette)
          colors.each { |role, rgb| _set_role(pal, role, 0xff000000 | rgb) }
          _fn(SYM_APP_SET_PALETTE, [V, V], VOID).call(pal, nil)
          _fn(SYM_PALETTE_DTOR, [V], VOID).call(pal) # the application keeps its own (shared) copy
          @palette = colors
        end
        true
      end

      def self.palette_owned?
        !@palette.nil?
      end

      # Qt class name of the widget whose native view is ns_view, nil if none.
      def self.class_name_of_view(ns_view)
        return nil unless supported?
        _qt_class_name(_widget_for_view(ns_view))
      end

      # -----

      def self._sym(name)
        F::Handle::DEFAULT[name]
      rescue F::DLError
        nil
      end

      def self._fn(sym, args, ret)
        @fns[[sym, args, ret]] ||= F::Function.new(F::Handle::DEFAULT[sym], args, ret)
      end

      def self._read_ptr(addr)
        F::Pointer.new(addr)[0, 8].unpack1('Q')
      end

      # On macOS a WId is the NSView.
      def self._widget_for_view(ns_view)
        return nil if ns_view.nil? || ns_view == 0
        widget = _fn(SYM_WIDGET_FIND, [F::TYPE_LONG_LONG], V).call(ns_view).to_i
        widget == 0 ? nil : widget
      end

      # metaObject() is virtual (vtable slot 0) : the exported symbol would only
      # give the base implementation.
      def self._qt_class_name(obj)
        return nil if obj.nil? || obj == 0
        meta_fn = _read_ptr(_read_ptr(obj))
        meta = F::Function.new(meta_fn, [V], V).call(obj).to_i
        _fn(SYM_CLASS_NAME, [V], V).call(meta).to_s
      end

      # Qt 6 QString = {d, char16_t *ptr, qsizetype size} ; d = nullptr gives
      # fromRawData semantics : Qt reads our buffer and never frees it.
      def self._qstring(s)
        utf16 = s.encode('UTF-16LE').b
        buf = F::Pointer.malloc(utf16.bytesize + 2)
        buf[0, utf16.bytesize] = utf16 unless utf16.empty?
        buf[utf16.bytesize, 2] = "\0\0"
        qs = F::Pointer.malloc(24)
        qs[0, 24] = [0, buf.to_i, utf16.bytesize / 2].pack('Q3')
        @keep << [buf, qs]
        qs
      end

      # A QPalette (implicitly shared : the copy only takes a reference) in a buffer of ours.
      # Fiddle::Pointer.malloc without a free function is never released : a few bytes per change.
      def self._copy_palette(src)
        pal = F::Pointer.malloc(64)
        _fn(SYM_PALETTE_COPY, [V, V], VOID).call(pal, src)
        pal
      end

      # QPalette::setColor is inline : setBrush(group, role, QBrush(color)) for Active, Disabled, Inactive.
      def self._set_role(pal, role, argb)
        color = F::Pointer.malloc(16)
        _fn(SYM_COLOR_RGB, [V, -F::TYPE_INT], VOID).call(color, argb) # QRgb is unsigned
        brush = F::Pointer.malloc(16)
        _fn(SYM_BRUSH_CTOR, [V, V, F::TYPE_INT], VOID).call(brush, color, 1) # Qt::SolidPattern
        [0, 1, 2].each { |group| _fn(SYM_PALETTE_SET_BRUSH, [V, F::TYPE_INT, F::TYPE_INT, V], VOID).call(pal, group, role, brush) }
        _fn(SYM_BRUSH_DTOR, [V], VOID).call(brush)
      end

      # Copied again on the next change : SketchUp may change its own palette meanwhile.
      def self._restore_palette
        return unless @original_palette
        _fn(SYM_APP_SET_PALETTE, [V, V], VOID).call(@original_palette, nil)
        _fn(SYM_PALETTE_DTOR, [V], VOID).call(@original_palette)
        @original_palette = nil
        @palette = nil
      end

    end
  end
end
