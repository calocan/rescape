require 'utils/Geometry_Utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Path_To_Point_Module

  def point_on_path
    raise "Mixer must implement"
  end

  def path
    raise "Mixer must implement"
  end

  def point
    raise "Mixer must implement"
  end

  def distance
    raise "Mixer must implement"
  end

  def pair
    raise "Mixer must implement"
  end

  def data_pairs
    raise "Mixer must implement"
  end

  # Returns a new instance that no longer has an offset point, but instead the point matches point_on_path
  def clone_with_affixed_point
    raise "Mixer must implement"
  end

  # Returns a new instance that no longer has an offset point, but instead the point matches point_on_path
  def clone_with_frozen_point
    raise "Mixer must implement"
  end

  def clone_with_new_offset_distance(distance)
    raise "Mixer must implement"
  end

  # Returns the pair of points from the path to the point
  def path_to_point_points
    [point_on_path, point.position]
  end

  # The vector from the pair closest to the point and the point
  def vector_from_path_to_point
    point_on_path.vector_to(point.position)
  end

  # The counterclockwise angle the vector of the pair closest to the point and the vector_from_path_to_point
  def angle_between_pair_and_point
    Geometry_Utils.radians_between(Geometry_Utils::CCW_KEY, pair.vector, vector_from_path_to_point)
  end

  def length_of_point_on_path_from_start_of_pair
    pair.points.first.distance(point_on_path)
  end

  # Computes the length of all data_pairs up to the point_on_path
  def composite_length_to_point_on_path
    index=data_pairs.index(pair)
    (index==0 ?
        0:
        Simple_Pair.composite_length(data_pairs[0..data_pairs.index(pair)-1])) +
    length_of_point_on_path_from_start_of_pair
  end

  # Returns the minimum distance to one of the closest pair points
  def distance_from_point_to_nearest_pair_point
    self.pair.points.map {|pair_point| pair_point.distance(self.point.position)}.sort.first
  end

  # The point of the pair nearest to self.point
  def nearest_pair_point
    self.pair.points.sort {|pair_point| pair_point.distance(self.point.position)}.first
  end

  # Identity is based on the hash of the ordered data_pairs and the point's position
  def hash
    [data_pairs.map {|data_pair| data_pair.hash}, point].map {|field| field.hash}.hash
  end

  def ==(other)
    self.hash==other.hash
  end

end
