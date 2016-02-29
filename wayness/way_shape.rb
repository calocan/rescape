require 'wayness/way_point_pair_behavior'
require 'wayness/side_point_pair'
require 'utils/edge'
require 'utils/pair_to_point_module'
require 'utils/basic_utils'

# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

# Defines a shape based on way data. Way_Shapes reference a way_point_pair or part of one and specify a data_pair that may be the same way_point pair or an edge of the way_point_pair, as well as an input_point that represents the offset from that data_pair. A Way_Shape is used 1) to represent an explicitly chosen point along a way when the user is drawing a path along the way (e.g. a new tram line.) It is also used to 2) represent the intersection of a new path drawn by the user that intersects with an existing way, in which case the way_point_pair and data_pair are normally equal and the input_point represents where the user clicked to make the intersection.
 # Way_Shape implements the Pair_To_Point to represent the relationship between the data_pair and the input_point where the user clicked. This interface can be used to merge a user's path into an existing way_grouping, based on the point and way_point_pair where the user's path intersecting existing ways.

class Way_Shape
  include Way_Point_Pair_Behavior
  include Pair_To_Point_Module
  include Basic_Utils

  attr_reader :way_grouping, :way_point_pair, :pair_to_point_data, :offset_configuration, :options
  POINT_MATCHING_PIXEL_THRESHOLD = 10

  # Defines a way_shape based one way_point_pairs and point sets about the way_point_pairs.
  # pair_to_point_data defines either an edge or the same_way_point_pair for its pair and the user's input point for its point. In other words pair_to_point describe to which pair the way_shape has been made relative and how much it is offset from that pair. The point of pair_to_point_data may be static or dynamic, depending on if the final position of the way_shape has been decided or not.
  # offset_configuration adds configuration properties to the way_shape for the way_shape related to the offset tool being used
  # options store options specific to this way_shape selected by the user, such as how it should connect the previous_way_shape. The options are:
  # :smooth_connect when true, makes the connecting path from the previous_way shape ignore the center or edge pairs and go straight to this way_shape. The default behavior of false means the path follows the center or edge_pair angles, leading to a less smooth but more parallel path
  # :force_path_on_way when true, ways shapes are forced to align their path with the previous way_shape to the way. If false, the path to the previous_way shape is the shortest path as the crow flies, or a path with intermediate points clicked by the user since the last way_shape.
  # :keyboard_aligned when true indicates that the way_shape was not aligned by the cursor but by keyboard input--either the arrow keys or input into the VCB.
  def initialize(way_grouping, way_point_pair, pair_to_point_data, offset_configuration, options={})
    @way_grouping = way_grouping
    @way_point_pair = way_point_pair
    @pair_to_point_data = pair_to_point_data
    @offset_configuration = offset_configuration
    @options = options
  end

  # Clones a Way_Shape with a new offset distance, which means pair_to_point_data will have a different point position. This only makes sense if the point is already static.
  # The offset_length is a float or Length instance indicating the distance to offset the point from the pair_to_point_data.point_on_path in the direction of the existing pair_to_point_data.point
  def clone_with_new_offset_position(offset_length_or_vector)
    pair_to_point_data = @pair_to_point_data.clone_with_new_offset_distance_based_on_length_or_vector(offset_length_or_vector)
    options = @options.merge({:keyboard_input=>true}) {|key, left, right| right}
    self.class.new(@way_grouping, @way_point_pair, pair_to_point_data, @offset_configuration, options)
  end

  def data_pair
    @pair_to_point_data.pair
  end

  # This is a Complex_Point, meaning it can be dynamic (an InputPoint, Input_Point_Collector, etc.) or static, a simple Geom::Point3d. It is dynamic in the case that the Way_Shape needs to move according to user input, and static when its position has been finalized
  def input_point
    @pair_to_point_data.point
  end

  # Conforms to the Pair_To_Point_Module interface
  def point
    @pair_to_point_data.point
  end

  def point_on_path
    @pair_to_point_data.point_on_path
  end

  # Determines whether or not this Way_Shape represents an edge
  def is_edge?
    @pair_to_point_data.pair.kind_of?(Sketchup::Edge_Module)
  end

  # Clone the Way_Shape, converting the dynamic input_point to its static equivalent
  def finalize()
    $grape = self
    self.class.new(@way_grouping, @way_point_pair, @pair_to_point_data.clone_with_frozen_point(), @offset_configuration, @options)
  end

  # True if the input_point is not dynamic but a static point
  def finalized?
    @pair_to_point_data.frozen_point?
  end

  # Tests if another way_shape is essentiall the same as this one, in that it has the same way_point_pair, same pair of it's pair_to_point_data, and the point is within a configured distance'
  def matches_within_threshold?(way_shape)
    self.is_match?(way_shape) &&
    self.pair_to_point_data.point.matches_within_threshold?(
        way_shape.pair_to_point_data.point,
        self.class.pixels_to_length(POINT_MATCHING_PIXEL_THRESHOLD))
  end

  # Returns true if the Way_Shapes share a common way_point_pair or have reverse way_point_pairs, and the pair of pair_to_input_point_data match
  # Way_Shape is a dynamic instance in that it's input_point can change, so input_point position is ignored here
  def is_match?(way_shape)
    [self.way_point_pair,self.way_point_pair.reverse].member?(way_shape.way_point_pair) and
        self.pair_to_point_data.pair.points_match?(way_shape.pair_to_point_data.pair)
  end

  # Like is_match, but only cares that the way_point_pair of the way_shapes match, where the reverse way_point_pair is also considered a match
  def is_way_point_pair_match?(way_shape)
    [self.way_point_pair,self.way_point_pair.reverse].member?(way_shape.way_point_pair)
  end

  # Reverse each way_point and the position in the pair
  def reverse()
    self.class.new(@way_grouping, @way_point_pair.reverse(), @pair_to_point_data.reverse, @offset_configuration, @options)
  end

  # Implementation of the Way_Point_Pair_Behavior interface
  def way_point1
    @way_point_pair.way_point1
  end

  def way_point2
    @way_point_pair.way_point2
  end

  def way
    @way_point_pair.way
  end

  # Get the points of the data_pair offset orthogonally to the input_point plus the @offset_configuration.offset_distance
  # The latter makes the way_shape not center around the input_point but instead makes it abut the input_point. On what side of the input_point the shape lies depends on whether the offset is based on an edge or way_point_pair
  # Optionally pass in points if only part of the data_pair should be offset
  def get_offset_points(points=data_pair.points)
    vector = @pair_to_point_data.vector_from_path_to_point()
    final_vector = (vector.length > 0) ?
      vector.clone_with_additional_length(@offset_configuration.offset_distance) :
      @pair_to_point_data.pair.orthogonal(rotate_offset_counterclockwise?(@pair_to_point_data)).clone_with_length(@offset_configuration.offset_distance)
    points.map {|point| point.transform(final_vector)}
  end

  # If the offset made by the cursor is 0 length, we still need to know the direction in order to apply the default offset
  # The direction of the offset is normally from an edge toward the center and from the center toward the closest edge. There could be cases where the direction should always be from the edge away from the street, such as for rows of houses. This would require a new configuration option.
  # Returns true for counterclockwise and false for clockwise
  def rotate_offset_counterclockwise?(pair_to_point_data)
    data_pair = pair_to_point_data.pair
    data_pair_vector = pair_to_point_data.pair.vector
    # The offset pair closest to the user's cursor, and normally the same pair as the last way_shape's offset. But this pair flips direction to match the user's cursor. The way_shape does not
    if (data_pair.kind_of?(Sketchup::Edge_Module))
     # For the edge case examine the vector from the edge to the way_point_pair
      vector_to_way_point_pair = data_pair.middle_point.vector_to(@way_point_pair.middle_point)
      angle = Geometry_Utils.radians_between(
          Geometry_Utils::CCW_KEY,
          data_pair_vector,
          vector_to_way_point_pair)
      angle < Math::PI
    elsif (data_pair.kind_of?(Way_Point_Pair_Behavior))
      # Arbitrary case, just pick counterclockwise
      true
    else
      raise "Unexpected data_pair of way_shape: #{data_pair.class}"
    end
  end

  # Transforms the way_shape's data_pair points to the input_point to create a side_point_pair
  # Use optional partial_points to get a partial side_point_pair rather than a full one
  def as_side_point_pair(partial_points=data_pair.points)
    offset_points=get_offset_points(partial_points)
    Side_Point_Pair.from_way_point_pair_with_points(@way_point_pair, offset_points)
  end

  # Returns the point on the path and the input point as points
  def path_to_point_points
    @pair_to_point_data.path_to_point_points
  end

  # The distance that the way_shape is offset from it's underlying data_pair, meaning the distance from @pair_to_point_data.point_on_path to @pair_to_point_data.point
  def offset_length
    @pair_to_point_data.vector_from_path_to_point.length
  end

  # Determines if the given input_point resolves to a way_shape with the same way_point_pair as the given way_shape. This is used to detect whether the input_point has moved to a new way_shape after having been on the given one.
  def matches_closest_way_point_pair?(input_point)
    # See if its closest to the same way_point_pair
    self.way_grouping==Entity_Map.way_grouping_of_input_point(active_travel_network, input_point) &&
    self.way_grouping.closest_way_point_pair_to_point(input_point)==self.way_point_pair
  end

  # Way_Shapes are unique by their way_point_pair, and pair_to_point_data
  def hash
    [self.way_point_pair, self.pair_to_point_data].map {|field| field.hash}.hash
  end

  def ==(other)
    self.hash == other.hash
  end

  def inspect
    "#{self.class} based on data pair #{self.data_pair.inspect} and offset #{path_to_point_points[0].distance(path_to_point_points[1])}  #{self.pair_to_point_data.point.kind_of?(Complex_Point) ? 'dynamically':'statically'} " + (self.data_pair.kind_of?(Way_Point_Pair_Behavior) ? '' : " with way_point_pair #{self.way_point_pair.inspect}")
  end
end