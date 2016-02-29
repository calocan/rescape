require "utils/Data_Point"
require "wayness/Way_Point_Behavior"

# Associates a side point with a Way_Point
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Side_Point
  include Data_Point
  include Way_Point_Behavior
  attr_reader :point, :way_point, :way, :other_way_point
  # Defines a point defining one side of the way corresponding to the given way_point
  # Specify other_way_point if the side point straddles two unique ways. other_way_point is used as a reference is the side_point represents the convergence of two ways, making other_way_point refer to the way_point of the other way at the same point. It is only used to validate whether two side points are adjacent
  def initialize(point, way_point, other_way_point=way_point)
    @point = point
    @way_point = way_point
    @other_way_point = other_way_point
    @way = way_point.way
  end

  # Clone the side point without changing the way_point data
  def clone_with_new_point(new_side_point)
    self.class.new(new_side_point, @way_point, @other_way_point)
  end

  def hash
    [@way_point.hash, @point.hash_point].hash
  end

  def ==(other)
    self.hash == other.hash
  end

  # Gets the one or two way_point associated with the side_point
  def way_points
    [@way_point, @other_way_point].map {|way_point| way_point}.uniq_by_hash {|way_point| way_point.hash}
  end

  # Returns one or two ways of the side_point. Two are returned if other_way_point belongs to another way
  def ways_of_side_point
    [@way_point, @other_way_point].map {|way_point| way_point.way}.uniq_by_hash {|way| way.hash}
  end

  # Finds the closest center points pair of the way to the associated_point_pair and returns that center_pair
  # There need not be a one-to-one association of associated pairs to center point pairs
  def closest_center_points(way, associated_point_pair)
    way.get_point_pairs.sort_by {|point_pair|
      point_pair[0].distance(associated_point_pair[0])+
          point_pair[1].distance(associated_point_pair[1])}.first
  end

  def inspect
    "%s of hash %s with%s another distinct way_point of %s" % [self.class, self.hash, self.other_way_point==self.way_point ? 'out':'', self.way_point.inspect]
  end
end

