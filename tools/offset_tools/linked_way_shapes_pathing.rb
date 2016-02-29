require 'wayness/side_point_pair'
require 'wayness/way_point_pair'
require 'utils/lambda_wrapper'
require 'wayness/Side_Point_Generator'

# Solves paths for Linked_Way_Shapes. This module expects to be used by Linked_Way_Shapes only
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Linked_Way_Shapes_Pathing

  START=0
  MIDDLE=1
  ENDING=2
  # Solves the path between the last two way_shapes, since the previous path is always finalized when this instance is constructed. This may be overridden for custom pathing between the two way shapes.
  def solve_active_data_pair_set(way_shapes)
    way_shapes.length > 1 ?
        solve_and_offset_path([way_shapes[-2], way_shapes[-1]]) :
        solve_and_offset_lone_way_shape(way_shapes[-1])
  end

  # For way_shapes connected directly without using the ways, make the path with a side_point_generator
  def create_direct_path_data_pair_set(way_shapes)
    solve_direct_path(way_shapes)
  end

  # Solves the path made by two way_shapes, returning Side_Point_Pairs
  # If the path cannot be solved because the way_shapes are not indirectly connected, return a Bad_Path containing the side_point_pair representation of the way_shapes
  def solve_and_offset_path(way_shape_pair)
    if (can_solve_path?(way_shape_pair))
      # The way_shapes are solvable in that a path can be made between the two ways or shared way that each represents.
      (linked_ways_path, modified_way_shape_pair) = solve_path(way_shape_pair)
      offset_data_pairs_of_linked_way_path(linked_ways_path, modified_way_shape_pair)
    else
      if (offset_configuration.make_unsolvable_way_based_paths_direct?)
        # Since the path is not solvable simply connect the points of each way_shape_pair directly without trying to find intermediate points
        solve_direct_path(way_shape_pair)
      else
        # If the configuration doesn't allow handling unsolvable paths, raise an error.
        raise_bad_path(way_shape_pair)
      end
    end
  end

  # Solve the when there is only one way_shape defined
  def solve_and_offset_lone_way_shape(way_shape)
    $mw1= way_shape
    # Rather than solving the path between way_shapes, we take the data_pair of this way shape and split it at the point of the user's cursor. The half of the data_pair returned depends on direction of the user's cursor movement, or if the user has already clicked a position for the way_shape, it depends on the direction from that click to the user's current position. Also, if the way_shape was aligned using keyboard input, the half should be based on the previous data_point to keep it from flipping.
    $mw2= modified_way_shape = way_shape.orient_to_vector(
        way_shape.input_point.frozen? &&
        !way_shape.input_point.position.matches?(self.data_point.position)  &&
        !way_shape.options[:keyboard_input] ?
          way_shape.input_point.vector_to(self.data_point.position) : # click point to current position
          self.data_point.vector_from_previous_point) # previous position to current position
    # Trim the data_pair at the way_shape.point_on_path (the user's input point). Make its data_pair an array to match solve_and_offset_path. Always pass true to treat the way_shape as a starting way_shape in a path. This way the segment of way_point_pair displayed will start at the user's cursor and continue in the direction of the mouse movement.
    trimmed_data_pairs=trim_data_pairs_for_end_way_shapes(
        modified_way_shape.as_array,
        modified_way_shape.data_pair.as_array, START).only.points
    modified_way_shape.as_side_point_pair(trimmed_data_pairs).as_array
  end

  # Solve a direct path between way_shapes, meaning no path solving between the way_shapes occurs. Their points are simply connected directly together.
  def solve_direct_path(way_shapes)
    data_pairs = Geom::Point3d.to_simple_pairs(way_shapes.flat_map {|way_shape| way_shape.point.trail_of_points})
    make_offset_data_pairs_for_direct_paths(data_pairs)
  end

  # Returns the data_pairs of the path without offsetting them
  def solve_without_offset(way_shape_pair)
    (linked_ways_path, modified_way_shape_pair) = solve_path(way_shape_pair)
    way_point_pairs = linked_ways_path.map {|linked_way| linked_way.way_point_pairs}.shallow_flatten
    way_point_pair_to_data_pair_lookup = build_way_point_pair_hash_to_data_pairs(way_point_pairs, modified_way_shape_pair)
    way_point_pair_to_index = resolve_way_point_pair_to_index(way_point_pairs, way_point_pair_to_data_pair_lookup, modified_way_shape_pair)
    create_partial_data_pair_sets(way_point_pair_to_data_pair_lookup, way_point_pairs, way_point_pair_to_index, modified_way_shape_pair)
  end

  # Solves the path of data_pairs between the two way_shapes of way_shape_pair
  def solve_path(way_shape_pair)
    $lww=linked_ways_path = way_grouping.solve_shortest_path_for_way_shapes(way_shape_pair)
    # Orient each way_shapes' data_pair so that they match the direction of the path. This means possibly reversing each way_shape's data_pair to match the direction of the linked_ways_path. Hence, a way_point_pair might be reversed or an edge made into a special Reverse_Edge class
    $before = way_shape_pair
    # Orient each way_shape to the extreme way_point_pairs of the path. If there's only one way_point_pair, we must orient by a simple pair between the way_shape.point
    $pair = way_point_pair_pair =
        (linked_ways_path.length==1 && linked_ways_path.only.way_point_pairs.length==1) ?
          Simple_Pair.new(way_shape_pair.map {|way_shape| way_shape.point.position}).as_array(2) :
          [linked_ways_path.first.way_point_pairs.first, linked_ways_path.last.way_point_pairs.last]

    $after = modified_way_shape_pair = way_shape_pair.dual_map(way_point_pair_pair) {|way_shape, pair|
      way_shape.orient_to(pair)
    }
    [linked_ways_path, modified_way_shape_pair]
  end

  # Raises an exception if a path is unsolvable
  def raise_bad_path(way_shape_pair)
    raise "Bad Path: #{way_shape_pair.map {|way_shape| way_shape.as_side_point_pair}.inspect}"
  end

  # Tests to see if any path exists between the two way_shapes. This will grab the solved path from the cache or try to solve for the first not-shortest solution
  def can_solve_path?(way_shape_pair)
    way_grouping.can_solve_path?(way_shape_pair)
  end

  # Resolves which data_pairs to used based on the linked_ways_path, then offsets them based on the offset of the way_shapes
  def offset_data_pairs_of_linked_way_path(linked_ways_path, way_shape_pair)
    $lwp = linked_ways_path
    $vax=way_shape_pair
    # Gather all the way_point_pairs of the path between the way_shapes. This may be 1 way_point_pair shared by the two way_shapes or many way_point_pairs with two belonging to the way_shapes and intermediate ones.
    $wpp=way_point_pairs = linked_ways_path.map {|linked_way| linked_way.way_point_pairs}.shallow_flatten
    # Map each way_point_pair to a lookup array containing each edge_set of the way_point_pair and the way_point_pair itself.
    # The two edge_sets and way_point_pair represent the options for associating each way_point_pair
    # This hash associates each way_point_pair to its two edges and to itself (function as a center line), unless edges or ways are ineligible
    $xdf=way_point_pair_hash_to_data_pairs_lookup = build_way_point_pair_hash_to_data_pairs(way_point_pairs, way_shape_pair)
    # The edge_sets/way_point_pair to which the way_point_pair resolves is determined by the edge_set/way_point_pair with which the way_shapes associate. If both way_shapes refer to the same side of edges, all intermediate way_point_pairs will refer to edge_sets on that side. If the way_shapes have different associations, half will resolve to the edge_set/way_point_pair of the first way_shape, and the other half the other set.
    # The index is therefore 0 for way_point_pair or 1, 2 for either edge_set (unless way_point_pairs are disallowed, see the method)
    # In the case where the way_shapes associate to the same way_point_pair, the association of the first will be returned here
    way_point_pair_to_index = resolve_way_point_pair_to_index(way_point_pairs, way_point_pair_hash_to_data_pairs_lookup, way_shape_pair)
    # With the index resolved for each way_point_pair map the way_point_pair to itself or the edge_set that was chosen
    # The edge/way_point_pairs selected may be trimmed into Partial_Data_Pairs if they lie at the ends of the path in order to conform to where the user clicked
    $parx=partial_data_pairs = create_partial_data_pair_sets(way_point_pair_hash_to_data_pairs_lookup, way_point_pairs, way_point_pair_to_index, way_shape_pair)
    # Finally offset each data_pair based on the cursor offset of the two way_shapes, where the offset of the intermediate data_pairs are a weighted average of the two way_shape offsets
    $zzz=offset_data_pairs_between_way_shape_pair(partial_data_pairs, way_shape_pair)
  end

  # Map the way_point_pairs of the path to their edges on both sides if either way_shape_pair represents an edge. If the two way_shapes both map to way_point_pairs, meaning to center line segments, then no edges are needed, since the path will use only way_point_pairs
  def build_way_point_pair_hash_to_data_pairs(way_point_pairs, way_shape_pair)
    # If either way_shape_pair represents an edge, create a hash of linked_ways to ordered edges for the edges of both sides
    way_shapes_are_edges = way_shape_pair.map {|way_shape| way_shape.is_edge?}

    # Hash each way_point_pair to 1 or 3 values. If no edges are in use the one value is the corresponding way_point_pair.
    # If edges are in use the other two values are each each corresponding to the set of edges on either side of the way_point_pair
    create_way_point_pair_hash_to_data_pairs_lookup(way_point_pairs, way_shapes_are_edges.any?)
  end

  # Get all way_point_pairs and both ordered edge sets associated to each linked_way and the reverse linked_way. Convert the edges to Side_Point_Pairs. Create a hash keyed by linked_way and with three collections for values
  # Set any_edges=false to avoid finding edges if unneeded
  def create_way_point_pair_hash_to_data_pairs_lookup(way_point_pairs, any_edges=true)
    way_point_pairs.map_to_hash(
      lambda {|way_point_pair| way_point_pair.hash},
      lambda {|way_point_pair|
      [[way_point_pair]] +
          (any_edges ?
              [@way_grouping.entity_map.sorted_edges_associated_to_way_point_pair(way_point_pair)]+
                  [@way_grouping.entity_map.sorted_edges_associated_to_way_point_pair(way_point_pair.reverse, true)] : [])
    })
  end

  # Based on whether the way_shapes represent the same edge set or way_point_pair (functioning as a center line segment), determine what the intermediate way_point_pairs should represent.
  # Returns a mapping from way_point_pair to an index, where 0 is way_point_pair and 1 and 2 are either edge set
  def resolve_way_point_pair_to_index(way_point_pairs, way_point_pair_hash_to_data_pairs_lookup, way_shape_pair)
    $f1=way_point_pair_hash_to_data_pairs_lookup
    # Find the indices into the data_pair_lookup for each way_shape
    way_shape_set_indices = way_shape_pair.map {|way_shape|
      index_of_matching_data_pair_set(
        data_pairs_of_way_shape(way_point_pair_hash_to_data_pairs_lookup, way_shape),
        way_shape.data_pair)
    }
    # Map each way_point_pair to the resolved index of the closest way_shape
    way_point_pairs.to_hash_keys {|way_point_pair|
      way_shape_set_indices[way_point_pairs.index(way_point_pair) < way_point_pairs.length/2.to_f ? 0 : 1]
    }
  end

  # Given a linked_way_path, returns the points of the way path or the offset points for portions of the path that match the way_shapes. The way_shapes each represent a way_point_pair at the extreme ways of the linked_ways_path. Thus we'll need to split these end ways at the way_point_pairs and we'll further divide those way_point_pairs in two based on the user's input point for that way_shape. We end up with a partial_data_pair on each end with all the complete data_pairs of the intermediate linked_ways. The data_pairs can be both edges and way_point_pairs depending what part of the surface the user selected.
  def create_partial_data_pair_sets(way_point_pair_hash_to_data_pairs_lookup, way_point_pairs, way_point_pair_to_index, way_shape_pair)
    # Create partial_data_pairs for the way_shapes based on the way_shape's point_on_pair
    # Each data_pair set will often be just one edge or way_point_pair, but could be multiple edges if multiple edges apply to one way_point_pair
    $kib=data_pair_sets = way_point_pairs.map {|way_point_pair|
      resolve_data_pairs(way_point_pair_hash_to_data_pairs_lookup, way_point_pair, way_point_pair_to_index)
    }

    # Create the path based on the two way shapes and the data_pair sets in between
    # trim_data_pair will shorten the data_pairs of the way_shape based on where the user clicked to create the way_shape (the way_shape.pair_to_point_data.point). The intermediate data_pair_sets are not modified since they connect the way_shape data_pairs
    if (way_shape_pair.first.is_way_point_pair_match?(way_shape_pair.last))
      # Resolve the data_pair_sets of each way_shape since they share a way_point_pair, making lookup by way_point_pair inadequate
      $wan=way_shape_data_pair_sets = way_shape_pair.map {|way_shape|
        resolve_data_pairs_for_shared_way_point_pair(way_point_pair_hash_to_data_pairs_lookup, way_shape)
      }
      if (way_shape_data_pair_sets.sets_all_same?)
        # If the two way_shapes share the same way_point_pair and data_pair_set, we need to trim down the one or more data_pairs associated to the way_point_pair to a Partial_Data_Pair between the click point of each way_shape.
        $dib=trim_data_pairs_for_end_way_shapes(way_shape_pair, way_shape_data_pair_sets[0], MIDDLE)
      else
        # If the two way_shape have the same way_point_pair but associate to a different data_pair sets (e.g. the first to one edge set and the second to the center line) then handle them separately and merge connect them at their closest points
        $ch1=start=trim_data_pairs_for_end_way_shapes([way_shape_pair[0]], way_shape_data_pair_sets[0], START)
        $e1=ending=trim_data_pairs_for_end_way_shapes([way_shape_pair[1]], way_shape_data_pair_sets[1], ENDING)
        # For now just grab as many starting pairs up until the end of the ending pairs which overlap like this
        $z1=Simple_Pair.fuse_pair_sets(start, ending)
      end
    else
      # If each way_shape is associated to a different way_point_pair, we trim them separately and then join them with the middle sets that aren't trimmed at all
      start=[trim_data_pairs_for_end_way_shapes([way_shape_pair[0]], data_pair_sets[0], START)]
      middle=data_pair_sets[1..-2]
      ending=[trim_data_pairs_for_end_way_shapes([way_shape_pair[1]], data_pair_sets[-1], ENDING)]
      $dob=(start+middle+ending).shallow_flatten
    end
  end

  # Resolves the data_pair(s) of an intermediate way_point_pair of the path
  def resolve_data_pairs(way_point_pair_hash_to_data_pairs_lookup, way_point_pair, way_point_pair_to_index)
    way_point_pair_hash_to_data_pairs_lookup[way_point_pair.hash][way_point_pair_to_index[way_point_pair]]
  end



  # Resolve the data_pairs of a way_shape for the somewhat special case where two way_shapes map to different data_pair sets of the same way_point_pair
  def resolve_data_pairs_for_shared_way_point_pair(way_point_pair_hash_to_data_pairs_lookup, way_shape)
      data_pairs_of_way_shape(way_point_pair_hash_to_data_pairs_lookup, way_shape).find {|data_pair_set|
        data_pair_set.find {|data_pair| data_pair.points_match?(way_shape.data_pair)}
      }
  end

  # Given one or more way_shapes (several are permitted if they all pertain to the same way_point_pair) that lie at the start, middle, or end of a path and the ordered_data_pairs that representing the linked_way upon which these way_shapes lie, return a trimmed version of the ordered_data_pairs up to or leading from the position of the way_shapes' click point. Thus if only one way_shape pertains to the first way_point_pair of the path, the data_pair will go from the way_shape's click point to its end point. If multiple way_shapes are defined that pertain to the first way_point_pair of the path, then data_pairs from the first's click point to the next's and so on until the end point of the last will be returned. The same apply for the way_shapes(s) at the end of the path, except that it starts with the first way_shapes first point and goes to the click point of the last way_shape.
  # For the start of path case, if one way_shape is defined for the way_point_pair:
  #-------------- way_point_pair total length
  #---(*--------) edge or center line of way_point_pair * is way_shape click point, so take way_shape's Partial_Data_Pair from click point to end
  #
  # For the start of path case, if two way_shapes are defined for the way_point_pair:
  #-------------- way_point_pair total length
  #---(*---*-----) edge or center line of way_point_pair * is way_shape click point, so take two way_shapes' Partial_Data_Pairs from click point of first to click point of second, then from click point of second to end. This is different than the above case because two Partial_Data_Pairs are returned.
  # This method is also used to create the path of a way_shape when no other way_shapes exist, in which case the ordered_data_pairs are only the data_pair of the way_shape, and position is based on the direction of the user's cursor movement toward the next way_shape.
  # ordered_data_pairs are all the edges or the way_point_pair itself (functioning as a center line segment) corresponding to the way of the way_shape's way_point_pair
  # position is START, MIDDLE, or ENDING
  def trim_data_pairs_for_end_way_shapes(way_shapes, ordered_data_pairs, position)
    raise "way_shapes don't share the same_way_point_pair: #{way_shapes.inspect}" unless way_shapes.map {|way_shape| way_shape.way_point_pair}.uniq_by_hash.length==1
    $wsh=way_shapes
    $pos = position
    $o1 = ordered_data_pairs
    $ps=points = way_shapes.map {|way_shape| way_shape.point_on_path}
    way_shape_data_pairs = way_shapes.map {|way_shape| way_shape.data_pair}
    if (!@offset_configuration.allow_partial_data_pairs?)
      way_shape_data_pairs.uniq
    else
      # Divide the way_shapes at the their point_on_path (the place the user clicked) and hash by the corresponding point of the way_shape. If partial_data_pairs are not allowed, return the data_pair whole
      $q1=partial_data_pair_sets =  Simple_Pair.divide_into_partials_at_ordered_points(ordered_data_pairs, points, true, true)
      case position
        when START
          # Take everything from the click point to the end of the data_pairs
          subset_of_partial_data_pairs = start_data_pairs(partial_data_pair_sets)
        when ENDING
          # Take everything from the start of the data_pairs to the click point
          subset_of_partial_data_pairs = end_data_pairs(partial_data_pair_sets)
        when MIDDLE
          # Take the intermediate sets
          subset_of_partial_data_pairs = partial_data_pair_sets.intermediates.shallow_flatten
      end
      $spdp=subset_of_partial_data_pairs
    end
  end

  def start_data_pairs(partial_data_pair_sets)
    rest = partial_data_pair_sets.rest.shallow_flatten
    (rest.length > 0) ?
        rest :
        [Partial_Data_Pair.minimum_data_pair_from_last_point(partial_data_pair_sets[0].last)]
  end

  def end_data_pairs(partial_data_pair_sets)
    all_but_last = partial_data_pair_sets.all_but_last.shallow_flatten
    (all_but_last.length > 0) ?
        all_but_last :
        [Partial_Data_Pair.minimum_data_pair_from_first_point(partial_data_pair_sets[-1].first)]
  end

  def data_pairs_of_way_shape(way_point_pair_hash_to_data_pairs_lookup, way_shape)
    way_point_pair_hash_to_data_pairs_lookup[way_shape.way_point_pair.hash].or_if_nil {
      $a1 = way_point_pair_hash_to_data_pairs_lookup
      $a2 = way_shape
      raise "The way_shape.way_point_pair of hash #{way_shape.way_point_pair.hash} was not found among the keys of #{way_point_pair_hash_to_data_pairs_lookup.inspect}"}
  end

  # Find the index of the data_pair_set matching the given way_shape_data_pair
  def index_of_matching_data_pair_set(way_point_pair_data_pair_sets, way_shape_data_pair)
    (0..way_point_pair_data_pair_sets.length-1).find {|index| way_point_pair_data_pair_sets[index].find {|data_pair| data_pair.points_match?(way_shape_data_pair)}}
  end

  def offset_data_pairs_between_way_shape_pair(data_pairs, way_shape_pair)
    # The way_shapes correspond to the ends of the solved path. Based on the offset distance between the end pairs of the path, we determine the offset distance for the rest of the pairs
    way_shape_side_point_pairs = way_shape_pair.dual_map(data_pairs.extremes) {|way_shape, data_pair|
      way_shape.as_side_point_pair(data_pair.points)
    }

    # Offset each data_pair according to its fraction of the total length. The way_shape data_pairs are offset to match the click point of each way_shape
    offset_data_pairs_with_side_point_generator(
        data_pairs,
        way_shape_side_point_pairs,
        way_shape_pair.first.points_match?(@way_shapes[0]),
        false)
  end

  # Offsets each data_pair by a fraction of the offset_vector_range and returns the pair
  def offset_data_pairs_with_side_point_generator(data_pairs, way_shape_side_point_pairs, include_first_way_shape, differing_associations)
    $ovr= offset_vector_range = calculate_offset_vector_range(data_pairs, way_shape_side_point_pairs)
    # Store if the rotations are counterclockwise or clockwise to the side_point_pairs
    rotations = data_pairs.extremes.dual_map(offset_vector_range.to_a) {|data_pair, offset_vector|
      data_pair.rotation_to(offset_vector)
    }
    # Connect the data_pairs where they don't connect
    $cest=connected_data_pairs = connect_data_pairs(data_pairs)
    # Map the way_shape data_pairs to the offset vectors
    $est = data_pair_to_offset_vectors = (connected_data_pairs.length == 1 ?
      # If their is only one data_pair because they share the same one, map it to the two vector ranges
      {connected_data_pairs.only => offset_vector_range} :
      # If there are two, map each to two copies the corresponding one of the range
      connected_data_pairs.extremes.dual_hash(
        offset_vector_range.map {|v| [v,v]}
    )).merge(
      # Calculate the vectors for any intermediate data_pairs
      # Given the fractional percentage of the intermediate length of the start and end point of each intermediate data pair, calculate their two offset vectors somewhere between the offset_vector_range. If differing_associates is set true each data_pair is assigned a different vector length for each end, otherwise each end gets the same length
      Hash[*map_data_pairs_to_vectors(connected_data_pairs.intermediates, offset_vector_range, rotations, differing_associations) {|data_pair, offset_vectors|
        [data_pair, offset_vectors]
      }.shallow_flatten]
    ) {|key, left, right| left}
    # Create a hash that maps the data_pair points to the vectors.
    $best = data_pair_point_hash_to_offset_vectors = data_pair_to_offset_vectors.map_keys_to_new_hash {|data_pair, offset_vectors|
      Geom::Point3d.hash_points(data_pair.points)
    }
    # Also create a hash to map each point to a vector in case a point is eliminated when making side_point_pair
    # Since many of the individual points will map to two values, the last will always be accepted as good enough
    data_pair_single_point_hash_to_offset_vectors = Hash[*data_pair_to_offset_vectors.map {|data_pair, offset_vectors|
       [data_pair.points.first.hash_point, offset_vectors.kind_of?(Array) ? offset_vectors.first : offset_vectors,
       data_pair.points.last.hash_point, offset_vectors.kind_of?(Array) ? offset_vectors.last : offset_vectors]
    }.shallow_flatten]

    # Create a transformation lambda_wrapper that maps the points of the data pair to the corresponding offset vector
    transformation_lambda_wrapper = Lambda_Wrapper.new(lambda {|data_pair|
      # The Way_Shape data_pairs map to a single offset_vector, the intermediate data_pairs map to two
      no_offset_vector = Geom::Vector3d.new
      offset_vectors = data_pair_point_hash_to_offset_vectors[Geom::Point3d.hash_points(data_pair.points)].or_if_nil {
        # If the data_pair points were modified such that the pair no longer matches the original data_pair, then try to match just one of the points
        offsets = data_pair.points.map {|point| data_pair_single_point_hash_to_offset_vectors[point.hash_point]}
        if (offsets)
          #Rescape::Config.log.info("Offset data_pair using a single point by #{offsets.first.length}")
        else
          Rescape::Config.log.warn("Unaable to match data_pair points to data_pair or point of data_pair")
          $unmatched = data_pair
        end
        # If this fails, then don't offset at all
        offsets.length > 0 ? offsets.first : no_offset_vector
      }
      make_orthogonal_point_translation_lambda(data_pair, offset_vectors)
    }, [connected_data_pairs], 2)

    $conn=connected_data_pairs_to_use = (include_first_way_shape || connected_data_pairs.length == 1) ? connected_data_pairs : connected_data_pairs.rest
    # Use a Side_Point_Generator or other technique to make a path from the data_pairs.
    $zex=make_offset_data_pairs(connected_data_pairs_to_use, transformation_lambda_wrapper)
  end

  # Makes lanes divided wherever the data_pairs don't touch
  def connect_data_pairs(data_pairs)
    data_pairs.create_sets_with_previous_when {|current_data_pair, previous_data_pair|
      !previous_data_pair ?
          false :
          previous_data_pair.points.last.hash_point != current_data_pair.points.first.hash_point
    }.map_with_previous_and_subsequent {|previous_data_pairs, current_data_pairs, next_data_pairs|
      # Connect the data_pair_sets when needed
      if (!next_data_pairs)
        # Last set, nothing to do
        last_data_pair = current_data_pairs.last
      elsif (current_data_pairs.last.vector.angle_between(next_data_pairs.first.vector) < 150.degrees)
        # Angle < 150 means we should connect at their intersection, so change the current set to meet at the intersection
        intersection = Geom.intersect_line_line(current_data_pairs.last.points, next_data_pairs.first.points)
        if (intersection && (current_data_pairs.last.point_between?(intersection) || next_data_pairs.first.point_between?(intersection)))
          last_data_pair = current_data_pairs.last.clone_with_new_points([current_data_pairs.last.points.first, intersection])
        else
          last_data_pair = current_data_pairs.last.clone_with_new_points([current_data_pairs.last.points.first, next_data_pairs.first.points.first])
        end
      else
        # Angle > 150 means we should simply connect the current set to start of the next set
        last_data_pair = current_data_pairs.last.clone_with_new_points([current_data_pairs.last.points.first, next_data_pairs.first.points.first])
      end
      modified_data_pairs = current_data_pairs.all_but_last + [last_data_pair]
      if (!previous_data_pairs)
        first_data_pair = modified_data_pairs.first
      elsif (modified_data_pairs.last.vector.angle_between(previous_data_pairs.first.vector) < 150.degrees)
        # Angle < 150 means we should connect at their intersection, so change the current set to meet at the intersection
        intersection = Geom.intersect_line_line(modified_data_pairs.first.points, previous_data_pairs.last.points)
        if (intersection && (modified_data_pairs.first.point_between?(intersection) || previous_data_pairs.last.point_between?(intersection)))
          first_data_pair = modified_data_pairs.first.clone_with_new_points([intersection, modified_data_pairs.first.points.last])
        else
          first_data_pair = modified_data_pairs.first
        end
      else
        # Angle > 150 means do nothing, the previous set will have already adjust to meet this one
        first_data_pair = modified_data_pairs.first
      end
      [first_data_pair] + modified_data_pairs.rest
    }.shallow_flatten
  end

  # Lanes are always temporary and shouldn't be stored to the model
  # Calculate the offset vector range by calculating the offset of the start and end data_pairs
  def calculate_offset_vector_range(data_pairs, way_shape_side_point_pairs)
    way_shape_side_point_pairs.dual_map(data_pairs.extremes) { |way_shape_side_point_pair, data_pair|
      data_pair.vector_to_parallel_pair(way_shape_side_point_pair)
    }
  end

  # Based on the offset_vector_range, map the intermediate data_pairs to offset vectors. Each data_pair is mapped to two offset vectors for its two points. The length of the offset is based on the fraction of the length of the data_pair versus the total data_pairs length.
  # rotations are two values corresponding to the offset_vector_range values. They are each either Geometry_Utils::CCW_KEY or Geometry_Utils::CW_KEY to determine the rotation from the way_shape data_pair vector to the
  # If use_two_lengths_per_data_pair is true, the two points can have different lengths. If it is false, they are each assigned the average length.
  # The block expects each data_pair and the fraction_range where the fraction_range indicates what fraction of the offset_vector range vector length to attribute to each point
  def map_data_pairs_to_vectors(intermediate_data_pairs, offset_vector_range, rotations, use_two_lengths_per_data_pair, &block)
    $idp=intermediate_data_pairs
    Simple_Pair.map_pairs_with_length_fractions(intermediate_data_pairs) {|data_pair, fraction_range|
      # Create the orthogonal vector from the data_pair going counterclockwise or clockwise, depending on whether it's closer to first or second way_shape
      orthogonal = data_pair.orthogonal((fraction_range.first+fraction_range.last)/2 <= 0.5 ?
                                            rotations[0] :
                                            rotations[1])
      if (orthogonal.length==0)
        $bad_data_pair = data_pair
        $bad_fraction_range = fraction_range
        raise "The orthogonal of the data_pair #{data_pair.inspect} from fraction_range #{fraction_range.inspect} is length 0. This shouldn't happen'"
      end

      # Create offset vectors for the two points of the data_pair based on the offset_fraction and offset_vector_range
      offset_vectors = [fraction_range.first, fraction_range.last].map {|offset_fraction|
        Geom::Vector3d.linear_combination(
            offset_fraction,
            orthogonal.clone_with_length(offset_vector_range[1].length),
            1-offset_fraction,
            orthogonal.clone_with_length(offset_vector_range[0].length))
      }
      offset_vectors.if_cond(!use_two_lengths_per_data_pair) {|vectors|
        # If the vectors for each point need to be the same average them here
        vector = Geom::Vector3d.linear_combination(0.5, vectors[1], 0.5, vectors[0])
        [vector, vector]
      }
      block.call(data_pair, offset_vectors)
    }
  end

  # Create a lambda that returns one or two transformation depending on whether offset_vectors is a scalar vector or array
  def make_orthogonal_point_translation_lambda(data_pair, offset_vectors)
    offset_vectoroj = offset_vectors.kind_of?(Array) ? offset_vectors : [offset_vectors]
      # Create a lambda that returns an orthogonal transformation based on the offset_vectors (1 or 2 of them) and the data_pair vector.
      translation_lambdas = offset_vectoroj.map {|offset_vector|
        Geometry_Utils::orthogonal_point_translation_lambda_from_vectors(offset_vector, data_pair.vector, offset_vector.length)
      }
      # Create a lambda that maps the point_pair to the one or two offset_lambdas
      lambda {|point_pair|
        translation_lambdas.map {|translation_lambda| translation_lambda.call(point_pair)}
      }
  end

  # Create a side point generator based on the chosen_path
  # Optionally provide an alternate path, such as a subset of the chosen_path
  def make_offset_data_pairs(data_pairs, transformation_lambda_wrapper)
    raise "data_pairs are empty. This should never happen" unless data_pairs.length > 0
    $lany = lane = Lane.new(Simple_Pair.to_unique_points(data_pairs))
    side_point_generator = Side_Point_Generator.new(Continuous_Ways.new(lane.class, [lane]), {})
    $sany = Side_Point_Manager.new(side_point_generator.make_side_points(transformation_lambda_wrapper)).side_point_pairs()
  end

  # Offset the given data_pair according to the transformations, which may be a single transformation, or an array of two transformations. A single transformation will be used for both points, whereas the array applies a different transformation to each point
  def offset_data_pair(data_pair, transformations)
    transformations = transformations.kind_of?(Array) ? transformations : [transformations, transformations]
    # Create a Side_Point_Pair by offsetting the way_point_pair or edge
    way_point_pair = data_pair.way_point_pair(@way_grouping)
    data_pair.to_side_point_pair_using_transformations(way_point_pair, transformations)
  end

  # This class only cares about the way_based_path as a reference to the way_point_pairs and edges that make up that path. Therefore instead of the default behavior of creating a Side_Point_Generator to make a smooth path, we simply return the data_pairs.
  def make_offset_data_pairs_for_direct_paths(data_pairs)
    lane = Lane.new(Simple_Pair.to_unique_points(data_pairs))
    no_offset = Geom::Vector3d.new
    side_point_generator = Side_Point_Generator.new(Continuous_Ways.new(lane.class, [lane]), {})
    identity_transformation_lambda_wrapper = Lambda_Wrapper.new(lambda {|data_pair|
        make_orthogonal_point_translation_lambda(data_pair, no_offset)
    }, nil, 2)
    Side_Point_Manager.new(side_point_generator.make_side_points(identity_transformation_lambda_wrapper)).side_point_pairs()
  end

end