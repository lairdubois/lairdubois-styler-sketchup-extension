# The only native layer: pushes a style sheet to the running QApplication.
#
# Validated on SketchUp 2027 / macOS arm64 (Qt 6.9.1). Other platforms and
# versions are reported unsupported until measured.
#
# Rules kept deliberately:
# - one Qt call that matters, QApplication::setStyleSheet(QString const&) ;
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

      SYM_QAPP_SELF = '_ZN16QCoreApplication4selfE'
      SYM_SET_STYLE_SHEET = '_ZN12QApplication13setStyleSheetERK7QString'
      SYM_STYLE = '_ZN12QApplication5styleEv'
      SYM_CLASS_NAME = '_ZNK11QMetaObject9classNameEv'

      @fns = {}
      @keep = []      # QString buffers Qt may still point to (d = nullptr => not owned by Qt)
      @owned = false  # true while the application style sheet is ours

      def self.supported?
        return @supported unless @supported.nil?
        @supported = Sketchup.platform == :platform_osx &&
                     Sketchup.version.to_i >= 27 &&
                     [SYM_QAPP_SELF, SYM_SET_STYLE_SHEET, SYM_STYLE, SYM_CLASS_NAME].all? { |s| _sym(s) }
      end

      # Class name of the application style: 'QStyleSheetStyle' as soon as any
      # application style sheet is set, SketchUp's own proxy style otherwise.
      def self.style_class_name
        return nil unless supported?
        style = _fn(SYM_STYLE, [], V).call.to_i
        _qt_class_name(style)
      end

      # A style sheet we did not set is in place (another extension): writing
      # ours would wipe it, and it cannot be read back to merge.
      def self.foreign_style_sheet?
        !@owned && style_class_name == 'QStyleSheetStyle'
      end

      # Returns :ok, :cleared, :unsupported or :foreign.
      def self.set_style_sheet(css)
        return :unsupported unless supported?
        return :foreign if foreign_style_sheet?
        css = css.to_s
        _fn(SYM_SET_STYLE_SHEET, [V, V], VOID).call(_qapp, _qstring(css))
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

      # qApp : QCoreApplication::self is a data symbol, instance() is inline.
      def self._qapp
        _read_ptr(F::Handle::DEFAULT[SYM_QAPP_SELF])
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
