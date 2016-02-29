require 'wayness/way_grouping'
require 'wayness/pair_way'
require 'utils/entity'
require 'wayness/entity_map_caching'

# Associates Sketchup entities with Rescape instances. This class will be the bases for binding/observers.`
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Entity_Map
  include Entity_Map_Caching

  attr_reader :way_grouping, :way_point_pair_to_edge_hash
  def initialize(way_grouping)
    @way_grouping = way_grouping
    initialize_caches()
  end

  def edge_to_dual_way(edge)
    dual_way = @way_grouping.dual_ways.find {|dual_way| dual_way.matches_way_hash?(edge.get_attribute('way','hash'))}
    raise "Couldn't find way intersections for edge with way hash: %s" % edge.get_attribute('way', 'hash') unless dual_way dual_way
  end

  def edges_to_dual_ways(edges)
    edges.map {|edge| edge_to_dual_way(edge)}
  end


  # Returns any edges associated to this way_behavior mixer, or an empty list if none exist.
  def way_to_ordered_edges(way_behavior)
    way_behavior.way_point_pairs.flat_map {|way_point_pair|
      sorted_edges_associated_to_way_point_pair(way_point_pair)
    }
  end

  # Like way_to_ordered_edges but maps all edges to a side_point_pair for abstraction
  def way_to_ordered_edges_as_side_point_pairs(way_behavior)
    way_to_ordered_edges(way_behavior).map {|edge| edge.to_side_point_pair(@way_grouping)}
  end

  # Finds the nearest set of side_point_pairs to the reference_point, which is assumed to be on one side of the way or the other and not on the way itself (which would then be ambiguous)
  # Returns both the array of side_point_pairs and the pair_to_point_data describing the side_point_pair and the projection of the point on pair.
  def side_point_pairs_of_pair_intersection(dual_way, intersecting_pair)
    dual_way.linked_ways.map {|linked_way|
      self.way_to_ordered_edges_as_side_point_pairs(linked_way).if_not_empty {|side_point_pairs|
        # Record both the pair_to_point_data instance and side_point_pairs. Note that the method called here returns two Pair_To_Point_Data instances but we only take one because we only care about the pair and the intersection point, which are identical for both instances.
        Pair_To_Point_Data.pair_to_point_data_at_pair_intersection(side_point_pairs, intersecting_pair).if_not_nil { |pair_to_point_data_instances|
          { :ordered_side_point_pairs=>side_point_pairs,
            :pair_to_point_data=>pair_to_point_data_instances.first
          }
        }
      }.only {raise "No edges were found for either side of the given dual_way: #{dual_way.inspect}"}.
      values_of([:ordered_side_point_pairs, :pair_to_point_data])
    }
  end

  # Given a dual_way this finds the edges closest to the reference_point, maps those edges to side_point_pairs, and then divides the side_point_pairs at the orthogonal projection of the reference point.
  # Return two sets of side_point_pairs, possibly with a partial_data_pair in each if the reference_point projection divides a pair. In the corner case where the reference_point equals an end point, it will one array of all the side_point_pairs.
  # Also returns a Pair_To_Point_Data instance that describes the intersecting side_point_pair (pair) and the intersection (point_on_path).
  def divide_intersecting_side_point_pairs_at_pair_intersection(dual_way, intersecting_pair)
    (ordered_side_point_pairs, pair_to_point_data) = self.side_point_pairs_of_pair_intersection(dual_way, intersecting_pair)
    [Side_Point_Pair.divide_into_partials_at_points(ordered_side_point_pairs, pair_to_point_data.point_on_path),
     pair_to_point_data]
  end

  # Given any number of data_pairs, create ways based on the given way class. The ways are based on continuous chains
  # of the data_pair points. Supply an optional block to expand to pairs to more pairs--to other adjacent pairs for instance
  # Returns 0 or more Way instances. The reverse way is not returned. Call self.pairs_to_ways_and_reverse_ways
  def self.pairs_to_ways(data_pairs, way_class)
    all_pairs = data_pairs.flat_map {|pair| block_given? ? yield(pair) : [pair] }.uniq

    data_pairs.empty? ?
        [] :
        data_pairs.first.class.make_uninterrupted_chains(all_pairs).map {|pair_chain|
          way_class.new(Simple_Pair.to_unique_points(pair_chain))
        }
  end

  def pairs_to_ways(pairs)
    self.class.pairs_to_ways(pairs, @way_grouping.way_class)
  end

  # Like pairs_to_ways but also extracts the reverse_way from each returned ways and returns all ways.
  def self.pairs_to_ways_and_reverse_ways(pairs, way_class)
    self.pairs_to_ways(pairs, way_class).flat_map {|way| [way, way.reverse_way]}
  end

  def pairs_to_ways_and_reverse_ways(pairs)
    self.class.pairs_to_ways_and_reverse_ways(pairs, @way_grouping.way_class)
  end

  # Given any number of data_pairs, create a Way_Grouping instance of Pair_Way instances
  # Supply an optional block to expand the pair to more values, such as adjacent pairs. The block must return an array of pairs
  def self.create_way_grouping_from_pairs(pairs)
    lambda = block_given? ? lambda{|pair| yield(pair)} : lambda{|pair| [pair]}
    Way_Grouping.new(Pair_Way, pairs_to_ways(pairs.flat_map {|pair| lambda.call(pair)}, Pair_Way))
  end

  # Given any number of pairs, this method finds all pairs connected to them and treats the pairs as ways using Pair_Way, then creates a Way_Grouping instance of the Pair_Way instances
  def self.create_way_grouping_from_all_connected_pairs(pairs)
    create_way_grouping_from_pairs(pairs) {|pair| pair.all_connected_pairs}
  end

  # Creates a way_grouping for the given pairs plus any adjacent pairs
  def self.create_way_grouping_from_pairs_and_adjacent_pairs(pairs)
    create_way_grouping_from_pairs(pairs) {|pair| [pair]+pair.neighbors}
  end

  # Given any entities, this method finds all edges connected to them and treats the edges as ways using Pair_Way, then creates a Way_Grouping instance of the Pair_Way instances
  def self.create_way_grouping_from_entities(entities)
    create_way_grouping_from_pairs(Sketchup::Entity.edges_of_entities(entities))
  end

  # Returns the unordered edges associated to the way_point_pair
  def edges_associated_to_way_point_pair(way_point_pair)
    # find the matching edges, removing end edges if they are possible to identify
    self.class.remove_ends(way_point_pair_to_edges_hash[way_point_pair.hash] || [])
  end

  # Finds the edges associated with the way_point_pair in order aligned with the vector direction of
  # the way_point_pair. Use the reverse way_point_pair to get the edges on the other side.
  def sorted_edges_associated_to_way_point_pair(way_point_pair, reverse=false)
    matching_edges = edges_associated_to_way_point_pair(way_point_pair)
    if (matching_edges.length==0)
      matching_edges
    else
      # Sort the edges so that they are all connected
      # If the edges are not all connected we resort to combined sets of connected edges
      sorted_edges = Object.try_or_rescue(lambda {Sketchup::Edge.sort(matching_edges)}, lambda {|e|
        Rescape::Config.log.warn(e.inspect)
        $matching_edges = matching_edges
        $disconnected_edges = Sketchup::Edge.make_chains(matching_edges).shallow_flatten
      })
      # Orient the edges to make them all flow in the same direction. This means some may become Reverse_Edges
      oriented_edges = Sketchup::Edge.orient_pairs(sorted_edges)
      # direct the edges according to the direction of the way_point_pair
      vector = oriented_edges.first.points.first.vector_to(oriented_edges.last.points.last)
      # If reverse is set true xor the vector of the edges is dissimilar to the way_point_pair reverse
      reverse ^ (vector.angle_between(way_point_pair.vector) > vector.reverse.angle_between(way_point_pair.vector)) ?
          oriented_edges.map {|edge| edge.reverse}.reverse : oriented_edges
    end
  end

  def self.remove_ends(edges)
    edges.reject{|edge| edge.is_end_edge? }
  end

  # Maps entities of a way_grouping to way_point_pairs. Any unmapped entity will be ignored
  def way_point_pairs_of_entities(entities)
    Sketchup::Entity.edges_of_entities(entities).map {|edge| edge.way_point_pair(@way_grouping) }.compact
  end

  # Returns any entity over which the input point hovers. Face has highest priority, then edge.
  def self.entities_of_input_point(input_point)
    entities=[input_point.face, input_point.edge, input_point.vertex].compact
    entities.map {|entity| entity.parent}.compact.uniq.find_all {|entity| entity.associated_to_way_grouping?} + entities
  end

  @@entity_priority = nil
  def self.entity_priority
    @@entity_priority ||= [Sketchup::Edge, Sketchup::Face, Sketchup::Group, Sketchup::ComponentInstance]
  end
  # The single way_grouping of the entity defined by the given input_point. In the case where the input_point covers multiple components, the first returned entity is used
  # If no way_grouping is found nil is returned
  def self.way_grouping_of_input_point(travel_network, input_point)
    entities = entities_of_input_point(input_point).reject {|x| x.kind_of?(Sketchup::Vertex)}.sort_by {|entity| self.entity_priority.index(entity.class) || 10}
    entities.map_until_not_nil {|entity| way_grouping_of_entities(travel_network, [entity])}
  end

  # The way_grouping associated with the given entities--vertices, edges, and faces
  # Raises an error if more than one way_grouping is selected
  # TODO it may be possible for some offsets to be cross-way_grouping, such as railroad tracks
  def self.way_grouping_of_entities(travel_network, entities)
    $ees = entities
    way_groupings = entities.find_all{|entity|
      entity.associated_to_way_grouping? }.map{|entity|
      entity.associated_way_grouping(travel_network)}.uniq
    # TODO This may be problematic
    way_groupings.first
  end

  # Returns the way_class of the entity to which the input_point is associated
  def self.way_class_of_input_point(input_point)
    entity = entities_of_input_point(input_point).first
    if (entity && entity.associated_to_way_grouping?)
      entity.associated_way_class
    end
  end

  # If the user wishes to offset unassociated edges we create a temporary way_grouping
  def self.create_ad_hoc_way_grouping(entities)
    # Find the edges that will make this way_grouping
    edges = Sketchup::Entity.edges_of_entities(entities)
    Entity_Map.create_way_grouping_from_all_connected_pairs(edges)
  end

  def inspect
    "#{self.class} for way_grouping of way_class #{way_grouping.way_class}"
  end

end