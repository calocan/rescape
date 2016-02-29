require 'tools/offset_tools/linked_way_shapes'
# An extender of Linked_Way_Shapes that considers free-form lines between Way_Shapes rather than just the way_point_pair based paths between Way_Shapes. This represents paths drawn by the user that are anchored in one or more place by a Way_Shape and thus associate to the Way_Grouping of the one or more Way_Shapes
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Hybrid_Linked_Way_Shapes < Linked_Way_Shapes

  # The normal data_pairs of Linked_Way_Shapes
  def way_based_data_pairs
    way_based_data_pair_sets.shallow_flatten.uniq_allow_loop
  end

  def all_way_based_points
    Side_Point_Pair.to_unique_points(way_based_data_pairs)
  end

  # Overrides the parent method and returns the data_pairs of the line chosen by the user
  def data_pairs
    data_pair_sets().shallow_flatten
  end

  # Overrides the parent method. Creates sets of data_pairs representing the chosen_path_sets between each way_shape. Points selected before a way_shape are incorporated into that way_shape. If points are selected after the last way_shape they form their own set. These sets each represent a new way or edge_set, depending on what tool is being used
  def data_pair_sets(point_sets=point_sets())
    # Use map_with_previous_and_subsequent to get iterations with nil values
    point_sets.map_with_previous_and_subsequent {|previous_point_set, point_set, next_point_set|
      # Add the last point of the previous set to each set, if one exists, so that the point pair join each set is included. Do not add in the case where the point matches the first point of the set, which can happen when the set only has one point defined itself. In this case the set will be eliminated by the next line
      points = ((previous_point_set != nil && !previous_point_set.last.matches?(point_set.first)) ? [previous_point_set.last] : []) + point_set
      # If a way_shape only has one point and there is no set previous, we don't make a pair
      points.length > 1 ? Simple_Pair.make_simple_pairs(points) : []
    }.reject_empty_collections
  end

  # Overrides the parent method and consolidates all the input points associated with each way_shape plus stray points at the end--in other words every point the user clicked
  def all_points()
    points = Geom::Point3d.unique_consecutive_points(point_sets().shallow_flatten)
    # If only one point exists, meaning the user is hovering but hasn't clicked yet, return the partial way_shape over which they hover if one exists.
    points.length < 2 && way_shapes.length > 0 ?
        all_way_based_points : points
  end

  # Returns all_points() minus the points that are actually associated with a way. This is always the final point of each way_shape. This will return 0 or more points.
  def all_off_way_points()
    Geom::Point3d.unique_consecutive_points(point_sets_without_way_points().shallow_flatten)
  end

  # Each way_shape contains points leading up to it since the previous way_shape. In this hybrid class, the points in between may be either points aligned to the way leading from the previous way_shape or points that veer off the way and connect two way_shapes. Going off the way is normally enabled by a modifier key that the user holds, and that option will be stored in each way_shape. The stray_points after the last way_shape make the final set if any exist.
  def point_sets()
    $iii=self.way_shapes.map_with_previous_and_subsequent {|previous_way_shape, way_shape, next_way_shape|
       if ((next_way_shape && next_way_shape.point.trail_of_points.length ==1) || # primary case
           (!next_way_shape && way_shape.point.trail_of_points.length ==1))   # last/only way shape case
         # If the user indicated that way_shape should follow the way
         if (self.way_shapes.length > 1 && !next_way_shape)
           # Skip the last iteration if it's not the only iteration, since we need way_shapes in pairs
           []
         else
           # Take the pair of way_shapes or just one for lists of one way_shape only
           way_shapes = next_way_shape ? [way_shape, next_way_shape] : [way_shape]
           # Get or solve the path on the ways between the way_shapes. The way_based_data_pair_sets correspond to each way_shape in way_shapes
           index = self.way_shapes.index(way_shapes.first)
           point_set = way_based_data_pair_sets[index]
           Side_Point_Pair.to_unique_points(point_set)
         end
       else
         # Solve the path from the last point of this way_shape and next_way_shape's trail_of_points
         if (next_way_shape)
           if (previous_way_shape)
             # We already handled the current way shape, just do the next one
             Side_Point_Pair.to_unique_points(create_direct_path_data_pair_set([next_way_shape]))
           else
             # First two, handle both
             Side_Point_Pair.to_unique_points(create_direct_path_data_pair_set([way_shape, next_way_shape]))
           end
         elsif (!previous_way_shape)
           # Case of only one
           Side_Point_Pair.to_unique_points(create_direct_path_data_pair_set([way_shape]))
         else
          # Case of last one where there's more than one. So it was already handled
          []
         end
       end
    }.reject_empty_collections +
    (stray_points.length>0 ? [stray_points()] : [])
