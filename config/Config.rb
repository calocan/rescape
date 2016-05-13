
module Rescape
  class Config
    class << self; attr_accessor :log end

    PLUGIN_DIR = '~/Library/Application Support/Sketchup 2016/SketchUp/Plugins'
    TOOLS_DIR = '~/Library/Application Support/Sketchup 2016/SketchUp/Tools'
    SKETCHUP_PATH='/Applications/Sketchup 2016/SketchUp.app'
    RUBY_FRAMEWORK="#{SKETCHUP_PATH}/Contents/Frameworks/Ruby.framework/Versions/Current"
    RESCAPE_LIB_DIR = "#{PLUGIN_DIR}/rescape/lib"
    RUBY_LIB = `which ruby`

    # Determines if the code is running in the Sketchup environment or externally
    def self.in_sketchup?
      (defined?(Sketchup) && defined?(Sketchup::Color))
    end

    def self.windows?
      !RUBY_PLATFORM.index("darwin")
    end

    def self.darwin?
      RUBY_PLATFORM.index("darwin") != nil
    end

    DEBUG_RESCAPE = false
    # Windows could be set up with an OpenLaszlo server, but I never do it
    DEBUG_LASZLO = self.windows? ? false : DEBUG_RESCAPE

    # The log level to output
    LOG_LEVEL = DEBUG_RESCAPE ? 2 : 3 # DEBUG=1 < INFO < WARN < ERROR < FATAL=5

    # The relative directory of rescape
    RESCAPE_DIR = 'rescape'
    # BASE_DIR allows hosting of the plugin code outside of the plugins folder.
    BASE_DIR = self.in_sketchup? ? # Allow the Config to run outside of Sketchup for testing
      Sketchup.find_support_file(RESCAPE_DIR, "Plugins") :
      Dir.pwd

    # Add the sketchup plugin path for testing outside sketchup
    unless (self.in_sketchup?)
     [PLUGIN_DIR, TOOLS_DIR].each {|x| $:.push(x)}
    end

    RESCAPE_DIR_ABS = (File.symlink?(BASE_DIR) ? File.readlink(BASE_DIR) : BASE_DIR)+'/'
    LOG_DIR = BASE_DIR+"/logs"
    # The location of resources used by Rescape
    RESOURCES_DIR = BASE_DIR+"/resources"
    Dir.mkdir(RESOURCES_DIR) unless File.exists?(RESOURCES_DIR)
    CACHES_DIR = BASE_DIR+"/caches"
    Dir.mkdir(CACHES_DIR) unless File.exists?(CACHES_DIR)

    # The xapi server used to fetch OpenStreetMap data
    XAPI_URI = 'http://open.mapquestapi.com/xapi/api/0.6/'

    # The URI to host for a DRb server. This will host a service that processes way_grouping shortest paths and other laborous processes
    DRB_URI = "druby://localhost:7168"

    @@configured = false

    def self.configured
      @@configured
    end

    def self.debug_rescape
      DEBUG_RESCAPE
    end

    # Indicates whether or not the web dialogs should refer to the OpenLaszlo server url. When in debug mode, we may or may not want to also debug the web dialogs
    def self.debug_laszlo
      DEBUG_LASZLO
    end

    def self.config
      if(!@@configured)

        # Put the rescape dir in the search path
        $:.push BASE_DIR

        # Add libs to the search path.
        # These libs are included in rescape because they are not part of the default Ruby build
        lib = self.in_sketchup? ?
          Sketchup.find_support_file("${RESCAPE_DIR}/lib", "Plugins") :
          "${RESCAPE_DIR}/lib"


        if !$:.include? lib
          $:.push lib
        end

        $gem=gems = []
        # Locate the required gems. Generic gems are in the lib dir and os specific ones are further down a level in the os dir
        os_skip_paths = ['windows', 'darwin', 'Ruby187', 'Ruby186']
        gem_lib_dirs = ["#{RESCAPE_DIR_ABS}lib", darwin? ? "#{RESCAPE_DIR_ABS}lib/darwin" : "#{RESCAPE_DIR_ABS}lib/windows"]
        gem_lib_dirs.each {|gem_lib_dir|
          Dir.foreach(gem_lib_dir) {|path|
            next if os_skip_paths.member?(path)
            full_path = "#{gem_lib_dir}/#{path}"
            if (File.directory?(full_path) && !['..','.'].member?(path))
              puts full_path
              # Push the lib path
              lib_path = "#{full_path}/lib"
              gems.push(lib_path)
              # Windows seems to need gem lib directories in ENV['PATH'] to load compiled libs
              if (windows?)
                ENV['PATH']=ENV['PATH'].split(';').push(lib_path.gsub('/','\\\\')).join(';')
              end
            end
          }
        }
        gems.each {|x| $:.push(x)}
        # Override the default XML parser for the OSMLIB gem
        # I haven't been able to make Libxml work on Windows, so resort to REXML
        if (darwin? || !in_sketchup?)
          ENV['OSMLIB_XML_PARSER'] = "Libxml"
        else
          ENV['OSMLIB_XML_PARSER'] = "REXML"
        end

        # Now we can set up logging
        require 'logging/log'
        self.log = Log.new(Rescape::Config::LOG_DIR, "rescape").log

        @@configured = true
      end
    end
  end
end

Rescape::Config.config()
