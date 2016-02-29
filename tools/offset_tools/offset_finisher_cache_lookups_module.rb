# Creates caches needed by Offset_Finisher_Module instances. an implementation of this is passed to mixers of the Offset_Finisher_Module
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/cache_lookup'

module Offset_Finisher_Cache_Lookups_Module

  def init_caches

    # Cache the data_point set created each time the user move the cursor to create new data_pair_sets.
    # This probably isn't useful since the user is unlikely to return to exactly the same place with mouse movements
    # We also must cache by the point_set_definition since some tools make this dynamic, and the calculation depends on it
    @data_point_set_cache_lookup = Cache_Lookup.new("#{self.class} Data_Point_Set cache lookup", lambda {|point_set_definition_and_data_pair_sets|
      $mz=point_set_definition_and_data_pair_sets
      point_set_definition = point_set_definition_and_data_pair_sets[0]
      data_pair_sets = point_set_definition_and_data_pair_sets[1]
      [point_set_definition.hash,
      Geom::Point3d.hash_points(Simple_Pair.to_unique_points(data_pair_sets.shallow_flatten))
      ].hash
    })
    @point_set_minus_active_data_pair_set_cache_lookup = Cache_Lookup.new("#{self.class} Point_Set minus data_pair_set cache lookup", lambda {
        |data_pair_sets| Geom::Point3d.hash_points(Simple_Pair.to_unique_points(data_pair_sets.all_but_last.shallow_flatten))
    })

    @way_grouping_cache_lookup = Cache_Lookup.new("#{self.class} Way_Grouping cache lookup", lambda {
        |drawn_path_as_data_pairs| Simple_Pair.unordered_pairs_hash(drawn_path_as_data_pairs)
    })
    @surface_component_cache_lookup = Cache_Lookup.new("#{self.class} Surface_Component", lambda {
        |data_pairs_and_offset_position| [Simple_Pair.unordered_pairs_hash(data_pairs_and_offset_position[0]), data_pairs_and_offset_position[1].hash_point].hash
    })
    @lane_cache_lookup = Cache_Lookup.new("#{self.class} Lane Cache Lookup", lambda {
        |path| Geom::Point3d.hash_points(path)
    })
    @side_point_generator_cache_lookup = Cache_Lookup.new("#{self.class} Side_Point_Generator Cache Lookup")

    @path_adjustor_cache_lookup = Cache_Lookup.new("#{self.class} Path adjustor cache lookup")
  end

  # Caches the point_sets that are based on the chosen_path, so it need not be regenerated if it does not change
  def data_point_set_cache_lookup
    @data_point_set_cache_lookup
  end

  # Caches all put the last three points of each point_sets so that if the users changes the last point the majority of the point_set data can be loaded from the cache. This assumes that the portion of the point_sets that will change are limited to the angle formed by the last three points
  def point_set_minus_active_data_pair_set_cache_lookup
    @point_set_minus_active_data_pair_set_cache_lookup
  end

  def way_grouping_cache_lookup
    @way_grouping_cache_lookup
  end

  def surface_component_cache_lookup
    @surface_component_cache_lookup
  end

  # Caches lanes used to perform offsets
  def lane_cache_lookup
    @lane_cache_lookup
  end

  # Caches side point generators based on the chosen path and variations thereof
  def side_point_generator_cache_lookup
    @side_point_generator_cache_lookup
  end

  # Caches any data needed during the path adjustment phase
  def path_adjustor_cache_lookup
    @path_adjustor_cache_lookup
  end

end