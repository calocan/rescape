#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Way_Parser
  def initialize(doc_hash)
    @doc_hash = doc_hash
  end

  def self.model
    Sketchup.active_model
  end

  def parse_ways()
    # Hash ways by node across all types of ways to use to detect intersections
    node_id_to_ways_lookup = create_node_id_to_ways_lookup(@doc_hash)

    Rescape::Config.log.info("Parsing data")
    ways = @doc_hash.map {|doc_hash, doc|
      node_lookup, surface_class_to_osm_ways = create_surface_class_to_osm_ways(doc)

      # Map data to Way instances. Instances are split at intersections with other nodes
      surface_class_to_osm_ways.map {|surface_class,osm_ways|
        Rescape::Config.log.info "Loaded %s %s ways" % [osm_ways.length, surface_class.name]
        osm_ways.map {|osm_way|
          # Each osm_way can needs to be split into a way instance at each intersection
          split_way_at_intersections(osm_way.nodes.map{|node_id| node_lookup[node_id.to_i]}, node_id_to_ways_lookup).map {|points|
            surface_class.create_way(osm_way, points)
          }
        }.shallow_flatten # one osm_way can result in multiple way instances due to intersections
      }.shallow_flatten # flatten the various surface types
    }.shallow_flatten
    ways.uniq_by_map {|way| Geom::Point3d.hash_points(way)}.reject {|way| way.length <=1 } # fatten the doc results and ensure legitimate ways
  end

  def create_surface_class_to_osm_ways(doc)
    all_ways = doc.ways.values
    node_lookup = doc.nodes
    # Split the ways up by the surface type they represent, e.g. ground, rail, water, aerial
    surface_class_to_osm_ways = all_ways.to_hash_value_collection { |osm_way|
      surface_class = Way_Surface_Definitions_Config.get_surface_class(osm_way.tags)
      surface_class != nil && surface_class.supports_way_type(osm_way.tags) ? surface_class : nil
    }.reject { |key, value| key==nil }
    return node_lookup, surface_class_to_osm_ways
  end

  def create_node_id_to_ways_lookup(doc_hash)
    # Associate each node id with the ways that contain it.
    doc_hash.map {|doc_hash, doc| doc.ways.values }.flatten.
        uniq_by_map{|way| way.id}.
        to_many_to_many_hash{|way| way.nodes.map {|node_id| node_id.to_i} }
  end

  # Way data imported from openstreetmap doesn't necessarily break at each intersection with another way, but this is essential to us for rendering the ways correctly. TODO add argument explanations
  def split_way_at_intersections(node_values, node_id_to_ways_lookup)
    # Separate points by node intersections with other ways
    node_groups = separate_nodes_by_intersection(node_values, node_id_to_ways_lookup)
    node_groups.map {|nodes|
      nodes.map{|node|
        self.class.model.latlong_to_point([node.lon.to_f, node.lat.to_f])
      }
    }
  end

  def separate_nodes_by_intersection(node_list, node_id_to_ways_lookup)
    f=lambda { |nodes, node_groups|
      node = nodes.first
      if (node_groups==nil)
        f.call(nodes.rest, [[node]]) # first node, make it the first group
      elsif (nodes.length ==1)
        node_groups.all_but_last + [node_groups.last+[node]] # final node, add it to the last group
      else
        f.call(nodes.rest, node_id_to_ways_lookup[node.id].length > 1 ?
            node_groups.all_but_last + [node_groups.last+[node]] + [[node]] : # put the node in the last group and a new group
            node_groups.all_but_last + [node_groups.last+[node]]) # add the node to the last group
      end
    }
    f.call(node_list, nil)
  end
end
