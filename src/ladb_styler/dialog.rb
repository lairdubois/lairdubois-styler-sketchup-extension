# Settings dialog : every change is saved and applied live.
#
# A new UI::HtmlDialog is created on each show : on SketchUp 2027 a dialog that
# was closed then shown again loses Ruby -> JS (execute_script).

require 'json'

module Ladb
  module Styler
    module Dialog

      # Message box previews : kind (from the page) => [UI.messagebox type, text].
      PREVIEWS = {
        'ok' => [MB_OK, 'Preview of an OK message box.'],
        'okcancel' => [MB_OKCANCEL, 'Preview of an OK / Cancel message box.'],
        'yesno' => [MB_YESNO, 'Preview of a Yes / No message box.'],
        'yesnocancel' => [MB_YESNOCANCEL, 'Preview of a Yes / No / Cancel message box.'],
        'retrycancel' => [MB_RETRYCANCEL, 'Preview of a Retry / Cancel message box.'],
        'abortretryignore' => [MB_ABORTRETRYIGNORE, 'Preview of an Abort / Retry / Ignore message box.'],
        'multiline' => [MB_MULTILINE, "Preview of a multiline message box.\n\nA longer text, spread over several lines, to check how the text and the buttons line up when the message is wider than the buttons."],
      }.freeze

      def self.show
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        @dialog = UI::HtmlDialog.new(
          dialog_title: "Styler #{VERSION}",
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
        @dialog.add_action_callback('preset_save') do |_, name, json|
          name = name.to_s.strip
          next if name.empty?
          Styler.save_preset(name, JSON.parse(json))
          _push("Preset \"#{name}\" saved.", nil, false, name)
        end
        @dialog.add_action_callback('preset_load') do |_, name|
          theme = Styler.preset(name)
          next unless theme
          Styler.save_theme(theme)
          status = Styler.apply(theme)
          _push(status == :ok ? "Preset \"#{name}\" applied." : status, theme, true, name)
        end
        @dialog.add_action_callback('preset_delete') do |_, name|
          Styler.delete_preset(name)
          _push("Preset \"#{name}\" deleted.", nil, false, '')
        end
        # File panels are modal : opened from a timer, like the message box previews.
        @dialog.add_action_callback('preset_export') do |_, name|
          next unless Styler.presets.key?(name)
          UI.start_timer(0, false) do
            path = UI.savepanel('Export Styler preset', '', "#{name.gsub(%r{[/\\:]}, '-')}.json")
            next unless path
            path += '.json' unless File.extname(path).casecmp?('.json')
            begin
              Styler.export_preset(name, path)
              _push("Preset \"#{name}\" exported to #{File.basename(path)}.")
            rescue StandardError => e
              _push("Export failed: #{e.message}")
            end
          end
        end
        @dialog.add_action_callback('preset_import') do |_|
          UI.start_timer(0, false) do
            path = UI.openpanel('Import Styler preset', '', 'Styler preset|*.json||')
            next unless path
            begin
              name, theme = Styler.read_preset_file(path)
              Styler.save_preset(name, theme)
              _push("Preset \"#{name}\" imported.", nil, false, name)
            rescue StandardError => e
              _push("Import failed, #{File.basename(path)}: #{e.message}")
            end
          end
        end
        @dialog.add_action_callback('messagebox_preview') do |_, kind|
          type, text = PREVIEWS[kind.to_s]
          # Opened from a timer : the box is modal and would block this callback.
          UI.start_timer(0, false) { UI.messagebox(text, type) } if type
        end
        @dialog.set_on_closed { @dialog = nil }

        @dialog.show
      end

      # status : a Styler.apply status, or a message string.
      # preset : name to select in the preset list (nil keeps the current selection).
      def self._push(status, theme = nil, reload = false, preset = nil)
        return unless @dialog
        theme ||= Styler.theme
        state = {
          presets: Styler.presets.keys.sort_by(&:downcase),
          preset: preset,
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
