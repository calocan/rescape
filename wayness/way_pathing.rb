require 'wayness/dual_way'
require 'utils/shortest_path'
require 'utils/sorting'
require 'wayness/way_point_pair'

# Works in conjunction with way_grouping to do all pathing operations for ways of the way_grouping
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Way_Pathing

  # Creates intersection data for ways. Make sure that each way defined in both directions or this will fail
  def create_linked_ways_network()
    # make a point_key of way end points to a list of ways with those end points
    # inspect the end of each way to look for intersections
    ignore_duplicates = true
    intersection_hash = self.map_to_two_deep_hash(ignore_duplicates) { |way|
      linked_way = Linked_Way.new(way)
      reverse_linked_way = linked_way.reverse_way
      # This will form two top-level hash entries, unless the way is a loop, in which case one
      # The merges are only needed for loops
      {linked_way.origin.hash_point=>{linked_way.hash=>linked_way}}.merge(
          {reverse_linked_way.origin.hash_point=>{reverse_linked_way.hash=>reverse_linked_way}}) {|key, v1, v2|
        v1.merge(v2) {|should,never,happen| raise "Linked way and reverse linked way have identical hash values!"}
      }
    }
    # Look at the complete data and find the neighbors of each linked_way
    # If the way forms a loop its reverse way will be in the same intersection hash. Make sure to reject it
    intersection_hash.each { |point_key, linked_way_hash_of_point|
      linked_way_hash_of_point.each {|way_key, linked_way|
        reverse_way_key = linked_way.reverse_way.hash
        linked_way.set_neighbors(linked_way_hash_of_point.reject {|key,value| key==way_key or key==reverse_way_key}.values)
      }

    }
  end

  # Returns a hash that maps each way hash to it way_node
  def make_way_hash_to_way_node_lookup
    @linked_way_network.map_to_new_hash {|point_hash, linked_way_hash_of_point|
      way_node = Way_Node.new(linked_way_hash_of_point.values)
      linked_way_hash_of_point.map {|way_hash, linked_way|
        [way_hash, way_node]
      }.shallow_flatten
    }
  end


  # Returns the intersection points
  def intersection_nodes()
    @linked_way_network.map {|way_node, linked_way_hash_of_point|
      way_node
    }
  end

  def way_node_of_way(way)
    linked_way_network[]
    Way_Node_Way_Point_Pair.new()
  end

  # Returns a flattened version of the intersections data structure. All Linked_Way instances are returned.
  def all_linked_ways
    @linked_way_network.values.map {|way_hash_to_linked_way| way_hash_to_linked_way.values}.shallow_flatten
  end

  def linked_way_of_way(way)
    all_linked_ways.find {|linked_way| linked_way.way==way} || raise("Way #{way.inspect} not found")
  end

  def all_dual_ways
    way_hash_to_linked_way = Hash[*@linked_way_network.values.map {|way_hash_to_linked_way|
      way_hash_to_linked_way.map{|way_hash, linked_way|
        [way_hash, linked_way]}.shallow_flatten}.shallow_flatten]
    make_dual_ways(way_hash_to_linked_way)
  end

  def make_dual_ways(way_hash_linked_way)
    if (way_hash_linked_way.length==0)
      return []
    end
    dual_way = way_hash_linked_way.values.first.as_dual_way
    [dual_way] +
        make_dual_ways(way_hash_linked_way.reject {|way_hash, linked_way|
          dual_way.member? linked_way
        })
  end

  # Chain ways together by taking the next unintersected way on the counterclockwise sides
  # Return a sets of these continuous ways
  def get_continuous_way_sets
    linked_ways = @linked_way_network.map { |way_node, point_hash|
      point_hash.values.map { |linked_way| linked_way
      } }.shallow_flatten
    # Chain the linked_way by connecting adjacent intersection in the clockwise direction
    # Always start the chain with an unchained item that has no adjacent intersection, or if none are left
    # Use any item because this item is part of a loop

    chained_linked_way_sets = Sorting::make_chains(
        linked_ways,
         # given the last linked_way in the chain, call this function on each
         # each remaining linked_way to find the one at the end of the way of the previous_linked_way
         lambda { |previous_linked_way, linked_way|
           resolve_next_linked_way(previous_linked_way, self.class::CW_KEY) == linked_way },
         # to start a new chain, find the first unchained linked_way that is a leaf (has no intersecting ways)
         # If no leaf linked_way exists, simply take the first unchained linked_way, which will be part of an internal loop of ways
         lambda { |unchained_linked_ways| unchained_linked_ways.find { |linked_way| linked_way.adjacent_linked_ways[self.class::CCW_KEY] == nil } or unchained_linked_ways.first })
    chained_linked_way_sets.map { |chained_linked_ways|
      Continuous_Ways.new(self.way_class, chained_linked_ways.map { |a_linked_way| a_linked_way }, side_point_generator_options)
    }
  end

  # By default we don't pass any special options to the Side_Point_Generator for ways. We could in the future pass options to make the side points have smoother curves, etc.
  def side_point_generator_options
    {}
  end

  # Finds the linked_way at the end of the way of the given linked_way that is resolved by rotating from
  # the reverse way of linked_way
  def resolve_next_linked_way(linked_way, rotate)
    linked_way.reverse_way.adjacent_linked_ways[rotate]
  end

  # If two or more dual_ways are connected, sort them here
  def sort_connected_ways(connected_dual_ways)
    Sorting::chain(connected_dual_ways,
       # Get the neighbors that are not on the side of previous_dual_way
       lambda { |previous_dual_way, dual_way|
         dual_way.neighbors_not_on_the_side_of_this_neighbor(previous_dual_way)
       },
       # To start the chain, get the first dual way with only neighbor, or failing that take the first dual_way
       lambda { |unchained_dual_ways|
         unchained_dual_ways.find {
             |dual_way| (dual_way.neighbors & unchained_dual_ways) == 1} or unchained_dual_ways.first })
  end

  # Initiate way_grouping path caching externally
  def remote_solve_all
    # In the case that we are responding to a change in the ways (via the Way_Grouping_Integrator methods), this will resolve all paths regardless of how little has changed
    Rescape::Setup.get_remote_server().if_not_nil {|remote_server| remote_server.solve_all(self)}
  end

  # Solves all paths
  # This is run externally from Sketchup so as to not tie up the process. It should thus use a cache that writes to the file system
  def solve_all
    # Solve all paths. This needs to be run outside of Sketchup
    shortest_path = create_shortest_path
    dual_ways = self.dual_ways
    $solved=dual_ways.map {|dual_way_i|
      dual_ways.find_all{|dual_way_x|
        # Skip identical and neighbors
        dual_way_i != dual_way_x && !dual_way_i.neighbors.member?(dual_way_x)
      }.map {|dual_way_j|
        path = [dual_way_i, dual_way_j]
        shortest_path.solve(path, true)
      }.shallow_flatten.compact
    }.shallow_flatten
  end

  # Debug method to see how many paths have been cached by the external process
  def how_many_cached?
    total = dual_ways.length**2 - dual_ways.length
    cached_total = @path_lookup.remote_size
    puts "#{cached_total} cached out of #{total}"
    cached_total
  end

  # Solves the shortest path between two or more dual_ways returning the path starting at the first dual_way and ending at the last, with any intermediate dual_ways specified in between
  def solve_shortest_path_between_dual_ways(dual_ways_to_solve_for, shortest_path=create_shortest_path)
    raise "Not enough dual_ways: #{dual_ways_to_solve_for.inspect}" unless dual_ways_to_solve_for.length > 1
    shortest_path.solve(dual_ways_to_solve_for).path
  end

  def create_shortest_path()
    Shortest_Path.new(
        self.dual_ways,
        # Weight is the length of this way
        lambda {|current_dual_way, neighbor_ignored| current_dual_way.total_length},
        # Get the neighbors at both ends of the dual way
        # TODO it should only be necessary to get the neighbors at end of the dual_way opposite the end of the current_path
        lambda {|current_dual_way, current_path|
          current_dual_way.neighbors
        },
        # Pass the Cache_Lookup instance so that intermediate paths can be cached
        path_lookup,
        true)
  end

  # Determines if a path between two way_point_pairs exists
  def can_solve_path?(way_point_pairs)
    can_solve_bidirectional?(way_point_pairs)
  end

  # Like solve_shortest_path, but handles way_shapes that associate to the same way_point_pair by returning the linked_way of that way_point_pair in the direction of the point of the first way_shape to the last
  def solve_shortest_path_for_way_shapes(way_shapes)
    if (way_shapes.first.is_way_point_pair_match?(way_shapes.last))
      $l1= dual_way = solve_shortest_path_bidirectional(way_shapes).only
      # Reverse the single linked_way solution if it runs counter to the points of the way_shapes
      simple_pair = Simple_Pair.new(way_shapes.map {|way_shape| way_shape.point.position})
      $l2=(dual_way.linked_ways[0].way_point_pairs.find {|way_point_pair|
        way_point_pair.points_match?(way_shapes.first.way_point_pair)}.is_oriented_to?(simple_pair) ?
          dual_way.linked_ways[0] :
          dual_way.linked_ways[1]).as_array
    else
      # way_shapes don't share a way_point_pair so just solve for their way_point_pairs
      solve_shortest_path(way_shapes)
    end
  end

  # Solve the shortest path between two or more way_point_pair instances
  # Each additional way_point_pair requires a run of the shortest_path algorithm from that point,
  # so pairs should be limited
  # Returns an ordered list of linked_ways representing the path
  def solve_shortest_path(way_point_pairs)
    # Solve the path with dual_ways and return the set of linked_ways matching the way_point_pairs
    linked_way_path = Dual_Way.get_directed_linked_ways_for_path_matching_pairs(
        solve_shortest_path_bidirectional(way_point_pairs),
        way_point_pairs)
    linked_way_path
  end

  # Mimic solve_shortest_path_bidirectional but does the minimum work to see if the path is solvable
  def can_solve_bidirectional?(way_point_pairs)
    if (way_point_pairs.uniq==1 || Way_Point_Pair.connected?(way_point_pairs))
      true
    else
      dual_ways_to_solve_for = dual_ways_of_way_point_pairs(way_point_pairs)
      # Practically speaking, it makes sense to attempt to solve for the shortest path, even if we just need to know if any path exists. If we succeed, the path will be cached and used immediately to actually solve the path. If we can't solve it, the algorithm will have to do a full search anyway to determine that no solution exists.
      create_shortest_path().solve(dual_ways_to_solve_for, true) != nil
    end
  end

  # Mas wayS_point_pairs to dual_ways
  def dual_ways_of_way_point_pairs(way_point_pairs)
    $ddog=dual_ways = way_point_pairs.map{|way_point_pair| dual_way_by_way_lookup[way_point_pair.way] }
    raise "way_point_pairs: #{way_point_pairs.inspect} map to nil dual_ways #{dual_ways.inspect}" if dual_ways.any? {|dual_way| dual_way==nil}
    dual_ways
  end

  # Like solve_shortest_path but returns the path as dual_ways when both directions are needed or direction doesn't matter
  # Returns an ordered list of Dual_Way instances
  def solve_shortest_path_bidirectional(way_point_pairs)
    # If all connected group of way_point_pairs of one way were chosen, put them in order
    connected = Way_Point_Pair.connected?(way_point_pairs)
    modified_way_point_pairs = connected ? Way_Point_Pair.sort(way_point_pairs) : way_point_pairs
    dual_ways_to_solve_for = dual_ways_of_way_point_pairs(modified_way_point_pairs)
    if (dual_ways_to_solve_for.length==1)
      # No need to solve the shortest path
      Dual_Way.trim_start_and_end(dual_ways_to_solve_for, modified_way_point_pairs)
    elsif (connected)
      # All are connected so there's no need to solve the shortest_path
      Dual_Way.trim_start_and_end(self.sort_connected_ways(dual_ways_to_solve_for), modified_way_point_pairs)
    else
      solution_path = solve_shortest_path_between_dual_ways(dual_ways_to_solve_for)
      Dual_Way.trim_start_and_end(solution_path, modified_way_point_pairs)
    end
  end

end