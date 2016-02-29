require 'wayness/way_point_pair'
require 'utils/data_point'

# Represents a fraction of a way_point_pair, using the pair of fractions given in range fraction to move each point
# a fraction of the way from @way_point1 to @way_point2 defined by an array [n,m] where 0 <= n < 1 and 0 < m <= 1
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Partial_Way_Point_Pair < Way_Point_Pair
  def initialize(way_point_pair, range_fraction_or_point_pair)
    super(*way_point_pair)
    if (range_fraction_or_point_pair.all? {|point| point.kind_of?(Data_Point)})
      @points = range_fraction_or_point_pair
    else
      @points = range_fraction_or_point_pair.map {|fraction|
        @way_point1.point.offset(@vector, fraction*vector.length)
      }
    end
  end

  # Returns the way_point_pair if range_fraction == [0,1]. Otherwise it constructs a Partial_Way_Point_Pair
  def self.create_partial_or_leave_whole(way_point_pair, range_fraction)
    range_fraction == [0,1] ? way_point_pair : self.new(way_point_pair, range_fraction)
  end

  def points
    @points
  end

  def inspect
    "#{self.class} with points #{points.inspect} of #{super.inspect}"
  end
end
