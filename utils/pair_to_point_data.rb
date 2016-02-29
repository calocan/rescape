require 'utils/path_to_point_module'
require 'utils/pair_to_point_module'
require 'utils/path_to_point_data'
require 'utils/dynamic_pair'
require 'utils/data_pair'
# Represents the relationship between a Data_Pair and a point. This is the default implementation of the Pair_To_Point_Module, and it also implements the Path_To_Point_Module by representing itself as of path of two points.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Pair_To_Point_Data
  include Path_To_Point_Module
  include Pair_To_Point_Module
  include Dynamic_Pair

  attr_reader :pair, :point, :distance
  def initialize(pair, point, point_on_path)
    @pair = pair
    @point = point
    @point_on_path = point_on_path
    @distance = distance
    validate_instance_variables()
    @last_position = nil
  end

  # The two points of the path
  def path
    pair.points
  end

  # A synonym of path that conforms with the Dyanmic_Pair interface
  def points
    path
  end

  def distance
    point.position.distance(point_on_path)
  end

  # Returns the single pair in a list to match the Path_To_Point_Module interface
  def data_pairs
    [pair]
  end

  # Returns two partial_data_pairs formed by splitting the pair at the point of point_on_path. The first pair is always the first point of pair and point_on_path, the second always the point_on_path and last point of pair.
  # Returns a single partial_data_pair in a list if point_on_path is one of the points of pair
  def partial_data_pairs
    pair.divide_into_partials_at_points([point_on_path])
  end

  # Optionally dynamic if @point is dynamic
  def point_on_path
    unless (@last_position and @last_position.matches?(@point.position))
      @last_position = @point.position
      @point_on_path = pair.project_point_to_pair(@point)
    end
    @point_on_path
  end

  # Creates a the Pair_To_Point_Data for the closest given pair to the point
  # This ignores the z axis
  def self.closest_pair_to_point_data(pairs, point)
    good_pairs = pairs.reject {|pair| pair.points[0].matches?(pair.points[1])} # reject pairs of singular point
    raise("In closest_pair_to_point_data. Pairs with identical points") if (good_pairs.length != pairs.length)
    sorted_pairs_to_point_data(good_pairs, point).or_if_empty {
        # If no point projected to a point on the pair, use the mean distance to each pair of points
      good_pairs.map{|pair| Pair_To_Point_Data.for_non_projectable_point(pair, point)}.sort_by{|x| x.distance}
    }.first
  end

  # Returns two Pair_To_Point_Data instances representing the relationship of each point of the intersecting_pair with the given data_pair that the intersecting_pair intersects. Raises an error if more than one data_pairs intersects. The Pair_To_Point_Data instances contain the data_pair (pair), intersection_point (point_on_path), and one point of the intersecting_pair (point)
  def self.pair_to_point_data_at_pair_intersection(data_pairs, intersecting_pair)
    data_pairs.map {|data_pair| data_pair.intersection(intersecting_pair).if_not_nil {|intersection|
        intersecting_pair.map {|intersecting_pair_point| self.new(data_pair, intersecting_pair_point, intersection)}
    }}.compact.none_or_one("Expected none or one intersecting data_pair for data_pairs: #{data_pairs.inspect} and intersecting pair: #{intersecting_pair.inspect}")
  end

  # Finds and sorts by distance the given pairs onto which the point orthogonally projects
  def reverse
    self.class.new(@pair.reverse, @point, @point_on_path)
  end

  # Clones with the point set to point_on_path. The point is made non-dynamic.
  def clone_with_affixed_point
    # We clone the point and move it to maintain the class of the point.
    self.class.new(@pair, point.freeze().clone_with_new_point(point_on_path), point_on_path)
  end

  # Clones with the dynamic input_point changed into a static version of the point at its current position
  def clone_with_frozen_point
    self.class.new(@pair, point.freeze(), point_on_path)
  end

  # Calls clone_with_new_offset_distance or clone_with_new_offset_distance_based_on_vector
  def clone_with_new_offset_distance_based_on_length_or_vector(distance_or_vector)
    distance_or_vector.kind_of?(Geom::Vector3d) ?
        self.clone_with_new_offset_distance_based_on_vector(distance_or_vector) :
        self.clone_with_new_offset_distance(distance_or_vector)
  end

  # Clones and changes the position of the @point to a different offset from the @point_on_path
  # This may change the underlying type of @point by calling Data_Point.clone_with_length, since some Data_Point implementors like Sketchup::InputPoint cannot simply accept a new point
  def clone_with_new_offset_distance(distance)
    vector = @point_on_path.vector_to(@point.position).
      if_cond(lambda {|v| v.length==0}) {|v| @pair.orthogonal}.
      clone_with_length(distance)
    new_position = @point_on_path.transform(vector)
    self.class.new(@pair, @point.clone_with_new_point(new_position), @point_on_path)
  end

  # Clones and changes the position of the @point to a different offset from the @point_on_path based on the given vector. The vector is analyzed for the positive or negative aspect of EITHER its x and y to determine how to offset the point. It compares these aspects to the existing offset. For instance, if the vector's x is nonzero and the offset direction is more x oriented than y, it will use the vector's x to set the offset relative to the current offset. Likewise if the vector's y is nonzero and teh offset direction is more y oriented than x, it will use the vector's y to set the offset relative to the current offset. Thus only x or y can have an effect on the offset, and it's possible that there is no offset change is the relevant vector coordinate is 0.
  # Also, the sign of the x or y component of the vector that is chosen will be flipped if the existing offset vector's corresponding direction is negative. For instance, if the existing offset vector is [0,-1,0] and the given vector is [0,12,0], the new offset vector will be [0,-13,0] rather than [0,11,0]. This is needed to preserve the geographic notion of up, down, left, right upon on which the given vector is based.
  # This may change the underlying type of @point by calling Data_Point.clone_with_length, since some Data_Point implementors like Sketchup::InputPoint cannot simply accept a new point
  def clone_with_new_offset_distance_based_on_vector(vector)
    # Get the vector from point_on_path to point
    vector_from_path_to_point = vector_from_path_to_point()
    # Add the vector.x or vector.y to the existing offset length
    existing_vector_length = vector_from_path_to_point.length
    vector_length = (vector_from_path_to_point.x.abs > vector_from_path_to_point.y.abs ?
              vector.x * (vector_from_path_to_point.x > 0 ? 1 : -1) :
              vector.y * (vector_from_path_to_point.y > 0 ? 1 : -1))

    offset_distance = existing_vector_length + vector_length
    # Clone with the new offset_length
    clone_with_new_offset_distance(offset_distance)
  end

  # Indicates whether or not the instance's point is frozen, meaning that its underlying position cannot change
  def frozen_point?
    @point.frozen?
  end

  def self.sorted_pairs_to_point_data(pairs, point)
    pairs.map {|pair|
      # Find the closest pair for which the point projects onto the pair
      pair_to_point_data(pair, point)
    }.compact.sort_by {|x| x.distance}
  end

  # Gets data about the orthogonal projection of a point on a pair, or returns nil if the point doesn't project onto the pair
  def self.pair_to_point_data(pair, point)
    point_on_path = pair.project_point_to_pair(point)
    pair.point_between?(point_on_path) ? self.new(pair, point, point_on_path) : nil
  end

  # Creates a Pair_To_Point_Data instance for the case where a point doesn't project orthogonally onto the pair. The point_on_path create in this case is not on the pair but parallel to it.
  def self.for_non_projectable_point(pair, point)
    point_parallel_to_line = pair.project_point_to_pair(point)
    self.new(pair, point, point_parallel_to_line)
  end

end