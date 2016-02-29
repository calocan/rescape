# point set functions used in conjunction with Offset_Finisher_Module
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Offset_Finisher_Point_Sets

  # Retrieves the point set identified by the given key
  def data_point_set(key)
    data_point_sets()[key]
  end

  # Retrieves the point set identified by the given key
  def point_set(key)
    point_sets = find_or_create_point_sets()
    point_sets[key].or_if_nil {raise "#{key} is not one of the point sets: #{point_sets.inspect}"}
  end

  # Gets the :center point_set, which always represents the chosen_path offset to the cursor_position
  def center_data_points()
    data_point_set(:center)
  end

  # Defines parallel lines represented by points. See make_data_point_sets for a description of the hash
  def point_set_definition
    {}
  end

  # The array of point set names that will represent the edges of the component whenever it is treated as a way_grouping
  # Use a single element array for a symmetric point_set. Use two for non-symmetric point_sets
  def edge_point_sets
    []
  end

  # Returns all the data_point_sets mapped to points
  def point_sets(data_pair_sets=way_dynamic_path.data_pair_sets)
    data_point_sets(data_pair_sets).map_values_to_new_hash {|key, data_points| data_points.map {|data_point| data_point.point}}
  end

  # Uses two caches to make point_set creation more efficient
  def find_or_create_point_sets(data_pair_sets=way_dynamic_path.data_pair_sets)
    find_or_create_data_point_sets(data_pair_sets).map_values_to_new_hash {|key, data_points| data_points.map {|data_point| data_point.point}}
  end

  def find_or_create_data_point_sets(data_pair_sets=way_dynamic_path.data_pair_sets)
    cache_key = [point_set_definition, data_pair_sets]
    if (cache_container.data_point_set_cache_lookup.member?(cache_key))
      cache_container.data_point_set_cache_lookup.find_or_nil(cache_key)
    else
      data_point_sets=data_point_sets(data_pair_sets)
      cache_container.data_point_set_cache_lookup.add(cache_key, data_point_sets)
    end
  end

  # Defines one or more sets of points offset from the chosen path
  # By default only the center points are created
  # Override this to provide more point_sets and to optionally make the points nonsymmetrical
  # Optionally provide a path to alter the default path, point_on_path_data.path
  def data_point_sets(data_pair_sets=way_dynamic_path.data_pair_sets)
    make_data_point_sets(point_set_definition, @offset_configuration.symmetric?, data_pair_sets)
  end

  # Creates data_point_sets for each set of data_pair_sets, which defaults to way_dynamic_path.data_pair_sets
  #
  def make_data_point_sets(distance_hash, symmetrical=true, data_pair_sets=way_dynamic_path.data_pair_sets)
    # I'd like to treat each set separately, so that it can define each curve from inside to outside (define all curves by the tightest point_set). But it's not easy to join the data_pair_sets cleanly and add in needed curves between the data_pairs_sets
    # Create the point_set hash for each data_pair set and merge the hash values
=begin
    data_pair_sets.map_with_index {|data_pair_set,i|
      make_data_point_sets_for_data_pair_set(distance_hash, symmetrical, Simple_Pair.to_unique_points(data_pair_set))
    }.merge_hashes {|key,a,b| a+b}
