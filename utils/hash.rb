#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Hash

  # Ruby returns an array for Hash.select when it should return a hash
  # This will be fixed in a future Ruby version
  def select_to_hash(&block)
     Hash[*self.select{|key,value| block.call(key,value)}.shallow_flatten]
  end

  # Maps the values of a hash to new values by passing the key and value to the block
  # The value returned by the block becomes the new value
  def map_values_to_new_hash(&block)
    Hash[*self.map { |key,value|
      [key, block.call(key, value)]
    }.shallow_flatten]
  end
  # Maps the keys of a hash to new values by passing the key and value to the block
  # The key returned by the block becomes the new value
  def map_keys_to_new_hash(&block)
    Hash[*self.map { |key,value|
      [block.call(key, value), value]
    }.shallow_flatten]
  end
  # Maps the keys and values to new key/values
  # block accepts a key and value and must return a pair to become new key/values or any even number to become key value
  def map_to_new_hash(&block)
    Hash[*self.map { |key,value|
      block.call(key,value)
    }.shallow_flatten]
  end

  # Maps the key and value of two items of the hash at a time
  def map_with_subsequent
    pairs = self.map { |key,value|
      [key,value]
    }
    pairs.map_with_subsequent {|pair1, pair2|
      block_given? ? yield(*[pair1, pair2].shallow_flatten) : [pair1, pair2]
    }
  end

  # Like map, but but flattens the results of each mapped pair for cases when each pair returns and array
  def flat_map
    map_lambda = lambda {|key, value| block_given? ? yield(key,value) : [key,value]}
    self.map {|key, value|
      map_lambda.call(key, value)
    }.shallow_flatten
  end

  # Returns the values of the given keys in order
  def values_of(keys)
    keys.map {|key| self[key]}
  end
end