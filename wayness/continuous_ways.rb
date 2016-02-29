require 'wayness/side_point_manager'
require 'wayness/Side_Point_Generator'

# A data structure that represents an ordered list of Way instances that are continuous, meaning that the end of point
# of one is the start point of the next one.
# This class extends Array and treats the ways as the base Array
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Continuous_Ways < Array

  attr_reader :way_class, :side_point_generator
  # Optionally provide offset_options for the Side_Point_Generator, which will be merged with any default options, favoring the former
  # Use disable_side_point_generator=true to prevent generating side points when they aren't needed'
  def initialize(way_class, ways, offset_options={})
    raise "Empty continuous ways are not allowed" unless ways.length > 0 and ways.first.length >= 2
    super(ways)
    @way_class = way_class
    # Create a side_point_generator in order to offset the ways into road, paths, trackbeds, etc.
    @side_point_generator = Side_Point_Generator.new(
        self,
        offset_options.merge({:angle_acceptance=>self.class.angle_acceptance}) {|key, left, right| left})
    @side_point_manager_lookup = Cache_Lookup.new('Side Point Manager')
  end

  # Angle acceptance limits extreme consecutive angles like z (zig-zags) in the ways when generating side points
  @@angle_acceptance = nil
  def self.angle_acceptance
    @@angle_acceptance ||= Math::PI/6
  end

  # Generates side_points for the continuous_ways, either based on the properties of the @way_class or on the given transformation_lambda
  # The optional transformation_lambda_wrapper is a Lambda_Wrapper used to offset the ways a particular distance rather than the default behavior of offsetting by the default width for the way class. The Lambda_Wrapper wraps a lambda expression
  def side_point_manager(transformation_lambda_wrapper=nil, way_preprocessor=nil)
    @side_point_manager_lookup.find_or_create(transformation_lambda_wrapper) {|transformation_lambda_w|
      Side_Point_Manager.new(@side_point_generator.make_side_points(transformation_lambda_w, way_preprocessor))
    }
  end

  # Creates a continuous set of way_points from the ways
  def way_points
    self.map {|way| way.as_way_points() }.shallow_flatten
  end

  # Make way_point_pairs in order for all the ways and combine them into a flat list
  def way_point_pairs
   self.map {|way| way.way_point_pairs() }.shallow_flatten
  end

  # Makes way_point_pairs only for the specified way_points. This is used when a caller has filtered out certain way_points that are undesirable because of bad data, user choice, etc.
  def limited_way_point_pairs(allowed_way_points)
    self.flat_map {|way| way.make_limited_way_point_pairs(allowed_way_points.find_all {|way_point| way_point.way==way}) }
  end

  # Like limited_way_point_pairs but doesn't flatten the results. The way_point_pairs of each way are left as separate lists
  def limited_way_point_pairs_as_sets(allowed_way_points)
    self.map {|way| way.make_limited_way_point_pairs(allowed_way_points.find_all {|way_point| way_point.way==way}) }.reject_empty_collections()
  end

  def points
    self.shallow_flatten.uniq_by_map_allow_loop {|point| point.hash_point}
  end

  # Determines if the continuous way points make a loop. Outer loops with an extrusion (e.g. ó) or inner loops
  # with an intrusion (e.g. θ) are excluded. (Trace each shape an notice how the path ends at the same point
  # like a real loop would)
  # In other words, if the first and last pair are identical it is not a loop
  def makes_loop?
    Geom::Point3d.points_match(self.first.first, self.last.last) &&
        (self.length==1 || !Geom::Point3d.points_match(self.first[1], self.last[-2]))
  end

  def inspect
    "Continuous Ways: way classes: %s" % self.map {|way| way.class}
  end

  # Hashes all the ways and creates a hash from the results that disregards array order
  def hash
    self.map {|way| way.hash}.sort.hash
  end

  def ==(other)
    self.hash == other.hash
  end

  # Returns the given ways that are contained within this Continuous_Ways instance
  def matching_ways(ways)
    ways.intersect_on(self) {|way| way.hash}
  end

  def draw_center_line
    self.each {|way| way.draw_center_line}
  end
end

# Creates a Continuous_Ways subclass based on continuous points
# This is useful if the underlying points don't come from a way, but instead from border points
class Simple_Continuous_Way < Continuous_Ways
  def initialize(way_class, points)
    super(way_class, way_class.new(points, {}))
  end
end