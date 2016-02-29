# Represents an offset path. The data_pairs are the pairs of points--either way_point_pairs or edges--used to create the path. The points are the actually path, which need not match point for point with the data_pairs.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Offset_Path_Data
  attr_reader :data_pairs, :points
  def initialize(data_pairs, points)
    @data_pairs = data_pairs
    @points = points
  end
end