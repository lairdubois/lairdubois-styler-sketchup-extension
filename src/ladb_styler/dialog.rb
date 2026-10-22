# Settings dialog : every change is saved and applied live.
#
# A new UI::HtmlDialog is created on each show : on SketchUp 2027 a dialog that
# was closed then shown again loses Ruby -> JS (execute_script).

require 'json'

module Ladb
  module Styler
    module Dialog

      def self.show
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        @dialog = UI::HtmlDialog.new(
          dialog_title: 'Styler',
          preferences_key: 'ladb_styler_dialog',
          width: 480,
          height: 780,
          min_width: 380,
          min_height: 400,
          style: UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_file(File.join(__dir__, 'html', 'settings.html'))

        @dialog.add_action_callback('ready') { |_| _push(nil) }
        @dialog.add_action_callback('change') do |_, json|
          theme = Theme.normalize(JSON.parse(json))
          Styler.save_theme(theme)
          _push(Styler.apply(theme), theme)
        end
        @dialog.add_action_callback('reset') do |_|
          Styler.save_theme(Theme.defaults)
          _push(Styler.apply, nil, true)
        end
        @dialog.add_action_callback('restore_native') { |_| _push(Styler.clear) }
        @dialog.set_on_closed { @dialog = nil }

        @dialog.show
      end

      def self._push(status, theme = nil, reload = false)
        return unless @dialog
        theme ||= Styler.theme
        state = {
          theme: theme,
          qss: Styler.qss(theme),
          status: status && Styler.status_message(status),
          supported: Qt.supported?,
          reload: reload || status.nil?,
        }
        @dialog.execute_script("receive(#{JSON.generate(state)})")
      end

    end
  end
end
