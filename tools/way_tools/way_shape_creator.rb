require 'wayness/way_point_pair'
require 'wayness/way_shape'
require 'utils/edge'
require 'utils/data_pair'
require 'utils/simple_pair'
require 'utils/basic_utils'

# Defines shapes atop the surface of way for use by the offset tools
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Way_Shape_Creator
  include Basic_Utils

  attr_reader :edge_boundary_lookup, :way_point_pair, :options, :locked_way_shape, :fixed_offset, :offset_configuration
  # Creates a way_shape based on the parameters.
  # way_grouping is the Way_Grouping to whose surface the way_shape pertains, usually because the input_point is over that surface.
  # offset_configuration configures the behavior based on the Offset_Tool in use.
  # input_point determines how to offset the way_shape from the data_pair to which to the input_point is associated. It is usually a dynamic mixer of Complex_Point whose underlying position is subject to change, but it may also be a regular Geom::Point3d to indicate that no dynamic change in offset is permitted.
  # See Hover_Handling.define_hover_shape for options configuration descriptions
  def self.way_shape_from_cursor(way_grouping, offset_configuration, input_point, options={})
    # Find the closest way_point_pair via the closest edge or closest_way_point_pair
    way_point_pair =  way_grouping.closest_way_point_pair_to_point(input_point)
    $ii=input_point
    $wig = way_grouping
    raise "No way_point_pair was found for way_grouping #{way_grouping.inspect}. This should never happen" unless way_point_pair

    self.new(way_grouping, way_point_pair, offset_configuration, input_point, options)
  end

  def initialize(way_grouping, way_point_pair, offset_configuration, input_point, options={})
    $way_shape_creator = self
    @way_grouping = way_grouping
    @way_point_pair = way_point_pair
    # Find the edges associated with the way_point_pair
    @edge_boundary_lookup = get_edge_boundary_lookup(way_point_pair)
    @offset_configuration = offset_configuration
    @input_point = input_point

    @options = options
    # Options that determine how the way_shape is chosen
    # locked_way_shape forces the created way_shape to honor the way_point_pair or edge set used by the way_shape specified in either of these options
    @locked_way_shape = options[:locked_way_shape] || options[:synced_to_previous_way_shape]
    # fixed_offset forces the length of the offset from the data_pair, thus disregarding the user's cursor position
    @fixed_offset = options[:fixed_offset] ||
        options[:synced_to_previous_way_shape].if_not_nil {|way_shape|
          way_shape.pair_to_point_data.vector_from_path_to_point.length}
    # Options that need to be stored in the way_shape pertaining to connecting with other way_shapes
    @way_shape_options = [:smooth_connect, :force_path_on_way].find_all {|key| options[key]}.to_hash_keys{|key| options[key]}
  end

  # Returns a lookup of each edge set based on the way_point_pair or reverse way_point_pair, since an edge set always belongs to the way_point_pair whose vector is rotated counterclockwise to point toward that edge set
  def get_edge_boundary_lookup(way_point_pair)
    way_point_pairs = [way_point_pair, way_point_pair.reverse]
    way_point_pairs.map_to_hash(
        lambda {|wpp| wpp.hash},
        lambda {|wpp|
          @way_grouping.entity_map.sorted_edges_associated_to_way_point_pair(wpp)
        })
  end

  # Like get_edge_boundary_lookup, but just returns the edge sets
  # Takes a way_point_pair because this might come from a previous way_shape's way_point_pair'
  def get_edge_boundaries(way_point_pair)
    way_point_pairs = [way_point_pair, way_point_pair.reverse]
    way_point_pairs.map {|wpp|
      @way_grouping.entity_map.sorted_edges_associated_to_way_point_pair(wpp)
    }
  end

  # The way_shape may be based on either the way_point_pair way points (i.e. center points) or on edge points. The point pair closest to the input_point are returned.
  def eligible_pair_sets()
    # Find the closest pair(s), whether the edges or way_point_pair to the cursor_point.
    # If select_edges_only? or select_way_point_pairs_only? is true then only edges or way_point_pairs, respectively, are considered
      # Reject the way_point_pair is this is true
    (@offset_configuration.select_edges_only? ? [] : [[@way_point_pair]]) +
      # Reject the edge collections if this is true
      (@offset_configuration.select_way_point_pairs_only? ?
          [] :
          get_edge_boundaries(@way_point_pair).reject_empty_collections())
  end

  # Determines the set index of the data_pair of the given way_shape, where 0 is the way_point_pair, 1 is the counterclockwise edge, and 2 is the clockwise edge. If way_point_pairs are not allowed, edges are 0 and 1. If edges are not allow, way_point_pair remains 0.
  def corresponding_index_of_previous_way_shape_data_pair(way_shape)
    # Resolve the full data_pair since way_shape.data_pair is probably a partial_data_pair
    full_data_pair = way_shape.data_pair.data_pair
    if (@offset_configuration.select_way_point_pairs_only? || full_data_pair == way_shape.way_point_pair)
      # If only edges are allowed or the data_pair (or its parent if its a partial) equals the way_point_pair, then this way_shape's data_pair is the way_point_pair
      0
    else
      # Otherwise, it's one of the edges
      #TODO this neads more work for matching the main way_point_pair's orientation'
      edge_boundaries = get_edge_boundaries(way_shape.way_point_pair.orient_to_vector(@way_point_pair.vector))
      if (Simple_Pair.matches?(edge_boundaries[0], full_data_pair))
        @offset_configuration.select_edges_only? ? 0 : 1
      elsif (Simple_Pair.matches?(edge_boundaries[1], full_data_pair))
        @offset_configuration.select_edges_only? ? 1 : 2
      else
        raise "The way_shape's data_pair didn't match anything. data_pair: #{way_shape.data_pair.inspect}. way_point_pair: #{way_point_pair.inspect}. edge_boundaries: #{edge_boundaries.inspect}"
      end
    end
  end

  # Returns the outline of a way shape defined by the way_point_pair and the width around the cursor point
  def way_shape_around_cursor_point()
    # Based on the closest way_point_pair, return the two sets of edges and a set containing the way_point_pair itself. One of these three sets will be closest to the input point, and thus be used to define the data_pair of the way_shape.
    $goobe=eligible_pair_sets = eligible_pair_sets().or_if_empty {raise "No eligible pair sets exist for the current cursor position. This should not happen"}
    # Get the closest pair, whether an edges of a way_point_pair or a way_point_pair
    $e2=closest_pair_set = eligible_pair_sets.sort_by {|pairs|
      Simple_Pair.shortest_distance_to_point(pairs, @input_point)
    }.first.or_if_nil {raise "No closest pairs were found"}

    # If a locked_way_shape exists use the same way_point_pair or edge set as the locked_way_shape
    # Otherwise use the closest of the way_point_pair or edge sets
    $e3=chosen_pair_set =
        (@locked_way_shape && eligible_pair_sets[corresponding_index_of_previous_way_shape_data_pair(@locked_way_shape)]) ||
        closest_pair_set

    # Create a Pair_To_Point_Data instance based on the closest of the eligible_pairs and the @input_point and then change then adjust the offset position from the input_point based on the configuration
    pair_to_point_data =  Simple_Pair.closest_pair_to_point_data(chosen_pair_set, @input_point).if_cond(@fixed_offset) {|pair_to_point_data|
        # Clone it and change the input_point position based on fixed_offset if the user has indicated a value in the Sketchup VCB
        # @fixed_offset may also be a vector to indicate the user nudged with an arrow key. In this case it adds the vector length to the existing length
        pair_to_point_data.clone_with_new_offset_distance_based_on_length_or_vector(@fixed_offset)
    }
    # Make sure the chosen pair meets proximity requirements of the configuration
    # The close_hover_threshold is to see if a point that is off of the way surface is close enough to qualify
    # The data_pair_selection_threshold is to see if a point on the way surface is close enough to qualify
    if ((@offset_configuration.allow_close_hovers? &&
        @offset_configuration.close_hover_threshold > 0 &&
        self.class.pixels_to_length(@offset_configuration.close_hover_threshold) < pair_to_point_data.distance) ||
        (@offset_configuration.data_pair_selection_threshold > 0 &&
        self.class.pixels_to_length(@offset_configuration.data_pair_selection_threshold) < pair_to_point_data.distance))
      return nil
    end

    # Now that we've selected the closest pair, we may need to replace the user's point with a point affixed to the pair. This is generally the case when we're forcing the user to choose a way_point_pair or edge. In other words we are not allowing any offset from the pair.
    pair_to_point_data_offset_adjusted = @offset_configuration.allow_way_shape_offset? ?
        pair_to_point_data :
        pair_to_point_data.clone_with_affixed_point()

    # If node selection is enabled, check to see if our modified point is within the node threshold to select a node instead of a pair:
    pair_to_point_data_node_adjusted = @offset_configuration.allow_node_selection? ?
        nearest_node_if_within_threshold(pair_to_point_data) :
        pair_to_point_data_offset_adjusted


    # Finally create a way_shape instance that stores the pair_to_point data that we've just gathered along with a reference to the way_point_pair that we passed into the constructor.
    Way_Shape.new(@way_grouping, @way_point_pair, pair_to_point_data_node_adjusted, @offset_configuration, @way_shape_options)
  end

  # Map the pair_to_point_data to a pair_to_point data where the pair is a Node_Data_Pair if it falls withing the configured threshold
  def nearest_node_if_within_threshold(pair_to_point_data)
    pair_to_point_data.distance_from_point_to_nearest_pair_point <= self.class.pixels_to_length(@offset_configuration.node_selection_threshold) ?
        pair_to_point_data.pair.as_node_data_pair(pair_to_point_data.nearest_pair_point) :
        pair_to_point_data

  end
end
