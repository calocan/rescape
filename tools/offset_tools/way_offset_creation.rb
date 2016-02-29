require 'wayness/entity_map'
require 'tools/offset_tools/offset_finisher_utilities_module'
require 'utils/lambda_wrapper'

# An extension of Offset_Finisher_Module that deals with creating new way elements, such as Way_Groupings, based on the path selected by the user.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Way_Offset_Creation

  # Create a new Way_Grouping based on chosen_path()
  def make_ad_hoc_way_grouping_from_chosen_path
    Entity_Map.create_way_grouping_from_pairs(data_pairs())
  end

  # Creates an ad hoc way_component based on an ad hoc way_component based in turn on the the edge(s) that the user wants to adjust. The width of the surface component is based on the distance from the path to the user's input point, i.e. vector_from_path_to_input_point()
  # The way_grouping usually be created by make_ad_hoc_way_grouping and represents the user's chosen path converted to a Way_Grouping, which is needed to serve as the owner of the Surface_Component
  # mirrored_offset determines whether or not the edges of the surface component are created for both sides of the path or for only one side. See transformation_lambda_from_path_along_vector() for details. It is true by default.
  def make_ad_hoc_surface_component(way_grouping, mirrored_offset=true)
    way_point_pairs = way_grouping.all_way_point_pairs
    cache_container.surface_component_cache_lookup.find_or_create([way_point_pairs, point().position]) {
      # Create a surface_component with offsets based on the chosen_path and the input_vector
      # mirrored_offset indicates whether or not the offset should be mirrored, meaning that edges should be created in both orthogonal directions from the path to the user's cursor where the user's cursor is an absolute length
      point_pair_transformation_lambda = transformation_lambda_from_path_along_input_vector(mirrored_offset)
      way_grouping.make_ad_hoc_surface_component(
        Lambda_Wrapper.new(
          point_pair_transformation_lambda,
          [vector_from_path_to_input_point().hash_vector]))
    }
  end

  # Returns the user's chosen path as set of ways. These match a subset of the ways created in way_grouping_from_chosen_path
  def chosen_path_as_ways
    way_dynamic_path.way_grouping.entity_map.pairs_to_ways_and_reverse_ways(data_pairs)
  end

  # Creates a way_grouping from the path user has drawn or selected plus the existing ways intersecting those points
  # Integrate the user's chosen_path as sets of data_pairs into the way_grouping and get back a minimum way_grouping that only contains ways of the user's path and the existing adjacent ways affected by the new ways. By creating a minimized way_grouping we can efficiently but accurate offset the new path to correspond with the side_point_pairs of the intersecting ways.
  def minimally_integrated_way_grouping_from_chosen_path
    way_grouping = way_dynamic_path.way_grouping
    cache_container.way_grouping_cache_lookup.find_or_create(data_pairs) {
      way_grouping.create_minimum_integrated_way_grouping_from_pairs(
          way_dynamic_path.data_pair_sets,
          way_dynamic_path.way_shapes)
    }
  end

  # Map the dual_ways to the chosen path intersections that occur on them (where the user clicked)
  def dual_ways_to_intersection_points
    way_grouping = way_dynamic_path.way_grouping
    way_dynamic_path.way_shapes.map_to_hash_with_recurring_keys(
        lambda { |way_shape| way_grouping.dual_way_from_way(way_shape.way_point_pair.way) },
        lambda { |way_shape| way_shape.input_point.position })
  end

  # Creates a surface_component from the points that the user has drawn
  # mirrored_offset determines whether the edges of the surface components should be created for both sides of the path (true) or only for the counterclockwise side (false)
  def integrated_surface_component_from_chosen_path(mirrored_offset=true)
    # Creates a way_grouping with new ways based on the chosen path and also with the ways of the existing way_grouping that are connected to the chosen_path
    ad_hoc_way_grouping = minimally_integrated_way_grouping_from_chosen_path()
    # Creates a surface_component that will offset the old ways to their predefined side_point_pairs and will offset the new ways according to the distance of the user's cursor
    make_ad_hoc_surface_component(ad_hoc_way_grouping, mirrored_offset)
  end

  # Integrates the user's chosen_path as sets of data_pairs into the way_grouping and get back a minimum way_grouping that only contains ways of the user's path and the existing adjacent ways affected by the new ways. By creating a minimized way_grouping we can efficiently but accurate offset the new path to correspond with the side_point_pairs of the intersecting ways.
  def surface_component_from_chosen_edge_path
    way_grouping = way_dynamic_path.way_grouping
    ad_hoc_way_grouping = cache_container.way_grouping_cache_lookup.find_or_create(data_pairs) {
      way_grouping.make_ad_hoc_way_grouping_from_chosen_path_of_edges_and_neighbors(data_pairs)
    }
    make_ad_hoc_surface_component(ad_hoc_way_grouping)
  end

  # Creates a surface component of the chosen_path and then extracts the perimeter point sets pertaining to the chosen path, since the surface_component will also contain perimeter_points of the existing way side_points that are used as constraints
  def perimeter_point_sets_of_chosen_path
    integrated_surface_component_from_chosen_path().get_perimeter_point_sets_of_ways(chosen_path_as_ways())
  end

  # Given a surface_component, returns the way_component of the surface_component nearest the user's input point (point()). Since each way_component has a reverse version, this selects the one whose counterclockwise orthogonal projection reaches the point()
  def get_way_component_nearest_input_point(surface_component)
    input_vector = vector_from_path_to_input_point().normalize
    # Find the continuous_way_set with a way_point_pair whose orthogonal vector is closest to the input_vector. This is needed because the way_grouping will contain two or more continuous way_sets based on each direction of each uninterrupted line
    way_component = surface_component.make_way_component(way_grouping.get_continuous_way_sets.sort_by {|continuous_way_set|
      continuous_way_set.way_point_pairs.map {|way_point_pair| way_point_pair.orthogonal.angle_between(input_vector)}.sort.first
    }.first)
    way_component
  end
end