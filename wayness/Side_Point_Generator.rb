require 'wayness/side_point_parent'
require 'wayness/way_grouping'

# Calculates the side points of continuous ways on one side of the way, the side that is counterclockwise from the # start of the first way. In other words, it expects ways that would be continuous left turns without interruption,
# until and end point way or a loop is completed. See continuous_ways.rb for the source data structure.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Side_Point_Generator

  # continuous_ways is a Continuous_Ways instance that holds consecutive Way instances that are not interrupted
  # by an intersection. Using uninterrupted ways makes side point generation simple, since each point only needs
  # to be concerned with the point on either side of it.
  # angle_acceptance is an optional argument that will cause the offset to reject points from offset consideration that create a sharper angle than the angle given. By default nothing is rejected. This fixes the side effects of unintended jags
  # curve_threshold is an optional argument that will smooth out the angle created by three offset points if the
  # angle is sharper than curve_threshold. It smooths the angle by adding extra points in place of the middle point
  # angle tolerance is useful for streetcar track and other ways that cannot have sharp angles but might be offset from
  # the sharp angles of streets
  def initialize(continuous_ways, options)
    @continuous_ways = continuous_ways
    @options = options.merge({:angle_acceptance=>0, :curve_threshold=>0, :curve_fraction=>1, :curve_length=>0}) { |key, option, default_option| option}
  end

  # Creates Side_Point instances based on the properties of the each way in the @continuous_ways
  # Normally side_points rely on the width of each way, which is variable
  # Use a transformation_lambda method to force a fixed width for the side points based on the transformation that the lambda returns. This is useful if the user is offsetting a way based on their input, for instance or if a certain way needs to be held to a fixed offset while another way is based on user input (e.g. adding a new way to existing ways and offsetting the new way).
  # The transformation_lambda_wrapper expects a pair of points as it argument, where each pair is based on the points of the ways being offset.
  def make_side_points(transformation_lambda_wrapper=nil, way_preprocessor=nil)
    transformation_lambda_maker = transformation_lambda_wrapper ?
        finalize_transformation_lambda(transformation_lambda_wrapper) :
        # The default lambda uses the way's default with to create a lambda that translates a point pair orthogonally based on that width. TODO this shouldn't be the default. No transformation should be the default
        Lambda_Wrapper.new(lambda {|way_point_pair| Geometry_Utils::orthogonal_point_translation_lambda(Way_Grouping::CCW_KEY, way_point_pair.way.width/2) }, nil, 2)
    $g5=Side_Point_Worker.new(@continuous_ways,  transformation_lambda_maker, way_preprocessor, @options).work()
  end

  # The given lambda may expect a way_point_pair and return a lambda that expects a point pair, or it may merely expect a point pair
  def finalize_transformation_lambda(transformation_lambda_wrapper)
    if (transformation_lambda_wrapper.kind_of?(Lambda_Wrapper) && transformation_lambda_wrapper.depth==2 )
      transformation_lambda_wrapper
    else
      # The way_point_pair is not considered in the transformation
      Lambda_Wrapper.new(lambda {|way_point_pair| transformation_lambda_wrapper }, nil, 2)
    end
  end
end


