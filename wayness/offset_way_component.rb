require 'wayness/Way_Component'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Offset_Way_Component < Way_Component

  def get_perimeter_data_pairs_of_ways(ways)
    side_point_pairs = existing_side_point_pairs(ways)
    # Return the limited pairs plus the end_point_pairs if the extreme points next to end points were not eliminated
    loop_or_end_pairs(side_point_pairs)
  end

  def existing_side_point_pairs(ways=@continuous_ways)
    ways.flat_map { |way|
      @way_grouping.way_hash_to_side_point_pairs[way.hash]
    }
  end

  # Bypass the Side_Point_Generator
  def initialize_side_point_manager
    side_point_pairs = existing_side_point_pairs()
    Side_Point_Manager.new(Side_Point_Pair.to_unique_data_points(side_point_pairs), side_point_pairs)
  end

  # Retrieves the points to be used to draw the side of the way
  def get_perimeter_points
    super()
    #get_perimeter_points_of_ways(@continuous_ways)
  end

  def get_perimeter_points_of_ways(ways)
    super(ways)
=begin
    side_point_points = get_perimeter_data_pairs_of_ways(ways).flat_map {|data_pair| data_pair.points}.uniq_consecutive_by_map {|point| point.hash_point}
    # Return the limited points plus the end points if the extreme points next to end points were not eliminated
    loop_or_end_points(side_point_points)
=end
  end
end