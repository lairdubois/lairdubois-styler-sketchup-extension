# The AppKit layer: colors the title bar of SketchUp's main window.
#
# The main window is a QNSWindow (Qt widget CMainFrame) with a real AppKit
# title bar (styleMask has Titled), out of reach of QSS. A transparent title
# bar shows the window background color, and the Qt content covers the rest,
# so only the title bar takes the color. Floating panels have no Titled flag :
# their title bar is drawn by Qt (KDDW).
#
# Leaving full screen, Qt resets titlebarAppearsTransparent (the background
# color stays) : a Ruby timer re-applies it. No AppKit observer on purpose : it
# would need a native callback, where a Ruby exception kills SketchUp.
#
# Only message sends with object, BOOL and double arguments ; the one returning
# a value by value is a BOOL, in x0.

require 'fiddle'

module Ladb
  module Styler
    module MacOS

      F = ::Fiddle
      V = F::TYPE_VOIDP

      NS_WINDOW_STYLE_MASK_TITLED = 1
      WATCH_INTERVAL = 1.0 # seconds

      @fns = {}
      @color = nil  # [r, g, b] 0..255 wanted
      # Both survive a reload : the timer can still be stopped, the title bar still restored.
      @timer = nil unless defined?(@timer)
      @owned = false unless defined?(@owned) # true while the title bar is ours

      def self.supported?
        Qt.supported?
      end

      # hex '#rrggbb', or nil / '' to restore the native title bar.
      # Returns :ok, :cleared, :unsupported or :no_window.
      def self.set_title_bar_color(hex)
        return :unsupported unless supported?
        @color = hex.to_s =~ /\A#(\h\h)(\h\h)(\h\h)\z/ ? [$1, $2, $3].map(&:hex) : nil
        _stop_timer
        return :cleared unless @color || @owned # never touch a title bar we did not color
        window = main_window
        return :no_window unless window
        if @color
          _apply(window)
          @owned = true
          @timer = UI.start_timer(WATCH_INTERVAL, true) { _watch }
          :ok
        else
          _restore(window)
          @owned = false
          :cleared
        end
      end

      def self.clear
        set_title_bar_color(nil)
      end

      # Looked up on every call : a cached NSWindow pointer could dangle.
      def self.main_window
        wins = _msg(_msg(_class('NSApplication'), 'sharedApplication'), 'windows')
        (0..._msg(wins, 'count')).map { |i| _msg(wins, 'objectAtIndex:', i) }.find do |w|
          (_msg_int(w, 'styleMask') & NS_WINDOW_STYLE_MASK_TITLED) != 0 &&
            Qt.class_name_of_view(_msg(w, 'contentView')) == 'CMainFrame'
        end
      end

      # -----

      def self._watch
        window = @color && main_window
        _apply(window) if window && (_msg_int(window, 'titlebarAppearsTransparent') & 1) == 0
      rescue StandardError => e
        _stop_timer
        puts "[Styler] Title bar watch stopped: #{e.message}"
      end

      def self._apply(window)
        r, g, b = @color
        color = _fn([V, V, F::TYPE_DOUBLE, F::TYPE_DOUBLE, F::TYPE_DOUBLE, F::TYPE_DOUBLE], V)
                  .call(_class('NSColor'), _sel('colorWithSRGBRed:green:blue:alpha:'), r / 255.0, g / 255.0, b / 255.0, 1.0)
        _set_bool(window, 'setTitlebarAppearsTransparent:', true)
        _msg(window, 'setBackgroundColor:', color.to_i)
      end

      def self._restore(window)
        _set_bool(window, 'setTitlebarAppearsTransparent:', false)
        _msg(window, 'setBackgroundColor:', _msg(_class('NSColor'), 'windowBackgroundColor'))
      end

      def self._stop_timer
        UI.stop_timer(@timer) if @timer
        @timer = nil
      end

      def self._fn(args, ret)
        @fns[[args, ret]] ||= F::Function.new(F::Handle::DEFAULT['objc_msgSend'], args, ret)
      end

      def self._sel(name)
        (@sels ||= {})[name] ||= F::Function.new(F::Handle::DEFAULT['sel_registerName'], [V], V).call(name).to_i
      end

      def self._class(name)
        F::Function.new(F::Handle::DEFAULT['objc_getClass'], [V], V).call(name).to_i
      end

      def self._msg(obj, sel, *args)
        _fn([V, V] + args.map { V }, V).call(obj, _sel(sel), *args).to_i
      end

      def self._msg_int(obj, sel)
        _fn([V, V], F::TYPE_LONG_LONG).call(obj, _sel(sel))
      end

      def self._set_bool(obj, sel, value)
        _fn([V, V, F::TYPE_CHAR], F::TYPE_VOID).call(obj, _sel(sel), value ? 1 : 0)
      end

    end
  end
end
