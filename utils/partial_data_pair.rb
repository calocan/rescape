require 'utils/data_pair'
# A partial version of a Data_Pair
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Partial_Data_Pair
  include Data_Pair

  attr_reader :data_pair, :point_pair
  def initialize(data_pair, point_pair)
    @data_pair = data_pair
    @point_pair = point_pair
  end

  # Creates a Partial_Data_Pair from the data_pair and the given range fraction, a pair of fractions that give the distance from the first point of data_pair to the two points defining the Partial_Data_Pair
  def self.from_range_fraction(data_pair, range_fraction)
      Partial_Data_Pair.new(data_pair,
        range_fraction.map {|fraction|
         data_pair.points[0].offset(data_pair.vector, fraction*data_pair.vector.length)
        })
  end

  def range_fraction(data_pair, point_pair)
    point_pair.map {|point| data_pair.points[0].vector_to(point).length / data_pair.vector.length}
  end

  # Override the Data_Pairs's points method to return the reduced points
  def points
    @point_pair
  end

  # Override Data_Pair's data_points to return the representation of the reduced points
  def data_points
    @data_pair.data_points.dual_map(self.points) {|data_point, point| data_point.clone_with_new_point(point)}
  end

  # Makes a new instance of this class with the given point_pair
  def clone_with_new_points(point_pair)
    self.class.new(@data_pair, point_pair)
  end

  # Reversed the partial data_pair by reversing the data_pair and the partial points
  def reverse
    self.class.new(@data_pair.reverse, self.points.reverse)
  end

  # Send missing methods to the data_pair
  def method_missing(m, *args, &block)
    @data_pair.send(m, *args, &block)
  end

  def inspect
    "#{self.class} with points #{points.inspect} of #{self.data_pair.inspect}"
  end

  def self.minimum_data_pair_from_last_point(data_pair)
    self.new(data_pair, [Geom::Point3d.linear_combination(0.1, data_pair.points.first, 0.9, data_pair.points.last), data_pair.points.last])
  end
  def self.minimum_data_pair_from_first_point(data_pair)
    self.new(data_pair, [data_pair.points.first, Geom::Point3d.linear_combination(0.9, data_pair.points.first, 0.1, data_pair.points.last)])
  end
end

