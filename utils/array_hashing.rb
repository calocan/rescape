#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Array_Hashing

  # Maps the given list to a hash using the two lambda functions on each item
  def map_to_hash(key_lambda, value_lambda)
    Hash[*self.flat_map { |v|
      [key_lambda.call(v), value_lambda.call(v)]
    }]
  end

  # Like map_to_hash but recurring key results are expected, therefore the values of the hash are arrays containing the one or more value per key
  def map_to_hash_with_recurring_keys(key_lambda, value_lambda)
    hash = {}
    self.collect { |item|
      key = key_lambda.call(item)
      if (hash[key] == nil)
        hash[key] = []
      end
      hash[key].push(value_lambda.call(item))
    }
    hash
  end

  # Maps the values of the list to hash keys and uses the block to map each item to a corresponding value
  def to_hash_keys(&block)
    Hash[*self.flat_map { |v|
      [v, block.call(v)]
    }]
  end

  # Maps the values of the list to hash values and uses the block to map each item to a corresponding key
  def to_hash_values(&block)
    Hash[*self.flat_map { |v|
      [block.call(v), v]
    }]
  end

  # Creates a two-level-deep hash. Given an array [a,b,c,...] the
  # block takes each value a,b,c,... and returns {x1=>{xx1=>xxx1,...}, x2=>{xx2=>xxx2,...}}
  # Each block result is added to a final hash.
  # Thus if a => {x1=>{xx1=>xxx1,...}, x2=>{xx2=>xxx2,...}} and b => {x1=>{yy1=>yyy1,...}, x2=>{yy2=>yyy2,...}}
  # The final result would be
  # {x1=>{xx1=>xxx1,yy1=>yyy1}, x2=>{xx2=>xxx2,yy2=>yyy3}}
  # In other words, if there are duplicate keys in the first dimension, the second dimension key/values will be put
  # together under a single key
  # ignore_duplicates true means don't reset a value once set, default true
  def map_to_two_deep_hash(ignore_duplicates=true, &block)
    hash = {}
    self.each { |item|
      hash_result = block.call(item)
      hash_result.each {|key,sub_hash|
        if (hash[key] == nil)
          hash[key] = {}
        end
        sub_hash.each {|k,v|
          hash[key][k] = v unless hash[key][k] and ignore_duplicates
        }
      }
    }
    hash
  end

  # Maps each value of the array to a list of values returned by block. Each list result is used
  # as a key of the returned hash and the original array value it mapped from is pushed into the
  # hash value. Thus there can be 1 or more hash keys and each hash value contains 1 or more original
  # array value
  # Example: a list of edges each with two vertices is mapped to a hash keyed by vertices and valued
  # by the edges that contain that vertex. This data structure can then be used to show which vertices
  # belong to 1 or more edges.
  def to_many_to_many_hash(&block)
    hash = {}
    self.collect { |v|
      list = block.call(v)
      list.each { |item|
        value = v # copy since v is a closed reference that will change
        if (hash[item] == nil)
          hash[item] = []
        end
        hash[item].push(value)
      }
    }
    hash
  end

  # Map the values in the array to a hash keyed by map result of the block,
  # valued by the collection of array values that map to the same key
  # Thus there are between 1 and N keys, where N is the size of the array,
  # and each collection contains 1 to N values from the array.
  def to_hash_value_collection(&block)
    map_to_hash_with_recurring_keys(block, lambda {|x| x})
  end

  # Maps parallel arrays to hash. The optional block takes an item from each array and must return a two element array
  def to_hash_keys_with_values(other_array)
    block = block_given? ? lambda {|a,b| yield(a,b)} : nil
    Hash[*(block ? self.dual_map(other_array, &block) : self.dual_map(other_array)).shallow_flatten]
  end

  # Assumes all items of this collection are hashes and merges. Assumes all keys are distinct
  # Optionally takes a block that takes the key, original, and new values to resolve duplicate keys
  def merge_hashes()
    if (self.length == 0)
      {}
    elsif (self.length == 1)
      self.only
    else
      block = block_given? ? lambda {|a,b,c| yield(a,b,c)} : lambda {|a,b,c| c}
      self.rest.inject(self.first) {|combined, item| combined.merge(item, &block)}
    end
  end
end