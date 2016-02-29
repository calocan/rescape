require 'utils/path_to_point_data'
# Like Path_To_Point_Data, but the last two points of the path are always used as the pair_to_point_data solution
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Path_To_Point_Data_For_Live_Path < Path_To_Point_Data
  def pair_to_point_data
    unless @last_input_point_position and @last_input_point_position.matches?(@point.position)
      @pair_to_point_data = Pair_To_Point_Data.pair_to_point_data(data_pairs.last, point) || Pair_To_Point_Data.for_non_projectable_point(data_pairs.last, point)
      @last_input_point_position = @point.position
    end
    @pair_to_point_data.or_if_nil {raise "Data is unexpectedly nil"}
  end
end