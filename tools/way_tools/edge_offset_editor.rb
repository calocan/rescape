require 'utils/Geometry_Utils.rb'
require 'tools/offset_tools/offset_tool_module'
require 'tools/offset_tools/way_path_properties'
require 'tools/way_tools/way_based_path_tool'

# The most basic implementation of the Offset_Tool, which simply draws a line for the offset
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Edge_Offset_Editor
  include Offset_Tool_Module
  include Way_Path_Properties

  UI_MESSAGES = {
    :title =>
        {:EN=>"Edit an edge by offsetting it",
         :FR=>"Modifiez une ?"},
    :tooltip =>
        {:EN=>"Edit an edge by offseting it",
         :FR=>"Modifiez une ?"}
  }
  def self.messages
    UI_MESSAGES
  end

  def self.offset_finisher_class
    Edge_Offset_Editor_Finisher
  end

  # Tells Way_Selector to activate Path_Adjustor to let the user update the width of the way that is created from the path
  def self.adjust_path_after_creation?
    true
  end

  def self.dynamic_final_point_set?
    true
  end

  def self.select_edges_only?
    true
  end

  def self.allow_way_shape_offset?
    false
  end

  def self.allow_partial_data_pairs?
    false
  end

  # Roads do no have a set width, as they are usually the varying surface upon which other offsets are drawn
  def self.has_set_width?()
    false
  end
end

class Edge_Offset_Editor_Finisher
  include Way_Based_Path_Tool

=begin
  # Limits the pairs that are actually offset. Nonmatching pairs are offset by the identity transformation
  def predicate_lambda
    simple_pairs = chosen_path().map_with_subsequent {|p1,p2| Simple_Pair.new([p1,p2])}
    lambda{|point_pair|
      Simple_Pair.matches?(simple_pairs, Simple_Pair.new(point_pair.map))
    }
=end

  def draw_offset(view, movement_flags)
    view.drawing_color = "yellow"
    view.line_width = 4
    view.line_stipple = ""
    # Create the perimeter points minus the end points that we used as constraints
    if (way_dynamic_path.all_points.length > 1)
      view.draw_polyline(adjust_z(way_dynamic_path.all_points))
    end
=begin
    view.drawing_color = "green"
    offset_points = create_offset_points()
    if (offset_points.length > 1)
      view.draw_polyline(adjust_z(offset_points))
    end
=end
  end

  def draw_path_adjustment(view)
    view.drawing_color = "yellow"
    view.line_width = 4
    view.line_stipple = ""
    view.draw_polyline(adjust_z(chosen_path))

    view.drawing_color = "brown"
    view.line_width = 2
    view.line_stipple = "-"
    $sc=surface_component = surface_component_from_chosen_edge_path()
    surface_component.get_perimeter_point_sets.each {|set|
      view.draw_polyline(adjust_z(set))
    }
    # Draw the current position of the cursor in case this is demo mode
    view.draw_points(@path_to_point.point.position, 10, 5, "red") # size, style, color
  end

  # Using an ad_hoc surface_component based on the selected edges, create offset points based on the distance from the edge to the user's cursor. The offset points are bound by neighboring edges
  def create_offset_points
    get_way_component_nearest_input_point(ad_hoc_surface_component).get_limited_perimeter_points(&side_point_pair_predicate_lambda)
  end

  # Creates a lambda predicate to determine if a side_point_pair matches points with the chosen_path()
  # Since we will offset the chosen_path along with reference points which do not offset, we need this
  # function to filter for the side_points that actually got offset, not those of the reference points
  def side_point_pair_predicate_lambda
    simple_pairs = chosen_path().map_with_subsequent {|p1,p2| Simple_Pair.new([p1,p2])}
    lambda{|side_point_pair|
      Simple_Pair.matches?(simple_pairs, side_point_pair.way_point_pair)}
  end

  # Draws the final component based on the offset input
  def finalize_offset()
    # Create the perimeter points minus the end points that we used as constraints
    offset_points = create_offset_points()
    # Add the line to the surface_component's component_instance. The edges referenced by the data_pairs limit face creation to new faces of those edges
    if (offset_points.length > 1)
      way_grouping.surface_component.incorporate_edge_points!(offset_points, data_pairs)
    end
  end

end

