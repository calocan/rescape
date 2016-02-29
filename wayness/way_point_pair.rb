require 'utils/data_pair'
require 'utils/array_module'
require 'wayness/way_point_pair_behavior'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Way_Point_Pair < Array
 include Way_Point_Pair_Behavior

  attr_reader :way_point1, :way_point2, :way
  def initialize(way_point1, way_point2)
    @way_point1 = way_point1
    @way_point2 = way_point2
    @way = @way_point1.way
    super([@way_point1, @way_point2])
  end

   # Reverse each way_point and the position in the pair
   def reverse()
     self.class.new(way_point2.reverse(), way_point1.reverse())
   end

   # Needed only to conform to the Way_Point_Pair_Basic_Behavior interface
   def way_point_pair(way_grouping=nil)
     self
   end

  # Creates way_point_pair instances from the given way_points
  def self.create_from_way_points(way_points)
   way_points.map_with_subsequent {|way_point1, way_point2| Way_Point_Pair.new(way_point1, way_point2) }
  end

  # The default partial class to use for splitting data_pairs
  def self.partial_class
    Partial_Data_Pair
  end
end

