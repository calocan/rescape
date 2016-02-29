#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Array_Sorting

  # Like sort_by but expects the result of the block to be {:value=>value}
  # where any other key value pairs can be included for reference, such as the item that produced the value.
  # value is evaluated for the sort order
  # Thus the block might return {:value=>value, :item=>item, :foo=>bar} where only :value=>value is required
  # The hashes created by the blcok will be returned sorted by value
  def sort_to_hash(&block)
    item_and_value_hash_list = self.map(&block)
    item_and_value_hash_list.sort_by {|hash| hash[:value]}
  end

  # Sorts by given blocks and returns the values in sets where each set contains values that mapped to the same thing
  def sort_by_to_sets(&block)
    self.sort_to_hash {|item| {:item=>item, :value=>block.call(item)}}.create_sets_with_previous_when {|previous, current|
      previous[:value] != current[:value]
    }.map {|set| set.map {|hash| hash[:item]}}
  end
end