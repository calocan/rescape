require 'utils/pair_to_point_data'
require 'utils/path_to_point_module'

# Represents the relationship between a point and a path, including the closest point along the path upon which the point projects and also the pair of points about that projection
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Path_To_Point_Data
  include Path_To_Point_Module
  attr_reader :path, :point, :data_pairs, :last_input_point_position
  # path is a set of points
  # data_point is the point that is related to the path. It may have a dynamic position, being an InputPoint or static, being a Point
  # data_pairs are an optional set of Data_Pair instances representing the path
  def initialize(path, data_point, data_pairs=Geom::Point3d.to_simple_pairs(path))
    @path = path
    @point = data_point
    @data_pairs = data_pairs
    validate_instance_variables()
    @pair_to_point_data = nil
    @last_input_point_position = nil
  end

  def self.from_pairs(data_pairs, point)
    self.new(Simple_Pair.to_unique_points(data_pairs), point, data_pairs)
  end

  # Returns one or two Path_To_Point_Data instances representing the relationship of each point of the intersecting_pair with the given data_pair that the intersecting_pair intersects. Raises an error if more than one data_pairs intersects. Each Path_To_Point_Data instances contain the intersection at @path_on_point and one of the two intersecting_pair points for @point. If intersecting_pair lies along data_pair, the intersections will
  def self.path_to_point_data_at_pair_intersection(data_pairs, intersecting_pair)
    path = Simple_Pair.to_unique_points(data_pairs)
    data_pairs.map {|data_pair|
      data_pair.intersection(intersecting_pair).if_not_nil {|intersection|
        intersecting_pair.map {|intersecting_pair_point| self.new(path, intersecting_pair_point, data_pairs)}
    }}.compact.none_or_one("Expected none or one intersecting data_pair for data_pairs: #{data_pairs.inspect} and intersecting pair: #{intersecting_pair.inspect}")
  end

  # Clones with the point set to point_on_path. The point is made non-dynamic.
  def clone_with_affixed_point
    self.class.new(path, point_on_path, data_pairs)
  end

  # Clones with the dynamic input_point changed into a static point at its current position
  def clone_with_frozen_point
    self.class.new(path, point.position, point_on_path)
  end

  # Clones and changes the position of the @point to a different offset from the @point_on_path
  # This may change the underlying type of @point, since Sketchup::InputPoint cannot simply accept a new point
  def clone_with_new_offset_distance(distance)
    vector = @point_on_path.vector_to(@point.position).if_cond(lambda {|v| v.length==0}) {|v| @pair.orthogonal}.clone_with_length(distance)
    new_position = @point_on_path.transform(vector)
    self.class.new(@path, @point.clone_with_new_point(new_position), @data_pairs)
  end

  # Calculates the pair_to_path data dynamically in case the point is a dynamic InputPoint
  # The result is saved and only recalculated if the @point is dynamic and the value changes
  # No pair_to_point_data is created if there are no data_pairs
  def pair_to_point_data
    unless @last_input_point_position and @last_input_point_position.matches?(@point.position)
      @pair_to_point_data = Pair_To_Point_Data.closest_pair_to_point_data(@data_pairs, @point)
      @last_input_point_position = @point.position
    end
    @pair_to_point_data.or_if_nil {raise "The point does not project to a pair of the path. point. #{self.inspect}"}
  end

  # The projection of the point on the path defined by the two points of pair
  def point_on_path
    pair_to_point_data().point_on_path
  end

  def distance
    pair_to_point_data().distance
  end

  # The data_pair of two points of the path that the point associates to.
  def pair
    pair_to_point_data().pair
  end

  def reverse
    self.class.new(@path.reverse, @point)
  end

  def pairs_to_point_data()
    $zog = @data_pairs.map {|pair|
      # Find the closest pair for which the point projects onto the pair
      Pair_To_Point_Data.pair_to_point_data(pair, @point)
    }.compact.sort_by {|x| x.distance}
  end
end


