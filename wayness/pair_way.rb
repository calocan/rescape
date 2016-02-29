require 'utils/data_pair'
require 'wayness/way'

# Treats edges as ways by converting a list of connected edges to ordered points.
# If the edges are not connected it will sort the points by proximity.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Pair_Way < Way
  # The first argument can be connected edges or points, the latter is needed because Way will call this constructor
  # to reverse the point and make a reverse way
  def initialize(connected_pairs_or_points, attributes={}, reverse=nil, id=nil)
   super(connected_pairs_or_points.all? {|pair| pair.kind_of?(Data_Pair)} ?
              connected_pairs_or_points.first.class.to_ordered_points(connected_pairs_or_points) :
              connected_pairs_or_points,
          attributes, reverse, id)
  end

  @@surface_color = nil
  def self.surface_color
    @@surface_color ||= Sketchup::Color.new(160, 144, 113, 128)
  end
  def self.way_color
    self.surface_color
  end

  # Unlike normal ways, Pair_Way points should already have a z_position transform, so do nothing here
  def z_position_constraint(points)
    points
  end

  # Pair_Ways are always temporary and shouldn't be stored to the model
  def self.save_to_model?
    false
  end
end