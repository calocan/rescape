require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/Ground/path.rb"
require "wayness/surface_definitions/Ground/street.rb"

#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Ground_Surface_Definition < Way_Surface_Definition
  WAY_CLASSES = [Path, Street]
  # Attributes of Open Street Map way elements
  SURFACE_KEYS = ['highway', 'cycleway']

  DEFAULT_Z_POSITION = 1*Geometry_Utils::FEET
  DEFAULT_Z_LAYER_MULTIPLIER = 15*Geometry_Utils::FEET

  def self.surface_keys
    SURFACE_KEYS
  end
  def self.way_classes
    WAY_CLASSES
  end
  def self.get_width(tags)
    tags['width'].to_f * INCHES_PER_METER
  end
end