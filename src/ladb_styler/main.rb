# Styler — entry point.
#
# The theme is saved with Sketchup.write_default and re-applied at startup.
# Ruby console helpers :
#
#   Ladb::Styler.apply             # re-apply the saved theme
#   Ladb::Styler.clear             # back to SketchUp's native look (until next apply)
#   puts Ladb::Styler.qss          # generated style sheet

require 'json'
require_relative 'qt'
require_relative 'macos'
require_relative 'theme'
require_relative 'dialog'

module Ladb
  module Styler

    PREFS_SECTION = 'ladb_styler'
    PREFS_KEY_THEME = 'theme'
    ASSETS_DIR = File.join(Sketchup.temp_dir, 'ladb_styler') # files the style sheet refers to (Theme.assets)

    # read_default evals the stored value, and write_default wraps a string in quotes
    # without escaping it: any `"` in the JSON breaks the eval. The JSON is therefore
    # stored as Base64 (pack 'm0': the base64 gem is not a default gem in Ruby 3.4).
    def self.theme
      raw = Sketchup.read_default(PREFS_SECTION, PREFS_KEY_THEME)
      json = raw.is_a?(String) && !raw.empty? ? raw.unpack1('m0').force_encoding(Encoding::UTF_8) : nil
      Theme.normalize(json ? JSON.parse(json) : {})
    rescue SyntaxError, ArgumentError, JSON::ParserError # unreadable (e.g. raw JSON saved by an older version)
      Theme.defaults
    end

    def self.save_theme(theme)
      Sketchup.write_default(PREFS_SECTION, PREFS_KEY_THEME, [JSON.generate(Theme.normalize(theme))].pack('m0'))
    end

    def self.qss(theme = self.theme)
      Theme.to_qss(theme, ASSETS_DIR)
    end

    # Written on every apply : the temp dir may have been cleaned since.
    def self.write_assets(theme)
      assets = Theme.assets(theme)
      return if assets.empty?
      Dir.mkdir(ASSETS_DIR) unless File.directory?(ASSETS_DIR)
      assets.each { |name, content| File.write(File.join(ASSETS_DIR, name), content) }
    end

    # Returns :ok, :cleared, :unsupported, :no_window or :foreign (see Qt.set_style_sheet).
    # The title bar is independent of the style sheet : applied even when :foreign.
    def self.apply(theme = self.theme)
      theme = Theme.normalize(theme)
      write_assets(theme)
      status = Qt.set_style_sheet(qss(theme))
      MacOS.set_title_bar_color(theme['enabled'] && theme['window']['enabled'] ? theme['window']['title_bar'] : nil)
      status
    end

    def self.clear
      MacOS.clear
      Qt.clear
    end

    def self.status_message(status)
      case status
      when :ok then 'Style applied.'
      when :cleared then 'Native style restored.'
      when :unsupported then 'Unsupported here: only validated on SketchUp 2027 for macOS.'
      when :foreign then 'Another extension already set a Qt style sheet: not overwritten.'
      when :no_window then 'SketchUp main window not found.'
      else status.to_s
      end
    end

    # ----- UI

    unless file_loaded?(__FILE__)

      menu = UI.menu('Plugins').add_submenu('Styler')
      menu.add_item('Settings…') { Dialog.show }
      menu.add_item('Re-apply') { UI.messagebox(status_message(apply)) }
      menu.add_item('Restore native style') { UI.messagebox(status_message(clear)) }

      # The application exists at load time, but let SketchUp finish building its UI first.
      UI.start_timer(0, false) do
        status = apply if theme['enabled']
        puts "[Styler] #{status_message(status)}" if status && status != :ok
      end

      file_loaded(__FILE__)
    end

  end
end
