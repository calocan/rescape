require "utils/data_point"
require 'wayness/way_point_pair_behavior'

# A simple wrapper of the Geom::Point3d class to allow associating a point with a Way instance
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Way_Point
  include Data_Point

  attr_reader :way, :point, :index
  def initialize(point, way)
    @point = point
    @way = way
    @index = @way.index(@point)
  end

  # Conforms with the Way_Point_Behavior interface
  def way_point
    self
  end

  # Clones the way_point with a new point. This will probably be superseded by copying a way and generating new way_points
  def clone_with_new_point(point)
    self.class.new(point, way)
  end

  def hash
    [@way.hash, @point.hash_point].hash
  end

  def ==(other)
    self.hash == other.hash
  end

  # gets the way_point of the reverse way of this one
  def reverse
    self.class.new(point, @way.reverse_way)
  end

  # Like closest_center_points, but returns all points from the end of the way defined by end_point to
  # the center points closest to the associated_point_pair
  def points_from_one_end(end_point)
    end_index=@way.index(end_point)
    way_index=@way.index(@point)
    @way[[end_index, way_index].min..[end_index,way_index].max]
  end

  def inspect
    "%s at index %s of way %s" % [self.class, self.index, self.way.inspect]
  end
end

