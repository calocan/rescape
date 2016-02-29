# Edits one or more edges by allowing the user to draw one or more line segments that replaces one ore more edges
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'tools/offset_tools/offset_tool_module'
require 'utils/input_point_collector'
require 'tools/offset_tools/line_path_properties'
require 'tools/way_tools/line_editor_tool'

class Way_Adjustor
  include Offset_Tool_Module
  include Line_Path_Properties

  UI_MESSAGES = {
      :title =>
          {:EN=>"Adjust Ways",
           :FR=>"?"},
      :tooltip =>
          {:EN=>"Adjust Ways",
           :FR=>""},
      :invalid_selection=>
          {:EN=>"",
           :FR=>""}
  }
  def self.messages
    UI_MESSAGES
  end

  def self.offset_finisher_class
    Way_Adder_Finisher
  end

  # Limit the Way_Editor to way_point_pair selection, not edges.
  def self.select_way_point_pairs_only?
    true
  end

  def self.select_edges_only?
    false
  end

  # Do not allow an offset from the selected way_point_pairs. This means that the input_point of each selected way_point_pair will always be affixed to that way_point_pair wherever the user clicked or hovers the cursor
  def self.allow_way_shape_offset?
    false
  end

  # Tells Way_Selector to activate Path_Adjustor to let the user update the width of the way that is created from the path
  def self.adjust_path_after_creation?
    true
  end

  # Tells the Offset_Finisher to keep the offset point dynamic so that Path_Adjuster can have an effect
  def self.dynamic_final_point_set?
    true
  end

end

class Way_Adder_Finisher
  include Line_Editor_Tool

  # Displays a polyline for the calculated offset
  def draw_offset(view, movement_flags)
    # Draw the ways of the way_grouping
    view.drawing_color = "yellow"
    view.line_width = 4
    view.line_stipple = ""
    way_grouping.each {|way|
      view.draw_polyline(adjust_z(way.points))
    }
    # Draw the line created by the user
    draw_line(view)
  end

  def draw_path_adjustment(view)
    view.drawing_color = "yellow"
    view.line_width = 4
    view.line_stipple = ""
    view.draw_polyline(adjust_z(chosen_path))

    view.drawing_color = "brown"
    view.line_width = 2
    view.line_stipple = "-"
    surface_component = integrated_surface_component_from_chosen_path()
    surface_component.get_perimeter_point_sets.each {|set|
      view.draw_polyline(adjust_z(set))
    }
    # Draw the current position of the cursor in case this is demo mode
    view.draw_points(adjust_z([@path_to_point.point.position]), 10, 5, "red") # size, style, color
  end

  # Once the user has double clicked to complete their path, this
  def finalize_offset()
    ad_hoc_surface_component = integrated_surface_component_from_chosen_path()
    way_grouping.integrate!(data_pairs(), dual_ways_to_intersection_points(), ad_hoc_surface_component)
  end

end
