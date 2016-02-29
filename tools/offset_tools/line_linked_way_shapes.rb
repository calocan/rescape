require 'tools/offset_tools/hybrid_linked_way_shapes'
# An extender of Linked_Way_Shapes that considers free-form lines between Way_Shapes rather than just the way_point_pair based paths between Way_Shapes. This represents paths drawn by the user that are anchored in one or more place by a Way_Shape and thus associate to the Way_Grouping of the one or more Way_Shapes
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Line_Linked_Way_Shapes < Hybrid_Linked_Way_Shapes

  # Overrides the parent method to always return the point_sets flattened, even if there is only one point defined. Line editing tools should be able to display a single point hovered over by the user or clicked on without moving further.
  def all_points()
    Geom::Point3d.unique_consecutive_points(point_sets.shallow_flatten)
  end

  # Overrides the parent method to always return the points collected before and on each way_shape, plus the stray points at the end
  def point_sets()
    self.way_shapes.map {|way_shape|
        way_shape.input_point.trail_of_points
    }.reject_empty_collections +
        (stray_points.length>0 ? [stray_points()] : [])
  end

  # Like point_sets, but omits points the point of each way_shape that is associated to the way, which is always the last point of a way_shape's points, since a way_shape collects all stray points leading up to the way association
  def point_sets_without_way_points
    self.way_shapes.map {|way_shape|
      way_shape.input_point.previous_points
    }.reject_empty_collections +
        (stray_points.length>0 ? [stray_points()] : [])
  end

  # Override the default method to return the data_pairs without offsetting.
  def make_offset_data_pairs(data_pairs, lambda_wrapper)
    data_pairs
  end

end