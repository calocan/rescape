# An interface/mixin to the high-level class encapsulating a point, such as Vertex for Edge or Way_Point for Way_Point_Pair
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Data_Point
  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Data_Point_Class_Methods)
  end

  # The underlying Geom::Point3d point of the Data_Point. For a Geom::Point3d this just returns self
  def point
    raise "Must implement interface method"
  end
  # A synonym for point
  def position
    self.point
  end

  # Clones the Data_Point with a new underlying point, when applicable
  def clone_with_new_point(point)
    raise "Must implement interface method"
  end

  # Gets the vector from this underlying point to another data_point's
  def vector_to(data_point)
    self.point.vector_to(data_point.point)
  end

  # Returns true if the underlying point matches that of the given data_point
  def matches?(data_point)
    self.point.matches?(data_point.point)
  end

  # Delegate any other method to the underlying point
  def method_missing(m, *args, &block)
    self.point.send(m, *args, &block)
  end

  module Data_Point_Class_Methods
    # Returns the intersection of the first set with the second where matching is based on the underlying point
    def find_all_matches(main_data_points, match_data_points)
      main_data_points.intersect_on(match_data_points) {|data_point| data_point.point.hash_point}
    end

    # Return the closest data_point of data_points to the given data_points
    def closest_data_point(data_points, data_point)
      data_points.sort_by {|a_data_point| a_data_point.vector_to(data_point).length}.first
    end
  end
end