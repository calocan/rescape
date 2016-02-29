# Loads way data (streets, paths, rail, etc) from openstreetmpap.org or a cached data source
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Sorting

  # Chains together a list of items using a lambda to get the next item to chain and an optional transformation function
  # to apply to the matched item. Chained items are concatenated with the + operator
  # Chained items must be an array with at least one item.
  # next_match_lambda is called by unchained_items.find on takes two arguments, the first is the last_chained_item
  # and the second is each unchained_item.
  # transform_match is called with the last_chained item and the item found in next_match_lamda
  # if no match is found by next_match_lamda, and exception is raised.
  def self.chain(items, next_match_lambda, start_chain_lambda=lambda {|unchained_items| unchained_items.first}, transform_match_lambda=lambda {|x,item| item})
    raise "Items are nil" unless items != nil
    self.internal_chain([], items, next_match_lambda, start_chain_lambda, transform_match_lambda)
  end

  def self.internal_chain(chained_items, unchained_items, next_match_lambda, start_chain_lambda=lambda {|unchained_items| unchained_items.first}, transform_match_lambda=lambda {|x,item| item})
    if (unchained_items.length==0)
        return chained_items
    end
    if (chained_items.length == 0)
      # Start case of each chain, use start_chain_lambda to start a new chain
      start_item = start_chain_lambda.call(unchained_items)
      if (start_item == nil)
        raise "Failed to retrieve a start item. Remaining items: %s" % unchained_items.inspect
      end
      chained_items = [start_item]
      unchained_items = unchained_items.reject{|item| item.hash==start_item.hash}
      if (unchained_items.length==0)
        # This is the one item case
        return chained_items
      end
    end
    last_chained_item = chained_items.last
    matched_item = unchained_items.find {|unchained_item| next_match_lambda.call(last_chained_item, unchained_item)  }

    if (matched_item==nil)
        raise "Chain broke. Last sorted link: %s, remaining: %s" % [last_chained_item.inspect, unchained_items.inspect]
    end
    transformed_matched_item = transform_match_lambda.call(last_chained_item, matched_item)
    internal_chain(chained_items+[transformed_matched_item],
                     unchained_items.reject{|item| item==matched_item},
                     next_match_lambda,
                     transform_match_lambda)
   end

  # Like chain, but doesn't throw an exception if no match is found. Instead it starts a new collection of chained
  # items with the first item in unchained items.
  # If chained_items is nil, the first item from unchained_items will start the first chain.
  # returns a set of collections of chained items.
  # next_match_lambda(last_chained_item, each_unchained_item) is called on each_unchained_item where last_chained_item is
  # is the last_chained_item. The first item that returns true will be used as the next match
  # start_chain_lambda(unchained_items) to get the first chained item at the start of each new chain. By
  # default it returns the next unchained item in the list
  def self.make_chains(items, next_match_lambda, start_chain_lambda=lambda {|itemoj| itemoj.first} )
    raise "Items are nil" unless items != nil
    self.internal_make_chains([], items, next_match_lambda, start_chain_lambda)
  end
  
  def self.internal_make_chains(chained_items, unchained_items, next_match_lambda, start_chain_lambda)
    if (unchained_items.length==0)
      # Terminal case, returned the last set of chained_items if anything is in it.
      return chained_items.length > 0 ? [chained_items] : []
    end

    if (chained_items.length == 0)
      # Start case of each chain, use start_chain_lambda to start a new chain
      start_item = start_chain_lambda.call(unchained_items)
      raise "start_chain_lambda returned nil!" unless (start_item)
      chained_items = [start_item]
      unchained_items = unchained_items.reject{|item| item.hash==start_item.hash}
      if (unchained_items.length==0)
        # Only one item left
        return [chained_items]
      end
    end
    # Use next_match_lambda to find the next item for the chain
    last_chained_item = chained_items.last
    matched_item = unchained_items.find {|unchained_item| next_match_lambda.call(last_chained_item, unchained_item)  }

    if (matched_item==nil)
      # No match was found so the chain ends and we start the next chain
        [chained_items] + internal_make_chains([],
                                                unchained_items,
                                                next_match_lambda,
                                                start_chain_lambda)
    else
      # A next item was found so we continue this chain
      internal_make_chains(chained_items+[matched_item],
        unchained_items.reject{|item| item==matched_item},
        next_match_lambda,
        start_chain_lambda)
    end
  end
end
