require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/aerial_surface_definition"
require "wayness/way"
require 'utils/Geometry_Utils'

#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Aerial_Conveyor < Way
  DEFAULT_GAUGE = 4*Geometry_Utils::FEET+ 8.5
  DEFAULT_WIDTH = 12*Geometry_Utils::FEET
  DEFAULT_Z_POSITION = 20*Geometry_Utils::FEET
  WAY_TYPES = ['cable_car', 'gondola', 'chair_lift', 'mixed_lift', 'drag_list']

  def self.surface_class
    Aerial_Surface_Definition
  end

  def default_width
    DEFAULT_WIDTH
  end

  def self.default_z_position
    DEFAULT_Z_POSITION
  end

  def self.way_types
    WAY_TYPES
  end

  def self.way_color
    Aerial_Surface_Definition.aerial_color
  end
end