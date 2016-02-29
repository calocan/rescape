require 'utils/data_pair'
require 'utils/simple_data_point'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Simple_Pair < Array
  include Data_Pair

  # Simple_Pairs are not aware of their neighbors so this returns []
  def neighbors
    []
  end

  # Simple_Pairs are not aware of their neighbors so this returns {point1=>[], point2=>[]}
  def neighbors_by_point
    self.points.to_hash_keys {|x| []}
  end

  # Doesn't need to clone, just makes a new instance
  def clone_with_new_points(point_pair)
    self.class.new(point_pair)
  end

  def inspect
    "%s with points %s" % [self.class, self.points.inspect]
  end

  # Simple_Pairs have no high level points, return the points themselves wrapped in Simple_Data_Points
  def data_points
    self.map {|point| Simple_Data_Point.new(point)}
  end

  def self.make_simple_pairs(points)
    points.map_with_subsequent {|point1, point2| self.new([point1, point2])}
  end
end