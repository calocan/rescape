require 'utils/file_cache_lookup'
# A Special cache for saving Way path solutions to file so that it can be run by an external process and read by the Sketchup process. Ideally this would be in memcached or something else better than files
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Solution_Cache_Lookup < File_Cache_Lookup
  def initialize(cache_name, file_lambda, hash_lambda, way_grouping)
    super(cache_name, file_lambda, hash_lambda)
    @way_grouping = way_grouping
  end

  # Load the file containing the marshaled way and use it to fetch the dual_way from the way_grouping
  def load_from_file(f)
    ways=Marshal.load(f)
    dual_ways = ways.map {|way|
      @way_grouping.dual_way_from_way_id(way.id)
    }
    # TODO, do we need to cache the weight or can it be 0
    Shortest_Path::Solution.new(dual_ways.last, dual_ways, 0)
  end

  # Save the item, which is a list of dual_ways, to a file, extracting the first way of each dual_way to actually store. This is enough to regenerate the dual_way from the way_grouping upon unmarshalling
  def save_to_file(item, f)
    Marshal.dump(item.path.map {|dual_way| dual_way.linked_ways.first.way}, f)
  end

  # Debug method
  def load_all_from_file
    dual_ways = @way_grouping.dual_ways
    $m=(0..dual_ways.length-1).map {|i|
      (0..dual_ways.length-1).find_all{|x| x!=i}.map {|j|
        [@hash_lambda.call([dual_ways[i], dual_ways[j]]),
        find_in_file_or_nil([dual_ways[i], dual_ways[j]])]
      }
    }.shallow_flatten
  end
end