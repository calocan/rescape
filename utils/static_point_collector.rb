require 'utils/complex_point'
# Static version of Input_Point_Collector, where the point reference is a Geom::Point3d instead of the current position of an InputPoint
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Static_Point_Collector
  include Complex_Point

  attr_reader :trail_of_points
  def initialize(trail_of_points)
    @trail_of_points = trail_of_points
  end

  def aligned_previous_points
    previous_points
    #(previous_points.length < 2 or previous_points.last.distance(point) < previous_points.first.distance(point)) ?
    #    previous_points :
    #    previous_points.reverse
  end

  # Return the trail_of_points with previous_points in their natural order or reversed so that the last previous_points is closest to point()
  def aligned_trail_of_points
    aligned_previous_points + [point]
  end

  def point
    @trail_of_points.last
  end

  # Since the points are static they are already constrained. This yields the same thing as point
  def unconstrained_point
    point
  end

  def previous_points
    @trail_of_points.all_but_last
  end

  # The class is always frozen, since it's the static version of Input_Point_Collector
  def frozen?
    true
  end

  def freeze
    self
  end

  def underlying_input_point
    raise "No underlying input_point for static_point_collector"
  end

  def clone_with_new_point(point)
    self.class.new(trail_of_points.all_but_last+[point])
  end

  # Clones the instance and passes the underlying points, which are static so don't need to be cloned
  def clone()
    self.new(trail_of_points)
  end

end
