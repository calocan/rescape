require 'wayness/side_point_pair'
# Wraps a collection instances to perform operations
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Side_Point_Manager < Array
  attr_reader :side_point_pairs

  def initialize(side_points, side_point_pairs=build_side_point_pairs(side_points))
    super(side_points)
    initialize_data_structures(side_point_pairs)
  end

  def initialize_data_structures(side_point_pairs)
    @side_point_pairs = side_point_pairs
    @way_point_pair_hash_to_side_point_pairs = @side_point_pairs.to_hash_value_collection{|side_point_pair| side_point_pair.way_point_pair.hash}
    # create a hash of way hashes to the side points that pertain to them]
    @way_hash_to_side_points = self.to_many_to_many_hash {|side_point| [side_point.way_point, side_point.other_way_point].map{|wp| wp.way.hash}}
    @way_point_hash_to_side_points =  self.to_many_to_many_hash {|side_point| [side_point.way_point, side_point.other_way_point].map{|wp| wp.hash}}
    @side_point_hash_to_side_point_pairs = side_point_pairs.to_hash_values {|spp| spp.map{|sp|sp.hash}.sort}
    @points_to_side_point_pairs = side_point_pairs.to_hash_values {|spp| spp.points.map{|p|p.hash_point}.sort}
  end

  def to_points()
    self.map{|sp| sp.point}
  end

  def build_side_point_pairs(side_points)
    side_points.map_with_subsequent {|sp1,sp2| Side_Point_Pair.new(sp1, sp2)}
  end

  def hashes_match_side_point_pair?(side_point_hashes)
    @side_point_hash_to_side_point_pairs.member? side_point_hashes.sort
  end

  def get_side_point_pair_by_hashes(side_point_hash_pair)
    @side_point_pairs.find {|side_point_pair| side_point_pair.matches_hashes?(side_point_hash_pair)}
  end

  def points_match_side_point_pair?(points)
    @points_to_side_point_pairs.member?(points.map {|p| p.hash_point}.sort)
  end

  # Merge multiple side_point_managers into one
  # This explicit merge is needed so that fake side_point_pairs are not regenerated from the flattened points
  # We don't want a fake pair between two sets of points
  def self.merge(side_point_managers)
    self.new(
        side_point_managers.map {|side_point_manager| side_point_manager.to_a }.shallow_flatten,
        side_point_managers.map {|side_point_manager| side_point_manager.side_point_pairs}.shallow_flatten)
  end

  # Gets the side_points associated with this way, if there are any
  def get_ordered_side_points_of_way(way)
    # Use quick lookup to get eligible side_points
   way.as_way_points.map {|way_point|
     @way_point_hash_to_side_points[way_point.hash] || [] }.shallow_flatten.
        uniq_by_map {|side_point| side_point.point.hash_point}.
        sort_by{|side_point| side_point.way_point.index}
  end

  # Find the 0 or more side_points associated with this way_point_pair and return them sorted
  # in an arbitrary direction
  def get_ordered_side_point_pairs_of_way_point_pair(way_point_pair)
    side_point_pairs = @way_point_pair_hash_to_side_point_pairs[way_point_pair.hash]
    Side_Point_Pair.sort_side_point_pairs_by_connection(side_point_pairs || [])
  end
  
  # Find the side_point_pairs associated with this way via way_point_pairs
  def get_ordered_side_point_pairs_of_way(way)
    way_point_pairs = way.way_point_pairs()
    way_point_pairs.map {|way_point_pair|
      get_ordered_side_point_pairs_of_way_point_pair(way_point_pair)}.shallow_flatten
  end

  # Debug functions
  def draw_from_way_to_side(ways)
    ways.each {|way|
      side_point_pairs = self.get_ordered_side_point_pairs_of_way(way)
      side_point_pairs.each {|side_point_pair|
        Sketchup.active_model.entities.add_curve(way.middle_point, side_point_pair.middle_point)}}
  end
  def draw_from_side_to_way(side_point_pairs)
    side_point_pairs.each{|side_point_pair|
      Sketchup.active_model.entities.add_curve(side_point_pair.middle_point, side_point_pair.way_point_pair.middle_point)}
  end
  def draw_continuous_side_point_pairs(side_point_pairs)
    points = side_point_pairs.map{|side_point_pair| side_point_pair.points}.shallow_flatten
    Sketchup.active_model.entities.add_curve(points)
  end
end