# Caches key values in a hash
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Cache_Lookup

  attr_reader :cache_name, :lookup_hash, :hash_lambda
  # Initialize the cache with a hashing function that expects an item and returns it's hash. Defaults to calling item.hash
  def initialize(cache_name, hash_lambda=lambda {|item| item.hash})
    @cache_name = cache_name
    @lookup_hash = {}
    @hash_lambda = hash_lambda
  end

  def add(item, value)
    #Rescape::Config.log.info("#{@cache_name}: Adding item keyed by: #{@hash_lambda.call(item)}")
    @lookup_hash[@hash_lambda.call(item)] = value
  end

  # The number of cached items
  def size
    @lookup_hash.values.length
  end

  def member?(item)
    found = @lookup_hash.member?(@hash_lambda.call(item))
    #Rescape::Config.log.info("#{@cache_name}: Cache #{found ? 'hit' : 'miss'} for item key #{@hash_lambda.call(item)}")
    found
  end

  def find_or_nil(item)
    @lookup_hash[@hash_lambda.call(item)]
  end

  def [](item)
    value = find_or_nil(item)
    raise "#{@cache_name}: Item #{item} is not in the cache" unless value
    value
  end

  # Find or create the cached value for the dual_way_pair. The build_block passes the dual_way_pair and should return
  # the value to be cached
  def find_or_create(item, &build_block)
    self.find_or_nil(item) || self.add(item, build_block.call(item))
  end

  # Like find_or_create, but doesn't cache the result of the build_block, so that caching can be done manually by the caller. This is useful when more than one cacheable result is produced by the build_block, such as intermediate or reverse results, that can be cached
  def find_or_create_without_caching(item, &build_block)
    self.find_or_nil(item) || build_block.call(item)
  end

  def clear!
    @lookup_hash.clear()
  end
end