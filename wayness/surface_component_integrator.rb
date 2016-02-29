# Integrates Surface_Component instances into other Surface_Component instances, or smaller pieces like new edges into an existing service component
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Surface_Component_Integrator

  # Incorporates the given edge points into the component_instance of this surface component.
  # Removes the edges represented by data_pairs, which will be edges created divisions that occur by adding the curve of the new points
  # This method will find any new faces created touching the new edges
  def incorporate_edge_points!(points, old_side_point_pairs)
    $oldy = old_side_point_pairs
    $moldy = old_side_point_pairs.map {|o| o.to_side_point_pair(@way_grouping)}
    # Make Simple_Pairs of the new points
    $mixy=new_edges_as_data_pairs = Simple_Pair.make_simple_pairs(points)
    # Create a hash keyed by each old_side_point_pairs and valued by one or more new data_pairs
    $pixy=old_side_point_pair_to_new_data_pairs =  Simple_Pair.sync_data_pair_set_to_data_pair_set(new_edges_as_data_pairs, old_side_point_pairs)
    # Add the new edges and transfer the attribute data from key to value
    new_edges = old_side_point_pair_to_new_data_pairs.map {|old_side_point_pair, new_data_pairs|
      new_data_pairs.map {|new_data_pair|
        edge = component_instance.entities.add_line(new_data_pair.points)
        edge.associate_to_way_point_pair!(way_grouping, old_side_point_pair.way_point_pair(way_grouping))
        edge.associate_to_way_grouping!(self.way_grouping)
        edge
      }
    }.shallow_flatten
    # This will only extend the face if the new_edges are outside the current surface_component instance face
    adjust_faces_and_edges_to_new_edges!(new_edges, old_side_point_pairs)

    # Invalidate the caches to account for new and erased edges
    invalidate()
  end

  # Integrates a new surface_component into this surface_component. The given surface_component defines side_points but has not yet drawn its component_instance entities. The given new_ways represent new ways which are represented as way_components in the given surface_component. The linked_ways_to_replacement_ways map the original ways of this surface component to the modified ways of the new surface_component at points where the ways of the new surface component intersect and therefore divide the old ways. The linked_ways_to_replacement maps each old way to multiple new partial ways
  def integrate_surface_component!(surface_component, new_ways, linked_ways_to_replacement_ways)
    # Fetch the Side_Point_Pairs and End_Pairs of the new ways, which will be used to generate edges
    $p = perimeter_data_pair_sets_for_new_ways = surface_component.get_perimeter_data_pair_sets_of_ways(new_ways)
    # Also gather the end points of each set so we know where they intersect existing edges
    $ee = end_points = perimeter_data_pair_sets_for_new_ways.flat_map {|data_pairs| Simple_Pair.point_extremes(data_pairs)}

    # Similarly get the perimeter_data_pairs of the replacement ways that are adjacent to the new_ways
    all_replacement_ways = linked_ways_to_replacement_ways.values.shallow_flatten
    $ppx = perimeter_data_pairs_of_reference_ways = surface_component.get_perimeter_data_pair_sets_of_ways(all_replacement_ways).shallow_flatten
    # Grab the pairs of among these data_pairs that touch the end_points. We'll use these later to identify invalid faces, since no new faces should touch these pairs
    $aa=adjacent_pairs = perimeter_data_pairs_of_reference_ways.find_all {|data_pair|
      end_points.any?{|end_point| data_pair.shares_this_point?(end_point) }}
    Rescape::Config.log.info("Found #{adjacent_pairs.length} adjacent_pairs")


    # Split the edges of the reference ways at the point where the new edges were introduced.
    # Only the edges that are actually intersected will be split
    # This is necessary because drawing the new edges does not automatically split the intersecting edges.
    # TODO when we figure out how to make a new way offset straddle multiple edges, this should still work, but needs to be verified
    $lin = linked_ways_to_replacement_ways
    $old_edges_to_new_edges = linked_ways_to_replacement_ways.map {|old_linked_way, replacement_ways|
      # Grab the edges of each old_way, which has already been replaced by the new ways
      reference_edges = way_grouping.entity_map.way_to_ordered_edges(old_linked_way.way)
      raise "For some reason old_linked_way #{old_linked_way.way.inspect} doesn't have any edges" unless reference_edges.length > 0
      edge_sets = reference_edges.map {|edge|
        # See if any intersect points intersect this edge. It could be 0 to several.
        points = end_points.find_all {|point| edge.point_between?(point)}
        if (points.length > 0)
          Rescape::Config.log.info("Found intersection points #{points.inspect} for edge #{edge.inspect}")
          # Split the edge at the intersecting points
          edge.smart_split(points)
        else
          # No intersections occurred
          [edge]
        end
      }

      all_processed_edges = edge_sets.shallow_flatten
      # If no splits were made, then no intersections occurred because the edges are on side of the way without an intersection. They must therefore be split to match the splits in the way resulting from the intersection on the other side.
      final_edges = (all_processed_edges.length != reference_edges.length) ?
          all_processed_edges :
          Sketchup::Edge.split_edges_by_ways(reference_edges, replacement_ways)

      # Now that the edges are split, reassociate them to the new ways
      final_edges.each {|edge|
        Sketchup::Edge.reassociate_edge(self.way_grouping, edge, replacement_ways)
      }

      {reference_edges=>edge_sets} # This is just for debugging, no result is actually used
    }.merge_hashes

    # Add the edges of the added ways, which will be both Side_Point_Pairs and possibly End_Point_Pairs (for dead end ways)
    new_edges = add_new_edges(perimeter_data_pair_sets_for_new_ways)

    # Add new faces of the new_edges that do not touch the adjacent_pairs
    adjust_faces_and_edges_to_new_edges!(new_edges, adjacent_pairs, false)

    # Invalidate the caches to account for new and erased edges
    invalidate()
  end

  # Adds the edges defined by the given perimeter_data_pair_sets, where each set represents data_pairs that defines the perimeter of one new way. The pairs are used to create new edges.
  def add_new_edges(perimeter_data_pair_sets_for_new_ways)
    new_edges = perimeter_data_pair_sets_for_new_ways.flat_map { |perimeter_data_pairs|
      perimeter_data_pairs.map { |perimeter_data_pair|
      # Add the new edge
        edge = component_instance.entities.add_line(perimeter_data_pair.points)
        # Associate the edge to the properties of the Side_Point_Pair or End_Point_Pair
        edge.associate_to_way_point_pair_or_end_point_pair!(way_grouping, perimeter_data_pair, false)
        edge
      }
    }
    Rescape::Config.log.info("Added #{new_edges.length} new edges")
    new_edges
  end


  # Add faces between the new and old edges
  # new_edges are the edges to search for new faces
  # reference_data_pairs are pairs whose point pairs must touch or must not touch the new face for the face to be valid
  # touch_reference_pairs is true if the reference_data_pairs must touch the face and false is they must not
  def adjust_faces_and_edges_to_new_edges!(new_edges, reference_data_pairs, touch_reference_pairs=true)
    $r=reference_data_pairs
    faces = new_edges.flat_map {|edge|
    # Create the new face made by the points and remove the old edges
    # The faces must touch one of the old edges
      edge.create_eligible_faces {|face|
        matches = Sketchup::Edge.find_all_matches(face.edges, reference_data_pairs)
        touch_reference_pairs ? matches.length > 0 : matches.length==0
      } +
      # Add existing faces that touch
      edge.faces.find_all {|face|
        matches = Sketchup::Edge.find_all_matches(face.edges, reference_data_pairs)
        touch_reference_pairs ? matches.length > 0 : matches.length==0
      }
    }.uniq
    Rescape::Config.log.info("Found #{faces.length} new faces")
    faces.each {|face|
      # Draw the face
      face.complete_face(@way_grouping.way_class.way_color)
      edges_to_erase = face.edges.reject {|face_edge| new_edges.member? face_edge}
      Rescape::Config.log.info("Erasing #{edges_to_erase.length} old edges for face #{face.hash}")
      # Erase the old edges
      if (edges_to_erase.length < 50) # Debug sanity check
        component_instance.entities.erase_entities(edges_to_erase)
      end
    }
  end


end