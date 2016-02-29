require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/ground_surface_definition"
require 'wayness/way'
require 'utils/Geometry_Utils'

# Any type of way that serves as a predominantly self-powered way, such as a bike path, trail, or foot path
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Path < Way

  @@road_color = nil
  def self.road_color
    @@road_color ||= Sketchup::Color.new(120, 104, 73, 128)
  end

  # note that proposed could apply to highways too, so this needs to be more sophisticated.
  WAY_WIDTH_HASH = {'proposed'=>10*Geometry_Utils::FEET, 'pedestrian'=>10*Geometry_Utils::FEET, 'path'=>10*Geometry_Utils::FEET, 'footpath'=>10*Geometry_Utils::FEET,'footway'=>10*Geometry_Utils::FEET, 'bridleway'=>10*Geometry_Utils::FEET, 'steps'=>10*Geometry_Utils::FEET}
  DEFAULT_HEIGHT = 1*Geometry_Utils::FEET

  def self.surface_class
    Ground_Surface_Definition
  end

  def self.way_types
    WAY_WIDTH_HASH.keys
  end

  def self.way_color
    self.road_color
  end

  def default_width
    WAY_WIDTH_HASH[self.way_type]
  end
end