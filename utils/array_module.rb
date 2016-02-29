require 'utils/array_sorting'
require 'utils/array_hashing'
require 'utils/list_sets'

# Modularizes common array methods and many new methods
# for use by classes that implement Enumerable and to extend the Array class itself
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Array_Module
  include Array_Hashing
  include Array_Sorting
  include List_Sets

  def sum()
    self.inject(0.0) { |result, el| result + el }
  end

  def mean()
    self.sum() / self.length
  end

  # Copy common array methods

  def last
    self[-1]
  end

  # Flatmap function
  # Maps the values to list of collections that have the same map result for each item.
  # The merge function is then called on each collection to merge the values into one entity
  # The resultant list of entities is returned.
  def merge_by_map_result(map,merge)
    hash = self.to_hash_value_collection {|item| map.call(item)}
    hash.values.map {|list| merge.call(list)}
  end

  # Greps the each item but also passes in the item after it. The last item always returns true.
  def grep_with_subsequent()
    results = []
    self.each_index { |index|
      if index == self.length-1 or yield(self[index], self[index+1])
        results.push(self[index])
      end
    }
    results
  end

  def grep_with_subsequent_with_loop_option(loop_last, &lambda)
    results = []
    (0..self.length-1).each { |index|
      if index < self.length-1
        results.push(self[index]) if lambda.call(self[index], self[index+1])
      elsif loop_last and index == self.length-1
        results.push(self[index]) if lambda.call(self[index], self[0])
      end
    }
    results
  end

  def grep_with_previous()
    results = []
    self.each_index { |index|
      if yield(self[index], index-1 >= 0 ? self[index-1] : nil)
        results.push(self[index])
      end
    }
    results
  end
  def grep_with_previous_and_subsequent()
    results = []
    self.each_index { |index|
      if yield(
          index > 0 ? self[index-1] : nil,
          self[index],
          index < self.length-1 ? self[index+1] : nil)
        results.push(self[index])
      end
    }
    results
  end

  def grep_with_previous_and_subsequent_with_loop_option(loop_last, &grep_block)
    results = []
    (0..self.length-1).each { |index|
    # Don't map the last item if loop_last==false
      if index < self.length-1 or loop_last
        if (grep_block.call( (loop_last && index==0) ? self[-1] : (index>0 ? self[index-1] : nil),
                                      self[index],
                                      (loop_last && index==self.length-1) ? self[0] : self[index+1]))
          results.push(self[index])
        end
      end
    }
    results
  end

  # Maps each item but also passes in the item after it to the passed in function. The last item is not mapped.
  # This creates a set of results one smaller than the original, useful for mapping each adjacent pair of items to a value
  # if loop_last is true the map will additionally return a pair of the last item and first item, false by default
  def map_with_subsequent
    results = []
    (0..self.length-1).each { |index|
      if index < self.length-1
        results.push(block_given? ? yield(self[index], self[index+1]) : [self[index],self[index+1]])
      end
    }
    results
  end

  # Maps the each member of the collection with the previous and subsequent item. The previous item is nil on the first iteration and the subsequent item is nil on the last iteration. Use map_with_previous_and_subsequent_with_loop_option to make the previous and subsequent items wrap.
  def map_with_previous_and_subsequent
    block = block_given? ? lambda {|previous, current, subsequent| yield(previous, current, subsequent)} : lambda {|previous, current, subsequent| [previous, current, subsequent]}
    results = []
    (0..self.length-1).each { |index|
      results.push(block.call(index>0 ? self[index-1] : nil, self[index], index < self.length-1 ? self[index+1] : nil))
    }
    results
  end

  def map_with_subsequent_with_loop_option(loop_last)
    results = []
    (0..self.length-1).each { |index|
      if index < self.length-1
        pair = [self[index], self[index+1]]
        results.push(block_given? ?  yield(pair) : pair)
      elsif loop_last and index == self.length-1
        pair = [self[index], self[0]]
        results.push(block_given? ? yield(pair) : pair)
      end
    }
    results
  end

  # Maps each item with the previous and subsequent item. The last item will be mapped with a nil next_item unless loop_last is true, in which case the subsequent item will be the first item. Likewise if loop_last is true, for the first iteration the previous item will be the last item and otherwise nil
  # loop_last is true to loop, false to not loop
  # map_lambda is a function that expects three items from the collection: the previous, current, and subsequent
  def map_with_previous_and_subsequent_with_loop_option(loop_last, &map_lambda)
    results = []
    (0..self.length-1).each { |index|
      results.push(map_lambda.call( (loop_last && index==0) ? self[-1] : (index>0 ? self[index-1] : nil),
                                    self[index],
                                    (loop_last && index==self.length-1) ? self[0] : ((index==self.length-1) ? nil : self[index+1])))
    }
    results
  end

  def map_with_index(index=0, &map)
    return [] if self.empty?
    [map.call(self.first, index)] + self.rest.map_with_index(index+1, &map)
  end

  # Determines if the collection is a loop, meaning the start and end items. The method accepts an optional mapping block, but defaults to an identity map
  def is_loop?()
      items = self.map {|item| block_given? ? yield(item) : item}
      items.first==items.last
  end

  # Returns the collection with the first item added to the end, if the first and last item aren't already identical
  # The optional map block maps the first and last items to values to determine equality of the items. It defaults to the identity function
  def loop_by_map
    first_and_last = [self.first, self.last].map {|item| block_given? ? yield(item) : item}
    self + (first_and_last.first==first_and_last.last ? [] : [self.first])
  end
  
  # Maps each item but also passes in the item after it to the passed in function.
  # The function is expected to return a pair of values where the first value is put in the result list and the second becomes the first argument for the next iteration.
  # The last item is not mapped.
  # This creates a set of results one smaller than the original, useful for mapping each adjacent pair of items to a value where the previous iteration may affect the parameter of the next iteration
  def map_with_subsequent_and_propagate()
    results = []
    previous_result = nil
    self.each_index { |index|
      previous_result_or_current_value = previous_result ? previous_result : self[index]
      if index < self.length-1
        pairs = yield(previous_result_or_current_value, self[index+1])
        results.push(pairs[0])
        previous_result = pairs[1]
      else
        results.push(previous_result_or_current_value)
      end
    }
    results
  end

  def shallow_flatten()
    results = []
    self.each { |item|
      if item.is_a? Array
        results.concat item
      else
        results.push item
      end
    }
    results
  end

  def uniq_by_hash
    uniq_by_map{|item| item.hash}
  end
  # Returns the first occurrence of each unique item according to the block result
  # Order is preserved
  def uniq_by_map(&block)
    found_values = {}
    self.find_all{|x|
      value = block.call(x)
      found = found_values.has_key? value
      found_values[value] = true
      !found
    }
  end

  # Like unique by map, but permits the first and last element to be identical
  def uniq_allow_loop()
    uniq_by_map_allow_loop {|x| x}
  end
  def uniq_by_map_allow_loop(&block)
    return self if self.length <= 1
    last = block.call(self.last)
    found_values = {}
    results = self.all_but_last.find_all{|x|
      # Map the item to it's unique check value
      value = block.call(x)
      # See if this value exists yet
      found = found_values.has_key? value
      # Mark that it exists
      found_values[value] = true
      !found
    }
    # Allow the last value unless it duplicates something other than the first item
    (!found_values[last] || last==block.call(results.first)) ? results+[self.last] : results
  end

    # Eliminates consecutive duplicate values from the list
  def uniq_consecutive(last_value=nil)
    return [] if self.length == 0
    (last_value != self.first  ? [self.first] : []) + self.rest.uniq_consecutive(self.first)
  end

  # Eliminates consecutive duplicate values from the list based on their mapping with &block
  def uniq_consecutive_by_map(last_value=nil, &block)
    return [] if self.length == 0
    ((!last_value or (block.call(last_value) != block.call(self.first))) ? [self.first] : []) + self.rest.uniq_consecutive_by_map(self.first, &block)
  end

    # Eliminates consecutive duplicate values from the list based on their mapping with map_lambda. merge_lambda takes two consecutive items that map to the same value and returns the merge result of the two instead of either of the items
  # This only works for two consecutive items that map to the same value, not three or more
  def uniq_consecutive_by_map_with_merge(map_lambda, merge_lambda, last_item=nil)
    return [] if self.length == 0
    # Add each item to the result if it doesn't match the block call result of the previous item
    last_doesnt_match = (!last_item or (map_lambda.call(last_item) != map_lambda.call(self.first)))
    result = (last_doesnt_match ? [self.first] : [merge_lambda.call(last_item, self.first)])
    result + self.rest.uniq_consecutive_by_map_with_merge(map_lambda, merge_lambda, self.first)
  end

  def first()
    self[0]
  end

  def only(error_message=nil)
    raise (error_message ? error_message : "Expected a one element array. Found #{self.length} #{self.inspect}") unless self.length == 1
    self[0]
  end

  def none_or_one(error_message=nil)
    raise (error_message ? error_message : "Expected a one element or empty array. Found #{self.length} #{self.inspect}") unless self.length <= 1
    self.length==1 ? self[0] : nil
  end

  def require_range(min, max)
    range = Range.new(min, max)
    raise "Number of array values does not meet required range: #{range.inspect}. Found: #{self.inspect}" unless range.member?(self.length)
    self
  end

  # For two dimensional arrays when only one or no items in the outer dimension is expected
  # Returns that one item or an empty array if there are no items
  def only_set_or_empty_set(error_message='')
    raise "#{error_message} Expected a one element array but found %s" % [self.inspect] unless self.length <= 1
    self.length==1 ? self.first : []
  end

  def rest()
    self[1..-1]
  end

  def all_but_last()
    self[0..-2]
  end

  # Calls intersect on two arrays mapped by &block
  # The values of self that intersect according to the mapping are returned
  def intersect_on(other_array, &block)
    my_mapped_values = self.map {|item| block.call(item)}
    other_mapped_values = other_array.map {|item| block.call(item)}
    (my_mapped_values & other_mapped_values).map {|intersect_value| self[my_mapped_values.index(intersect_value)]}
  end

  # Maps this array collection with the given array, sending each pair of values to the block, or returning the pair as a two element array if no block is given
  def dual_map(other_array)
    raise "Unequal array length. Self: #{self.length} Parameter: #{other_array.length}" unless self.length==other_array.length
    block = block_given? ? lambda{|a,b| yield(a,b)} : lambda{|a,b| [a,b]}
    if (self.length==0)
      []
    else
      [block.call(self.first, other_array.first)] + self.rest.dual_map(other_array.rest, &block)
    end
  end

  # Like dual_map but makes the elements of this instance keys and the given elements the corresponding values. Optionally pass a block that takes each pair of values that returns an array of two values.
  def dual_hash(other_array)
    raise "Unequal array length. Self: #{self.length} Parameter: #{other_array.length}" unless self.length==other_array.length
    block = block_given? ? lambda {|a,b| yield(a,b)} : lambda {|a,b| [a,b]}
    if (self.length==0)
      {}
    else
      Hash[*self.dual_map(other_array, &block).shallow_flatten]
    end
  end

  def triple_map(array2, array3, &block)
    raise "Unequal array lengths" unless self.length==array2.length and self.length==array3.length
    if (self.length==0)
      []
    else
      [block.call(self.first, array2.first, array3.first)] + self.rest.triple_map(array2.rest, array3.rest, &block)
    end
  end

  # Returns an array from the given index and goes back to the beginning if
  # the end is reached up until start_index-1
  def looped_array_from_index(start_index)
    self[start_index..-1] + (start_index==0 ? [] : self[0..start_index-1])
  end

  # Rejects the given item from the list
  def reject_one(one)
    self.reject {|x| x==one}
  end
  # Rejects the given items from the list
  def reject_any(list)
    self.reject {|x| list.member?(x)}
  end

  # Maps each item in a set of set and then does a shallow flatten to make a single list
  def flat_map()
    block = block_given? ? lambda {|item| yield(item)} : lambda {|item| item}
    self.map {|item| block.call(item)}.shallow_flatten
  end

  # Expands each item of the array by calling map_item_to_list, where map_item_to_list_lambda returns a list of 0 or more values, or
  # by default the given item in a single element array.
  # The groups of mapped items are then flattened with shallow_flatten and filtered for uniqueness by
  # the given uniq_map_lambda, or unique by hash by default
  def flat_map_to_uniq(map_item_to_list_lambda=lambda {|x| [x]}, uniq_map_lambda=lambda {|item| item.hash})
    self.flat_map(&map_item_to_list_lambda).shallow_flatten.uniq_by_map(&uniq_map_lambda)
  end

  # A two step process that expects this array to be any number of groups of values (i.e. a 2D array) and maps each member
  # of each group according to the
  # map_item_to_list_lambda, which must return list of 0 or more values for each item.
  # map_item_to_list_lambda defaults to an identity map that puts the given item in a single element list
  # Within each group, the resulting lists are merged with shallow_flatten and items are made unique using uniq_by_hash
  # This entire process is equivalent to a flat_map operation, where items are expanded and then merged back together
  # Next each group of items is intersected with the other group based on a call to intersect_on, called on
  # each previous intersection result and the next group. intersect_on uses intersect_map_lambda as its block
  # to possibly map each item to a different value to evaluate equality
  # intersect_map_lambda defaults to hashing the item.
  # The combined results of the intersection are returned as an array of items
  def intersect_groups(map_item_to_list_lambda=lambda {|x| [x]}, intersect_map_lambda=lambda {|item| item.hash})
    # Find the way_point of each edge. The way_point is part of a linked_way.
    # Get the linked_way and all its neighbors and flatten them all
    # We fetch the neighbors because an important linked_way may be found for which no edges exist
    flat_mapped_groups = self.map {|group| group.flat_map_to_uniq(map_item_to_list_lambda) }
    flat_mapped_groups.inject(flat_mapped_groups.first) {|last, group| last.intersect_on(group, &intersect_map_lambda)}
  end

  # Returns duplicate items
  def duplicates()
    self.to_hash_value_collection {|item| item.hash}.values.find_all {|value| value.length > 1}.map {|value| value.first}
  end

  # Simply calls the given block with no arguments if this calling array is empty
  # Useful to chain operations that should occur if the previous operation returns an empty list
  def or_if_empty(&block)
    self.length > 0 ?
        self :
        block.call
  end

  # Calls the given block on the array if the array is not empty, where the array is the only argument to the block
  def if_not_empty(&block)
    self.length > 0 ?
        block.call(self) :
        self
  end

  # Maps the first and last item of the collection with the pair of values and passes it to the given block which expects the collection item and pair item. Middle values are left alone. Raises an exception if the collection has fewer than two items
  def map_first_and_last(collection, pair, &block)
    raise "Collection has fewer than two items: #{collection}" if collection.length < 2
    [block.call(collection.first, pair.first)] + collection[1..-2] + [block.call(collection.last, pair.last)]
  end

  # take_while exists in new Ruby versions, hence the naming take_whilst. take_whilst returns all values until the predicate fails
  # Optional return_rest makes the function return two sets, the matching and all after the matching, false by default
  def take_whilst(return_rest=false)
    items = []
    block = block_given? ? lambda{|item| yield(item) } : lambda {|item| item}
    self.each {|item|
      value = block.call(item)
      break unless value
      items.push(item)
    }
    return_rest ? [items, self[items.length..-1]] : items
  end

  # Like take_whilst put also passes the previous item to the block as the second argument
  def take_while_with_previous(return_rest=false)
    items = []
    block = block_given? ? lambda{|item, previous_item| yield(item, previous_item) } : lambda {|item, previous_item| item}
    self.map_with_previous_and_subsequent {|previous, item, subsequent|
      value = block.call(item, previous)
      break unless value
      items.push(item)
    }
    return_rest ? [items, self[items.length..-1]] : items
  end


  # Like take_whilst but returns mapped values until the value differs from the previous mapped value
  # Optional return_rest makes the function return two sets, the matching and all after the matching
  def take_until_change(return_rest=false)
    items = []
    block = block_given? ? lambda{|item| yield(item) } : lambda {|item| item}
    previous_value = nil
    self.each {|item|
      value = block.call(item)
      break unless !previous_value || value == previous_value
      previous_value = value
      items.push(item)
    }
    return_rest ? [items, self[items.length..-1]] : items
  end

  # Returns the first non-nil mapping result or nil if none are found
  def map_until_not_nil
    self.each {|item|
      value = block_given? ? yield(item) : item
      return value if value
    }
    nil
  end

  # Returns the first and last item. Raises an exception if the list is empty
  # The optional block accepts both extremes and maps them to new values
  def extremes()
    raise "Cannot take extremes of an empty list" if self.length == 0
    block = block_given? ? lambda {|first, last| yield(first, last)} : lambda {|first, last| [first,last]}
    block.call(self.first, self.last)
  end

  # Take the first and last element of the array or the only element
  # Raises if the array is empty
  def extremes_or_only()
    self.length > 1 ? extremes() : only()
  end

  # Returns all but the first and last values
  def intermediates()
    (self.length < 3) ?
      [] :
      self[1..-2]
  end

  def map_to_strings()
    self.map {|item| item.to_s}
  end

  # Returns true if all values are equal, or if a block is given if all map to the same value
  def all_same?()
    return true if empty?
    lambda = block_given? ? lambda {|item| yield(item)} : lambda {|item| item}
    value = lambda.call(self.first)
    self.rest.all? {|item|
      other = lambda.call(item)
      other.kind_of?(value.class) &&
      other==value
    }
  end

  # Convenience inspection method
  def inspect_join
    self.map {|x| x.inspect}.join("\n\n")
  end

  # Hash the items independent of the order
  def unordered_hash_key
    self.map {|item| item.hash}.sort.hash
  end

  # Greps the items by calling the given predicate block with the three items: previous, current, and subsequent.
  # The previous item is the previous item that wasn't eliminated by the predicate. The first item of the list is always returned.
  def grep_with_propagated_previous_and_subsequent(first_call=true, &block)
    if (self.length < 3)
      # Return the last two or one items. The first was already returned
      self.rest
    else
      previous = self[0]
      current = self[1]
      subsequent = self[2]
      rest = self[3..-1]
      (first_call ? [previous] : []) +
      (block.call(previous, current, subsequent) ?
          # Return the current item, make the current the previous in the next iteration
          [current] + ([current, subsequent]+rest).grep_with_propagated_previous_and_subsequent(false, &block) :
          # Don't return the current item, keep the previous as previous in the next iteration
          ([previous, subsequent]+rest).grep_with_propagated_previous_and_subsequent(false, &block)
      )
    end
  end

  # Returns the array as a single item if the template is a single item.
  # Returns the array unaltered if template is an array
  def match_plurality(template)
    template.kind_of?(Array) ? self : self.only
  end

end
