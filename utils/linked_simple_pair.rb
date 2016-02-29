# A Simple_Pair whose data_points know what they are connected to, meaning the Simple_Pair knows its neighbors
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/simple_pair'

class Linked_Simple_Pair < Simple_Pair
  def initialize(linked_data_points)
    @linked_data_points = linked_data_points
    super(@linked_data_points.map {|data_point| data_point.point})
  end

  def data_points
    @linked_data_points
  end
end