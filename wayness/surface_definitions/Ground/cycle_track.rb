require "wayness/surface_definitions/way_surface_definition"
require "wayness/surface_definitions/ground_surface_definition"
require 'wayness/way'
require 'utils/Geometry_Utils'

# Any type of way that serves as a predominantly self-powered way, such as a bike path, trail, or foot path
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Cycle_Track < Way

  @@default_color = nil
  def self.default_color
    @@default_color ||= Sketchup::Color.new(40, 80, 0, 128)
  end
  @@center_line_color = nil
  def self.center_line_color
    @@center_line_color ||= Sketchup::Color.new(200, 200, 200, 255)
  end


  # note that proposed could apply to highways too, so this needs to be more sophisticated.
  WAY_WIDTH_HASH = {'cycleway'=>8*Geometry_Utils::FEET}
  DEFAULT_Z_POSITION = 1*Geometry_Utils::FEET
  CENTER_LINE_WIDTH = 6
  DEFAULT_MATERIAL_NAME = 'Bike Asphalt'

  def self.surface_class
    Ground_Surface_Definition
  end

  def self.way_types
    WAY_WIDTH_HASH.keys
  end

  def self.way_color
    PATH_COLOR
  end

  def default_width
    WAY_WIDTH_HASH[self.way_type]
  end

  def self.default_z_position
    DEFAULT_Z_POSITION
  end

end