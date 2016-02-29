require 'wayness/side_point'

# A subclass of Side_Point that allows a side_point to store an alternative set up points to represent it.
# This is used for a point that has been converted to a curve due to a limited angle tolerance
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Side_Point_Parent < Side_Point

  attr_reader :side_point_children, :neighbor_side_points
  # Expects a Side_Point and a list of child Geom::Point3d points, side_point_children, representing the side_point converted to the curve when it falls at too great an angle relative to its neighbors. neighbor_side_points are the Side_Point instances next to the side_point for reference
  def initialize(side_point, side_point_children, neighbor_side_points)
    super(side_point.point, side_point.way_point, side_point.other_way_point)
    @side_point_children = side_point_children
    @neighbor_side_points = neighbor_side_points
  end
  def is_curved?
    @side_point_children.length > 1
  end

  def children_as_side_points
    @side_point_children.map {|point| Side_Point.new(point, @way_point, @other_way_point)}
  end

end