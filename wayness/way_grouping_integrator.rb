# Provides procedures to integrate new ways into the Way_Grouping that mixes in this module
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Way_Grouping_Integrator

  # Creates a new way_grouping that integrates the given data_pair_sets as ways into the way_grouping and returns a way_grouping with the new ways and divided existing ways that are intersected (and therefore divided) by the new ways
  # dual_way_to_intersection_points maps existing dual_ways to the intersection points at which one or more data_pair sets intersect them. The dual_ways are split at the intersection points and added to the way_grouping.
  # Returns a way_grouping
  def create_minimum_integrated_way_grouping_from_pairs(data_pair_sets, pair_to_point_intersections)
    raise "data_pair_sets do not match pair_to_point_intersections. There should be the same number or one more data_pair_set. data_pair_sets: #{data_pair_sets.inspect} pair_to_point_intersections: #{pair_to_point_intersections}" unless data_pair_sets.length-pair_to_point_intersections.length <= 1

    dual_ways_to_pair_to_point_intersections = dual_ways_to_pair_to_point_intersections(pair_to_point_intersections).
    # Find all the dual_ways adjacent to those that are intersected, but only up to complex intersections of 3 or more ways. This way if an intersection occurs near the end of a way the side_point_pairs of the new ways can account for the adjacent ways. These have no intersections, so make the hash values empty lists
      merge(adjacent_dual_ways_up_to_complex_intersections(pair_to_point_intersections).to_hash_keys {|x| []})
    # Find where the data_pair_sets intersect existing ways and split those ways. We need to include them in the way_grouping to make a surface component that takes the existing side_point_pairs into account
    # Create the way_grouping with the user's path and the split ways. The reversed ways will be included when the way_grouping is created so they need not be added explicitly.
    new_ways = data_pair_sets.flat_map {|data_pairs| self.entity_map.pairs_to_ways(data_pairs)}
    # Combine the new and split ways into a new way_grouping
    ways_to_side_point_pairs = existing_ways_to_side_point_pairs(dual_ways_to_pair_to_point_intersections, data_pair_sets)
    self.make_integrating_way_grouping(
        ways_to_side_point_pairs.keys.uniq_by_map {|way| way.as_dual_way.hash},
        new_ways,
        ways_to_side_point_pairs)
  end

  # Create a Way_Grouping with the chosen_path of edges and their neighbors, which will function as relative points for offsets
  def make_ad_hoc_way_grouping_from_chosen_path_of_edges_and_neighbors(data_pairs)
    edges = Sketchup::Edge.data_pairs_as_edges(data_pairs, self)
    Entity_Map.create_way_grouping_from_pairs_and_adjacent_pairs(edges)
  end

  # Give a sub
  def make_integrating_way_grouping(ways, new_ways, ways_to_side_point_pairs)
    Integrating_Way_Grouping.new(way_class, ways, new_ways, ways_to_side_point_pairs)
  end

  # Finds the ways that are intersected by the give pair_to_point_intersections and then returns the al_ways of those found up to complex intersections.
  def adjacent_dual_ways_up_to_complex_intersections(pair_to_point_intersections)
    dual_ways = dual_ways_to_pair_to_point_intersections(pair_to_point_intersections).keys
    dual_ways.flat_map {|dual_way| dual_way.neighbors_up_to_multiway_intersections()}.uniq.reject_any(dual_ways).find_all {|dual_way|
    # Make sure the dual_way actually has side_point_pairs, otherwise we don't want to include it in the offset
      dual_way.linked_ways.all?{|linked_way|
        !self.entity_map.way_to_ordered_edges_as_side_point_pairs(linked_way).empty?
      }
    }
  end

  # Map the the pair_to_point_intersections to dual_ways and create a dual_way to pair_to_point_intersection hash, where a dual_way can have multiple pair_to_point_intersections
  def dual_ways_to_pair_to_point_intersections(pair_to_point_intersections)
    pair_to_point_intersections.map_to_hash_with_recurring_keys(
        lambda { |pair_to_point_intersection| self.dual_way_by_way_lookup[pair_to_point_intersection.way_point_pair.way] },
        lambda { |pair_to_point_intersection| pair_to_point_intersection })
  end

  # Splits the linked_ways in one direction of the given dual_ways at the given intersection and maps each way_point_pair to side_point_pairs that are also split at the intersections
  def existing_ways_to_side_point_pairs(dual_ways_to_pair_to_point_intersections, data_pair_sets)
    $money =  dual_ways_to_pair_to_point_intersections.map {|dual_way, pair_to_point_intersections|
      $is=intersection_points = pair_to_point_intersections.map {|pair_to_point_intersection| pair_to_point_intersection.point.position}
      dual_way.linked_ways.map {|linked_way|
      # Split the ways wherever they are intersecting by the way_shape positions
        $silly=split_ways = linked_way.divide_at_points(intersection_points)
        # Get the existing side_point_pairs
        $siggy=side_point_pairs = entity_map.way_to_ordered_edges_as_side_point_pairs(linked_way)
        raise "Linked_Way #{linked_way.inspect} has no side_point_pairs" if side_point_pairs.length==0
        # Calculate the intersections of the user's path with the side_point_pairs
        side_point_pair_intersections = calculate_side_point_pair_intersections(pair_to_point_intersections, side_point_pairs, data_pair_sets)
        # Now divide the side_point_pairs at the intersection points, creating a set of partial pairs for each side_point_pair. Some of these will actually split and some won't
        $stable = partial_side_point_pair_sets = Way_Point_Pair.divide_into_partials_at_points(
            $fogger=side_point_pairs,
            $dogger=side_point_pair_intersections,
            true)

        raise "Made #{partial_side_point_pair_sets.length} partial_side_point_pair sets when there are #{split_ways.length} split ways and #{side_point_pair_intersections.length} intersections" unless partial_side_point_pair_sets.length==split_ways.length
        split_ways.dual_map(partial_side_point_pair_sets) {|split_way, partial_side_point_pairs|
        # Divide the way_point_pairs so that there is at least one way_point_pair for each partial_side_point_pairs
          side_point_pairs = create_side_point_pairs_for_split_way(split_way, partial_side_point_pairs)

          {split_way=>side_point_pairs}
        }.merge_hashes # merge the split_way keys
      }.merge_hashes # merge the results for both linked_ways of this dual_way
    }.merge_hashes # merge the results for all dual_ways
  end

  # Given way_shapes sharing a way and the side_point_pairs of that way, calculate where the user's path leading to and following the way shape intersection crosses the side_point_pairs
  def calculate_side_point_pair_intersections(pair_to_point_intersections, side_point_pairs, data_pair_sets)
    pair_to_point_intersections.flat_map { |pair_to_point_intersection|
    # Get the user's path leading up to this way_shape and following it
      data_pairs = data_pairs_before_and_after(pair_to_point_intersection, pair_to_point_intersections, data_pair_sets).or_if_empty {}
      # Try to figure out where the user's path (the data_pairs) intersects the side_point_pairs
      $whooga = [side_point_pairs, data_pairs]
      Side_Point_Pair.find_intersections(side_point_pairs, data_pairs).or_if_empty {
        # If no intersections were found, just project the way intersection to the side_point_pairs--the exact point shouldn't matter
        [Path_To_Point_Data.new(Side_Point_Pair.to_unique_points(side_point_pairs), pair_to_point_intersection.input_point.position).point_on_path]
      }
    }
  end

  # Returns all the data_pairs leading up to and after the given pair_to_point_intersection
  # This is used to find pairs of the user's chosen path that intersect existing edges of the way upon which the pair_to_point_intersection is based.
  def data_pairs_before_and_after(pair_to_point_intersection, pair_to_point_intersections, data_pair_sets)
    index=pair_to_point_intersections.index(pair_to_point_intersection)
    start_index = [index-1, 0].max
    end_index =  [index+1, pair_to_point_intersections.length-1].min
    # Take the points of each way_shape, meaning the point on the way_shape and subsequent points. Also take the stray points not associated with a way_shape if our search includes the last way_shape
    pair_to_point_intersections[start_index..end_index].dual_map(data_pair_sets[start_index..end_index]) {|close_pair_to_point_intersection, data_pairs|
      data_pairs
    }.shallow_flatten + ((end_index==pair_to_point_intersections.length-1 && data_pair_sets.length==end_index+1) ? data_pair_sets.last : [])
  end

  # Given a split_way and the corresponding split side_point_pairs of that way, create a one to one mapping between the each side_point_pair and way_point_pair, by splitting the way_point_pairs to match the side_point_pairs. In a sense we are creating normalized way_point_pairs so that when we offset the side_point_pairs they map to distinct way_point_pairs (which are then offset back to the side_point_pairs)
  def create_side_point_pairs_for_split_way(split_way, partial_side_point_pairs)
    $saks=partial_side_point_pair_to_partial_way_point_pairs = Way_Point_Pair.sync_data_pair_set_to_data_pair_set(split_way.way_point_pairs, partial_side_point_pairs)
    # Create a new side_point_pair that associates the partial_data_pair side_points to the partial way_point_pair way_points
    $billy=side_point_pairs = partial_side_point_pairs.map { |partial_side_point_pair|
      $az=way_point_pairs = partial_side_point_pair_to_partial_way_point_pairs[partial_side_point_pair]
      # Extract the extreme way_points
      $ez=extreme_way_points = way_point_pairs.extremes { |first, last| [first.data_points.first, last.data_points.last] }
      # Create a Side_Point_Pair based on the created data
      Side_Point_Pair.new(*partial_side_point_pair.data_points.dual_map(extreme_way_points) { |side_point, way_point| Side_Point.new(side_point.point, way_point) })
    }
    side_point_pairs
  end


  # Integrate the data_pairs into this way_grouping.
  # data_pairs are a set up Data_Pair instances describing the point_pairs to be transformed into ways
  # dual_ways_to_intersection_points describe where the data_pairs intersect the existing ways of the way_grouping (This could be calculated, but it's safer to pass in the data if available)
  # ad_hoc_surface_component is the optional ad_hoc surface that accompanies the new way. If the new way is completely internal to the surface_component instance face, then no ad_hock_surface_component is needed
  def integrate!(data_pairs, dual_way_to_intersection_points, ad_hoc_surface_component=nil)
    # Split one of the linked_ways of the dual_way at each intersection point
    Rescape::Config.log.info("Dividing linked ways")
    linked_way_to_replacement_ways = dual_way_to_intersection_points.map {|dual_way, intersection_points|
      dual_way.linked_ways.to_hash_keys {|linked_way|
        linked_way.divide_at_points(intersection_points)
      }
    }.merge_hashes
    Rescape::Config.log.info("Divided #{linked_way_to_replacement_ways.keys.length} linked ways into #{linked_way_to_replacement_ways.values.total_count}")

    # Create the new ways that pertain to the data_pairs
    new_ways = entity_map.pairs_to_ways_and_reverse_ways(data_pairs)

    # Store the old edges as side_point_pairs in case they need to be rolled back
    linked_way_to_old_side_point_pairs = dual_way_to_intersection_points.map {|dual_way, intersection_points|
      dual_way.linked_ways.to_hash_keys {|linked_way|
        entity_map.way_to_ordered_edges_as_side_point_pairs(linked_way).map
      }
    }.merge_hashes

    begin
      # Add the resulting new ways, all other ways, and the data_pairs as ways to a new way_grouping
      # Also supply the existing surface_component which we will edit to draw the new ways
      self.integrate_new_ways!(
          linked_way_to_replacement_ways,
          new_ways)

      if (ad_hoc_surface_component)
        # Integrate the changes into the surface_component if there is an ad_hoc_surface_component. This is the case when an external way is added and the user defines its width
        Rescape::Config.log.info("Integrating surface component")
        surface_component.integrate_surface_component!(
            $a=ad_hoc_surface_component,
            $b=new_ways,
            linked_way_to_replacement_ways)
      else
        # This is the case when the user creates an internal way so no surface component is needed. We still need to split and reassociate the edges of the split ways
        split_edges_to_new_ways(linked_way_to_replacement_ways)
      end
    rescue
      raise
      self.rollback_new_ways!(
          linked_way_to_replacement_ways,
          new_ways,
          linked_way_to_old_side_point_pairs)
    end
    init_data_structures()
  end

  # Reassociates the edges of old ways to those of new ways that result from splitting the old ways.
  # The edges are split according to the split points of the new ways
  def split_edges_to_new_ways(linked_ways_to_replacement_ways)
    linked_ways_to_replacement_ways.map {|old_linked_way, replacement_ways|
      # Grab the edges of each old_way, which has already been replaced by the new ways
      reference_edges = self.entity_map.way_to_ordered_edges(old_linked_way.way)
      final_edges = Sketchup::Edge.split_edges_by_ways(reference_edges, replacement_ways)
      # Now that the edges are split, reassociate them to the new ways
      final_edges.each {|edge|
        Sketchup::Edge.reassociate_edge(self, edge, replacement_ways)
      }
    }
    invalidate()
  end

  # Integrates new ways into the Way_Grouping and replaces existing ways with divided ways where the new_ways occur
  def integrate_new_ways!(linked_way_to_replacement_ways, new_ways)
    Rescape::Config.log.info("Integrating new ways #{new_ways.inspect} for way_grouping #{self.inspect}")
    self.push(*new_ways)
    linked_way_to_replacement_ways.each {|linked_way, replacement_ways|
      Rescape::Config.log.info("Replacing old way #{linked_way.inspect} with #{replacement_ways.inspect}")
      self.delete(linked_way.way)
      self.push(*replacement_ways.map {|lw| lw.way})
    }
    Rescape::Config.log.info("Finished integrating new ways for way_grouping #{self.inspect}")
  end

  # Rollback new ways if something goes wrong
  def rollback_new_ways!(linked_way_to_replacement_ways, new_ways, linked_way_to_old_side_point_pairs)
    new_ways.each {|new_way|
      self.delete(new_way)
    }
    linked_way_to_replacement_ways.each {|linked_way, replacement_ways|
      replacement_ways.each {|replacement_way|
        self.delete(replacement_way)
      }
      self.push(linked_way)
    }
    linked_way_to_old_side_point_pairs.each {|linked_way, side_point_pairs|
      surface_component.restore_edges_from_side_point_pairs(linked_way.way, side_point_pairs)
    }
    init_data_structures()
  end
end