# The class that does the actually side_point creation
class Side_Point_Worker

  # Initializes the instance with the continuous_ways.
  # continuous_ways are way sets that form unbroken chains and can therefore offset without interfering (in most cases) with other sets of ways.
  # translation_lambda_maker is a lambda that returns another lambda. The outer lambda expects a way_behavior which will be used to configure the transformation for the underlying way--namely the default width. The inner lambda expects a simple point pair that will be the points that are offset by the Geom::Transformation referenced within it. The outer lambda returns a Transformation that is applied to both points or two Transformation that are applied to each point. Ex:
  # lambda {|way_behavior| transformation = ...; lambda {|point_pair| point_pair.map {|p| p.transform(transformation) }}
  def initialize(continuous_ways, translation_lambda_maker, way_preprocessor, options)
    @continuous_ways = continuous_ways
    @translation_lambda_maker = translation_lambda_maker
    @way_preprocessor = way_preprocessor || lambda {|way_point_pairs| way_point_pairs}
    @options = options
  end

  def work()
    # Eliminate points that make offsets malfunction, such as tiny zigzags and overlaps
    $c1=corrected_way_points = correct_bad_way_points(@continuous_ways.way_points)
    $m1=modified_way_point_pair_sets = @continuous_ways.limited_way_point_pairs_as_sets(corrected_way_points).
    # In some cases we are working with some ways that already have side points, and new ways that do not. Replace Way_Point_Pairs with Side_Point_Pairs if thus configured.
      map {|way_point_pair_set| @way_preprocessor.call(way_point_pair_set) }

    # Flatten the sets, we need not distinguish between ways anymore
    $c2=modified_way_point_pairs = modified_way_point_pair_sets.shallow_flatten

    raise "way_point_pair with identical points" if modified_way_point_pairs.any?{|pair| pair.points[0].hash_point==pair.points[1].hash_point}
    # Make the side points by iteratively eliminating any way_point_pairs that become to short to offset or have other problems
    $c3=side_points = make_side_points_until_stable(modified_way_point_pairs, @continuous_ways.makes_loop?)
    # If Side_Point_Parents were created for curves, break them down into their child points here
    $c4=@options[:curve_threshold]>0 ?
      side_points.map {|sp|
        sp.class==Side_Point_Parent ?
          sp.children_as_side_points.map{|spc| spc} :
          [sp]}.
        shallow_flatten.uniq_by_map{|p| p.hash_point} :
      side_points
  end

  # Reject way_point_pairs representing extreme angles at either side
  # This also takes care of overlapping ways
  def correct_bad_way_points(way_points)
    internal_correct_bad_way_points(way_points).uniq_consecutive
  end
  def internal_correct_bad_way_points(way_points, previous=nil)
    if (way_points.length==0)
      []
    else
      item = way_points.first
      subsequent = way_points.length > 1 ? way_points[1] : nil
      reject = previous!=nil && subsequent!=nil && (item.vector_to(previous).angle_between(item.vector_to(subsequent)) < @options[:angle_acceptance])
      (reject ? [] : [item]) + internal_correct_bad_way_points(way_points.rest, reject ? previous : item)
    end
  end


  # Given a set of data_pairs that have underlying way_point_pairs, this creates side points and eliminates invalid the data_pairs whose way_point_pairs form invalid side_points. Invalid side_points result from angles that are too tight versus the length of the pairs, forcing the pairs to offset "backwards".
  # Each time side_points are found invalid, the corresponding center data_pairs are eliminated from the set that creates the side points. This makes pairs that were not adjacent be adjacent.
  def make_side_points_until_stable(data_pairs, loop_last, end_data_pairs=[data_pairs.first, data_pairs.last])
    $ddo=data_pairs
    $mmo=side_points = create_side_points(data_pairs, loop_last, end_data_pairs)
    side_point_pairs = side_points.map_with_subsequent {|side_point1, side_point2|
      Side_Point_Pair.new(side_point1, side_point2)}
    $sso=side_point_pairs

    $mwpp=modified_way_point_pairs = trim_invalid_pairs(side_point_pairs, loop_last)
    if (modified_way_point_pairs.length == 0)
      []
    else
      if (modified_way_point_pairs.length != data_pairs.length)
        # If any way_point_pairs were trimmed start over with the trimmed list
        $digy = data_pairs
        $migy = modified_way_point_pairs
        $sppi=side_point_pairs
        modified_data_pairs = re_preprocess_trimmed_way_point_pairs(modified_way_point_pairs)
        $pigy = modified_data_pairs
        raise "data_pairs were not trimmed by preprocessing!" if modified_data_pairs.length==data_pairs.length
        make_side_points_until_stable(
            modified_data_pairs,
            loop_last,
            end_data_pairs)
      else
        # Nothing was trimmed so we're done
        side_points
      end
    end
  end

  # Take the modified_way_point_pairs and divide them back into sets by way. Run them through the way_preprocessor and flatten the results.
  def re_preprocess_trimmed_way_point_pairs(modified_way_point_pairs)
    modified_way_point_pairs.create_sets_when_change_occurs { |way_point_pair| way_point_pair.way.hash }.flat_map { |way_point_pairs|
      $zigy = way_point_pairs
      @way_preprocessor.call(way_point_pairs)
    }
  end

  # Removes point pairs whose corresponding side_pair has a reverse vector, indicating the point_pair
  # is too short for consideration in the offset.
  # With point pairs removed, the newly adjacent pairs will pretend that the intersect and create a corresponding offset point
  def trim_invalid_pairs(side_point_pairs, loop_last)
    if (side_point_pairs.length<1)
      return []
    end
    # Make sure the vectors are close to parallel, as opposing vector directions between the way_point_pair and side_point_pair indicate sides that are too short and that the offset is "inverted". When you use the standard Sketchup offset tool, it will invert offsets of edges that form too sharp an angle. We can't allow this, so we eliminate the way_point_pairs that form those angle.
    # Most of the comparisons between the side_point_pair vector and way_point_pair vector will be parallel, but differing way widths can make the sides meet nonparallel to the ways.
    side_point_pair = side_point_pairs.first
    if (side_point_pair.data_points.any? {|side_point| side_point.class == Bad_Side_Point})
      # If either point of the pair is invalid, drop this way_point_pair
      Rescape::Config.log.info "Bad_Side_Point"
      trim_invalid_pairs(side_point_pairs.rest, loop_last)
    else
      way_point_pair = side_point_pair.way_point_pair
      if (self.class.side_and_way_vectors_align?(side_point_pair) || @options[:allow_reversed_pairs])
        # use < Math::PI/2 as a conservative guess that the vectors are going in the same direction (they'll normally be parallel or close to)
        [[way_point_pair], trim_invalid_pairs(side_point_pairs.rest, loop_last)].shallow_flatten
      else
        #Rescape::Config.log.info "Trimmed way_point_pair #{way_point_pair.inspect} because vectors are way_point_pair:#{way_point_pair.vector.normalize}, side_point_pair:#{side_point_pair.vector.normalize}"
        # If the vector is reversed that means the side was too short to offset and must be eliminated from consideration
        side_point_pairs.rest.map {|spp| spp.way_point_pair}
      end
    end
  end

  # Determines whether or not the side_point_pair's point vector and the underlying way_point_pair's point vector are acceptably similar in orientation. If they are more that 90 degrees apart, it means the side_point_pair was "flipped" to accommodate a too-acute angle, and therefore the underlying way_point_pairs will need to be eliminated from consideration
  def self.side_and_way_vectors_align?(side_point_pair)
    way_point_vector = side_point_pair.way_point_pair.vector.normalize
    side_vector = side_point_pair.vector.normalize
    angle_between = way_point_vector.angle_between(side_vector)
    Math::PI/2 > angle_between
  end

  # Creates offsets finding the offset point between each pair of data_pairs. data_pairs must implement Way_Point_Pair_Behavior, such that each pair has an underlying Way_Point_Pair that will form the basis off the offset. As of now, the data_pairs are normally Way_Point_Pairs. They may also be Side_Point_Pairs for cases where some of the Ways being offset already have valid Edges but other do not yet. In this case the @transformation_lambda simply transforms the Side_Point_Pairs underlying Way_Point_Pair points to the points of the Side_Point_Pair.
  # loop_last indicates that the pairs being offset form a loop, if true
  # end_data_pairs represent the first and last data_pairs the first time the function is called, because subsequent calls may reduce the data_pairs if certain data_pairs formed invalid offset points, but the original end point references need to be remembered.
  def create_side_points(data_pairs, loop_last, end_data_pairs)
     mid_offset_points = data_pairs.map_with_subsequent_with_loop_option(loop_last) {|data_pair1, data_pair2|
      # Expose the underlying Way_Point_Pairs, which in many cases will be the same instance as the data_pairs
      # The distinction is important when the data_pairs are Side_Point_Pairs
      way_point_pair1 = data_pair1.way_point_pair
      way_point_pair2 = data_pair2.way_point_pair
      reverse_way_point_pair1 = way_point_pair1.reverse
       # Find the intersection of the closest point between the two Way_Point_Pairs. This will often be the point that each pair shares, but there are cases when too short intermediate Way_Point_Pairs are eliminated and so this point is a projection of where the two pairs meet. This returns nil in the parallel case
      origin_intersection = Geom.intersect_line_line(reverse_way_point_pair1.points, way_point_pair2.points)
      $origin_intersections.push(origin_intersection) if origin_intersection
      if (origin_intersection and origin_intersection.vector_to(reverse_way_point_pair1.points.last).normalize != reverse_way_point_pair1.vector.normalize)
        # Detect diverging lines that intersect on the side opposite of the side we expect according to the way_point_pair vector directions. This is only possible when an intermediate way_point_pair was previously eliminated from consideration, leaving two adjacent pairs that not only don't meet at the expected end but whose angle is such that they diverge at that end.
        Rescape::Config.log.info('Origin at wrong end!')
        Bad_Side_Point.new(way_point_pair2.first, way_point_pair1.last)
      else
        # If the two vectors are reverse of one another, we expect an exception
        begin
          offset_point = Geometry_Utils::get_offset_intersection(
            origin_intersection ?
              origin_intersection :
              Geom::Point3d.linear_combination(0.50, way_point_pair1.last.point, 0.50, way_point_pair2.first.point), # find point between parallels
            way_point_pair1,
            way_point_pair2,
            # Create transformation lambdas based on data_pair properties
            @translation_lambda_maker.call(data_pair1),
            @translation_lambda_maker.call(data_pair2)
          )
          $offset_intersections.push(offset_point)
        # Associate the side point with the first point of way_point_pair2 and also note last point of way_point_pair1
        # The second way_point associated with the side point is way_point_pair1.last unless the previous vector combination was invalid. In that case we take the first point of the previous because the second point of the previous and way_point_pair1.first represent an invalid point.
        Side_Point.new(offset_point, way_point_pair2.first, way_point_pair1.last)
        rescue Invalid_Offset_Angle => e
          # Handle the exception by instantiating a special class that will be identified later
          Rescape::Config.log.info e.message
          Bad_Side_Point.new(way_point_pair2.first, way_point_pair1.last)
        end
      end
    }
    if loop_last
       side_points=([mid_offset_points.last].compact+mid_offset_points).uniq_consecutive_by_map {|sp| sp.hash}
    else
      # Extend the start and end points according to whether or not the original start and end points have been eliminated. If they have not been eliminated they will match and we simply transform the start and end points like all the other points. If they do not match then we instead record the original end point as a side point and ignore the current start and end points. The reason for the latter case is that the offset must consider the original start and end points of the curve even if they are unable to form a valid offset line themselves. If we didn't do this, than the current start and end line segments might extend beyond the end points (TODO explain with a drawing)
      $endos = end_data_pairs
      $end_points = end_points = [0,-1].map {|index|
        resolve_end_point(end_data_pairs[index], data_pairs, index)
      }
      # Combine the end points and mid offset points.
      side_points=[[end_points[0]], mid_offset_points, [end_points[1]]].shallow_flatten.uniq_consecutive_by_map {|sp| sp.hash}
    end

    # If sharp angles are not tolerated, correct them here.
    if (side_points.any?{|side_point| side_point.class==Bad_Side_Point} || @options[:curve_threshold] == 0)
      # Don't bother if we have any invalid side points because these results will be thrown away and recalculated
      side_points
    else
      curved_side_points = side_points.map_with_previous_and_subsequent {|previous_side_point, current_side_point, subsequent_side_point|
        previous_side_point != nil && subsequent_side_point != nil ?
          Side_Point_Parent.new(current_side_point,
                                make_corrections(current_side_point,
                                                 previous_side_point,
                                                 subsequent_side_point),
                                [previous_side_point, subsequent_side_point]) :
          current_side_point
      }

      # If we have adjacent Side_Point_Parents containing curved points, we must recalculate the them if their curves overlap
      curved_side_points.map_with_previous_and_subsequent {|previous_side_point, current_side_point, subsequent_side_point|
        previous_or_subsequent_also_curved = [previous_side_point, subsequent_side_point].map {|other_side_point|
          other_side_point && [other_side_point, current_side_point].all? {|side_point|
            side_point.kind_of?(Side_Point_Parent) and side_point.is_curved? }
        }
        previous_or_subsequent_also_curved.any? ?
          Side_Point_Parent.new(current_side_point,
                              make_corrections(current_side_point,
                                               previous_side_point,
                                               subsequent_side_point,
                                               previous_or_subsequent_also_curved),
                                  [previous_side_point, subsequent_side_point]) :
          current_side_point
      }
    end
  end

  # Compares the generated original to the way_point_pairs left after offset to see if they match. If they match we can safely offset the way_point_pair according to the transformation_lambda_maker. If not it means that the original end_way_point_pair was eliminated. This is okay, but we need to make sure that the new end point is constrained to where the original end point was. Otherwise it's possible to have some crazy offsets.
  def resolve_end_point(original_end_data_pair, data_pairs, pair_and_point_index)
    if (original_end_data_pair != data_pairs[pair_and_point_index])
      $yytop = original_end_data_pair
      $zztop = data_pairs[pair_and_point_index]
    end
    data_pair = data_pairs[pair_and_point_index]
    #Rescape::Config.log.info("Recovering original end position") if original_end_data_pair!=data_pair
    $wyclef= original_end_data_pair== data_pair ?
      # They match, so perform the offset, which means we transform the given pair and take one that's the end point
      Side_Point.new(Geometry_Utils::transform_pair(
                        data_pair.way_point_pair.points,
                        @translation_lambda_maker.call(data_pair))[pair_and_point_index],
                      data_pair.way_point_pair[pair_and_point_index].way_point) :
      Side_Point.new(Geometry_Utils::transform_pair(
                        original_end_data_pair.way_point_pair.points,# maybe this should be the original end_data_pair points?
                        @translation_lambda_maker.call(original_end_data_pair))[pair_and_point_index], # then this index would have to flip
                     data_pair.way_point_pair[pair_and_point_index].way_point)
      #TODO I know there's a case where the side_point has to be constrained to the way_point, but I can't remember when
      #[Side_Point.new(original_end_data_pair.way_point_pair[pair_and_point_index].point, original_end_data_pair.way_point_pair[pair_and_point_index].way_point)]
  end

  # Corrects sharp angles depending on the configured curve options
  # Grade determines how many points to use for the curve. See curve_angle
  def make_corrections(side_point, previous_side_point, subsequent_side_point, previous_and_subsequent_curved=[false,false], grade=2)
    (v1, v2) = [[previous_side_point, side_point], [side_point, subsequent_side_point]].dual_map(previous_and_subsequent_curved) {|side_points, other_curved|
      vector = side_points[0].vector_to(side_points[1])
      vector.length > 0 ?
        vector.normalize.clone_with_length(curve_length(vector, other_curved)) :
        vector
    }
    ((v1.reverse.angle_between(v2) >= @options[:curve_threshold]) ? [side_point.point] : curve_angle(side_point.point, v1.reverse, v2, grade))
  end

  # Uses the curve_length or curve_fraction to determine how much of the angle to curve
  # If the curve_length exceeds the vector length, the length is set to that of the vector
  # curved_at_both_ends indicates that both sides of this vector need curving, so don't overlap curves
  def curve_length(vector, curved_at_other_end)
    @options[:curve_length] > 0 ? [@options[:curve_length], curved_at_other_end ? vector.length/2 : vector.length].min() : vector.length*@options[:curve_fraction]
  end

  # Get an arc of points tangent to the two vectors from the origin
  # grade specifies how smooth the curve is grade=1 yields 3 points, grade=2 yields 5, grade=3 yields 9, etc
  def curve_angle(origin, vector1, vector2, grade)
    if (grade==0)
      return []
    end
    # Transform the origin to the vector lengths
    point1 = origin.transform(vector1)
    point2 = origin.transform(vector2)
    # Find the point in between
    mid_point = Geom::Point3d.linear_combination(0.5, point1, 0.5, point2)
    # Find the point between the mid_point and origin
    center_line_mid_point = Geom::Point3d.linear_combination(0.5, mid_point, 0.5, origin)
    results = [point1,point2].map {|point|
      #  For each find the point between the point and center_line_mid_point
      point_to_vertex_mid_point = Geom::Point3d.linear_combination(0.5, point, 0.5, origin)
      # Return the point and center_line_mid_point as outer points and recursively call curve_angle
      # to generate more curve if the grade warrants it
      [point] +
        curve_angle(point_to_vertex_mid_point,
                    point_to_vertex_mid_point.vector_to(point),
                    point_to_vertex_mid_point.vector_to(center_line_mid_point), grade-1) +
        [center_line_mid_point]
    }
    results[0] + results[1].reverse
  end

  def hash
    [@continuous_ways, @options].map {|item| item.hash}.hash
  end

  def ==(other)
    self.hash == other.hash
  end
end

class Bad_Side_Point < Side_Point
  def initialize(way_point, other_way_point)
    super(Geom::Point3d.new, way_point, other_way_point)
  end
  def inspect
    "%s" % self.class
  end
end
