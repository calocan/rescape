require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/rail_surface_definition"
require 'wayness/way'
require 'utils/Geometry_Utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Tram < Way
  DEFAULT_WIDTH = 12*Geometry_Utils::FEET
  DEFAULT_GAUGE = 4*Geometry_Utils::FEET + 8.5
  DEFAULT_HEIGHT = 1*Geometry_Utils::FEET
  # The Rail should reach 1 foot
  RAIL_BASE_START_HEIGHT = DEFAULT_HEIGHT - (6 + 5.to_f/8)
  RAIL_BASE_WIDTH = 5.5
  DEFAULT_Z_POSITION = 2 #1*Geometry_Utils::FEET
  DEFAULT_BED_MATERIAL_NAME = 'Concrete_Aggregate_Smoke'
  DEFAULT_RAIL_MATERIAL_NAME = 'Metal_Corrogated_Shiny'

  def self.surface_class
    Rail_Surface_Definition
  end

  def default_width
    DEFAULT_WIDTH
  end

  def self.default_z_position
    DEFAULT_Z_POSITION
  end

  def self.way_types
    ['tram']
  end

  def self.way_color
    Rail_Surface_Definition.ballast_color
  end
end