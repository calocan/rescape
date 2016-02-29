# Edits one or more edges by allowing the user to draw one or more line segments that replaces one ore more edges
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'tools/offset_tools/offset_tool_module'
require 'tools/way_tools/line_editor_tool'
require 'tools/offset_tools/line_path_properties'
require 'utils/input_point_collector'

class Edge_Editor
  include Offset_Tool_Module
  include Line_Path_Properties

  UI_MESSAGES = {
      :title =>
          {:EN=>"Edit Edges",
           :FR=>""},
      :tooltip =>
          {:EN=>"Edit edges",
           :FR=>""},
      :invalid_selection=>
          {:EN=>"",
           :FR=>""}
  }
  def self.messages
    UI_MESSAGES
  end

  def self.offset_finisher_class
    Edge_Editor_Finisher
  end

  # Limit the Edge_Editor to edge selection.
  def self.select_edges_only?
    true
  end

  # Do not allow an offset from the selected edges. This means that the input_point of each selected edge will always be affixed to that edge if the user hovers close to the edge, and not to an offset of the edge
  def self.allow_way_shape_offset?
    false
  end

  # Allow the user to click a point unassociated with an edge. This allows the user to create intermediate points when modifying the edges of a way. The points are not associated with a way_shape
  def self.allow_unassociated_points?(x)
    true
  end

  def self.allow_close_hovers?
    true
  end

  def self.allow_hover_over_consecutive_point_in_way_shape?()
    true
  end

  def self.close_hover_threshold
    10
  end

  # Don't allow the user to connect edges across a way or make other paths that are not solvable. This doesn't prevent crazy paths between distance ways (and over other ways). That should in the future be detected by a way intersection function.
  def make_unsolvable_way_based_paths_direct?
    false
  end
end

class Edge_Editor_Finisher
  include Line_Editor_Tool

  # Displays the lines being drawn and highlights the edges they are replaces
  def draw_offset(view, movement_flags)
    draw_line(view)
  end

  # Draws the final component based on the offset input
  def finalize_offset()
    # Take end pairs of paths and divide them if the draw line intersects either one
    points = way_dynamic_path.all_points
    if (points.length > 1)
      # Use the subset of way_based_data_pairs that make up the way-based path of the points. Normally this will be all of the way_based_pairs, but there's a bug where an extra pair can be included at the start or finish when the new path drawn by the user intersects right where the edges meet. TODO prevent this from happening in the Linked_Way_Shape_Pathing. trim_data_pairs_for_end_way_shape(
      $w=way_based_data_pairs = way_dynamic_path.way_based_data_pairs
      $f=first_data_pair = way_based_data_pairs.find {|data_pair| data_pair.points[0].matches?(points.first)}
      $l=last_data_pair = way_based_data_pairs.find {|data_pair| data_pair.points[1].matches?(points.last)}
      data_pair_indices = [way_based_data_pairs.index(first_data_pair), way_based_data_pairs.index(last_data_pair)]
      raise "The chosen path #{points.inspect} did not match a way_based_data_pairs #{way_based_data_pairs.inspect}" unless data_pair_indices.all? {|index| index != nil}
      way_grouping.surface_component.incorporate_edge_points!(points, way_based_data_pairs[data_pair_indices[0]..data_pair_indices[1]])
    end
  end


end
