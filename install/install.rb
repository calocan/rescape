#!/usr/bin/ruby

require 'config/config'

####
# Updates the user's Sketchup installation to use a complete version of Ruby instead of the
# the one embedded in Sketchup
# TODO: Is this still necessary?
####
=begin

SKETCHUP_PATH = Rescape::Config::SKETCHUP_PATH
SKETCHUP_RUBY_FRAMEWORK="#{SKETCHUP_PATH}/Contents/Frameworks/Ruby.framework/Versions/Current"
RESCAPE_DIR = "#{Rescape::Config::PLUGIN_DIR}/rescape"
RESCAPE_LIB_DIR = "#{RESCAPE_DIR}/lib"
RUBY_LIB = `which ruby`.sub("/bin/ruby\n", '/lib/ruby')

# Make sure that version 2016 of Sketchup is installed where expected
puts "The Rescape installer requires Sketchup 2016 to be installed at #{SKETCHUP_PATH}" unless File.exists?(SKETCHUP_PATH)

# Make sure version 1.8 of Ruby is installed where expected
puts "The Rescape installer requires Ruby to be installed" unless File.directory?(RUBY_LIB)

# Update Sketchup to link to the Darwin Ruby installation
['Resources', 'Ruby'].each {|file_name|
  file = "#{SKETCHUP_RUBY_FRAMEWORK}/#{file_name}"
  backup_file = "#{file}.back"
  lib_file = "#{RUBY_LIB}/#{file_name}"

  unless (File.exists?(backup_file))
    mv = "mv '#{file}' '#{backup_file}'"
    puts "Backing up file #{file} with command: #{mv}"
    system(mv)

    ln = "ln -s '#{lib_file}' '#{file}'"
    puts "Linking Sketchup ruby reference to system version with command: #{ln}"
    system(ln)
  end
}
=end
