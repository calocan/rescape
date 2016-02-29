#!/usr/bin/ruby

require 'install_config'

# Make sure that version 8 of Sketchup is installed where expected
puts "The Rescape installer requires Sketchup 8 to be installed at #{SKETCHUP_PATH}" unless File.exists?(SKETCHUP_PATH)

# Make sure version 1.8 of Ruby is installed where xpected
puts "The Rescape installer requires Ruby version 1.8.7 library to be installed at #{RUBY_LIB}" unless File.exists?("#{RUBY_LIB}/Ruby")

puts File.exists?(SKETCHUP_PATH) && File.exists?("#{RUBY_LIB}/Ruby")
