require 'utils/complex_point'
require 'utils/static_point_collector'
require 'utils/basic_utils'
# A variant of a Sketchup::InputPoint that remembers previous positions to aid in storing a set of points forming a line.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Input_Point_Collector
  include Complex_Point
  include Basic_Utils

  attr_reader :input_point, :previous_points

  # Creates a new instance with a Sketchup::InputPoint and a collection of previous_points selected by that input point
  # alignable indicates whether or not the previous_points should be flipped to match current input point when calling the aligned* methods. This is useful for a case where the line should be extended from whatever end the input point is closest to.
  def initialize(input_point, previous_points=[], alignable=true, z_constraint=nil)
    @input_point = input_point
    @previous_points = previous_points
    @alignable = alignable
    # An optional z constraint for all points that are finalized
    @z_constraint = z_constraint
  end

  # Returns the static point, constrained to the z_constraint if set
  def point
    constrained_input_point_position()
  end
  # Synonym for point
  def position
    point.position
  end

  # Reposition the input point
  def clone_with_new_point(point)
    self.class.new(@input_point.clone_with_new_point(point), @previous_points, @alignable, @z_constraint)
  end

  # Clones the instance and the underlying_input point, which is dynamic so needs to be unique. The static previous_points need not be cloned.
  def clone()
    self.class.new(input_point.clone(), @previous_points, @alignable, @z_constraint)
  end

  # Clears the previous points and optionally reassigns alignable
  def reset(alignable=nil)
    @previous_points = []
    @alignable = alignable if alignable
  end
  # Sets a z constraint for all points, since Sketchup is too stupid to allow constraining to a plane
  def set_z_constraint(z)
    @z_constraint = z
    @previous_points = @previous_points.map {|p| constrain_z(p, z)}
  end

  def frozen?
    false
  end

  # Returns the static version of the instance so that the point is no longer dynamic, here a Static_Point_Collector
  def freeze
    Static_Point_Collector.new(aligned_trail_of_points)
  end

  # Freeze the instance but ignore the current position. This is needed for double click where the first click is registered but we don't want the position at the time when the double click is registered because it might be a duplicate or different than that first click, an is in any case not desired.
  def freeze_without_current_position
    Static_Point_Collector.new(previous_points)
  end

  # Add the current input_point position to the previous points, thus making it a finalized member of the trail_of_points. The input_point.position will continue to change dynamically but the memory of this point is recorded.
  def finalize_current_position()
    # Constrain the point the z axis position of the other points
    point = constrain_z(@input_point.position, @z_constraint)
    # Reject a duplicate point
    return if last_previous_point_matches?(point)
    @previous_points.push(point)
  end

  def last_previous_point_matches?(point)
    @previous_points.length > 0 && @previous_points.last.matches?(point)
  end

  def remove_previous_position()
    @previous_points.delete_at(@previous_points.length-1)
  end

  # Constrain the height of the point to that of the reference point, if one exists
  def constrain_z(point, z)
    z ? point.constrain_z(z) : point
  end

  # Determines whether or not the z position has been constrained yet
  def constrained_z?
    !@z_constraint.kind_of?(NilClass)
  end

  def constrained_input_point_position
    constrain_z(@input_point.position, @z_constraint)
  end

  # All the previous points plus the input_point position
  def trail_of_points
    input_point_position = constrained_input_point_position()
    @previous_points + (last_previous_point_matches?(input_point_position) ? [] : [input_point_position])
  end

  # Return the previous points in their natural order or reversed so that the last point is closest to the input_point
  def aligned_previous_points
    (!@alignable or @previous_points.length < 2 or @previous_points.last.distance(constrained_input_point_position) < @previous_points.first.distance(constrained_input_point_position)) ?
        @previous_points :
        @previous_points.reverse
  end

  # Return the trail_of_points with the previous points in their natural order or reversed so that the last point is closest to the input_point
  def aligned_trail_of_points
    input_point_position = constrained_input_point_position()
    aligned_previous_points + (last_previous_point_matches?(input_point_position) ? [] : [input_point_position])
  end

  def underlying_input_point
    @input_point.underlying_input_point
  end

  # Delegate any other method to the underlying InputPoint
  def method_missing(m, *args, &block)
    @input_point.send m, *args, &block
  end
end

