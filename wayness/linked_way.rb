require "wayness/way"
require "wayness/way_grouping"
require "utils/geometry_utils"

# A wrapper of Way
# A data structure explaining the relationship of a way with other ways. It stores the ways that are adjacent at the
# start intersection of the way, both on the clockwise and counterclockwise side at the start of the way. Not
# all ways have adjacent ways. A way beginning as a leaf in the network has no adjacent nodes. A two way intersection
# means that the same way is on both sides of the other way. A three or more way intersection means that way has
# distinct adjacent ways on each side of it.
#
# Linked_Way instances help chain continuous ways together for use in drawing the sides of the ways (in particular
# to help calculate how the sides of the ways should intersect) and for drawing offsets, paths, etc.
#
# Linked_Way instances are unidirectional, but their counterpart is accessed by the reverse_way attribute
# A as_dual_way combines the two linked_ways to form the concept of a dual way with a dual_way instance.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Linked_Way
  include Way_Behavior

  attr_reader :adjacent_linked_ways, :reverse_way, :way

  # Linked_Way instances are initialized with the Way they wrap. The
  # set_neighbors will be called to set the neighbors and adjacent_linked_ways properties,
  # since neighbors are of the same class type and must be created after initialization
  def initialize(way, reverse_way=nil, neighbors=nil)
    @way = way
    @reverse_way = reverse_way || self.class.new(way.reverse_way, self)
    set_neighbors(neighbors) if neighbors
  end

  def vector
    way[0].vector_to(way[1])
  end

  def set_neighbors(neighbors)
    @neighbors = neighbors
    @adjacent_linked_ways = neighbors.length > 0 ? calculate_adjacent_linked_ways() : {}
  end

  # Neighbors are linked ways sharing the same origin. A Linked_Way and its neighbors thus share a point that is a node of the way graph, though nodes are not defined explicitly
  def neighbors
    raise "Neighbors uninitialized for %s" % self.inspect unless @neighbors
    @neighbors
  end

  # Find the closest way in each rotation direction from the end of this way
  def calculate_adjacent_linked_ways()
    [Way_Grouping::CCW_KEY, Way_Grouping::CW_KEY].to_hash_keys {|rotate|
      closest_linked_way = Geometry_Utils::find_closest_vector_data(rotate, self.vector, @neighbors)
      raise "Expected neighbor vector but didn't find one" unless closest_linked_way
      closest_linked_way
    }
  end

  # Define the required method for Way_Behavior
  def way
    @way
  end

  # Override the Way_Behavior method to return the reverse linked_way
  def reverse_way
    @reverse_way
  end

  def as_dual_way
    Dual_Way.new(self)
  end

  # Make a version of Linked_Way that overrides the points to represent
  # a partial version of the underlying Way
  def get_partial_linked_way(start_index, end_index)
    Partial_Linked_Way.new(self, start_index, end_index)
  end

  # Override the Way_Behavior method
  def clone_with_new_points(points)
    Linked_Way.new(way.clone_with_new_points(points))
  end

  # Gets the neighbors at the end of this way, meaning the reverse_way.neighbors
  def end_neighbors
    self.reverse_way.neighbors
  end

  # Override the Way_Behavior method
  def inspect
    "%s for %s" % [self.class, way.inspect]
  end
end
