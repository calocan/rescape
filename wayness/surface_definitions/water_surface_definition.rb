require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/water/navigational_waterway"
require "wayness/surface_definitions/water/navigational_channel"
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Water_Surface_Definition < Way_Surface_Definition
  WAY_CLASSES = [Navigational_Waterway, Navigational_Channel]
  # Attributes of Open Street Map way elements
  SURFACE_KEY = 'waterway'
  @@water_color = nil
  def self.water_color
    @@water_color ||= Sketchup::Color.new(0, 0, 255, 128)
  end

  def self.surface_keys
    [SURFACE_KEY]
  end
  def self.way_classes
    WAY_CLASSES
  end
end