require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/rail/standard_rail"
require "wayness/surface_definitions/rail/subway"
require "wayness/surface_definitions/rail/tram"
require "wayness/surface_definitions/rail/monorail"
require "wayness/surface_definitions/rail/funicular"
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Rail_Surface_Definition < Way_Surface_Definition
  WAY_CLASSES = [Standard_Rail, Subway, Tram, Monorail, Funicular]
  # Attributes of Open Street Map way elements
  SURFACE_KEY = 'railway'
  @@ballast_color = nil
  def self.ballast_color
    @@ballast_color ||=  Sketchup::Color.new(100, 100, 100, 128)
  end

  def self.surface_keys
    [SURFACE_KEY]
  end
  def self.way_classes
    WAY_CLASSES
  end
end