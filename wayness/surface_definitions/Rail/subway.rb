require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/rail_surface_definition"
require 'wayness/way'
require 'utils/Geometry_Utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Subway < Way
  DEFAULT_GAUGE = 4*Geometry_Utils::FEET + 8.5
  DEFAULT_WIDTH = 12*Geometry_Utils::FEET

  def self.surface_class
    Rail_Surface_Definition
  end

  def default_width
    DEFAULT_WIDTH
  end

  def self.way_types
    ['subway']
  end

  def self.way_color
    Rail_Surface_Definition.ballast_color
  end
end