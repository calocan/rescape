require 'rescape/config/Config.rb' # configures rescape so it can live outside the plugins dir
require 'sketchup.rb'
require 'extensions.rb'
require 'rescape/utils/reload.rb'

rescape_extension = SketchupExtension.new "Rescape", "rescape/init/setup.rb"
rescape_extension.version = '0.1'
rescape_extension.description = "Redesign your neighborhood for people"
Sketchup.register_extension rescape_extension, true

