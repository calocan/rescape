# A way that contains the points of an offset_component. The center of the offset_component defines the way. The edges are defined by other point_sets of the offset_component
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'wayness/way'

class Offset_Way < Way

  def initialize(points, attribute, reverse=nil, id=nil)
    super(points, attribute, reverse, id)
  end

  def default_width
    raise "Offset_Way has no default width!"
  end

  # Unlike normal ways, Offset_Way points should already have a z_position transform, so do nothing here
  def z_position_constraint(points)
    points
  end

  def self.surface_type

  end

  def self.way_types
    []
  end

  def self.way_color
    Sketchup::Color.new(255,255,255,255)
  end

end