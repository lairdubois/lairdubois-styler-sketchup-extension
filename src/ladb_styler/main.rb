# Styler — entry point.
#
# The theme is saved with Sketchup.write_default and re-applied at startup.
# Ruby console helpers :
#
#   Ladb::Styler.apply             # re-apply the saved theme
#   Ladb::Styler.clear             # back to SketchUp's native look (until next apply)
#   puts Ladb::Styler.qss          # generated style sheet
#   Ladb::Styler.presets.keys      # saved presets
#   Ladb::Styler.builtin_presets.keys  # built-in presets (presets/*.json)

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

    PREFS_KEY_PRESETS = 'presets'
    PREFS_KEY_ACTIVE_PRESET = 'active_preset'

    # read_default evals the stored value, and write_default wraps a string in quotes
    # without escaping it: any `"` in the JSON breaks the eval. The JSON is therefore
    # stored as Base64 (pack 'm0': the base64 gem is not a default gem in Ruby 3.4).
    def self._read_json(key)
      raw = Sketchup.read_default(PREFS_SECTION, key)
      json = raw.is_a?(String) && !raw.empty? ? raw.unpack1('m0').force_encoding(Encoding::UTF_8) : nil
      json ? JSON.parse(json) : nil
    rescue SyntaxError, ArgumentError, JSON::ParserError # unreadable (e.g. raw JSON saved by an older version)
      nil
    end

    def self._write_json(key, value)
      Sketchup.write_default(PREFS_SECTION, key, [JSON.generate(value)].pack('m0'))
    end

    def self.theme
      Theme.normalize(_read_json(PREFS_KEY_THEME) || {})
    end

    def self.save_theme(theme)
      _write_json(PREFS_KEY_THEME, Theme.normalize(theme))
    end

    # ----- Presets : { name => theme }, named snapshots of the whole theme.
    #
    # Built-in presets are the preset files (format below) in presets/, listed in file
    # name order, read-only. Saved presets are the user's, in the SketchUp preferences ;
    # a saved preset never takes a built-in name.

    PRESETS_DIR = File.join(__dir__, 'presets')

    # Read once ; a `load` of this file reads them again.
    @builtin_presets = nil

    def self.builtin_presets
      @builtin_presets ||= Dir.glob(File.join(PRESETS_DIR, '*.json')).sort.each_with_object({}) do |path, presets|
        name, theme = _parse_preset_file(path)
        presets[name] ||= theme
      rescue StandardError => e
        puts "[Styler] Built-in preset #{File.basename(path)} skipped: #{e.message}"
      end
    end

    def self.builtin_preset?(name)
      builtin_presets.key?(name)
    end

    def self.presets
      presets = _read_json(PREFS_KEY_PRESETS)
      presets.is_a?(Hash) ? presets.reject { |name, _| builtin_preset?(name) } : {}
    end

    def self.preset?(name)
      builtin_preset?(name) || presets.key?(name)
    end

    def self.save_preset(name, theme)
      raise ArgumentError, "\"#{name}\" is a built-in preset" if builtin_preset?(name)
      _write_json(PREFS_KEY_PRESETS, presets.merge(name => Theme.normalize(theme)))
    end

    def self.delete_preset(name)
      _write_json(PREFS_KEY_PRESETS, presets.tap { |p| p.delete(name) })
      self.active_preset = nil if _read_json(PREFS_KEY_ACTIVE_PRESET) == name
    end

    # Saved presets only.
    def self.rename_preset(name, new_name)
      all = presets
      raise ArgumentError, "unknown preset \"#{name}\"" unless all.key?(name)
      raise ArgumentError, "\"#{new_name}\" already exists" if preset?(new_name)
      was_active = active_preset == name
      _write_json(PREFS_KEY_PRESETS, all.to_h { |n, t| [n == name ? new_name : n, t] })
      self.active_preset = new_name if was_active
    end

    # ----- Active preset : the last one applied or saved, nil after a reset.

    def self.active_preset
      name = _read_json(PREFS_KEY_ACTIVE_PRESET)
      name.is_a?(String) && preset?(name) ? name : nil
    end

    def self.active_preset=(name)
      _write_json(PREFS_KEY_ACTIVE_PRESET, name)
    end

    # True when the theme differs from the active preset. The master 'enabled' switch is
    # not a style choice : left out.
    def self.preset_modified?(theme = self.theme)
      name = active_preset
      return false unless name
      strip = ->(t) { Theme.normalize(t).tap { |h| h.delete('enabled') } }
      strip.(theme) != strip.(preset(name))
    end

    # Normalized on read : a preset saved by an older version gets the new keys' defaults.
    def self.preset(name)
      theme = builtin_presets[name] || presets[name]
      theme && Theme.normalize(theme)
    end

    # ----- Preset files : { "format", "version", "name", "theme" } as pretty JSON.

    PRESET_FILE_FORMAT = 'ladb_styler_preset'
    PRESET_FILE_VERSION = 1

    def self.export_preset(name, path)
      theme = preset(name)
      raise ArgumentError, "unknown preset \"#{name}\"" unless theme
      File.write(path, JSON.pretty_generate(
        'format' => PRESET_FILE_FORMAT, 'version' => PRESET_FILE_VERSION, 'name' => name, 'theme' => theme
      ))
    end

    # Returns [name, theme] ; raises ArgumentError / JSON::ParserError on a file that is not a preset.
    # The name defaults to the file name.
    def self._parse_preset_file(path)
      data = JSON.parse(File.read(path, encoding: 'UTF-8'))
      unless data.is_a?(Hash) && data['format'] == PRESET_FILE_FORMAT && data['theme'].is_a?(Hash)
        raise ArgumentError, 'not a Styler preset file'
      end
      name = data['name'].to_s.strip
      name = File.basename(path, '.*') if name.empty?
      [name, Theme.normalize(data['theme'])]
    end

    # As _parse_preset_file, for an import : an existing preset (built-in or saved) is never
    # replaced, " (2)", " (3)"… is appended to the name.
    def self.read_preset_file(path)
      base, theme = _parse_preset_file(path)
      name = base
      n = 1
      name = "#{base} (#{n += 1})" while preset?(name)
      [name, theme]
    end

    def self.qss(theme = self.theme)
      Theme.to_qss(theme, ASSETS_DIR)
    end

    # Written on every apply : the temp dir may have been cleaned since.
    def self.write_assets(theme)
      assets = Theme.assets(theme)
      return if assets.empty?
      Dir.mkdir(ASSETS_DIR) unless File.directory?(ASSETS_DIR)
      assets.each { |name, content| File.binwrite(File.join(ASSETS_DIR, name), content) } # the lens is a PNG
    end

    # Returns :ok, :cleared, :unsupported, :no_window or :foreign (see Qt.set_style_sheet).
    # The title bar and the palette are independent of the style sheet : applied even when :foreign.
    # The palette goes first : setting the sheet afterwards makes the main window's descendants
    # follow it (see qt.rb).
    def self.apply(theme = self.theme)
      theme = Theme.normalize(theme)
      write_assets(theme)
      Qt.set_palette(Theme.palette(theme))
      status = Qt.set_style_sheet(qss(theme))
      MacOS.set_title_bar_color(theme['enabled'] && theme['window']['enabled'] ? theme['window']['title_bar'] : nil)
      status
    end

    def self.clear
      MacOS.clear
      Qt.set_palette(nil)
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
