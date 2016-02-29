class Geometry_Utils

  CW_KEY = :clockwise
  CCW_KEY = :counterclockwise
  ROTATE_LOOKUP = {:counterclockwise=> Math::PI/2, :clockwise=> -Math::PI/2}
  REVERSE_ROTATE = { CW_KEY => CCW_KEY, CCW_KEY => CW_KEY }
  INCH = 1
  FEET = 12
  MILLIMETER = 0.0393700787
  METER = MILLIMETER*1000

  # Returns the clockwise or counterclockwise radians between, where the min is 0 and the max is 2PI
  def self.radians_between(direction, v1, v2)
      sign = direction == :counterclockwise ? 1 : -1
      (sign*Math::atan2(v2.y,v2.x) - sign*Math::atan2(v1.y,v1.x)) % (2*Math::PI)
  end


  # Make two line segments extending from a common origin that will be translated and then intersected.
  # The origin intersection represents the points where the origin of the two line segments meet or would meet if they were extended to do so. The main_transformation_lambda and adjacent_transformation_lambda transform the pairs formed by the main_pair (origin_intersection and origin_intersection transformed by the  main_vector) and the adjacent_pair (origin_intersection and origin_intersection transformed by the adjacent_vector), respectively, to two new point pairs. The lines of these "offset" point pairs are then intersected to determine the offset intersection point.
  def self.get_offset_intersection(origin_intersection, main_data_pair, adjacent_data_pair, main_transformation_lambda, adjacent_transformation_lambda)
    main_vector = main_data_pair.vector
    adjacent_vector = adjacent_data_pair.vector
    # The main_pair must use the reverse of the main_vector since the origin_intersection is the last point of the data_pair upon which the main_pair is based. We then reverse the whole thing som main_pair points in the expected direction
    main_pair = [origin_intersection, origin_intersection.transform(main_vector.reverse)].reverse
    adjacent_pair = [origin_intersection, origin_intersection.transform(adjacent_vector)]
    # Transform by the given lambdas and take the intersection of the lines, or if they are parallel translate the origin_intersection
    # by according to the main_transformation
    main_pair_transformed = transform_pair(main_pair, main_transformation_lambda)
    adjacent_pair_transformed = transform_pair(adjacent_pair, adjacent_transformation_lambda)
    intersect = Geom.intersect_line_line(main_pair_transformed, adjacent_pair_transformed)
    modified_intersect = nil
    unless (intersect)
      # If vectors in parallel but opposite directions, no valid offset. This is a rather extreme corner case where a small connecting pair is eliminated and the two adjacent pairs are left going in opposite directions. Picture a U where the connector at the bottom is eliminated and leaves the two stems with reverse vectors.
      if (main_vector.reverse.normalize==adjacent_vector.normalize)
        raise Invalid_Offset_Angle, "Vectors are reverse of one another"
      end
      # The much more common case is that vectors are in same direction, which is no problem. We could average the transformations here if it matters
      # Our origin_intersection already accounts for this
      modified_intersect = transform_point(origin_intersection, main_pair, main_transformation_lambda)
    end
    intersect || modified_intersect
  end

  # Given a pair_to_transform, original_pair, and a transformation_lambda, this passes the pair to the transformation_lambda to get one or two Geom::Transformation instances which is then used to actually transform the pair_to_transform.
  # The lambda can return a single transformation (or single transformation as a one-element array) to apply to both points or an array of two transformations to apply to each point respectively.
  def self.transform_pair(pair_to_transform, transformation_lambda)
    transformations= transformation_lambda.call(pair_to_transform)
    transformations.kind_of?(Array) && transformations.length == 2 ?
      pair_to_transform.dual_map(transformations) {|p, transformation| p.transform(transformation)} :
      pair_to_transform.map {|p| p.transform(transformations.kind_of?(Array) ? transformations.only : transformations)}
  end

  # Transform just one point using the transformation_lambda, which may return two transformations
  # We assume that the transformations are the same result or the results don't matter
  def self.transform_point(point, pair, transformation_lambda)
    transformation = transformation_lambda.call(pair)
    transformation.kind_of?(Array) ?
        point.transform(transformation[0]) :
        point.transform(transformation)
  end

  # Create an orthogonal translation lambda based on two vectors along a plane
  # The orthogonal translation direction is based on the whether the clockwise or counterclockwise
  # angle between the two vectors is smaller. points_vector is the vector of the point pair
  # to offset and offset_vector the offset direction. offset_vector may be length 0 to indicate no offset
  # The distance indicates the distance of the offset
  # predicate_lambda is an optional lambda that will be called on each point_pair before translating the pair. For pairs that return true, the normal translation will occur. For false pairs, the identity translation will occur.
  # The also optional nonmatching_transformation_lambda transforms pairs that don't pass predicate_lambda to given transformation instead of the identity translation
  def self.orthogonal_point_translation_lambda_from_vectors(offset_vector, points_vector, distance, predicate_lambda=nil, nonmatching_transformation_lambda=nil)
      rotate = (offset_vector.length==0 or self.radians_between(CW_KEY, offset_vector, points_vector) < Math::PI) ? CCW_KEY : CW_KEY
      self.orthogonal_point_translation_lambda(rotate, distance, predicate_lambda, nonmatching_transformation_lambda)
  end

  # Create an orthogonal translation lambda that takes a pair of points and translates them orthogonally
  # along the xy plane
  # rotate is either CCW_KEY or CW_KEY, rotating either direction based on the point_pair's vector
  # distance is how far to translate along the orthogonal vector. distance may be 0 to indicate no translation
  # The optional predicate_lambda defaults the transformation to the identity transformation for pairs that return false when the predicate is called with the pair as an argument.
  # The also optional nonmatching_transformation_lambda transforms pairs that don't pass predicate_lambda to given transformation.
  def self.orthogonal_point_translation_lambda(rotate, distance, predicate_lambda=nil, nonmatching_transformation_lambda=nil)
    default_transformation = Geom::Transformation.new
    lambda {|point_pair|
      if (predicate_lambda and !predicate_lambda.call(point_pair))
        nonmatching_transformation_lambda ?
          nonmatching_transformation_lambda.call(point_pair) :
          default_transformation
      else
        self.orthogonal_translation(point_pair, rotate, distance)
      end
    }
  end

  # Creates a Geom::Transformation that translates orthogonal to the given point pair with a rotation of either Geometry_Utils::CCW_KEY or CW_KEY for counterclockwise or clockwise. The orthogonal distance to translate is given by distance.
  def self.orthogonal_translation(point_pair, rotate, distance)
    tr = Geom::Transformation.rotation point_pair[0], [0, 0, 1], ROTATE_LOOKUP[rotate]
    orthogonal_transformation = point_pair[0].vector_to(point_pair[1]).transform(tr)
    raise "point_pair contains identical points" if orthogonal_transformation.length==0
    orthogonal_transformation.length = distance
    Geom::Transformation.translation orthogonal_transformation
  end

  # Finds the closest vector by the given direct in the given special vector data
  def self.find_closest_vector_data (direction, v, intersection_data_list)
    intersection_data_list.sort_by{|linked_way| self.find_angle_between(direction, v, linked_way.vector) }[0]
  end

  def self.find_angle_between(direction, v1, v2)
    Geometry_Utils::radians_between(direction, v1, v2)
  end
end