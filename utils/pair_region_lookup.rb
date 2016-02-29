require 'utils/simple_pair'
# Hashes pairs by their geographic region to aid in efficient lookups
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Pair_Region_Lookup
  attr_reader :pair_class, :pairs, :region_size, :lookup_hash

  # Initializes the instance with pairs and a region size.
  def initialize(pairs, region_size=Sketchup::Entity::REGION_SIZE, lookup_hash=nil)
    @pair_class = pairs ? pairs.first.class : Simple_Pair # The class is just used for common class methods of data_pair
    @pairs = pairs
    raise ("Pairs with identical points") if @pairs.length != @pairs.reject {|pair| pair.points[0].matches?(pair.points[1])}.length
    @region_size = region_size
    @lookup_hash = lookup_hash || hash_pairs_by_region()
  end

  def merge(pair_region_lookup)
    raise "Pair_Region_Lookup region_sizes are not the same. Cannot merge" unless @region_size == pair_region_lookup.region_size
    self.class.new(@pairs+pair_region_lookup.pairs, @region_size, @lookup_hash.merge(pair_region_lookup.lookup_hash) {|key,old,newe| old+newe})
  end

  # Create a hash that maps the point of each pair to a region code, creating a hash keyed by region code and valued by pairs within that region code. The region code represents an x,y,z range of REGION_SIZE for each coordinate
  def hash_pairs_by_region
    @pairs.to_many_to_many_hash {|pair|
      pair.region_hashes(@region_size)
    }
  end

  # Finds the closest pair that is in one of the point's regions or failing that searches all pairs
  def closest_pair_to_point(point)
    # Try to use the speedy region-based lookup, but fall back to searching all way_point_pairs
    @pair_class.closest_pair_to_point_with_region_lookup(point, @lookup_hash) || @pair_class.closest_pair_to_point(@pairs, point)
  end

  # Finds the pair matching both points of the given data_pair. This is useful for matching a side_point_pair back to and edge from which it was created
  def find_matching_pair(data_pair)
    @pair_class.closest_pair_to_pair_with_region_lookup(data_pair, @lookup_hash)
  end
end