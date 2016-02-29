require 'utils/pair_to_point_data'

# Handles caching of data that relates Rescape data structures (Ways) to Sketchup data (Edges, etc)
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Entity_Map_Caching

  attr_reader :way_point_pair_and_edge_lookup_hash, :edge_region_lookup_hash
  # Sets up the caches, which are actually not populated until first needed. The code should eventually be able to create them by multithreading.
  def initialize_caches()
    invalidate()
  end

  # Invalidates any caches after an update to Sketchup entities occurs
  def invalidate
    @way_point_pair_to_edge_hash=nil
    @edge_region_lookup_hash=nil
    @way_point_pair_and_edge_lookup_hash=nil
    @edge_lookup_by_points=nil
  end

  # Looks for deleted edges in the cache and invalidates the caches if any are found
  def purge
    if (way_point_pair_to_edges_hash().values.shallow_flatten.any? {|edge|
      edge.deleted?
    })
      invalidate()
    end
  end

  # Create a hash that maps a way_point_pair hash to all the edges associated to the way_point_pair
  def way_point_pair_to_edges_hash
    if (!@way_point_pair_to_edge_hash)
      edges = @way_grouping.surface_component ?
          @way_grouping.surface_component.associated_edges :
          []
      @way_point_pair_to_edge_hash = edges.reject {|edge| edge.is_end_edge?}.to_hash_value_collection {|edge|
        way_point_pair = edge.way_point_pair(@way_grouping)
        unless (way_point_pair)
          Rescape::Config.log.warn "Found unassociated edge #{edge.inspect}. Associating to way_point_pair"
          way_point_pair = edge.associate_to_best_way_point_pair!(@way_grouping)
          Rescape::Config.log.warn "Associated edge #{edge.inspect} to best way_point_pair #{way_point_pair.inspect}"
        end
        way_point_pair ? way_point_pair.hash : 0 # TODO Fix
      }
    end
    @way_point_pair_to_edge_hash
  end

  # Returns a Pair_Region_Lookup instance that hashes edges by region. Only edges belonging to this surface component and associated to a way_point_pair will be cached
  def edge_region_lookup()
    unless @edge_region_lookup_hash
      Rescape::Config.log.info "Generating edge region lookup "
      edges = @way_grouping.surface_component.associated_edges
      Rescape::Config.log.info "Fetched edge region lookup edges"
      @edge_region_lookup_hash = Pair_Region_Lookup.new(edges)
      Rescape::Config.log.info "Finished generating edge region lookup"
    end
    @edge_region_lookup_hash
  end

  def edge_lookup_by_points(points)
    @edge_lookup_by_points = @way_grouping.surface_component.associated_edges.to_hash_values{|edge|
      Geom::Point3d.hash_points_unordered(edge.points)} unless @edge_lookup_by_points
    @edge_lookup_by_points[Geom::Point3d.hash_points_unordered(points)]
  end

  def edge_lookup_by_points_hash
    @edge_lookup_by_points
  end

  # Find the edge matching the points of the given data_pair
  def edge_of_data_pair(data_pair)
    edge = edge_lookup_by_points(data_pair.points)
    raise "No edge found matching data_pair: #{data_pair.inspect}" unless edge
    edge
  end

  # Finds the closest way_point_pair to the point by finding the closest way_point_pair or edge
  def closest_way_point_pair_to_point(point)
    @way_point_pair_and_edge_lookup_hash = @way_grouping.way_point_pair_region_lookup().merge(edge_region_lookup()) unless @way_point_pair_and_edge_lookup_hash
    pair = @way_point_pair_and_edge_lookup_hash.closest_pair_to_point(point)
    pair.kind_of?(Sketchup::Edge_Module) ? pair.way_point_pair(@way_grouping) : pair
  end

  # Finds the closest edge to the point efficiently by caching edges by region
  def closest_edge_to_point(point, proximity_length=0)
    pair = edge_region_lookup.closest_pair_to_point(point)
    proximity_length==0 || (pair && Pair_To_Point_Data.pair_to_point_data(pair, point).
        if_not_nil{|ptp| ptp.distance <= proximity_length}.
        or_if_nil{false}) ?
      pair :
      nil
  end

  # Iterates through all the edges or the given edges of the surface and associates each one with a portion of a way.
  # Already associated edges will be left alone, and newly created edges without associations will be associated
  # An edge with no obvious association will adopt that of its neighbors.
  # An edge with no neighbors will resolve to nil
  def associate_edges_to_way_point_pair!(edges=@way_grouping.surface_component.edges)
    edge_to_way_point_pair = edges.to_hash_keys {|edge| edge.way_point_pair(@way_grouping)}
    unless (edge_to_way_point_pair.values.all?)
      edge_to_way_point_pair = edge_to_way_point_pair.map_values_to_new_hash {|edge, way_point_pair|
          way_point_pair || edge.associate_to_best_way_point_pair!(@way_grouping)
      }
      invalidate
    end
    edge_to_way_point_pair
  end
end