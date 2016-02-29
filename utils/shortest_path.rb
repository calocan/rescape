# Dykstra's algorithm implemented functionally
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Shortest_Path

  attr_reader :list
  # Supply the list of nodes (or edges) to graph.
  # get_weight_lambda takes the current_node and a neighbor_node and returns the weight of the edge between them
  # (if you are graphing edges without nodes get_weight_lambda should return the weight of the first argument)
  # get_neighbors_lambda takes the current item from list and the path leading up to the current item (INCLUDING the current item) and returns the items in the list that are neighbors
  # cache_lookup is a Cache_Lookup instance that should be given if the results of need to be cached. This will also cache the intermediate results of the path.
  # Specify cache_reverse_results as true in order to also cache the reverse results of the solved path and intermediate paths. This adds performance to two-way graphs with bidirectionally equal weights
  def initialize(list, get_weight_lambda, get_neighbors_lambda, cache_lookup=nil, cache_reverse_results=false)
    @list = list
    @get_weight_lambda = get_weight_lambda
    @get_neighbors_lambda = get_neighbors_lambda
    @cache_lookup = cache_lookup
    @cache_reverse_results = false
  end

  # Solves the paths from one item to all others or the path between two or more items
  # Specify one item in items to get the solutions to all other nodes
  # Specify two or more items to get the solution from the first item to the last item via any middle items
  # The path data returned are in the form {:path=>ordered_items, :item=>target_item, :weight=>total_weight}
  # where ordered_items are all items from the start_item to the target_item not including the target_item
  def solve(items, return_nil_on_bad_path=false)
    raise "No items passed to shortest_path.solve" if (items.length==0)
    $st=start_item = items.first
    rest = items.rest
    # Create a hash keyed by items that gives the path from the start_item to the item and the weight of the path. Initially all weights are maximized; the path visit algorithm will use this to store minimized paths
    items_to_path_data = @list.reject{|item| item==start_item}.to_hash_keys{|item| {:path=>[], :weights=>[], :weight=>Float::MAX}}
    # This returns a solution from the start_item to rest.first, plus solutions to all nodes encountered in the process
    # If next_item is nil the cache lookup will always fail and it will solve the path to all other items
    $nx=next_item = rest.first
    $sol= solutions =
      ((next_item && (start_item==next_item || @get_neighbors_lambda.call(start_item, [start_item]).member?(next_item))) ?
        identical_or_neighbor_solution(start_item, next_item) :
        @cache_lookup.find_or_create_without_caching([start_item, next_item]) {|two_items|
          # Find the path between the two items, or between the start_item and all other items if next_item is nil. Either way, multiple solutions will be generated as the path from start_item to any other item encountered in the search is retured as a solution. Cache all found solutions if the @cache_lookup is defined
          visit([two_items[0]],
                0,
                [],
                items_to_path_data,
                two_items[1]).each {|solution|
            cache_result(solution)}
        }).as_array_if_singular

    if (rest.length == 0)
      # If we solved from a single item to all others, return all solutions
      solutions
    else
      # Find the solution matching from the first to second item.
      solution = solutions.find{|solution| solution.item==rest.first}
      unless (solution)
        if (return_nil_on_bad_path)
          Rescape::Config.log.warn("Could not solve path between #{start_item.inspect} and #{rest.first.inspect}")
          nil
        else
          raise "The path to items #{start_item.inspect} and #{rest.first.inspect} was not found. Make sure all items are connected or that the get_neighbors_lambda is resolving neighbors correctly"
        end
      end
      # Find the path to the rest of the items, concatinating the solutions
      if (rest.length > 1)
        if solution.path.member?(rest.first)
          raise "Item to solve #{rest.first.inspect} is already part of the path between previous items to solve: #{solution.path.inspect}. This is not permissible unless the path is allowed to intersect itself."
        end
        solution + solve(rest)
      else
        solution
      end
    end
  end

  # Dykstra's algorithm with shortest paths recorded
  # Visit the first item and then the start item on recursive calls.
  # The closest item is defined by the items that has the lowest accumulative weight from the start item
  # After an item that is the last item of current path is finalized, it won't be in the items_to_path_data
  # current_path contains the ordered list of items from the start item to the current item
  # current_weight is the accumulated weight of the current_path
  # items_to_path_data is an array of all items that have not yet been finalized.
  # It's form is {item=>{:path=>path, :weight=>weight, :weights=>[]]} where path is an array of the best path thus far
  # to this item and weight is the corresponding weight of the path. :weights tracks the weight of each item of the path (the latter is completely optional, but useful to calculate find sub solutions)
  # The optional argument target_item tells visit to stop finding paths when the path to
  # target_item has been found
  # Returns [{:item=>item, :path=>path, :weight=>weight} indicating the final best path to each item,
  # where path includes item as the last element
  def visit(current_path, current_weight, path_weights, items_to_path_data, target_item=nil)
    current_item = current_path.last
    # Get all the neighbors of the current item that remain in items_to_path_data
    modified_items_to_path_data = optimize_neighbor_paths(current_item, current_path, current_weight, path_weights, items_to_path_data)
    # Sort all items by weight  and take the first result
    next_item_to_path_data = get_next_item_to_path_data(modified_items_to_path_data)
    if (next_item_to_path_data==nil)
      # End if there are no more reachable items
      []
    else
      (next_item, next_path_data) = next_item_to_path_data
      # Finish the next item by recording its final path data and recursing with it as the current item
      solution_path = next_path_data[:path]+[next_item]
      solution = Solution.new(next_item, solution_path, next_path_data[:weight], next_path_data[:weights])
      rest = modified_items_to_path_data.reject{|item, path_data|
        item==next_item}
      if (rest.length != modified_items_to_path_data.length-1)
        raise "Item not eliminated: Item: %s Remaining: %s" % [next_item.hash, modified_items_to_path_data.keys.map {|x|x.hash}.sort.inspect]
      end
      # Move on to the next solution or stop if the target_item has been found
      [solution] + ((target_item and next_item==target_item) ? [] : visit(solution_path, next_path_data[:weight], next_path_data[:weights], rest))
    end
  end

  # A trivial solution when two items are neighbors or identical
  def identical_or_neighbor_solution(start_item, neighbor_item)
    weight = @get_weight_lambda.call(start_item, neighbor_item)
    Solution.new(neighbor_item, [start_item, neighbor_item], weight, [weight])
  end

  # If @cache_lookup is specified, cache the solution path keyed by the first item of the path and the solution item
  # Also cache the reverse path is @cache_reverse_results is true
  def cache_result(solution)
    if @cache_lookup
      [solution, solution.reverse].each {|cache_solution|
        @cache_lookup.add([cache_solution.path.first, cache_solution.item], cache_solution)
      }
      # Cache the intermediate solutions by recursing
      if (solution.path.length >= 2)
        cache_result(solution.pop())
      end
    end
  end

  # Calculate new paths to the immediate neighbors and use them to optimize the full path to the neighbor
  # current_path is the path leading up to the current_item INCLUDING the current item
  def optimize_neighbor_paths(current_item, current_path, current_weight, path_weights, items_to_path_data)
    items = items_to_path_data.keys
    neighbors = @get_neighbors_lambda.call(current_item, current_path).find_all {|neighbor| items.member?(neighbor)}
    # Modify items_to_path_data entries that are neighbors and have new lower weights
    items_to_path_data.map_values_to_new_hash { |item, path_data|
      new_weight = neighbors.member?(item) ? current_weight + @get_weight_lambda.call(current_item, item) : nil
      if (new_weight != nil and new_weight < path_data[:weight])
        {:path=>current_path, :weight=>new_weight, :weights=>path_weights+[new_weight]}
      else
        path_data
      end
    }
  end

  # Gets the lightest item that hash already been reached
  def get_next_item_to_path_data(modified_items_to_path_data)
    modified_items_to_path_data.find_all { |item, path_data|
      path_data[:path].length > 0 }.sort_by { |item, path_data| path_data[:weight] }.first
  end

  def min(path_data1, path_data2)
    path_data1[:weight] <= path_data2[:weight] ? path_data1 : path_data2
  end
  def add(path_data1, path_data2)
    {:path=>path_data1[:path]+path_data2[:path].rest, :weight=>path_data1[:weight]+path_data2[:weight], :weights=>path_data1[:weights]+path_data2[:weights]}
  end

