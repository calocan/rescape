# Operations on arrays/sets of lists
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module List_Sets
  # For collections of collections, remove any collection that is empty
  def reject_empty_collections()
    self.reject {|list| list.length==0}
  end

  # For a pair of sets, reverses the second set of the pair
  def reverse_second_of_pair()
    raise "expected two lists" unless self.length==2
    [self.first, self.last.reverse]
  end

  # Splits the list into sets whenever the given condition is met
  # The block should return true wherever a new set shall be started.
  # if empty_set_if_first_matches is true (false by default) it will return the first set empty if the block succeeds on the first item. Otherwise the first item will not be tested and will always be the first member of the first set
  def create_sets_when(empty_set_if_first_matches=false, &block)
    return [] if self.length == 0
    # Always take the first item so that each set has at least one element
    first = self.first
    rest = self.rest
    if (empty_set_if_first_matches)
      # Get two sets, those up to the match and those after
      results = self.take_whilst(true) {|item| !block.call(item)}
      # Return those up to the match as a set and iterate on those after
      [results[0]] + results[1].create_sets_when(&block)
    else
      # Get two sets, those up to the match and those after
      results = rest.take_whilst(true) {|item| !block.call(item)}
      # Return first+those up to the match as a set and iterate on those after
      [[first]+results[0]] + results[1].create_sets_when(&block)
    end
  end

  # Like create_sets_when but passes the current item and the previous item to the block
  def create_sets_with_previous_when(&block)
    return [] if self.length == 0
    # Always take the first item so that each set has at least one element
    first = self.first
    rest = self.rest
    results = rest.take_while_with_previous(true) {|item, previous_item| !block.call(item, previous_item || first)}
    [[first]+results[0]] + results[1].create_sets_with_previous_when(&block)
  end

  # Like create_sets_when but simply looks for block to return a different value than previously. When this occurs a new set is created
  def create_sets_when_change_occurs(&block)
    return [] if self.length == 0
    results = self.take_until_change(true, &block)
    [results[0]] + results[1].create_sets_when_change_occurs(&block)
  end

  def total_count()
    self.inject(0) { |result, item| result + item.length }
  end

  # Returns true if all sets are equal. Optionally a mapping block can be provided
  def sets_all_same?()
    return true if empty?
    lambda = block_given? ? lambda {|item| yield(item)} : lambda {|item| item}
    set = lambda.call(self.first)
    self.rest.all? {|item|
      other_set = lambda.call(item)
      set.length==other_set.length &&
      set.dual_map(other_set) {|set_item, other_set_item|
        other_set_item.kind_of?(set_item.class) &&
        set_item == other_set_item
      }.all?
    }
  end

end