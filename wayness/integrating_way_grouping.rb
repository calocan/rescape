require 'wayness/way_grouping'
require 'utils/lambda_wrapper'
# A subclass of Predefined_Side_Point_Pair_Way_Grouping designed for integrating new ways into an existing Way_Grouping
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Integrating_Way_Grouping < Predefined_Side_Point_Pair_Way_Grouping

  # Expects old and new ways. ways are ways of an existing way_grouping, and new_ways are ways created by a path drawn by the user (to add a new way, for instance). way_to_existing_side_point_pairs maps the old ways to their side_point_pairs. The new_ways don't have side_point_pairs yet; they will be defined by the user's cursor drag or some other means
  # unique_id is omitted since this Way_Grouping will never be preexisting
  def initialize(way_class, ways, new_ways, way_to_existing_side_point_pairs)
    super(way_class, ways + new_ways, nil, way_to_existing_side_point_pairs)
  end

  # Any way_point_pairs that don't have side_point_pairs are just our new ways, so simply return here
  def handle_way_point_pairs_without_side_point_pairs(way_point_pairs)
    way_point_pairs
  end
end

