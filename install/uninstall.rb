#!/usr/bin/ruby

require 'config/config'
=begin

# Delete the Rescape plugin
PLUGIN_DIR = Rescape::Config::PLUGIN_DIR
rm_rescape_dir = "rm -r '#{PLUGIN_DIR}/rescape'"
puts "Deleting Rescape plugin folder with command #{rm_rescape_dir}"
system(rm_rescape_dir)
rm_rescape_file = "rm '#{PLUGIN_DIR}/rescape.rb'"
puts "Deleting Rescape plugin file with command #{rm_rescape_file}"
system(rm_rescape_file)

# Revert Sketchup Ruby links
['Resources', 'Ruby'].each {|file_name|
  file = "#{RUBY_FRAMEWORK}/#{file_name}"
  backup_file = "#{RUBY_FRAMEWORK}/#{file_name}.back"
  raise "Unable to revert Sketchup Ruby links because backup file #{backup_file} does not exist" unless File.exists?(backup_file)
  rm = "rm '#{file}'"
  puts "Deleting file #{file} with command #{rm}"
  system(rm)
  mv = "mv '#{backup_file}' '#{file}'"
  puts "Restoring file from backup with command #{mv}"
  system(mv)
}
=end