end

# A simple class to store pathing solutions. The item is the item being sought and the path are the connected items leading up to item including the item itself. The weight specifies the cost of the path, whether it is in distance or other units
class Solution
  attr_reader :item, :path, :weight, :weights
  def initialize(item, path, weight, weights)
    @item=item
    @path=path
    @weight = weight
    $soufds = self
    raise "WHAAA" unless weights
    @weights = weights
  end

  # Add solutions to together for multi-leg trips
  # The path must be pruned for duplicates that result in combining paths
  def +(solution)
    solution != nil ?
        Solution.new(@item, @path + solution.path.rest, @weight+solution.weight, @weights+solution.weights) :
        self
  end

  # Remove the first item of the solution to create a solution from the second item
  def pop()
    path = @path.rest
    weights = @weights.rest
    Solution.new(path.last, path, weights.inject(0) {|total, weight| total+weight}, weights)
  end

  # Reverses the solution, creating a solution where item is the fist item of path and path is reversed
  # Weight remains the same, since it's assumed the path is bidirectionally equal in weight
  def reverse()
    self.class.new(@path.first, @path.reverse, @weight, @weights.reverse)
  end

  def inspect
    "#{self.class} of path:%s, weight:%s" % [@path.map{|item| item.inspect}.join("==>\n"), @weight]
  end
end