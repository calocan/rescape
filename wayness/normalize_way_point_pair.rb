require 'wayness/way_point_pair'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Normalized_Way_Point_Pair < Way_Point_Pair
  attr_reader :vector
  def initialize(way_point_pair, start_way_point)
    super(start_way_point, start_way_point)
    @way_point_pair = way_point_pair
  end

  def vector
    @way_point_pair.vector.normalize
  end
end
