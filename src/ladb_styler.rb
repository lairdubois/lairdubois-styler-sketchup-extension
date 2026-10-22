# Styler — prototype that restyles SketchUp's Qt interface with QSS
#
# Extension registrar. For development, add this file's src/ folder as an extra
# load path with the Extension Sources extension; otherwise copy (or symlink)
# this file and the ladb_styler/ folder into SketchUp's Plugins directory.
#
# Once loaded, open Extensions > Styler > Settings…

require 'sketchup.rb'
require 'extensions.rb'

module Ladb
  module Styler

    unless file_loaded?(__FILE__)

      ex = SketchupExtension.new('Styler', File.join(File.dirname(__FILE__), 'ladb_styler', 'main'))
      ex.description = 'Prototype: customize the style of the SketchUp interface (toolbars first) with Qt style sheets.'
      ex.version = '0.1.0'
      ex.creator = 'Boris Beaulant'
      ex.copyright = '2026 Boris Beaulant'
      Sketchup.register_extension(ex, true)

      file_loaded(__FILE__)
    end

  end
end
