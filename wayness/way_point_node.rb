require 'wayness/way_point_behavior'
require 'wayness/way_point_pair_behavior'
require 'utils/data_point'

# Represents the node of Way_Point that share a common point
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Way_Point_Node
  include Way_Point_Behavior
  include Way_Point_Pair_Behavior

  attr_reader :way_points, :point
  def initialize(way_points)
    @way_points = way_points
    @point = way_points.map {|way_point| way_point.point}.uniq_by_hash {|point| point.hash_point}.only("way_points don't share a common point #{way_points.inspect}'")
  end

  # Conforms with the Way_Point_Behavior interface
  def way_point
    self
  end

  # Clones each way_point with the new position
  def clone_with_new_point(point)
    self.new(@way_points.map {|way_point| way_point.clone_with_new_point(point)})
  end

  # Returns the one node_way_point
  def way_point1
    self
  end

  # Returns the one node_way_point
  def way_point2
    self
  end

  # Reversing has no effect
  def reverse()
    self
  end

  def as_node_data_pair(data_point, way_grouping)
    self
  end
end