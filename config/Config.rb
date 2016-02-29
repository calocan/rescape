
module Rescape
  class Config
    class << self; attr_accessor :log end

    # Determines if the code is running in the Sketchup environment or externally
    def self.in_sketchup?
      (defined?(Sketchup) && defined?(Sketchup::Color)) ? true : false
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
     ["/Library/Application Support/Google SketchUp 8/SketchUp/Plugins", "/Library/Application Support/Google SketchUp 8/SketchUp/Tools"].each {|x| $:.push(x)}
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


    def self.ruby_install_location
      darwin? ?
          # We want to use the default system version of Ruby for darwin
          '/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/lib/ruby':
          (in_sketchup? ?
              # The current state for windows is that Sketchup runs in 1.8.6 and extends itself with the 1.8.6 libraries
              "#{RESCAPE_DIR_ABS}lib/windows/Ruby186/lib/ruby" :
              # Outside of Sketchup under the external server we run 1.8.7 in order to have a better supported version of Ruby which makes it possilbe to get a working version of libxml. They appear to be able to communicate somewhat but it crashes often, though this isn't necessarily due to the version mismatch (it might just be running an external process on windows or something)
              "#{RESCAPE_DIR_ABS}lib/windows/Ruby187/lib/ruby")
    end

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
        libs = get_ruby_lib_base_dir()

        if !$:.include? libs[0]
          libs.each	{|x| $:.push x}
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
        # Windows needs the .so files in the LOAD_PATH
        if (windows?)
              $:.push("#{ruby_install_location}/1.8/i386-mswin32")
        end
        # Override the default XML parser for the OSMLIB gem
        # I haven't been able to make Libxml work on Windows, so resort to REXML
        if (darwin? || !in_sketchup?)
          ENV['OSMLIB_XML_PARSER'] = "Libxml"
        else
          ENV['OSMLIB_XML_PARSER'] = "REXML"
        end
        require 'logging/log'
        self.log = Log.new(Rescape::Config::LOG_DIR, "rescape").log

        @@configured = true
      end
    end

    def self.get_ruby_lib_base_dir()
        # Remove the most minor version number if under 1.9.0.
        if RUBY_VERSION < '1.9.0'
          ver=RUBY_VERSION.split('.')[0..1].join('.')
        else
          raise "ruby version >1.8.* is not supported"
          #ver=RUBY_VERSION
        end
        prefix=ruby_install_location
        if (darwin?)
          # Use the ruby platform that is used by the external ruby installation for OS X since the current Sketchup ruby platform darwin8 is out of date
          darwin_versions = []
          Dir.foreach("#{prefix}/#{ver}/") {|path|
            if (path.match('universal-darwin10.0'))
                #path.match('i686-darwin'))
              darwin_versions.push(path.split('/')[-1])
            end
          }
          platform = darwin_versions.sort.last
        else
          # Use the RubyInstaller platform
          platform = 'i386-mingw32'
        end

        # Add the ruby libs
        load_path = ["#{prefix}/#{ver}", "#{prefix}/#{ver}/#{platform}", "#{prefix}/site_ruby/#{ver}", "#{prefix}/site_ruby/#{ver}/#{platform}"]
        puts load_path.inspect
        # only apply if there are things installed there
        #$LOAD_PATH << "#{pre}/vendor_ruby/#{ver}"
        #$LOAD_PATH << "#{pre}/vendor_ruby/#{ver}/#{plat}"
        # Add the rescape base directory
        [BASE_DIR, "."] + load_path
      end
    end
end

Rescape::Config.config()
