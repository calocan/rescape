require 'utils/entity'
require 'utils/complex_point'
require 'utils/point3d_substitute' if !Rescape::Config.in_sketchup?
require 'utils/vector3d'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Geom
  class Point3d
    include Complex_Point

    # Trivial implementation of Data_Point
    def point
      self
    end

    # This simply returns the new position, which should be a Geom::Point3d
    def clone_with_new_point(position)
      position
    end

    # Constrains the point height to the given height
    def constrain_z(z)
      Geom::Point3d.new(self.x, self.y, z)
    end

    # Constrains the point or points to the given z value and returns and array or singular item in accordance with what was passed in
    def self.constrain_z(points, z)
      points.as_array_if_singular.map {|point| point.constrain_z(z) }.match_plurality(points)
    end

    def self.zero_z(points)
      self.constrain_z(points, 0)
    end

    # Trivial implementation of Complex_Point
    # Returns the static version of the point, which is in this case the point itself
    def freeze
      self
    end

    # Returns true if the points match in position. This is important since Sketchup allows multiple points of the same position to have a different hash
    def matches?(point)
      self.hash_point == point.hash_point
    end

    # Returns true if the given point is within the threshold length of this point
    def matches_within_threshold?(point, threshold)
      self.distance(point.position) <= threshold
    end

    # Checks to see if the point matches the a new Geom::Point3d position [0,0,0]
    def unassigned?
      self==Geom::Point3d.new
    end

    # Returns true if this point matches any of the given points
    def member?(points)
      points.any? {|match_point| self.matches?(match_point)}
    end

    # Create a hash key for a 2D point
    def hash_point
      self.to_a.map {|c| (c.to_f*1000).round()}.hash
    end

    # Returns the total length between ordered points
    def self.total_length(points)
      points.map_with_subsequent.inject(0) {|sum, pair| sum+pair[0].vector_to(pair[1]).length }
    end

    # Finds the closest pair of points to the given point given a path of points.
    def closest_pair_of_path(path)
      Simple_Pair.closest_pair_to_point(self.class.to_simple_pairs(path), self)
    end

    # Finds the closest point to the given point along the given path of points
    def point_on_path_closest_to_point(path)
      Simple_Pair.point_on_pair_closest_to_point(path, self)
    end

    def self.to_simple_pairs(path)
      path.map_with_subsequent {|point1, point2| Simple_Pair.new([point1, point2])}
    end

    # Find the shortest distance from the given point to a point along the given path of points
    def shortest_distance_to_path(path)
      Simple_Pair.shortest_distance_to_point(self.class.to_simple_pairs(path), self)
    end

    # Finds the region hash code for a point
    def region_hashes
      sets = [self.x, self.y, self.z].map {|coordinate| floor_and_round(coordinate / Sketchup::Entity::REGION_SIZE)}
      # TODO find a permutation/combination algorithm
      sets[0].map {|x|
        sets[1].map {|y|
          sets[2].map {|z|
            [x,y,z]
          }
        }.shallow_flatten
      }.shallow_flatten.map {|xyz| xyz.join(",")}
    end
    # Find the number a float rounds to and the number beyond that
    def floor_and_round(number)
      # if you round up, take the ceiling and the one above, otherwise take the floor and the one below
      number.round > number ? [number.floor, number.round] : [number.floor, number.floor-1]
    end

    # Hashes all the given points and hashes the array of hashes. Order matters
    def self.hash_points(points)
      points.map {|p| p.hash_point}.hash
    end
    # Hashes all the given points and hashes the array of hashes. Order doesn't matter
    def self.hash_points_unordered(points)
      points.map {|p| p.hash_point}.sort.hash
    end

    # Determines whether or not the given points match by calling hash_point on each
    def self.points_match(p1,p2)
      p1.hash_point==p2.hash_point
    end

    def self.point_lists_match?(points1, points2)
      points1.length==points2.length and points1.dual_map(points2) {|p1,p2| p1.matches?(p2)}.all?
    end

    # Determines the index of point in points by mapping all points to hash_point
    def self.index_of_point(points, point)
      points.map {|p| p.hash_point}.index(point.hash_point)
    end

    def self.unique_consecutive_points(points)
      points.uniq_consecutive_by_map {|point| point.hash_point}
    end

    # Determines if the points form a loop
    def self.is_loop?(points)
      return false unless points.length >= 3
      points.extremes.all_same?{|point| point.hash_point}
    end

    # Get rid of points that form a straight line, meaning are the vertex of a 180 angle or greater or equal to the optional angle_tolerance
    def self.eliminate_straight_points(points, angle_tolerance=179.99.degrees)
      return points if points.length < 3
      points.grep_with_propagated_previous_and_subsequent {|previous, current, subsequent|
        a=current.vector_to(previous).angle_between(current.vector_to(subsequent))
        a <= angle_tolerance
      }
    end

    def method_missing(m, *args, &block)
      raise "Could not find method #{m} for class #{self.class}"
    end

    # I can't figure out a way to use marshal_dump and marshal_load here. It seems when Ruby initializes a Geom::Point3d by unmarshalling something makes the instance unusable
    def _dump(level)
      Marshal.dump([x,y,z])
    end

    def self._load(data)
      self.new(*Marshal.load(data))
    end
  end
end