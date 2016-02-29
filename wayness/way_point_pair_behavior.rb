require 'utils/array_module'
require 'utils/data_pair'
require 'utils/data_pair_class_methods'
require 'wayness/way_point_pair_basic_behavior'

#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Way_Point_Pair_Behavior
  include Data_Pair
  include Enumerable
  include Array_Module
  include Way_Point_Pair_Basic_Behavior

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Data_Pair)
  end

  def way_point1
    raise "Must be implemented by mixer for class #{self.class}"
  end

  def way_point2
    raise "Must be implemented by mixer"
  end

  # Reverse each way_point and the position in the pair
  def reverse()
    raise "Must be implemented by mixer"
  end

  # Returns the two Way_Points
  def way_points
    [way_point1, way_point2]
  end

  def each
    way_points.each {|way_point| yield way_point}
  end

  def [](index)
    way_points[index]
  end

  def length
    way_points.length
  end

  def +(other)
    self.pair + other.pair
  end

  def vector
    way_point1.point.vector_to(way_point2.point)
  end

  def indices
    [way_point1.index, way_point2.index]
  end

  # Order of the pair matters for identity, since a way the reverse way
  # has the same pair in the opposite direction
  def hash
    self.map {|way_point| way_point.hash}.hash
  end

  def ==(other)
    self.hash == other.hash
  end

  def create_partials(range_fractions)
    range_fractions.map {|range_fraction| Partial_Way_Point_Pair.new(self, range_fraction)}
  end

  # Returns a Range instance that gives the percent of the two way_points in the way
  def range_in_way
    Way_Point_Pair.range_of_data_pair(self.way.way_point_pairs, way_point_pair)
  end

  # The neighbors of the way_point_pair within its way
  # This could be extended to include other linked ways if the way_point_pair ways were known to be linked_ways
  def neighbors
    way_point_pairs = self.way.way_point_pairs
    index = way_point_pairs.index(self)
    (index==0 ? [] : [way_point_pairs[index-1]]) + (index==way_point_pairs.length-1 ? [] : way_point_pairs[index+1])
  end

  # Returns a node version of the way_point_pair. This can be either the intersection of way_point_pairs or the intersection of ways
  # The return type is either a Node_Way, Node_Way_Point
  def as_node_data_pair(way_point, way_grouping)
    if (way_point.index == 0)
      # The way_point is the start of the way, get Way_Node of the way (always corresponds to the first point of the way) and then make a Node_Way_Point_Pair thereout.
      way_grouping.way_node_of_way(self.way)
    elsif (way_point.index == self.way.length-1)
      # The way_point is the end of the way, get Way_Node of the reverse way and then make a Node_Way_Point_Pair thereout.
      way_grouping.way_node_of_way(self.way.reverse_way)
    else
      Way_Point_Node.new([way_point, way_point.reverse])
    end
  end

  # Maps the neighbors by point to {point1=>[neighbors1], point2=>[neighbors2]}
  def neighbors_by_point
    neighbors.to_hash_value_collection {|neighbor| self.find {|way_point| neighbor.contains_data_point?(way_point)}}
  end

  # The high-level class of points, Way_Point instances here
  def data_points
    self.to_a
  end

  # Creates a way_point_pair by calling way_point
  def clone_with_new_points(point_pair)
    Partial_Way_Point_Pair.new(self, point_pair)
  end

  def inspect
    "%s of indices %s, direction %s, with hash %s of {%s}" % [self.class, self.indices.inspect, self.cardinal_direction, self.hash, self.way.inspect]
  end

end



