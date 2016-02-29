require 'utils/data_point'
require 'wayness/way_point_pair_behavior'
require 'wayness/way_point'
require 'wayness/way_behavior'
#
# An enhanced Geom::Point3d that stores the association of Linked_Way instances of ways that intersect because they have a common start point. Linked_Ways are each aware of their neighbors, so this doesn't store any unique data.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Way_Node
  include Data_Point
  include Way_Point_Pair_Behavior
  include Way_Behavior
  attr_reader :point, :linked_ways, :way_point_node
  def initialize(linked_ways)
    $linked_ways = linked_ways
    @point = linked_ways.map {|linked_way| linked_way.way.first}.uniq_by_map {|point| point.hash_point}.only("The linked_ways did not share the same start way point #{linked_ways.map {|linked_way| linked_way.way.first}.inspect}")
    @linked_ways = linked_ways
    @way_point_node = linked_ways.map {|linked_way| linked_way.way.as_way_points.first}
  end

  def point
    @point
  end

  def way
    Node_Way.new([point], {:name=>description()})
  end

  def description
    "Intersection of ways #{linked_ways.map{ |linked_way| linked_way.way.name + ' (' + linked_way.way.direction + ')'}.join(", ")}"
  end

  def as_way_point
    Way_Point.new(@point, self)
  end

  def clone_with_new_point(new_point)
    self.new(@linked_ways.map {|linked_way| linked_way.clone_with_new_points([new_point]+linked_way.way.rest)})
  end

  # Returns the representation of the node as a Node_Way_Point
  def way_point1
    @way_point_node
  end

  # Returns the representation of the node as a Node_Way_Point
  def way_point2
    @way_point_node
  end

  # The reverse is the same
  def reverse()
    self
  end

  def as_node_data_pair(data_point, way_grouping)
    self
  end

  # identify the Way_Node by its point only
  def hash
    @point.hash_point
  end
end