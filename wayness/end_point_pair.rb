require 'utils/data_pair'
require 'wayness/side_point'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class End_Point_Pair
  include Data_Pair

  attr_reader :pair_of_way_point_and_side_point, :ways
  def initialize(pair_of_way_point_and_side_point)
    @pair_of_way_point_and_side_point = pair_of_way_point_and_side_point
    @way_points =  @pair_of_way_point_and_side_point.flat_map {|way_point_or_side_point|
      way_point_or_side_point.class == Side_Point ? way_point_or_side_point.way_points : [way_point_or_side_point]}.uniq
    @ways = @way_points.map {|way_point| way_point.way}.uniq
  end

  # Gets the one or two distinct way_points of the end_point_pair (probably always one).
  def way_points
    @way_points
  end

  def neighbors
    raise "End_Point_Pair is not aware of its neighbors. You must override this method"
  end

  # Maps the neighbors by point to {point1=>neighbors1, point2=>neighbors2}
  def neighbors_by_point
    raise "End_Point_Pair is not aware of its neighbors. You must override this method"
  end

  # Create a clone of the pair, replacing its points with the given point pair
  def clone_with_new_points(point_pair)
    raise "Mixin interface method not implemented"
  end

  # Reverse the side_point_pair. We don't reverse the way_point_pair
  def reverse
    self.class.new(@pair_of_way_point_and_side_point.reverse)
  end

  # The high-level class of points, Way_Point instances here
  def data_points
    self.pair_of_way_point_and_side_point
  end
end