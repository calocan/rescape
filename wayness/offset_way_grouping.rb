require 'wayness/predefined_side_point_pair_way_grouping'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Offset_Way_Grouping < Predefined_Side_Point_Pair_Way_Grouping

  attr_reader :offset_configuration
  # Creates a way_grouping for an offset, where the way_class is Offset_Way and the ways are composed of the center points of the offset.
  # data_pair_sets_for_edges contains two sets of data_pairs representing the points of the edges to draw for each of the ways. Upon initial creation the length of data_pair_set_for_edges will be twice that of the length of ways, since ways are reversed and added by the Way_Grouping constructor. Thus the order of data_pair_sets_for_edges must be all those for the forward ways followed by all those for the reverse ways. The side_point_pair sets are always the counterclockwise rotation of the way's direction, by convention (so for one way going north there will be two sets of side_point_pairs, first the one on the west side and then the one on the east side--to correspond with the reverse way facing south)
  def initialize(way_class, ways, unique_id, data_pair_sets_for_edges, offset_configuration)
    $owg=self

    # Make the reverse reversion of the ways and create a list of ways and reverse_ways.
    # If unique_id is not nil then this is an unmarshalling case and the reverse ways already exist
    all_ways = unique_id ? ways : ways + ways.map {|way| way.reverse_way}
    ways_to_side_point_pair_sets = create_way_to_side_point_pair_sets(all_ways, data_pair_sets_for_edges)
    # The offset_configuration contains the configuration of the offset tool that made this Offset_Way_Grouping
    @offset_configuration = offset_configuration
    super(way_class, ways, unique_id, ways_to_side_point_pair_sets)
  end


  # Dual hash the ways to the provided data_pair_sets, creating a hash
  def create_way_to_side_point_pair_sets(ways, data_pair_sets)
    ways.dual_hash(data_pair_sets) {|way, data_pair_set|
      # Create new Side_Points that associate to the Offset_Way_Grouping Way_Points. The data_point_set Side_Points were created by offsetting the inner path of the component, so we must associate them to the Way_Points by proximity
      way_point_pairs = way.way_point_pairs
      [way,
      data_pair_set.map {|side_data_pair|
        Side_Point_Pair.from_way_point_pair_with_points(
            Way_Point_Pair.closest_pair_to_point(way_point_pairs, side_data_pair.middle_point),
            side_data_pair.points)
      }]
    }
  end

  # Overrides the method in Way_Pathing to pass the offset_configuration's offset_options to the Side_Point_Generator
  def side_point_generator_options
    @offset_configuration.offset_options
  end

  # Overrides the default to create a surface_component using the custom transformation_lambda_wrapper and the way_preprocessor
  # These map the way_point_pairs to the pre-existing side_point_pairs
  def get_or_create_surface_component
    if (@surface_component)
      verify_surface_component
    else
      @surface_component = Offset_Surface_Component.new(active_model, self, way_point_pair_level_lambda(), @way_preprocessor, @component_instance)
    end
    @surface_component
  end

  def inspect
    "#{self.class} of offset_configuration class #{self.offset_configuration.class} with #{self.length} ways and hash #{self.hash}"
  end
end