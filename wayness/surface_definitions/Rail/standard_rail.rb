require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/rail_surface_definition"
require 'wayness/way'
require 'utils/Geometry_Utils'

# Rail representing standard gauge rail, light rail, narrow gauge, and anything else that is capable of interacting,
# except for trams.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Standard_Rail < Way
  RAIL_TYPES =  ['rail', 'light_rail', 'abandoned', 'disused', 'preserved', 'narrow_gauge', 'construction']
  DEFAULT_GAUGE = 4*Geometry_Utils::FEET + 8.5
  DEFAULT_WIDTH = 12*Geometry_Utils::FEET
  DEFAULT_TIE_WIDTH = 8.5*Geometry_Utils::FEET
  DEFAULT_TIE_LENGTH = 9
  DEFAULT_TIE_SPACING = 12
  DEFAULT_TIE_REPEAT = DEFAULT_TIE_LENGTH+DEFAULT_TIE_SPACING
  RAIL_BASE_START_HEIGHT = 7
  DEFAULT_Z_POSITION = 1*Geometry_Utils::FEET
  DEFAULT_TIE_MATERIAL_NAME = 'Concrete_Aggregate_Smoke'
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
    RAIL_TYPES
  end

  def self.way_color
    Rail_Surface_Definition.ballast_color
  end
end