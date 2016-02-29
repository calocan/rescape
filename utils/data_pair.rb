require "utils/sorting"
require 'utils/Geometry_Utils'
require 'utils/data_pair_class_methods'

# Common method for anything that represents a pair of points, like Edge and Way_Point
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Data_Pair

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Data_Pair_Class_Methods)
  end

  # Required implementations:
  def neighbors
    raise "Mixin interface method not implemented"
  end

  # Maps the neighbors by point to {point1=>[neighbors1], point2=>[neighbors2]}
  def neighbors_by_point
    raise "Mixin interface method not implemented"
  end

  # Returns the instances of the non primitive point class that represents points for this class
  # (e.g. Vertex for Edge, Way_Point for Way_Point_Pair, Side_Point for Side_Point_Pair)
  def data_points
    raise "Mixin interface method not implemented"
  end

  # Create a clone of the pair, replacing its points with the given point pair
  def clone_with_new_points(point_pair)
    raise "Mixin interface method not implemented for class #{self.class}"
  end

  # Reverses the points of the pair
  def reverse
    raise "Mixin interface method not implemented"
  end

  # Returns a node version of a data_pair for pairs that have neighbors
  # The give data_point must be one of the data_points of the data_pair
  def as_node_data_pair(data_point, way_grouping)
    raise "Mixin interface method not implemented"
  end

  # Mimics Sketchup::Edge's method by returning the first Data_Point
  def start
    self.data_points.first
  end

  # Mimics Sketchup::Edge's method by returning the last Data_Point
  def end
    self.data_points.last
  end

  # Mimic's Sketchup::Edge's other_vertex call by returning the Data_Point not specified
  def other_data_point(data_point)
    self.data_points.reject_one(data_point).only
  end

  # the given pairs (0, 1 or 2)
  #method points must return the two Geom::Point3d points
  #method neighbors must return the neighbors of  pair, meaning those sharing a point
  # to return the number of points that this instance shares with the given pairs
  def shares_how_many_points(pairs)
    self.data_points.find_all {|data_point| self.class.shares_this_point?(pairs, data_point)}.length
  end

  def matches_how_many_points(points)
    self.data_points.find_all {|data_point| data_point.point.member?(points)}.length
  end

  # The underlying points of each data_point
  def points
    self.data_points.map {|data_point| data_point.point}
  end

  # Returns true if both points of this pair match both points of the given pair, independent of order
  def points_match?(pair)
    (self.points.intersect_on(pair.points) {|point| point.hash_point}).length==2
  end

  # Find a pair that matches this pair, otherwise return nil
  def find_match(pairs)
    pairs.find {|pair| self.points_match?(pair) }
  end

  # Hash the raw points independent of order
  def non_directional_points_hash
    self.points.map {|point| point.hash_point}.sort.hash
  end

  # Hash the raw points in order
  def directional_points_hash
    self.points.map {|point| point.hash_point}.hash
  end

  # End of interface definition #
  # Determines if this pair contains the data_point given (see self.data_points)
  def contains_data_point?(data_point)
    self.data_points.member? data_point
  end

  # Determines if this pair has the given point
  def shares_this_point?(point)
    self.points.map {|p| p.hash_point}.member?(point.hash_point)
  end

  # The index of this pair's point that is shared with pair
  def index_of_shared_point(pair)
    self.points.index(self.shared_point(pair))
  end

  # Determines if this pair shares a point with the given pair
  def shares_point?(pair)
    (self.points.map {|point| point.hash_point} & pair.points.map {|point| point.hash_point}).length >= 1
  end
  # Returns the shared point. Raises an error if one does not exist
  def shared_point(pair)
    self.points.intersect_on(pair.points) {|point| point.hash_point}.or_if_empty {
      raise "Expected shared_point between #{self.inspect} and #{pair.inspect} but none was found"
    }.first
  end

  # Returns true is this pair's start point matches the given pairs end point, or visa vera, or share both opposing points
  def shares_an_opposing_point?(pair)
    self.points.first.matches?(pair.points.last) || self.points.last.matches?(pair.points.first)
  end

  # Determines the closest Data_Point instance for this pair and the given pair
  # based on which points of each are closest. Returns an array of two Data_Points,
  # the first is the Data_Point of this pair and the second the Data_Point of the given pair
  def closest_data_points(pair)
    hash=self.data_points.sort_to_hash {|data_point1|
      pair.data_points.sort_to_hash {|data_point2|
        {:dp1=>data_point1, :dp2=>data_point2, :value=>data_point1.point.distance(data_point2.point)}
      }.first
    }.first
    [:dp1, :dp2].map {|dp| hash[dp]}
  end

  # Orients the given pair to another pair based on matching points or based on vector if the points don't match
  def orient_to(pair)
    if (self.points_match?(pair))
      self.points.first.matches?(pair.points.first) ? self : self.reverse
    else
      orient_to_vector(pair.vector)
    end
  end

  # Flips the data_pair to make it match the direction of the vector if the vector direction is more than 90 degrees apart from the pair direction
  def orient_to_vector(vector)
    self.vector.angle_between(vector) > 90.degrees ?
        self.reverse :
        self
  end

  # Determines if the given pair is oriented to this pair or not, meaning they are within 90 degrees of vector direction
  def is_oriented_to?(pair)
    if (self.points_match?(pair))
      self.points.first.matches?(pair.points.first)
    else
      self.vector.angle_between(pair.vector) <= 90.degrees
    end
  end

  # Finds the closest of the given pairs to this pair. This uses the closest_pair_to_point function, using the middle_point of this pair as the point.
  def closest_pair(pairs)
    self.class.closest_pair_to_point(pairs, self.middle_point)
  end

  def vector
    self.points[0].vector_to(self.points[1])
  end

  # The orthogonal vector to vector produced by rotating vector counter clockwise by 90°
  # If the optional argument counter_clockwise is false, clockwise will be used
  def orthogonal(counter_clockwise=true)
    rotation = Geom::Transformation.rotation(
        Geom::Point3d.new,
        Geom::Vector3d.new(0,0,1),
        Geometry_Utils::ROTATE_LOOKUP[counter_clockwise ? :counterclockwise : :clockwise])
    vector.transform(rotation)
  end

  # Determines whether or not the rotation from the vector of this data_pair is closer going counterclockwise or clockwise to the given vector.
  # Returns Geometry_Utils::CCW_KEY or Geometry_Utils:CW_KEY
  def rotation_to(vector)
    Geometry_Utils.radians_between(Geometry_Utils::CCW_KEY, self.vector, vector) <= Math::PI
  end

  # Returns the point in the middle of the pair
  def middle_point()
    Geom::Point3d.linear_combination(0.5, self.points[0], 0.5, self.points[1])
  end

  # Finds the angle between the vectors of each pair, where the angle is aways 0 <= θ <= π
  def angle_between(pair)
    vector.angle_between(pair.vector) 
  end

  # Converts the pair into Sketchup's definition of a line--a position point and a vector
  def to_line(points = self.points)
    [points[0], points[0].vector_to(points[1])]
  end

  # Returns true if the point is between the points of the pair or equal to one of the pair points
  def point_between?(point)
    vectors = self.points.map {|pair_point| pair_point.vector_to(point).normalize}
    point.on_line?(self.to_line()) and (vectors[0]==vectors[1].reverse or vectors.any? {|vector| vector.length==0})
  end
  # Test method
  def point_between_data(point)
    vectors = self.points.map {|pair_point| pair_point.vector_to(point).normalize}
    [point.on_line?(self.to_line())]+vectors
  end

  # Returns the point projected on the line of the pair. Use point_between? after if you are concerned with whether the projection is actually between the pair points
  def project_point_to_pair(point)
    Rescape::Config.log.warn "Pair has identical points" if self.to_line()[1].length==0
    point.position.project_to_line(self.to_line(self.points))
  end

  # Like find_via_breadth_first_search to does two searches starting with the neighbors on each
  # end of the pair.
  # Returns two arrays of the first tier of neighbors that meet the criterion block called on each neighbor.
  # The tier for each of the two searches are independent, so they can be different degrees of separation
  # from the edge. They can also have duplicate neighbors between them
  def breadth_first_search_from_each_end(&block)
    self.neighbors_by_point.values.map {|neighbors|
      get_search_lambda(&block).call(neighbors, [self])
    }
  end

  # Searches neighbors of the pair, looking testing the criterion_lambda on each neighbor until
  # it returns true.
  # One or more results are returned depending on the number of findings at the first degree of
  # separation that returns a match
  # If all linked pairs are exhausted without a result, an empty list is returned
  def find_via_breadth_first_search (&block)
    get_search_lambda(&block).call(self.neighbors, [self])
  end

  def get_search_lambda(&block)
    evaluate_tiers_until_found = lambda { |neighbors, visited|
      if (neighbors.length==0)
        []
      else
        associated_neighbors = neighbors.find_all {|neighbor| block.call(neighbor) }
        if (associated_neighbors.length > 0)
          associated_neighbors
        else
          all_visited = visited+neighbors
          next_neighbors = neighbors.map {|neighbor| neighbor.neighbors}.shallow_flatten.reject_any(all_visited)
          evaluate_tiers_until_found.call(next_neighbors, all_visited)
        end
      end
    }
  end

  # Finds all connected pairs for pairs that have defined neighbors. This collection is unsorted use Data_Pair_Class_Methods.sort to sort them
  # Accepts an optional block as a predicate that blocks any pair for which the predicate returns false
  # TODO figure out how to pass the optional block more elegantly
  def all_connected_pairs()
    lambda = block_given? ? lambda {|item| yield(item)} : lambda {|item| item}
    # delegate to allow classes that override this to default to it
    all_connected_pairs_internal() {|item| lambda.call(item)}
  end
  def all_connected_pairs_internal(pairs_found_so_far=[self])
    # Find all neighbors that are not in the found list and pass the optional predicate
    new_neighbors = self.neighbors_by_point.values.map {|neighbors| neighbors.reject_any(pairs_found_so_far).find_all {|neighbor| block_given? ? yield(neighbor) : true}}.shallow_flatten
    [self] + new_neighbors.map {|neighbor|
      neighbor.all_connected_pairs_internal(pairs_found_so_far + new_neighbors)}.shallow_flatten.uniq
  end

  # The region hash values of the points of this pair. Region hashes indicate a 3D box in which a point resides
  def region_hashes(region_size)
    # Dividing the pair points by region size means that we get at least one point in each region through which the pair passes
    divide_by_approximate_length(region_size).map {|point| point.region_hashes}.shallow_flatten.uniq
  end

  # Divides by the approximate length given. If the length is greater than the pair, the pair points will be returned
  # If the length is half or just under half the pair, then three points will be returned, etc.
  def divide_by_approximate_length(length)
    divide(self.vector.length / length)
  end

  # Divides the pair into the given number of points plus the two end points
  # Thus providing 2 will return 4 points
  def divide(number_of_points)
    count = number_of_points+1 # linear_combination produces 2 results for 1, 3 for 2, etc, and we want 2 more than specified
    (0..count).map {|index| Geom::Point3d.linear_combination((count-index)/count.to_f, self.points.first, index/count.to_f, self.points.last) }
  end

  def divide_into_partials_by_approximate_length(length)
    divide_into_partials_at_points(divide_by_approximate_length(length))
  end

  def divide_into_partials(number_of_points)
    divide_into_partials_at_points(divide(number_of_points))
  end

  # Divides a pair into two partial_data_pairs at the given fraction between 0.0 and 1.0, returning both
  # If 0 or 1 is given only one item will be returned in the collection
  def divide_into_partials_at_fraction(fraction)
    divide_point = self.points.first.transform(self.vector.clone_with_length(self.vector.length*fraction))
    self.divide_into_partials_at_points([divide_point])
  end

  # Reorders the given points that lie between the data_pair points to match the direction of the data_pair
  def order_points_to_data_pair(points)
    points.sort_by {|point| data_pair.points.first.vector_to(point).length}
  end

  # Divides the pair into two partial_data_pairs at the given point, or one if the point is at an end. This always returns a collection regardless of the number of results.
  def divide_into_partials_at_points(unordered_points)
    return self.as_array unless points.length > 0
    points = order_points_to_data_pair(unordered_points)
    bad_points = points.find_all {|point| !self.point_between?(point)}
    raise "The given points #{bad_points.inspect} do not lie between the data_pair #{self.inspect}" if bad_points.length > 0

    # Take the uniq points plus the points of this pair and make partials
    ([self.points[0]]+points+[self.points[1]]).uniq_consecutive_by_map {|point| point.hash_point}.map_with_subsequent {|point1, point2|
      self.to_partial_with_points([point1, point2])
    }
  end

  # Creates a partial with the given point_pair.
  def to_partial_with_points(point_pair)
    self.class.partial_class.new(self, point_pair)
  end

  # Find the vector this pair's orthogonal vector to the given pair
  def vector_to_parallel_pair(data_pair)
    self.points[0].vector_to(self.points[0].project_to_line(data_pair.points))
  end

  # Transforms both points of the given pair and returns the transformed points
  def transform_points(transformation)
    self.points.map {|point| point.transform(transformation)}
  end

  def cardinal_direction()
    (self.vector.y > 0 ? 'North' : (self.vector.y==0 ? '' : 'South'))+(self.vector.x > 0 ? 'east' : (self.vector.x==0 ? '' : 'west'))
  end

  # Creates a side_point_pair from the data_pair by transforming the edge points by the two given transformations
  def to_side_point_pair_using_transformations(data_pair, transformations)
    Side_Point_Pair.new(*self.points.triple_map(data_pair, transformations) {|point, data_point, transformation|
      Side_Point.new(point.transform(transformation), data_point)})
  end

  # Returns the intersection of the given pair with this pair if one exists
  def intersection(data_pair)
    $da=data_pair
    $do=self
    intersection = Geom.intersect_line_line(self.to_line, data_pair.to_line)
    return nil unless intersection
    #raise "No intersection found, perhaps #{data_pair.inspect} is parallel to #{self.inspect}" unless intersection
    (self.point_between?(intersection) && data_pair.point_between?(intersection)) ? intersection : nil
  end

  # Finds all neighbors up to and including the given degree of separation, which must be 0 or greater
  def neighbors_up_to_degree(degree, visited_pairs=[self])
    return [] if (degree==0)
    # Store the neighbors that have not yet appeared
    [self.neighbors.reject_any(visited_pairs),
     # Recurse on each neighbor
     self.neighbors.flat_map {|neighbor|
       neighbor.neighbors_up_to_degree(degree-1, visited_pairs+self.neighbors)}].
     # Flatten the neighbors with the recursion results check for uniqueness, since some duplicates may still appear
     shallow_flatten.uniq
  end

  # This exists to conforms to the implicit interface of Partial_Data_Pair, returning itself
  def data_pair
    self
  end

  # Abstracts an associated edge to a side_point_pair

  def draw(parent=Sketchup.active_model)
    parent.entities.add_line(self.points)
  end

end
