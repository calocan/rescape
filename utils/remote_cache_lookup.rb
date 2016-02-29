# Attempts to lookup a cache over DRb. It is assumed the remote process uses an instance of this cache to do the lookup. Thus there are remote methods defined that go over the wire and local methods defined that are to be called on the remote side
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/cache_lookup'

class Remote_Cache_Lookup < Cache_Lookup

  attr_reader :external_server_lambda
  # Initializes the cache like Cache_Lookup but adds a external_server DRbObject that proxies an External_Server class to query before resorting solving and writing to the local cache. Nothing will ever be cached to the external_server that is solved locally
  # cache_set_key is a unique identifier to pass to the server that it knows what cache space to search. Both cache_name and cache_set_key are passed to uniquely identify the cache on the server.
  # If the external_server is nil it then this functions just like Cache_Lookup
  def initialize(cache_name, hash_lambda=lambda {|item| item.hash}, external_server_lambda=lambda{nil}, cache_set_key=nil)
    super(cache_name, hash_lambda)
    @external_server_lambda = external_server_lambda
    @cache_set_key = cache_set_key
  end

  # Override Cache_Lookup to delegate to the external_server when the item isn't stored locally
  def member?(item)
    found = @lookup_hash.member?(@hash_lambda.call(item))
    #Rescape::Config.log.info("#{@cache_name}: Local cache #{found ? 'hit' : 'miss'} for item key #{@hash_lambda.call(item)}")
    found = found || remote_member?(item)
    found
  end

  # Calls the external_server's member? method, which expects the hash of the item, rather than the item itself.
  # This prevents the item from having to be serialized
  def remote_member?(item)
    found = @external_server_lambda.call() ? @external_server_lambda.call().member?(cache_name, @cache_set_key, @hash_lambda.call(item)) : false
    #Rescape::Config.log.info("#{@cache_name}: Remote cache #{found ? 'hit' : 'miss'} for item key #{@hash_lambda.call(item)}")
    found
  end

  # Called on the remote server to see if the key given by the remote_member? call exists
  def local_member?(item_hash_key)
    @lookup_hash.member?(item_hash_key)
  end

  # Override Cache_Lookup to delegate to the external_server when the item isn't stored locally
  def find_or_nil(item)
    value = @lookup_hash[@hash_lambda.call(item)]
    #Rescape::Config.log.info("#{@cache_name}: Local cache #{value ? 'hit' : 'miss'} for item key #{@hash_lambda.call(item)}")
    value || (@external_server_lambda.call() && remote_find_or_nil(item))
  end

  # Calls the external_server's find_or_nil method, which expects the hash of the item, rather than the item itself.
  # This prevents the item from having to be serialized
  def remote_find_or_nil(item)
    value = @external_server_lambda.call().find_or_nil(cache_name, @cache_set_key, @hash_lambda.call(item))#
    # We don't expect misses unless the user starts solving paths very quickly, so log them
    Rescape::Config.log.warn("#{@cache_name}: Remote cache miss for item key #{@hash_lambda.call(item)}") unless value
    value
  end

  def local_find_or_nil(item_hash_key)
    @lookup_hash[item_hash_key]
  end

  def remote_cache_lookup
    @external_server_lambda.call().get_cache_lookup(cache_name, @cache_set_key)
  end

  # Copy the entire hash fro the external server to the local_hash, favoring the values of the local hash
  def sync_remote_to_local
    @lookup_hash.merge!(remote_cache_lookup.lookup_hash) {|key,local,remote| local}
    true
  end

  # The number of items in the remote cache
  def remote_size()
    @external_server_lambda.call().size(cache_name, @cache_set_key)
  end
end