require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/ground_surface_definition"
require 'wayness/way'
require 'utils/Geometry_Utils'

# Any type of way that serves as a predominantly powered way, such as a street for cars
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Street < Way

  @@road_color = nil
  def self.road_color
    @@road_color ||= Sketchup::Color.new(160, 144, 113, 128)
  end
  WAY_WIDTH_HASH = {
      'secondary'=>50*Geometry_Utils::FEET,
      'secondary_link'=>50*Geometry_Utils::FEET,
      'tertiary'=>50*Geometry_Utils::FEET,
      'residential'=>50*Geometry_Utils::FEET,
      'motorway'=>50*Geometry_Utils::FEET,
      'motorway_link'=>50*Geometry_Utils::FEET,
      'trunk'=>50*Geometry_Utils::FEET,
      'trunk_link'=>50*Geometry_Utils::FEET,
      'primary'=>50*Geometry_Utils::FEET,
      'primary_link'=>50*Geometry_Utils::FEET,
      'unclassified'=>50*Geometry_Utils::FEET,
      'way'=>50*Geometry_Utils::FEET,
      'living_street'=>50*Geometry_Utils::FEET,
      'service'=>50*Geometry_Utils::FEET,
      'track'=>50*Geometry_Utils::FEET,
      'raceway'=>50*Geometry_Utils::FEET,
      'services'=>50*Geometry_Utils::FEET,
      'bus_guideway'=>50*Geometry_Utils::FEET}

  def self.surface_class
    Ground_Surface_Definition
  end

  def default_width
    WAY_WIDTH_HASH[way_type]
  end

  # Street widths need to be adjusted for primary streets that are marked one-way. One way primary are represented by two ways that are parallel, which causes major problems if the two overlap, which they inevitably do. Since it is difficult to identify the relationship between the two ways, the simple solution is to half the way widths.
  def width
    # Get the width
    width = super()
    # Cut the width in half if it's a one-way
    (way_type=='primary' && attributes['oneway'] && attributes['oneway']=='yes') ? width/2 : width
  end

  def self.way_types
    WAY_WIDTH_HASH.keys
  end

  def self.way_color
    Street.road_color
  end
end