=begin
# Trying to figure out how to get a smooth connection between a way_shape and stray points or way_shape and way_shape with multiple_points
    (stray_points.length>0 ?
      (stray_points.length() > 1 ?
        #[Side_Point_Pair.to_unique_points(make_offset_data_pairs_for_direct_paths(Geom::Point3d.to_simple_pairs(stray_points())))] :
        [stray_points()] :
        [stray_points()]) :
      [])
=end
  end

  # This checks if the last way_shape has the same accumulated points as the current input_point_collector. If not the input_point_collector points are added to the display. We compare previous_points because even when the two have identical previous_points, their current points are allowed to differ since the input_point_collector current point is dynamic.
  # We always order the returned previous_points according to the proximity to the current input_point position. This way the user can add points to either side of the stray points, depending on proximity
  def stray_points()
    last_way_shape = self.way_shapes.last
    # Add stray points if there is no previous way_shape
    if (!last_way_shape ||
        # or no previous points of this input point
        self.data_point.previous_points.length==0 ||
        # or the previous points of this input point don't match those of the last way shape
        !Geom::Point3d.point_lists_match?(
            last_way_shape.input_point.aligned_previous_points,
            self.data_point.aligned_previous_points))
      # Points do not match so add them. Get the previous points in normal order or reverse them so the last one is closest to the user's input point. This allows the user to always add to the points the cursor is nearest to when there are way_shapes connected yet.
      previous_points = aligned_or_normal_previous_points()
      # Only return the current position if it's not over the previous way_shape and does match the previous point
      previous_points +
          (allow_last_stray_point?(previous_points) ? [self.data_point.constrained_input_point_position] : [])
    else
      []
    end
  end

  # Determines whether the previous points should be rearranged to be reversed with the current point
  # This is needed when the user has selected a predefined line and wishes to extend it
  def aligned_or_normal_previous_points()
    self.way_shapes.length == 0 ?
      self.data_point.aligned_previous_points() : # No clicked way_shapes yet so align stray points to cursor
      self.data_point.previous_points
  end

  # Determines if the current position of the data_point matches a way_shape with the same way_point_pair as the most recent recorded way_shape. If so, allow_hover_over_consecutive_point_in_way_shape? configuration options determines whether the stray point will be accepted.
  def allow_last_stray_point?(previous_points)
    # If the last point doesn't match
    (previous_points.empty? || !previous_points.last.matches?(self.data_point.constrained_input_point_position)) &&
    (self.way_shapes.length == 0 ||
      # And the last way_shape's point position does match the stray point position (this happens when allow_close_hovers? is true and the user is hover off the way put it is associating with the way)
      (!self.way_shapes.last.point.position.matches?(self.data_point.constrained_input_point_position) &&
       # And the cursor isn't still associating with the same way_point_pair (multiple points on the way_point_pair should be enabled in the future)
       !self.way_shapes.last.matches_closest_way_point_pair?(self.data_point)))
    #!offset_configuration.allow_hover_over_consecutive_point_in_way_shape?()
  end

end