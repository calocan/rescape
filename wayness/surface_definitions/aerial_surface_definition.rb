require "wayness/surface_definitions/Way_Surface_Definition"
require "wayness/surface_definitions/Aerialway/aerial_conveyor"
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Aerial_Surface_Definition < Way_Surface_Definition

  WAY_CLASSES = [Aerial_Conveyor]
  # Attributes of Open Street Map way elements
  SURFACE_KEYS = ['aerial']

  @@aerial_color = nil
  def self.aerial_color
    @@aerial_color ||= Sketchup::Color.new(100, 100, 255, 128)
  end

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
