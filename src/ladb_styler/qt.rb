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
# Rules kept deliberately:
# - one Qt call that matters, QWidget::setStyleSheet(QString const&) ;
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

      @fns = {}
      # Both survive a reload : dropping @keep would let the GC free buffers Qt still reads.
      @keep = [] unless defined?(@keep)     # QString buffers Qt may still point to (d = nullptr => not owned by Qt)
      @owned = false unless defined?(@owned) # true while the main window style sheet is ours

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

    end
  end
end
