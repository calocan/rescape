require "wayness/linked_way"
# A clipped version of an existing way
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Partial_Linked_Way < Linked_Way
  attr_reader :indices, :linked_way
  # Create a view of the linked_way with limited indices indicated by start_index and end_index, inclusive
  # Thus a linked_way of 4 points with start_index=1 and end_index=2 will be a view of the second to third point of the way
  # modified_start_point and modified_end_point can be used to change the extreme points to different positions
  # to represent a trimmed line segment
  def initialize(linked_way, start_index, end_index, modified_start_point=nil, modified_end_point=nil)
    super(linked_way.way, linked_way.reverse_way, linked_way.neighbors)
    @linked_way = linked_way
    @indices = [start_index, end_index]
    @modified_extreme_points = [modified_start_point, modified_end_point]
  end

  # Override linked_way to keep the points reduced
  def reverse_way
    @linked_way.reverse_way.get_partial_linked_way(@linked_way.length-@indices[1]-1, @linked_way.length-@indices[0]-1)
  end

  def inspect
    "%s with indices %s of %s" % [self.class, self.indices.inspect, @linked_way.inspect]
  end

  # We always think of indices in terms of the full way
  def index point
    @linked_way.index point
  end

  def points
    points = @linked_way.points[@indices[0]..@indices[1]]
    [(@modified_extreme_points[0] || points.first)] +
    points.rest.all_but_last +
    [(@modified_extreme_points[1] || points.last)]
  end

  # Override Linked_Way
  def clone_with_new_points(points)
    Linked_Way.new(way.clone_with_new_points(points))
  end
end