require 'wayness/way_point_pair'
# A simple wrapper to Linked_Way that treats the Linked_Way as dual directional
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Dual_Way
  # The two linked_ways that represent the dual_way. The first is always the linked_way that was passed to the initializer
  attr_reader :linked_ways, :id
  def initialize(linked_way)
    @linked_ways = [linked_way, linked_way.reverse_way]
    # Create a string id for the dual way
    @id = [linked_way.id, linked_way.reverse_way.id].sort.join('_').to_s
  end

  # Returns the id of the Dual_Way, which is based on the ids of the two underlying ways
  # Ruby complains when id is used, hence this method
  def unique_id
    @id
  end

  def name
    "%s:%s" % [@linked_ways.first.name, self.hash]
  end

  def member?(test_linked_way)
    @linked_ways.member? test_linked_way
  end

  def matches_way?(way)
    @linked_ways.find {|linked_way| linked_way.hash == way.hash}
  end

  def matches_way_hash?(test_way_hash)
    @linked_ways.find {|linked_way| linked_way.hash == test_way_hash}
  end

  def total_length
    @linked_ways.first.total_length
  end

  def get_linked_way_neighbors_as_dual_ways(linked_way)
    linked_way.neighbors.map {|neighbor| neighbor.as_dual_way}
  end

  def neighbors
    linked_ways.inject([]) {|list, linked_way| list+get_linked_way_neighbors_as_dual_ways(linked_way)}
  end

  # Given a dual_way find all the adjacent dual_ways until reaching intersections of more than two ways
  # This should be a very small set, since most way breaks are at intersections of 3 or more ways
  def neighbors_up_to_multiway_intersections(previous_dual_ways=[])
    # Take the two linked_ways of the dual_way and find those with less than two neighbors
    valid_neighbors = self.linked_ways.find_all {|linked_way| linked_way.neighbors.length < 2}.
        # Find the neighbors of those linked_ways
        flat_map {|linked_way| linked_way.neighbors}.
        # Convert them to dual_ways, reduce to unique, and reject any already encountered
        map {|linked_way| linked_way.as_dual_way}.uniq.reject_any(previous_dual_ways)
    # Combine the valid neighbors with a recursive call to each one
    valid_neighbors + valid_neighbors.flat_map {|dual_way| dual_way.neighbors_up_to_multiway_intersections(self.as_array + valid_neighbors)
    }
  end


  # Get the underlying linked_way that has a shared start point with the given neighbor
  def linked_way_connected_to_this_neighbor(neighbor_dual_way)
    linked_way = @linked_ways.find {|linked_way|
      linked_way_neighbors_as_dual_ways = get_linked_way_neighbors_as_dual_ways(linked_way)
      linked_way_neighbors_as_dual_ways.member? neighbor_dual_way }
    raise "neighbor_dual_way is not a neighbor of this dual_way. This: #{self.inspect} Neighbor: #{self.inspect}" unless linked_way
    linked_way
  end

  # Gets the non-neighbor linked_way unless the two dual_ways are loops, in which case nothing is returned
  # This is useful if you want to chain the underlying linked_ways by continuous direction
  def get_non_neighbor_linked_way(dual_way)
    @linked_ways.find {|linked_way|
      dual_way.neighbors.intersect_on(get_linked_way_neighbors_as_dual_ways(linked_way)) {|x|x.hash}.length == 0 }
  end

  def neighbors_not_on_the_side_of_this_neighbor(neighbor)
      # find the neighbors on the end of current_dual_way that doesn't intersect last
      # to get the neighbors that are not neighbors of last (i.e. don't backtrack)
      non_neighbor_linked_way = neighbor && self.get_non_neighbor_linked_way(neighbor)
      # If the two dual ways form a loop, there is no non_neighbor_linked_way
      non_neighbor_linked_way != nil ?
        non_neighbor_linked_way.neighbors.map{|lw| lw.as_dual_way} :
        []
  end

  # Given a pair of points that represents one side of the dual_way, pick the linked_way that should represent it.
  # linked_ways by definition define their sides as the side at a counterclockwise angle from the start of the way.
  def linked_way_for_side_pair(pair)
    self.linked_ways.sort_by {|linked_way|
      # create a vector from the start of the way to the pair's middle_point. This vector is accurate enough
      # unless the pair crosses the way, in which case it's not a valid side anyway
      vector_to_pair = linked_way.origin.vector_to(pair.middle_point)
      Geometry_Utils.radians_between(Way_Grouping::CCW_KEY, linked_way.vector, vector_to_pair)
    }.first
  end

  # Dual ways are uniquely identified by the unordered hashes of the two underlying linked ways
  def hash
    @linked_ways.inject(0) {|last,lw| last+lw.hash}
  end
  
  def ==(other)
    hash == other.hash
  end

  # This is used to get a partial way matching a way_point_pair to form the end way segments of a path
  def slice_way_to_way_point_pair(neighbor_dual_way, way_point_pair)
    # Choose which direction to used based on the given neighbor's location
    linked_way = linked_way_connected_to_this_neighbor(neighbor_dual_way)
    raise "The given dual_way is not a neighbor!" unless linked_way
    # Reverse the way_point_pair to match the linked_way direction if needed
    oriented_way_point_pair = linked_way.hash==way_point_pair.way.hash ? way_point_pair : way_point_pair.reverse
    # Create the partial way from the start of the way up to the highest index of the way point pair
    Partial_Linked_Way.new(linked_way,
        0,
        oriented_way_point_pair.map{|way_point| way_point.index}.max).as_dual_way
  end

  # Get the partial_way representing two or more way_point_pairs within. It's possible that the way_point_pairs are identical, in which case we take just that way_point_pair in our Partial_Linked_Way'
  def slice_according_to_way_point_pairs(ordered_way_point_pairs)
    # Orient the way point pairs to go the same direction
    oriented_way_point_pairs = Way_Point_Pair.orient_pairs(ordered_way_point_pairs)
    # Picked the linked_way whose direction matches the way_point_pairs
    linked_way = @linked_ways.find {|linked_way| linked_way.way.hash==oriented_way_point_pairs.first.way.hash}
    indices = oriented_way_point_pairs.map {|way_point_pair| way_point_pair.indices}.shallow_flatten
    Partial_Linked_Way.new(linked_way,
        indices.min,
        indices.max).as_dual_way
  end

  # Returns the point in the middle of the first and last point of the way
  def middle_point()
    linked_way = @linked_ways.first
    vector = linked_way.first.vector_to(linked_way.last)
    linked_way.first.offset(vector, vector.length/2)
  end

  # TODO dual_way should implement Way_Behavior to remove the need for this
  def draw_center_line
    @linked_ways.first.way.draw_center_line
  end

  def inspect
     "%s with pair of linked_ways %s and hash %s" % [self.class, linked_ways.inspect, self.hash]
  end

  # Given an ordered set of dual_ways trim the first and last dual_way to match the two way_point_pair positions. If
  # there is only one dual_way it will be trimmed at both ends
  def self.trim_start_and_end(ordered_dual_ways, way_point_pairs)
    # Get the unique dual_ways from the list. It's possible that way_point_pairs are associated with the same Dual_Way'
    unique_ordered_dual_ways = ordered_dual_ways.uniq
    unique_ordered_dual_ways.length == 1 ?
        [unique_ordered_dual_ways[0].slice_according_to_way_point_pairs(way_point_pairs)] : # one dual_way, slice within it
    ([unique_ordered_dual_ways[0].slice_way_to_way_point_pair(unique_ordered_dual_ways[1], way_point_pairs.first)] + # slice start
    unique_ordered_dual_ways.rest.all_but_last + # leave middle alone
    [unique_ordered_dual_ways[-1].slice_way_to_way_point_pair(unique_ordered_dual_ways[-2], way_point_pairs.last)]) # slice end
  end

  # Extract the appropriate path of linked_ways base on the first and last ordered_pairs, where the first pair must match the first pair of the first linked_way and the last the last pair of the last linked_way. The orientation of the pairs doesn't matter
  def self.get_directed_linked_ways_for_path_matching_pairs(ordered_dual_ways, ordered_pairs)
    linked_ways = self.get_directed_linked_ways_for_path(ordered_dual_ways)
    ordered_linked_ways = linked_ways.find {|ordered_linked_ways|
      # Map the end pairs against the first and last pair of each linked_way path. The first points of the first linked_way must match the first pair, and visa-versa for the last
      [ordered_pairs.first, ordered_pairs.last].dual_map(
        # Grab the first and last pairs
        [ordered_linked_ways.first.way_point_pairs.first, ordered_linked_ways.last.way_point_pairs.last]) {|pair, linked_way_pair|
        pair.points_match?(linked_way_pair)
      }.all? # all? tests that both first and last pairs matched
    }
    raise "Neither ordered_linked_ways matched the given ordered pairs" unless ordered_linked_ways
    ordered_linked_ways
  end

  # Extract the linked ways forming both continuous directions based on the order of the dual ways
  # This therefore returns two arrays of linked_ways
  def self.get_directed_linked_ways_for_path(ordered_dual_ways)
    if (ordered_dual_ways.length==0)
      [[],[]]
    elsif (ordered_dual_ways.length==1)
      ordered_dual_ways.only.linked_ways.map {|lw| [lw]}
    else
      [ordered_dual_ways, ordered_dual_ways.reverse].map {|dws| self.get_directed_linked_ways(dws)}
    end
  end

  def self.get_directed_linked_ways(ordered_dual_ways)
    first = ordered_dual_ways.first
    rest = ordered_dual_ways.rest
    # Figure out the linked way that is neighbors with the next dual_way
    linked_way = first.linked_way_connected_to_this_neighbor(rest.first).reverse_way
    [linked_way] + (rest.length > 1 ? self.get_directed_linked_ways(rest) : [rest.first.linked_way_connected_to_this_neighbor(first)])
  end
end