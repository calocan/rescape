require 'wayness/way_grouping'
require 'utils/lambda_wrapper'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Predefined_Side_Point_Pair_Way_Grouping < Way_Grouping
  attr_reader :way_hash_to_side_point_pairs, :way_preprocessor
  # Creates a grouping of ways whose side_point_pairs are already defined
  # way_to_existing_side_point_pairs maps each way to the existing side_point_pairs of those ways, such that when the surface_creator draws its edges, it draws them to match those side_point_pairs.
  def initialize(way_class, ways, unique_id, way_to_existing_side_point_pairs)
    # The @way_preprocessor maps all the existing ways to their side_point_pairs.
    # This tells the surface_component to map these ways to the existing side_point_pairs when drawing the surface.
    # Make sure that this is defined by for get_or_create_surface_component is called
    @way_preprocessor = lambda {|way_point_pairs| way_point_pairs_to_side_point_pairs(way_point_pairs)}

    super(way_class, ways, nil)

    @way_hash_to_side_point_pairs = way_to_existing_side_point_pairs.map_keys_to_new_hash {|way,spps| way.hash}
  end

  # Override Way_Grouping to create non-remote cache lookup
  def create_path_lookup
    Cache_Lookup.new(
        'solved_paths',
        lambda {|dual_way_path| dual_way_path.extremes.map {|dual_way|
          dual_way.unique_id}.join('_')}
    )
  end

  # Override Way_Grouping to not commence a remote solve_all operation for this temporary way_grouping
  def remote_solve_all
    # noop
  end

  # Override the Way_Grouping method to use the @way_preprocessor
  # The transformation_lambda_wrapper will be needed to map the new ways to the distance of the user's cursor, a predefined distance, etc. (See way_offset_creation.make_ad_hoc_surface_component for an example)
  def make_ad_hoc_surface_component(transformation_lambda_wrapper, way_preprocessor=@way_preprocessor)
    super(way_point_pair_level_lambda(transformation_lambda_wrapper), way_preprocessor)
  end

  # Maps the way_point_pairs of each way to the preexisting side_point_pairs
  def way_point_pairs_to_side_point_pairs(way_point_pairs)
    # Get the remaining way range, since some pairs may have been dropped
    way = way_point_pairs.first.way
    $left = way_point_pairs
    $all = all_way_point_pairs = way.way_point_pairs
    # TODO this should create several ranges to accomodate intermediate missing way_point_pairs
    $rangey=way_range = Way_Point_Pair.range_of_data_pair(
        all_way_point_pairs,
        Simple_Pair.new(Way_Point_Pair.point_extremes(way_point_pairs)))
    if (@way_hash_to_side_point_pairs.member?(way.hash))
      # Match the way and map it to Side_Point_Pairs. Since way_point_pairs may be eliminated by offsetting, we must filter the side_point_pairs by way_point_pair.
      # First check that the way_point_pair of the side_point_pair remains. If it passes this test then do the range test
      # The way_point_pairs may be partials, so we must check that they fall within the way_range
      @way_hash_to_side_point_pairs[way.hash].find_all {|side_point_pair|
        if (all_way_point_pairs.member?(side_point_pair.way_point_pair) && !way_point_pairs.member?(side_point_pair.way_point_pair))
          false
        else
          way_point_pair_range = Way_Point_Pair.range_of_data_pair(all_way_point_pairs, side_point_pair.way_point_pair)
          [way_point_pair_range.begin, way_point_pair_range.last].all? {|percent| way_range.include?(percent)}
        end
      }
    else
      handle_way_point_pairs_without_side_point_pairs(way_point_pairs)
    end
  end

  # By default we expect all way_point_pairs to be mapped to side_point_pairs, but this can be overridden
  def  handle_way_point_pairs_without_side_point_pairs(way_point_pairs)
    raise "The following way_point_pairs were unexpectedly not mapped to side_point_pairs: #{way_point_pairs.inspect}"
  end

  # Creates the transformation_lambda used by the Side_Point_Generator. Since way_preprocessor turns the way_point_pairs of our old ways into their corresponding side_point_pairs, this recognizes those side_point_pairs and creates a transformation from the side_point_pair's way_point_pair back to the side_point_pair. The Side_Point_Generator in turn offsets the way_point_pairs to their side_point_pair position
  # The point_pair_translation_lambda is a lambda or Lambda_Wrapper that can optionally be used to map way_point_pairs that don't already map to a side_point_pair. By default it raises an error when any such pair is encountered.
  def way_point_pair_level_lambda(point_pair_translation_lambda=nil)

    Lambda_Wrapper.new(
        lambda {|data_pair|
          Lambda_Wrapper.new(
              (data_pair.data_pair.kind_of?(Side_Point_Pair) ?
                  lambda {|point_pair|
                    # Create a transformation from each point to the side_point
                    point_pair.dual_map(data_pair.points) {|point, side_point| Geom::Transformation.new(point.vector_to(side_point))}
                  } :
                  point_pair_translation_lambda.or_if_nil {raise "The data_pair #{data_pair.inspect} was not a Side_Point_Pair as expected. Make sure that the @way_preprocessor was defined for the Surface_Creator"}),
              nil,
              1)
        },
        point_pair_translation_lambda.kind_of?(Lambda_Wrapper) ? point_pair_translation_lambda.properties : nil,
        2) # Indicates the depth of the Lambda_Wrapper
  end
end