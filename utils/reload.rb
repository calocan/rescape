require 'config/Config'
require 'find'

# Reload loads all the files when Rescape starts up, and can also be used to reload after making code changes
class Reload

  # Skip the following files or files matching the given strings. These represent files that should net be explicitly loaded by Rescape
  BASE_DIR_SKIP_LIST = ['lib', 'caches', 'install', 'logs', 'resources', 'server', 'tests', '\.']
  SKIP_LIST = ['reload.rb', 'setup.rb', 'server', 'lib', 'install', 'external', '\/test']
  # We can't load observers and other things outside of Sketchup, since they inherit from a Sketchup class
  SKIP_OUTSIDE_SKETCHUP_LIST = ['observer', 'rescape.rb']

  # We use a few class extensions outside of Sketchup to simulate Sketchup classes, like Geom::Point3d, which don't seem to be accessible outside of Sketchup
  SKIP_INSIDE_SKETCHUP_LIST = ['substitute']

  # Reloads all the files except those that can't be reloaded like this file and setup.rb
  # Optionally provide a predicate block to limit which paths are loaded
  def self.all
    block = block_given? ? lambda{|path| yield(path)} : lambda{|path| true}
    previous_time = Time.now
    load_times = {}
    Dir.foreach(Rescape::Config::RESCAPE_DIR_ABS) {|base_path|
      base_path_full = "#{Rescape::Config::RESCAPE_DIR_ABS}#{base_path}"
      next unless File.directory?(base_path_full) && BASE_DIR_SKIP_LIST.all? {|base_dir| !base_path.match(base_dir)}
      Find.find(base_path_full) {|path|
        if SKIP_LIST.all?{|skip| !path.match(skip)} and
           SKIP_OUTSIDE_SKETCHUP_LIST.all?{|skip| Rescape::Config.in_sketchup? || !path.match(skip)} and
           SKIP_INSIDE_SKETCHUP_LIST.all?{|skip| !Rescape::Config.in_sketchup? || !path.match(skip)} and
           path.index('.rb') == path.length-3 and
           block.call(path)
          Rescape::Config.log.info("Loading #{path}")
          load path
          puts path
          time = Time.now
          duration = time - previous_time
          Rescape::Config.log.info("Loaded #{path}, duration: #{duration} seconds")
          previous_time = time
          load_times[path] = duration
        end
      }
    }
  end

  # Loads any file whose path matches the given name
  def self.matching(name)
    all {|path| path.match(name)}
  end
end