=end
    # So simply curve the whole path
    make_data_point_sets_for_data_pair_set(distance_hash, symmetrical, way_dynamic_path.all_points)
  end

  def make_data_point_sets_for_data_pair_set(distance_hash, symmetrical, path)
    # Determine which side of the path should be the primary vector based on the curve of the path. The purpose of finding the inner curve vector is to find the side of the path with the tightest angle. We base all other paths based on the tightest path. This fails to be effective if there are multiple curves for this path
    angles = path.intermediates.map_with_previous_and_subsequent_with_loop_option(path.is_loop?) {|previous_point, point, next_point|
      previous_point = previous_point || path.first
      next_point = next_point || path.last
      Geometry_Utils.radians_between(Geometry_Utils::CCW_KEY, previous_point.vector_to(point), point.vector_to(next_point))
    }
    # Determines if the last way_shape.data_pair.vector rotated toward the way_shape.data_point is counterclockwise
    rotate_offset_counterclockwise = rotate_offset_counterclockwise?
    # The offset direction is determined by the direction from the last way_shape.data_pair to the way_shape.data_point (the user's cursor)
    # Generally the user's cursor should correspond to one of the two outermost paths. It should be the outermost path that is closest to the data_pair (edge or center line) upon which to offset is based. So which orthogonal vector we use depends on the direction the path is going and the direction from the data_pair to the cursor
    orthogonal = path_to_point_data.pair.orthogonal(rotate_offset_counterclockwise)
    ccw_path = angles.inject(0) {|total, angle| total + (angle <= Math::PI ? angle : angle-Math::PI*2)} > 0
    # If both the orthogonal and path curve are ccw or cw, it means our inner curve is closer to the data_pair, so we need to go from the inside (near the data_pair) to the outside (far from the data_pair) for our other paths.
    inside_to_outside = ccw_path ^ rotate_offset_counterclockwise
    $icd=inner_curve_distance = inside_to_outside ?
        # Side of outer curve is on the far side of the data_pair, so take the negative distance, which represents the close side of the data_pair and has the tightest curve Visual:  (<-| or |->) where | is the data_pair ) is the path and <-/-> is the orthogonal
        (symmetrical ? -distance_hash.values.max : distance_hash.values.min) || 0 :
        # Side of outer curve is on the close side of the data_pair, so take the positive distance, which represents the far side from the data_pair and has the tightest curve )<-| or |->(
        (symmetrical ? distance_hash.values.max : distance_hash.values.max) || 0

    # Of all the point sets, set the vector length to the inner_curve set distance
    vector = Geom::Vector3d.new
    # Calculate the orthogonal vector from the center to the inner_curve
    $icv=inner_curve_vector = vector.length > 0 ?
        vector.clone_with_additional_length(inner_curve_distance) :
        orthogonal.clone_with_length(inner_curve_distance)

    # All points are based on offsetting the inner_curve path so that inner point sets won't maintain points that were eliminated by the inner_curve offset. Map each key of the distance hash to two values for symmetric behavior or one value for non-symmetric. The distances are relative to the inner_curve distance in the direction toward the center. Also add in the :center set which is offset inner curve distance (from the inner curve distance, going toward the center)
    $cow=from_inner_curve_distance_hash = (
    Hash[*distance_hash.map {|key, distance|
      symmetric_key_names = symmetric_key_names(key)
      symmetrical ?
          [symmetric_key_names[0],
           inner_curve_distance-distance,
           symmetric_key_names[1],
           inner_curve_distance+distance] :
          [key, inner_curve_distance-distance]
    }.shallow_flatten]).merge({:center=>inner_curve_distance})
    # If the inner curve vector is closer to the data_pair reference, we want the other paths to continue away from the data_pair.
    # If it is farther from the data_pair reference, we reverse the vector to come back toward the data_pair
    other_path_vector_direction = inside_to_outside ? inner_curve_vector : inner_curve_vector.reverse

    # Calculate the points for the outer curve point set
    $path = path
    $fee=inner_curve_side_points = offset_points_based_on_vector(inner_curve_vector, side_point_generator(path))
    # Create an Offset_Way, a generic way to handle generating the various point sets relative to the inner curve
    $gee=inner_curve_offset_way = Offset_Way.new(inner_curve_side_points.map {|side_point| side_point.point}, {})
    side_point_generator = Side_Point_Generator.new(Continuous_Ways.new(inner_curve_offset_way.class, [inner_curve_offset_way]), @offset_configuration.offset_options())
    from_inner_curve_distance_hash.map_values_to_new_hash {|key, distance|
      distance==0 ?
          inner_curve_side_points :
          create_points_based_on_vector(side_point_generator, other_path_vector_direction, distance)
    }
  end

  # The direction of the offset is normally from an edge toward the center and from the center toward the closest edge. There could be cases where the direction should always be from the edge away from the street, such as for rows of houses. This would require a new configuration option.
  # Returns true for counterclockwise and false for clockwise
  def rotate_offset_counterclockwise?()
    # If there is an offset for the last way_shape, we need to compare the last way shape offset vector to the pair vector of the path_to_point data.
    # If there is no offset then we use the vector from the way_shape's data_pair to its way_point_pair, if they differ
    # The pair vector flips relative to the user's drag direction so the two vectors together tell us which way to rotate
    unless (self.way_dynamic_path.way_shapes.length > 0)
      # If no way_shapes are defined because we have only stray points, we can't guess which way to rotate
      return true
    end
    way_shape = self.way_dynamic_path.way_shapes.last
    data_pair = way_shape.data_pair
    vector = way_shape.pair_to_point_data.vector_from_path_to_point
    # The offset pair closest to the user's cursor, and normally the same pair as the last way_shape's offset. But this pair flips direction to match the user's cursor. The way_shape does not
    pair_vector = path_to_point_data.pair.vector
    if (vector.length > 0)
      # If there is an offset compare the offset vector to the pair vector
      vector_to_offset_point = way_shape.pair_to_point_data.vector_from_path_to_point
      angle = Geometry_Utils.radians_between(
          Geometry_Utils::CCW_KEY,
          pair_vector,
          vector_to_offset_point)
    elsif (data_pair.kind_of?(Sketchup::Edge_Module))
      # For the edge case examine the vector from the edge to the way_point_pair
      # (use data_pair.data_pair in case the data_pair is a Partial_Data_Pair or some other wrapper tha needs to resolve to the actual edge)
      vector_to_way_point_pair = data_pair.data_pair.middle_point.vector_to(way_shape.way_point_pair.middle_point)
      angle = Geometry_Utils.radians_between(
          Geometry_Utils::CCW_KEY,
          pair_vector,
          vector_to_way_point_pair)
    elsif (data_pair.kind_of?(Way_Point_Pair_Behavior))
      # Arbitrary case, just pick counterclockwise
      angle = 0
    else
      raise "Unexpected data_pair of way_shape: #{data_pair.class}"
    end
    # Is the counterclockwise rotation less that PI and therefore more counterclockwise than clockwise
    angle < Math::PI
  end

end