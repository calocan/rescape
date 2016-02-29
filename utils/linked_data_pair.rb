# Extends Data_Pair for classes that are aware of their neighbors, such as Edge
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/data_pair'

module Linked_Data_Pair
  include Data_Pair
  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Data_Pair)
  end

  # Uses each Linked_Data_Point's data_pairs method to determine the neighbor
  def neighbors
    self.data_points.map {|data_point| data_point.data_pairs.reject{|pair| pair==self}}.shallow_flatten.uniq
  end

  # Maps the neighbors by point to {point1=>neighbors1, point2=>neighbors2}
  def neighbors_by_point
    self.data_points.map_to_hash(lambda{|data_point| data_point.point},
                                 lambda {|data_point| data_point.data_pairs.reject{|pair| pair==self}})
  end

  # Find the neighbor of this data_pair connected to this data_point
  def neighbors_by_data_point(data_point)
    data_point.data_pairs.reject{|pair| pair==self}
  end

end