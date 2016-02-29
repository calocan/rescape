require 'utils/pair_to_point_data'
require 'utils/path_to_point_data'
require 'utils/point3d'
#require 'utils/partial_data_pair' Circular reference

# A suite class-level methods that apply to multiple Data_Pairs
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Data_Pair_Class_Methods

  # The default partial class to use for splitting data_pairs
  def partial_class
    Partial_Data_Pair
  end

  # Resolves ordered pairs to ordered unique points. The points returned only need to be consecutively unique.
  def to_unique_points(pairs)
    pairs.map {|pair| pair.points}.shallow_flatten.uniq_consecutive_by_map{|point| point.hash_point}
  end

  # Resolves ordered pairs to ordered unique data_points. The data_points returned only need to be consecutively unique.
  def to_unique_data_points(pairs)
    pairs.map {|pair| pair.data_points}.shallow_flatten.uniq_consecutive_by_map{|data_point| data_point.hash}
  end

  # Returns true if all the pairs are connected, and false otherwise
  def connected?(pairs)
    self.make_chains(pairs).length==1
  end

  # Adjusts ordered pairs to give each pair a common point with the next at the point between the two points
  # Returns a new set of pairs
  def connect_pairs(ordered_pairs)
    ordered_pairs.map_with_previous_and_subsequent {|previous_pair, pair, subsequent_pair|
      points = [previous_pair ?
                    Geom::Point3d.linear_combination(0.5, previous_pair.last.point, 0.5, pair.first.point) :
                    pair.first.point,
                subsequent_pair ?
                    Geom::Point3d.linear_combination(0.5, pair.last.point, 0.5, subsequent_pair.first.point) :
                    pair.last.point]
      pair.clone_with_new_points(points)
    }
  end

  # Creates a path from ordered pairs that do not necessarily intersect. Projects pairs to their intersection if they don't meet
  def create_path_by_projecting(ordered_pairs)
    [ordered_pairs.first.first] +
    ordered_pairs.map_with_subsequent {|pair, subsequent_pair|
      intersect = Geom.intersect_line_line(pair, subsequent_pair)
      intersect ? [intersect] : [pair.last, subsequent_pair.first]
    }.shallow_flatten +
    [ordered_pairs.last.last]
  end

  # Sorts the pair by connecting ends. The first pair in the given connected_pairs will begin the chain
  # Use connected? to ensure all pairs are connected before calling
  def sort(connected_pairs)
    self.make_chains(connected_pairs).only_set_or_empty_set("Sorted pairs were not all connected and thus produced multiple chains")
  end

  # Chains connected pairs together using Sorting.make_chains. Returns 1 to n arrays of chained pairs
  # where n is the number of pairs. If all edges are connected 1 array is returned, if none are connected n arrays of one item each are returned
  # Requires the implementation of interface instance method shares_how_many_points
  def make_chains(pairs)
    Sorting.make_chains(pairs,
                        lambda{|last_pair, pair| last_pair.shares_point?(pair)}, # match neighbors
                        lambda{|unchained_pairs|
                          start_item = unchained_pairs.find{|pair| # get start item that shares 0 or 1 point
                            pair.shares_how_many_points(pairs.reject{|pr|pr==pair}) <= 1
                          }
                          start_item || unchained_pairs.first # loops won't have a natural start item
                        })

  end

  # Chains connected in uninterrupted pairs together using Sorting.make_chains. This means that chains are broken
  # at intersections between more than two pairs.
  # Returns 1 to n arrays of chained pairs where n is the number of pairs. If all edges are connected 1 array is returned, if none are connected n are returned
  # Requires the implementation of interface instance method shares_how_many_points
  def make_uninterrupted_chains(pairs)
    point_hash_to_pairs = pairs.to_many_to_many_hash {|pair| pair.points.map {|point| point.hash_point}}
    Sorting.make_chains(pairs,
                        lambda{|last_pair, pair| # Neighbors. Check if the pairs share a point exclusive of other pairs
                          last_pair.shares_point?(pair) and
                              point_hash_to_pairs[last_pair.shared_point(pair).hash_point].length==2
                        },
                        lambda{|unchained_pairs| # Start item
                          unchained_pairs.find {|pair| # get a pair that has one point shared with 0 or >1 other pair
                            pair.points.any? {|point| point_hash_to_pairs[point.hash_point].length != 2}
                          } || unchained_pairs.first # loops won't have a natural start item
                        })

  end

  # Hashes the pairs by making an unordered set of their points hash values
  # Use lookup_by_point_pair to match a pair to an entry in this hash
  def hash_by_point_pair(pairs)
    pairs.to_hash_values {|pair| pair.non_directional_points_hash()}
  end

  def lookup_by_point_pair(point_pair_hash, pair)
    point_pair_hash[pair.non_directional_points_hash()]
  end

  # Returns all of main_pairs that match match_pairs where a match is a pair with the same two points in any order
  def find_all_matches(main_pairs, match_pairs)
    main_pairs.intersect_on(match_pairs) {|pair| pair.non_directional_points_hash}
  end

  # Determines whether or not pair matches one of pairs, where point ordering does not matter
  def matches?(pairs, pair)
    find_all_matches(pairs, [pair]).length==1
  end

  # Determines if any of the pairs have a data_point that matches the given_data point. This is useful to determine if a set of pairs is touches point
  def shares_this_point?(pairs, data_point)
    pairs.find{|data_pair| data_pair.shares_this_point?(data_point)}
  end

  def index_of_pair_that_matches(pairs, pair)
    pairs.index(find_all_matches(pairs, [pair]).only("For pair #{pair.inspect}, no matching pairs were found in #{pairs.inspect}"))
  end

  # Finds the closest pair to the point (see closest_pair_and_distance_to_point)
  def closest_pair_to_point(pairs, point)
    closest_pair_to_point_data(pairs, point).pair
  end

  # Finds the shortest distance from the point to the pairs (see closest_pair_and_distance_to_point)
  def point_on_pair_closest_to_point(pairs, point)
    closest_pair_to_point_data(pairs, point).point_on_path
  end

  # Finds the shortest distance from the point to the pairs (see closest_pair_and_distance_to_point)
  def shortest_distance_to_point(pairs, point)
    closest_pair_to_point_data(pairs, point).distance
  end

  # Finds the closest pair of points to the given point and the distance. Distance is measured by the projection of the point onto the line made by the pairs, where pairs are only valid if the project of the point lies between the pair points. If no valid pairs exist, the closest pair by average distance to each point of the pair is used
  # Returns an array with the pair, the point on the line of the pair, and the distance from the point to the point on the line
  def closest_pair_to_point_data(pairs, point)
    raise "No pairs given" unless pairs.length > 0
    Pair_To_Point_Data.closest_pair_to_point_data(pairs, point)
  end

  # Returns true if the point lies on one of the pairs
  def point_between_any_pair?(data_pairs, point)
    data_pairs.find {|pair| pair.point_between?(point)} != nil
  end

  # Finds the points at which the pair sets intersect. Other_pairs are iterated through fully for each main_pair to find the intersections
  def find_intersections(main_pairs, other_pairs)
    return [] if (main_pairs.length==0)
    main_pair = main_pairs.first
    intersection = other_pairs.map_until_not_nil {|other_pair| main_pair.intersection(other_pair)}
    intersection.as_array() + find_intersections(main_pairs.rest, other_pairs)
  end

  # Like closest_pair_to_point_data but operates on a path, finding the closest pair on the path to the point and returning a Path_To_Point instance
  # The optional data_pairs arguments represent the underlying Data_Pairs of the path
  def make_path_to_point_data(path, point, data_pairs=nil)
    Path_To_Point_Data.new(path, point, data_pairs)
  end

  # Find the closest pair to the point in the pair_region_lookup
  def closest_pair_to_point_with_region_lookup(point, pair_region_lookup)
    pairs = point.region_hashes().map {|region_hash| pair_region_lookup[region_hash]}.shallow_flatten.compact || []
    pairs.length > 0  ? closest_pair_to_point(pairs, point) : nil
  end

  # Hash the pairs by their points independent of pair and point order
  def unordered_pairs_hash(pairs)
    pairs.map {|pair| pair.non_directional_points_hash()}.sort.hash
  end

  def draw_all(pairs, parent)
    pairs.each {|pair| pair.draw(parent)}
  end

  def composite_length(pairs)
    pairs.inject(0) {|sum, pair| sum+pair.vector.length}
  end

  # Find the closest data_points between ordered pairs that might individually be orientated in the wrong direction. The first pair is oriented so its last pair is closer to the first point of the second pair, and the second pair is oriented to guarantee this. Subsequent pairs are oriented according to go in the direction of the previous using point proximity. The possibly reoriented pairs are returned
  def orient_pairs(pairs, first_set=true)
    # If zero or one pair is present return it unaltered. Otherwise we are at the end case of the iteration
    return first_set ? pairs : [] if pairs.length < 2
    first_pairs = [pairs.first, pairs.rest.first]
    # Find the two closest data_points
    closest_points = first_pairs[0].closest_data_points(first_pairs[1]).map {|data_point| data_point.point}
    (first_set ? # only reorient the first pair on the first iteration
      [closest_points[0]==first_pairs[0].points[1] ? # closest point is second point of first_pair, then leave the pair be
        first_pairs[0] : first_pairs[0].reverse] :
      []) +
    # Always orient the second pair
    [closest_points[1]==first_pairs[1].points[0] ? first_pairs[1] : first_pairs[1].reverse] +
    # Iterate but don't orient the first pair on any future iterations
    orient_pairs(pairs.rest, false)
  end

  # Iterate through each data_pair giving it the two fractions of the length of all the pairs that each of its two points represent.
  # Returns the Range instance for each item, or if a block is given the result of each block. The block accepts the current data_pair and Range instance with the min and max being the two fractions.
  def map_pairs_with_length_fractions(data_pairs, total_length=self.composite_length(data_pairs), total_so_far=0)
    if (data_pairs.length==0)
      []
    else
      data_pair = data_pairs.first
      data_pair_length = data_pair.vector.length
      # Get the fraction of distance to offset each point of the pair
      fraction_range = Range.new(total_so_far / total_length, (total_so_far+data_pair_length) / total_length)
      block = lambda {|the_data_pair, the_fraction_range|
        block_given? ? yield(the_data_pair, the_fraction_range) : fraction_range}
      [block.call(data_pair, fraction_range)] +
       self.map_pairs_with_length_fractions(data_pairs.rest, total_length, total_so_far+data_pair_length, &block)
    end
  end

  # Takes the ordered data_pairs and returns ordered points for them. By default this just calls to_unique_points, though some pairs with arbitrary orientation, namely edges, need override behavior.
  def to_ordered_points(ordered_data_pairs)
    to_unique_points(ordered_data_pairs)
  end

  # Orders the given points along the data_pairs, assuming all points lie along one of the pairs.
  def order_points_to_data_pairs(data_pairs, points)
    return [] unless points.length > 0
    raise "The following points were not on any of the data_pairs. Points: #{points.inspect}" unless data_pairs.length > 0
    $points = points
    $dp = data_pairs
    data_pair = data_pairs.first
    matching_points = points.find_all {|point| data_pair.point_between?(point)}
    nonmatching_points = points.reject_any(matching_points)
    data_pair.order_points_to_data_pair(matching_points) + order_points_to_data_pairs(data_pairs.rest, nonmatching_points)
  end

  # Divide the pairs by the number given, returning the divide points and optionally the vector_direction of the data_pair they lie on
  # In the latter case the result will be a set of two element arrays
  def divide(ordered_data_pairs, number_of_points, also_return_direction_vector=false)
    # Make a fake set of data_pairs of number_of_points length that each have the same pair length.
    pair_length = self.composite_length(ordered_data_pairs)/number_of_points
    fake_vector = Geom::Vector3d.new(pair_length,0,0)
    origin = Geom::Point3d.new
    fake_data_pairs = (0..number_of_points).map {|index| Simple_Pair.new(
        [origin.transform(fake_vector.clone_with_length(index*pair_length)),
        origin.transform(fake_vector.clone_with_length((1+index)*pair_length))])
    }
    # Sync the ordered_data_pairs to the fake data_pairs returning a hash keyed by each fake data_pair and valued by the partial_data_pairs of the ordered_data_pairs, where the partials represent the same range percentage as the fake data_pair
    data_pair_to_partial_data_pairs = sync_data_pair_set_to_data_pair_set(ordered_data_pairs, fake_data_pairs)
    # Take the first and last point of each hash value, flatten, and make unique to give us the desired points
    results = fake_data_pairs.flat_map {|fake_data_pair|
      data_pairs = data_pair_to_partial_data_pairs[fake_data_pair]
      point_extremes = self.point_extremes(data_pairs)
      also_return_direction_vector ?
          # Return the extreme points with their original full data_pair
          [[point_extremes[0], data_pairs.first.data_pair.vector], [point_extremes[1], data_pairs.last.data_pair.vector]] :
          # Just return the extreme points
          point_extremes
    }
    also_return_direction_vector ?
      results.uniq_consecutive_by_map_with_merge(
          lambda {|data| data[0].hash_point},
          lambda {|data1, data2| [data1[0], data1[1]+data2[1]]}) :
      Geom::Point3d.unique_consecutive_points(results)
  end

  # Divides by the approximate length given. If the length is greater than the pair, the pair points will be returned
  # If the length is half or just under half the pair, then three points will be returned, etc.
  def divide_by_approximate_length(ordered_data_pairs, length)
    divide(ordered_data_pairs, self.composite_length(ordered_data_pairs) / length)
  end
  
  def divide_into_partials_by_approximate_length(ordered_data_pairs, length, create_sets=false)
    divide_into_partials_at_points(ordered_data_pairs, divide_by_approximate_length(ordered_data_pairs, length), create_sets)
  end

  def divide_into_partials(ordered_data_pairs, number_of_points, create_sets=false)
    divide_into_partials_at_points(ordered_data_pairs, divide(ordered_data_pairs, number_of_points), create_sets)
  end


  # Given an ordered set of data_pairs, divides them at given points. The points must each lie between a pair but the order of the points does not matter, as they will be sorted to aligned with the ordered_data_pairs direction
  # The optional create_sets will return sets of Partial_Data_Pairs delineated at the divide_point created by the unordered_points. If a point falls at the first point of the first pair or last point of the last pair an empty set will be returned at the start or end, respectively. The default of false will simply return a flat list of Partial_Data_Pairs
  # allow_end_points_off_path permits two points to be off the path, with the assumption that they don't quite lie on the path but near the ends. Those points will be ignored by the divide
  def divide_into_partials_at_points(ordered_data_pairs, unordered_points, create_sets=false)
    points_on_path = unordered_points.find_all {|point| point_between_any_pair?(ordered_data_pairs, point)}
    raise "The following points were off the path unexpectedly #{(Set.new(unordered_points) - Set.new(points_on_path)).inspect}" if
        (unordered_points.length-points_on_path.length) > 0
    points = order_points_to_data_pairs(ordered_data_pairs, points_on_path)
    divide_into_partials_at_ordered_points(ordered_data_pairs, points, create_sets, false)
  end

  # Like divide_into_partials_at_points but with the points already ordered according to the data_pairs.
  # The optional argument allow_end_points_off_path defaults to true and allows the first and last point to be off the path. In this case an extra set is created at the start and/or end if either point is off the path (if create_sets=true)
  def divide_into_partials_at_ordered_points(ordered_data_pairs, ordered_points, create_sets=false, allow_end_points_off_path=true)
    #begin
      points_on_path = ordered_points.find_all {|point| point_between_any_pair?(ordered_data_pairs, point)}
      end_points = ordered_points.extremes()

      # Make sure only the end_points are off if allowed
      if (points_on_path.length < ordered_points.length && (!allow_end_points_off_path || end_points.all?{|end_point| points_on_path.member?(end_point)}))
        raise "The following points were off the path unexpectedly #{(Set.new(ordered_points) - Set.new(points_on_path)).inspect}"
      end

      partial_data_pairs = internal_divide_into_partials_at_points(ordered_data_pairs, points_on_path)
      if (create_sets)
        sets = partial_data_pairs.create_sets_when(true) {|partial_data_pair|
          partial_data_pair.points.first.member?(ordered_points)
        } +
            # Append and empty set if the last point matches the end of the last pair. create_sets will add an empty set at the start for the case of the first poin matching the first point of the first partial_data_pair
            ((create_sets && ordered_points.length > 0 && partial_data_pairs.last.points.last.matches?(ordered_points.last)) ? [[]] : [])
        # If the first or last point fell off the path create empty sets to represent them
        (points_on_path.member?(ordered_points.first) ? [] : [[]]) +
        sets +
        (points_on_path.member?(ordered_points.last) ? [] : [[]])
      else
        partial_data_pairs
      end
    #rescue Exception => e
    #  $error_points = unordered_points
    #  $error_data_pairs = ordered_data_pairs
    #  raise "Some of the points #{points_on_path.inspect} where not along the data_pairs #{ordered_data_pairs.inspect} --> #{e.message}"
    #end
  end

  # Divides an ordered set of Pair_To_Point_Data items into Partial_Data_Pairs by grouping them by common data_pair and then dividing the common data_pairs by the points
  # Returns a flattened list of Partial_Data_Pairs
  def divide_pair_to_points_into_partials(ordered_pair_to_point_data_instances)
    ordered_pair_to_point_data_instances.create_sets_with_previous_when {|pair_to_point_data1, pair_to_point_data2|
      pair_to_point_data1.data_pair != pair_to_point_data2.data_pair
    }.flat_map {|pair_to_point_data_set|
      pair_to_point_data_set.first.data_pair.divide_into_partials_at_points(pair_to_point_data_set.map {|ppd| ppd.point})
    }
  end

  def internal_divide_into_partials_at_points(ordered_data_pairs, points)
    return [] unless ordered_data_pairs.length > 0
    data_pair = ordered_data_pairs.first
    matching_points = points.take_whilst {|point|
      data_pair.point_between?(point)
    }
    partial_data_pairs = data_pair.divide_into_partials_at_points(matching_points)
    # Create a separate set or flatten depending on the flag
    partial_data_pairs +
    self.internal_divide_into_partials_at_points(ordered_data_pairs.rest, points[matching_points.length..-1])
  end

  # Syncs the first set of data_pairs to the second by dividing the first pairs to match the length in relative percentage of the second set. This could split some data_pairs and leave others whole, resulting in the same path with more intermediate points.
  # The optional result_hash_lambda is described in divide_data_pairs, which is called by this method. It can be used to return different results if needed.
  # Returns a hash keyed by each data_pair and valued by the 0 or more partial_data_pairs created by dividing sync_data_pairs
  # The partial_data_pairs within each data_pair are ordered.
  def sync_data_pair_set_to_data_pair_set(sync_data_pairs, data_pairs, result_hash_lambda=nil)
    sync_data_pair_fraction_range_sets = self.map_pairs_with_length_fractions(sync_data_pairs) {|data_pair, fraction_range|
      {:pair=>data_pair, :range=>fraction_range}
    }
    data_pair_fraction_range_sets = self.map_pairs_with_length_fractions(data_pairs) {|data_pair, fraction_range|
      {:pair=>data_pair, :range=>fraction_range}
    }
    arguments = [sync_data_pair_fraction_range_sets, data_pair_fraction_range_sets] + (result_hash_lambda ? [result_hash_lambda] : [])
    results = self.divide_data_pairs(*arguments)
    # Merge the hashes by combining the values of each key. This by default returns each data_pair as a key with all the partial sync_data_pairs as ordered values
    results.merge_hashes {|key, left, right| left+right}
  end

  # Expects two sets of data_pairs each mapped to a range that represents that data_pair's range of the total distance for the array of each data_pair. Divides the first set of data_pairs according to the ranges of the second. The first set is divided into a number of sets equaling that of the second, where each division is based on the relative length of the second set ranges.
  # The optional result_hash_lambda formats the result hash of the operation. It takes a resultant data_pair and sync_data_pair, where the sync_data_pair may be left whole or a partial_data_pair. By default it creates the hash described below.
  # Returns a list of one element hashes keyed by each data_pair and valued by a one element array of a partial_data_pair created by dividing sync_data_pairs unless result_hash_lambda overrides. The order of the results is consistent with the order of the data_pairs in data_pair_and_fraction_range_set. The format allows easy merging by the caller if desired.
  def divide_data_pairs(sync_data_pair_and_fraction_range_set, data_pair_and_fraction_range_set, result_hash_lambda=lambda{|sync_data_pair, data_pair| {data_pair=>[sync_data_pair]}})
    if (sync_data_pair_and_fraction_range_set.length == 0)
      []
    else
      data_pair = data_pair_and_fraction_range_set.first[:pair]
      data_pair_range_fraction = data_pair_and_fraction_range_set.first[:range]
      sync_data_pair = sync_data_pair_and_fraction_range_set.first[:pair]
      sync_data_pair_fraction_range = sync_data_pair_and_fraction_range_set.first[:range]
      first_last_members = [data_pair_range_fraction.member?(sync_data_pair_fraction_range.first), data_pair_range_fraction.member?(sync_data_pair_fraction_range.last)]
      if (first_last_members.all?)
        # sync_data_pair falls within data_pair range, leave it whole
        [result_hash_lambda.call(sync_data_pair, data_pair)] + divide_data_pairs(
            sync_data_pair_and_fraction_range_set.rest,
            data_pair_range_fraction.last==sync_data_pair_fraction_range.last ?
                data_pair_and_fraction_range_set.rest : # only advance this for the above corner case`
            data_pair_and_fraction_range_set,
            result_hash_lambda)
      elsif (first_last_members.first)
        # start of sync_data_pair falls within data_pair range, divide and assign each
        sync_data_pair_percent = (data_pair_range_fraction.last-sync_data_pair_fraction_range.first) / (sync_data_pair_fraction_range.last-sync_data_pair_fraction_range.first)
        partial_point_pairs=sync_data_pair.divide_into_partials_at_fraction(sync_data_pair_percent)
        # Return the first half of the divide and send the second half to the next iteration with a range from the end of the data_pair range to the end of the sync_data_pair range
        [result_hash_lambda.call(partial_point_pairs.first, data_pair)] +
            divide_data_pairs(
              [{:pair=>partial_point_pairs.last, :range=>Range.new(data_pair_range_fraction.last, sync_data_pair_fraction_range.last)}] + sync_data_pair_and_fraction_range_set.rest,
              data_pair_and_fraction_range_set.rest,
            result_hash_lambda)
      else
        raise "Unexpected case #{first_last_members.inspect} #{data_pair_and_fraction_range_set.inspect} - #{sync_data_pair_and_fraction_range_set.inspect}"
      end
    end
  end

  # Gets the extreme points of an ordered set of data_pairs
  def point_extremes(ordered_data_pairs)
    [ordered_data_pairs.first.points.first, ordered_data_pairs.last.points.last]
  end

  # Gets the extreme Data_Points of an ordered set of data_pairs
  def data_point_extremes(ordered_data_pairs)
    [ordered_data_pairs.first.data_points.first, ordered_data_pairs.last.data_points.last]
  end

  # Returns a Range indicating the percent of each point of the data_pair within the data_pairs. The data_pair need not match one of the data_pairs, but its two points must lie along the path of the data_pairs. Otherwise its points points will be projected to the data_pairs which may lead to unintended results
  def range_of_data_pair(data_pairs, data_pair)
    path = to_unique_points(data_pairs)
    path_to_point_data_intersections = data_pair.points.map {|point|
      Path_To_Point_Data.new(path, point, data_pairs)
    }
    total_length = self.composite_length(data_pairs)
    Range.new(*path_to_point_data_intersections.map {|path_to_point_data_intersection|
      partial_length = path_to_point_data_intersection.composite_length_to_point_on_path
      partial_length.to_f/total_length
    })
  end

  # The opposite of point_extremes, takes all points of the order_data_pairs excluding the extremes
  def intermediate_points(ordered_data_pairs)
    self.to_ordered_points(ordered_data_pairs)[1..-2]
  end

  # Given pairs and a point, take all the pairs up to the pair with the end point that is closest to point. Or if the start point of the first pair is closest, return an empty list.
  # Append a pair that connects the closest point of pairs to point if include_connector is true (true by default). The created pair is made by clone_with_new point on the first pair that is not returned
  # Example
  # ---- (pairs)
  #   * (point)
  # --  returned if include_connector=false
  # --\ returned if include_connector=true, where \ is cloned from the third pair
  def pairs_up_to_point(pairs, point, include_connector=true)
      start_pair = pairs.first
      rest = pairs.rest
      main_distance = start_pair.points.last.distance(point)
      next_start_pair = rest.first
      [pairs.first] +
          ((!next_start_pair || (main_distance < next_start_pair.points.last.distance(point))) ?
            (include_connector ? [next_start_pair.clone_with_new_points([next_start_pair.points.first, point])] : []) :
            pairs_up_to_closest_point(rest, point, include_connector))
  end

  # Likes pairs_up_to_point, but takes all pairs after the pair whose start is closest to the given point. Optionally includes a connector pair from the point to the start point of the first pair
  def pairs_from_point(pairs, point, include_connector=true)
    start_pair = pairs.first
    rest = pairs.rest
    main_distance = start_pair.points.first.distance(point)
    next_start_pair = rest.first
    if (!next_start_pair)
      []
    else
      ((main_distance < next_start_pair.points.first.distance(point)) ?
            (include_connector ? [next_start_pair.clone_with_new_points([point, next_start_pair.points.first])] : []) + rest :
            pairs_from_point(rest, point, include_connector))
    end
  end

  # Connect two pair sets where they are closest.
  def fuse_pair_sets(pairs1, pairs2)
    fuse_point = Simple_Pair.new([pairs1.first.points.first, pairs2.last.points.last]).middle_point
    point_on_path1 = Path_To_Point_Data.from_pairs(pairs1, fuse_point).point_on_path
    partial_data_pairs1 = self.divide_into_partials_at_ordered_points(pairs1, [point_on_path1], true, true)[0]
    point_on_path2 = Path_To_Point_Data.from_pairs(pairs2, fuse_point).point_on_path
    partial_data_pairs2 = self.divide_into_partials_at_ordered_points(pairs2, [point_on_path2], true, true)[1]
    partial_data_pairs1+partial_data_pairs2
  end
end