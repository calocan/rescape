require 'utils/Way_Importer'
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


# The following class provides methods to run processes whose results are shared over DRb
class External_Server
  attr_reader :caches, :solved_way_groupings, :create_time
  def initialize
    # A 2D hash of cache_lookup objects, keyed first by the cache_name (e.g. 'solution_paths'), and keyed second by the id of a particular object (e.g. a way_grouping.unique_id)
    @caches = {'solved_paths'=>{}}
    @solved_way_groupings = [] #debug only
    @create_time = Time.now
  end

  # A simple remote test to make sure the server is running.
  def connected?
    true
  end

  def server_create_time
    @create_time
  end

  # The number of cached items of the cache specified
  def size(cache_name, cache_set_key)
    @caches[cache_name][cache_set_key].size
  end

  def member?(cache_name, cache_set_key, item_key)
    @caches[cache_name].
        if_not_nil {|caches_of_type| caches_of_type[cache_set_key]}.
        if_not_nil {|item_cache_lookup| item_cache_lookup.local_member?(item_key)}.
        or_if_nil {false}
  end

  def find_or_nil(cache_name, cache_set_key, item_key)
    @caches[cache_name].
        if_not_nil {|caches_of_name| caches_of_name[cache_set_key]}.
        if_not_nil {|item_cache_lookup| item_cache_lookup.local_find_or_nil(item_key)}
  end

  # Performs path solving for a way_grouping in a separate thread, returning true immediately to allow the calling Sketchup process to continue uninterrupted.
  def solve_all(way_grouping)
    raise "This isn't a way_grouping: #{way_grouping.class}" unless way_grouping.kind_of?(Way_Grouping)
    @solved_way_groupings.push(way_grouping)
    # Solve in a thread so the client doesn't await the result
    Thread.new do
      # Exposes the way_grouping's cache to the lookup functions.
      # This isn't thread safe, since we'll be writing to the cache while it's exposed for reads
      @caches['solved_paths'][way_grouping.unique_id] = way_grouping.path_lookup
      # Solves all way_grouping paths and saves them to the way_grouping's @path_lookup'
      way_grouping.solve_all()
      true
    end
  end

  # Performs an import of way data simply to allow libxml to be run in a Ruby environment outside of Sketchup, since making libxml function in the current version of Ruby (1.8.6) in Sketchup has proved difficult. This could also be made to run in a separate thread and return immediately, but the UI experience for the user would be weird if they didn't wait for the data to render
  def import(dimension_sets)
    way_importer = Way_Importer.new(dimension_sets)
    way_importer.load_data
    way_importer
  end

  # Reports whether solve_all has been called for the given way_grouping id
  def started_solving_way_grouping?(way_grouping_id)
    @solved_way_groupings.find {|way_grouping| way_grouping.unique_id==way_grouping_id} != nil
  end

  def dump_all_hash_keys
    @caches.map_values_to_new_hash {|cache_name, cache_of_name|
      cache_of_name.map_values_to_new_hash {|cache_key, cache_lookup|
        cache_lookup.lookup_hash.keys
      }
    }
  end

  def keys_of_cache_lookup(cache_name, cache_set_key)
    @caches[cache_name].
        if_not_nil {|caches_of_name| caches_of_name[cache_set_key]}.
        if_not_nil {|cache_lookup| cache_lookup.lookup_hash.keys}
  end

  # Download the entire cache_lookup
  def get_cache_lookup(cache_name, cache_set_key)
    @caches[cache_name][cache_set_key]
  end

  def keys_of_solved_way_grouping(index)
    @solved_way_groupings[index].path_lookup.lookup_hash.keys
  end

  def dual_way_ids_of_solved_way_grouping(index)
    @solved_way_groupings[index].dual_ways.map {|dw| dw.id}
  end

  # Debug method to see what happens to an object when it gets sent back and forth
  def exchange(object)
    object
  end

  def object_class_name(object)
    object.class.name
  end

  # Allows a remote caller to stop the service (possibly to restart it)
  def stop_service
    DRb.stop_service
  end
end

