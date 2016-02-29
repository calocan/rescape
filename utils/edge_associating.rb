require 'wayness/edge_association_resolver'
require 'wayness/side_point_pair'
require 'wayness/end_point_pair'
require 'wayness/entity_map'
require 'utils/entity_associating'

# A module of instance methods to associate edges with the network of Ways
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Edge_Associating
  include Entity_Associating

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Entity_Associating)
    base.extend(Class_Methods)
  end

  WAY_DICTIONARY = 'way'
  WAY_POINT_PAIR_DATA_KEY = 'way_point_pair_data'
  END_EDGE_KEY = 'end_edge'
  WAY_POINTS = 'way_points' # way_points are stored for end edges, since they have no way_point_pair

  # Sets an attribute of an edge to store the given way_point_pair
  # You must manually invalidate any caches that map way_point_pairs to edges afterward
  # The optional enforce_way_grouping is true by default and ensures that the way_point_pair given is associated to the given way_grouping. This should be set false in cases where the way of the way_point_pair was just created and doesn't yet associate to a way_grouping.
  def associate_to_way_point_pair!(way_grouping, way_point_pair, enforce_way_grouping=true)
    raise "The given way_point_pair #{way_point_pair.inspect} does not belong to the given way_grouping #{way_grouping.inspect}" unless way_grouping.way_point_pair_is_member?(way_point_pair.hash) if enforce_way_grouping
    # Store the hash of the way_point_pair to which this edge associates
    # Store the range fraction of the way_point_pair for a partial_way_point_pair, or default to the full range [0,1]
    # Store the attributes of the way in the edge
    way_point_pair.way.attributes_for_entity.each{|key,value| self.set_attribute(WAY_DICTIONARY,key,value)}
    # Store data about the specific way_point_pair to which this edge corresponds
    self.associate_to_way_grouping!(way_grouping)
    self.set_attribute(WAY_DICTIONARY, WAY_POINT_PAIR_DATA_KEY,
                       [way_point_pair.hash] +
                           (way_point_pair.kind_of?(Partial_Way_Point_Pair) ? way_point_pair.range_fraction : [0,1]))
    way_point_pair
  end


  # Like associate_to_way_point_pair!, but chooses either the given pair or its reverse depending on the position of the edge
  # The chosen way_point_pair has a counterclockwise vector closest in angle to the vector from the middle_point of the way_point_pairs to the middle point of the edge. This is because way_point_pairs by definition associate the edges in the counterclockwise direction
  def associate_to_way_point_pair_or_reverse!(way_grouping, way_point_pair)
    vector_from_way_point_pair_to_edge = way_point_pair.middle_point.vector_to(self.middle_point)
    chosen_way_point_pair = [way_point_pair, way_point_pair.reverse].sort_by {|wpp|
     wpp.orthogonal.angle_between(vector_from_way_point_pair_to_edge)
    }.first
    associate_to_way_point_pair!(way_grouping, chosen_way_point_pair)
  end

  # Sets edge attributes to either the properties of a way_point_pair or an end_point_pair depending on what class data_pair is.
  # The optional enforce_way_grouping is true by default and ensures that the way_point_pair given is associated to the given way_grouping. This should be set false in cases where the way of the way_point_pair was just created and doesn't yet associate to a way_grouping.
  def associate_to_way_point_pair_or_end_point_pair!(way_grouping, data_pair, enforce_way_grouping=true)
    if (data_pair.class==Side_Point_Pair)
      associate_to_way_point_pair!(way_grouping, data_pair.way_point_pair, enforce_way_grouping)
    elsif (data_pair.class==End_Point_Pair)
      mark_as_end_edge(data_pair.way_points)
    else
      raise "Unexpected class #{data_pair.class}"
    end
  end


  def copy_way_attributes!(from_edge)
    from_edge.attribute_dictionary(WAY_DICTIONARY).each {|key, value|
      self.set_attribute(WAY_DICTIONARY, key, value)
    }
  end

  # Associates the Edge to one of the way_point_pairs given
  # If the edge is already associated to a way_point_pair, that way_point_pair is returned
  # If not an algorithm determines the best matching way_point_pair, based on proximity, vector comparison, and neighbors
  # The optional enforce_way_grouping is true by default and ensures that the way_point_pair given is associated to the given way_grouping. This should be set false in cases where the way of the way_point_pair was just created and doesn't yet associate to a way_grouping.
  def associate_to_best_way_point_pair!(way_grouping, eligible_way_point_pairs=[], enforce_way_grouping=true)
    way_point_pair = (eligible_way_point_pairs.length > 0) ?
      self.closest_pair(eligible_way_point_pairs) :
      Edge_Association_Resolver.new(self, way_grouping).best_way_point_pair()
    Rescape::Config.log.info("Found best way_point_pair #{way_point_pair.inspect}")
    way_point_pair ? associate_to_way_point_pair!(way_grouping, way_point_pair, enforce_way_grouping) : nil
  end

  # True if the edge is associated to a way_point_pair or end edges to way_points
  def associated_to_way_point_pair?()
    self.way_point_pair_hash != nil
  end

  def find_first_associated_neighbor
    self.find_via_breadth_first_search {|neighbor| neighbor.associated_to_way_grouping?}.first
  end

  # The way_point_pair hash of the edge.
  def way_point_pair_hash
    self.get_attribute(WAY_DICTIONARY,WAY_POINT_PAIR_DATA_KEY).if_not_nil{|data| data[0]}
  end

  # Get the way_point_pair to which this Edge associates or return nil
  def way_point_pair(way_grouping=self.associated_way_grouping)
    way_point_pair_data = self.get_attribute(WAY_DICTIONARY,WAY_POINT_PAIR_DATA_KEY)
    if (way_point_pair_data)
      begin
        way_point_pair = way_grouping.find_way_point_pair_by_hash(way_point_pair_data[0])
        range_fraction = way_point_pair_data[1..2]
        Partial_Way_Point_Pair.create_partial_or_leave_whole(way_point_pair, range_fraction)
      rescue
        nil
      end
    else
      # If the edge has no association it may share points with a way_point_pair (such as end Edges)
      way_grouping.all_way_point_pairs.find {|way_point_pair| self.points_match?(way_point_pair)}
    end
  end

  def distance_to_way_point_pair(way_point_pair)
    self.middle_point.distance(way_point_pair.middle_point)
  end

  # Marks an edge as being the end of a way storing the one or two way_points associated to it.
  # There is normally only one way point since an end edge is split into two edges each edge associated to a different way
  def mark_as_end_edge(way_points)
    self.set_attribute(WAY_DICTIONARY, END_EDGE_KEY, true)
    self.set_attribute(WAY_DICTIONARY, WAY_POINTS, way_points.map {|way_point| way_point.hash})
  end

  # Retrieves the one or two way_points of the give end edge. There is normally only one way_point per end edge since it is normally split into two edges
  def way_points_of_end_edge(way_grouping)
    raise "Edge is not an end" unless self.get_attribute(WAY_DICTIONARY, END_EDGE_KEY)
    way_point_hashes = self.get_attribute(WAY_DICTIONARY, WAY_POINTS)
    way_point_hashes.map {|way_point_hash|
      way_grouping.find_way_point_by_hash(way_point_hash)
    }
  end

  # Returns true if the edge is marked as the end of a way
  def is_end_edge?()
    self.get_attribute(WAY_DICTIONARY, END_EDGE_KEY)
  end

  def to_side_point_pair(way_grouping)
    way_point_pair = self.way_point_pair(way_grouping)
    raise "Edge has no way_point_pair" unless way_point_pair
    Side_Point_Pair.from_way_point_pair_with_points(way_point_pair, self.points)
  end

  module Class_Methods
     # Get the data_pairs representing the chosen_path and find the corresponding edges. We always expect our chosen_path to based on edges for the Surface_Adjustment_Tool
    def data_pairs_as_edges(data_pairs, way_grouping)
      data_pairs.map {|data_pair| way_grouping.entity_map.edge_of_data_pair(data_pair)}
    end

    # Splits the edges according to number of ways that resulted from dividing a way into two or more new ways
    # Returns the edges split according to the ways and flattened into a single list
    def split_edges_by_ways(reference_edges, replacement_ways)
      Rescape::Config.log.info("No splits found for edges of way, syncing edges to split ways")
      # Sync the edges to the way_point_pairs
      # Pass a lambda that formats the results to give us a hash keyed by the edge and valued by the partial_edges
      edge_to_partial_edges = Sketchup::Edge.sync_data_pair_set_to_data_pair_set(
          reference_edges,
          replacement_ways.flat_map{|way| way.way_point_pairs},
          lambda {|sync_partial_data_pair, data_pair|
            {sync_partial_data_pair.data_pair => [sync_partial_data_pair]}
          })
      edge_to_partial_edges.flat_map {|edge, partial_data_pairs|
        intermediate_ordered_points = Partial_Data_Pair.intermediate_points(partial_data_pairs)
        edge.smart_split(intermediate_ordered_points)
      }
    end

    # Reassociates edges associated to from_way to to_ways. This is used when ways are split.
    # Invalidate must be called after this operation
    def reassociate_edges(way_grouping, from_way, to_ways)
      @way_grouping.entity_map.way_to_ordered_edges(from_way).each {|edge|
        reassociate_edge(way_grouping, edge, to_ways)
      }
    end

    # Reassociates the given edge to the best matching way_point_pair of the given ways. This is used when an edge is split to reflect a split way and the edge segments must be associated to new ways.
    # Invalidate must be called after this operation
    def reassociate_edge(way_grouping, edge, to_ways)
      way_point_pairs = to_ways.flat_map {|way| way.way_point_pairs}
      Rescape::Config.log.info("Reassociating edge #{edge.inspect} associated to #{edge.way_point_pair(way_grouping).inspect} to best way_point_pair of ways #{to_ways.inspect}")
      way_point_pair = edge.associate_to_best_way_point_pair!(way_grouping, way_point_pairs, false)
      Rescape::Config.log.info("Reassociated edge #{edge.inspect} to way_point_pair #{way_point_pair.inspect}")
    end
  end
end
