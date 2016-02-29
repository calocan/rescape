require 'wayness/side_point'
require 'wayness/way_point_pair_basic_behavior'
require 'utils/data_pair'

# Associates two adjacent Side_Point instances. A Sketchup Edge references each Side_Point_Pair instance
# When the edge is changed the corresponding Side_Point is updated via the Side_Point_Manager binding
# Every Side_Point_Pair is in turn refers to Way_Point_Pair, which represents two center points of a Way
# Updates to the Side_Point_Pair will in turn update the Way_Point_Pair and underlying Way.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Side_Point_Pair < Array
  include Data_Pair
  include Way_Point_Pair_Basic_Behavior

  attr_reader :side_point1, :side_point2, :common_way_point, :vector

  # Create a side_point_pair from two side points. If partial_way_point_pair is specified,
  # The side_point_pair will refer to a partial way_point_pair (e.g. from 0.25 to 0.75 of the way pair)
  def initialize(side_point1, side_point2, way_point_pair=make_way_point_pair(side_point1, side_point2))
    raise "Not side points: %s, %s" % [side_point1.class, side_point2.class] unless [side_point1, side_point2].all?{|side_point| side_point.kind_of?(Side_Point)}
    @side_point1 = side_point1
    @side_point2 = side_point2
    super([@side_point1, @side_point2])
    @way_point_pair = way_point_pair
    @vector = side_point1.point.vector_to(side_point2.point)
  end

  # The way of the side_point_pair representing the common way shared by both side_points
  def way
    @way_point_pair.way
  end

  # Conforms to Basic_Way_Point_Pair_Behavior and exposes the Way_Point_Pair of this Side_Point_Pair
  def way_point_pair(way_grouping=nil)
    @way_point_pair
  end

  # Applies the given transformation to the way_point_pair points to create new points, which are in turned used with the way_point_pair construct a Side_Point_Pair
  def self.from_way_point_pair(way_point_pair, transformations)
    modified_transformations = transformations.kind_of?(Array) ? transformations : [transformations, transformations]
    Side_Point_Pair.new(*way_point_pair.dual_map(modified_transformations) {|way_point, transformation| Side_Point.new(way_point.point.transform(transformation), way_point)})
  end

  # Makes a side_point_pair from a Way_Point_Pair with the given pair of points
  def self.from_way_point_pair_with_points(way_point_pair, pair_of_points)
    Side_Point_Pair.new(*way_point_pair.dual_map(pair_of_points) {|way_point, point| Side_Point.new(point, way_point)})
  end


  # Order of the pair does not matter for identity
  def hash
    self.map {|side_point| side_point.hash}.sort.hash
  end

  def ==(other)
    self.hash == other.hash
  end

  # Returns true if the two given side_point_ids match this side_point_pair
  def matches_hashes? (side_point_hashes)
    Set.new(self.map{|side_point| side_point.hash})==Set.new(side_point_hashes)
  end
  # Returns true if the two given points match those of this side_point_pair
  def matches? (point_pair)
    Set.new(points.map{|p| p.hash_point}).entries==Set.new(point_pair.map{|p| p.hash_point}).entries
  end
  # Returns true if one and only one point of the given pairs matches of of this side_point_pair
  def connected? (side_point_pair)
    1==(Set.new(points.map{|p| p.hash_point}) & Set.new(side_point_pair.points.map{|p| p.hash_point})).length
  end

  # Chooses each side_point's way_point or other_way_point based on which one has the same
  # underlying way as the other side_point. If two ways are shared, it will select the first found
  def make_way_point_pair(side_point1, side_point2)
    hash_pairs = [side_point1, side_point2].map{|sp| [sp.way_point.way.hash, sp.other_way_point.way.hash]}
    intersection = hash_pairs[0] & hash_pairs[1]
    #raise "Side_Point does not share one or both ways: self:%s,way_point_ids:%s, arg:%s,way_point_ids:%s" % [side_point1.inspect, [side_point1.way_point.way.hash, side_point1.other_way_point.way.hash].inspect, side_point2.inspect, [side_point2.way_point.way.hash, side_point2.other_way_point.way.hash].inspect]  unless intersection.length > 0
    way_point_pair = Way_Point_Pair.new(*[side_point1, side_point2].map {|side_point| side_point.way_point.way.hash == intersection.first ? side_point.way_point : side_point.other_way_point})
    #raise "Identical way_points #{way_point_pair.inspect} while creating side_point_pair with side_points #{side_point1.inspect} and #{side_point2.inspect}" if way_point_pair.way_points[0]==way_point_pair.way_points[1]
    way_point_pair
  end

  # Divide the side_point_pair based on pairs of start-end points [[start,end],[start,end],...]
  def divide(start_end_pairs)
    # ensure pairs run from the first side_point to the second side_point
    start_end_pairs = start_end_pairs.first.first.match(self[0].point) ? start_end_pairs : start_end_pairs.reverse.map{|pair| pair.reverse}
    total_length = @vector.length
    range_fractions = ([0]+
      start_end_pairs.map {|start_end_pair|
        start_end_pair[0].vector_to(start_end_pair[1]).length / total_length }+[1]).
          map_with_subsequent {|fraction1, fraction2| [fraction1,fraction2] }

    partial_way_point_pairs = @way_point_pair.create_partials(range_fractions)
    start_end_pairs.dual_map(partial_way_point_pairs) {|start_end_pair, partial_way_point_pair|
      side_points=self.dual_map(start_end_pair) {|side_point, new_point|
        side_point.clone_with_new_point(new_point)}
      self.class.new(side_points[0], side_points[1], partial_way_point_pair)}
  end


  # Implementation of Data_Pair interface #

  # Reverse the side_point_pair. We don't reverse the way_point_pair
  def reverse
    self.class.new(@side_point2, @side_point1, @way_point_pair)
  end


  def neighbors
    raise "Side_Point_Pair is not aware of its neighbors. You must override this method"
  end

  # Maps the neighbors by point to {point1=>neighbors1, point2=>neighbors2}
  def neighbors_by_point
    raise "Side_Point_Pair is not aware of its neighbors. You must override this method"
  end

  # Clone the side_point_pair by replacing each side_point point with the given points
  def clone_with_new_points(point_pair)
    Side_Point_Pair.new(*point_pair.dual_map(data_points) {|point, side_point| side_point.clone_with_new_point(point)})
  end

  # The high-level class of points, Side_Point instances here
  def data_points
    self.to_a
  end

  # End Data_Pair implementation

  # Sorts connected side_point_pairs. The pairs must be connected
  def self.sort_side_point_pairs_by_connection(side_point_pairs)
    Sorting.chain(side_point_pairs,
                  lambda{|last_spp, spp| last_spp.connected?([spp])}, # find neighbors
                  lambda{|unchained_spps| unchained_spps.find{|spp| # find first item without two neighbors
                    side_point_pairs.find_all {|aspp| spp.connected?(aspp)}.length<=1}})
  end

  def inspect
    "%s of points %s and hash %s of way_point_pair %s" % [self.class, self.points.inspect, self.hash, self.way_point_pair.inspect]
  end

end

