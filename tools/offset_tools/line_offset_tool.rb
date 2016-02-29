require 'tools/offset_tools/offset_tool_module'
require 'tools/way_tools/hybrid_way_based_path_tool'
require 'tools/offset_tools/hybrid_path_properties'
require 'tools/offset_tools/hybrid_linked_way_shapes'

# The most basic implementation of the Offset_Tool, which simply draws a line for the offset
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Line_Offset_Tool
  include Offset_Tool_Module
  include Hybrid_Path_Properties

  UI_MESSAGES = {
      :title =>
          {:EN=>"Create a line",
           :FR=>"Créez une ligne"},
      :tooltip =>
          {:EN=>"Use an offset to create a line",
           :FR=>"Employez un offset pour créer une line"}
  }
  def self.messages
    UI_MESSAGES
  end

  # Curve all angles
  def self.curve_threshold()
    180.degrees
  end

  # Curve 25 feet around around angles that are over the curve_threshold()
  def self.curve_length()
    25*Geometry_Utils::FEET
  end

  def self.offset_finisher_class
    Line_Offset_Finisher
  end

  def symmetric?
    false
  end

end

class Line_Offset_Finisher
  include Hybrid_Way_Based_Path_Tool

  def self.offset_width
    12*1
  end

  # The soul path mimics the center line
  def point_set_definition
    {:line=>0}
  end


  # Displays a polyline for the calculated offset
  def draw_offset(view, movement_flags)
    drawing_colors = ['red', 'yellow', 'pink', 'green', 'purple', 'orange', 'blue']
    view.line_width = 5
    view.line_stipple = ""
    offset_points = point_set(:line)
    index=0
    offset_points.map_with_subsequent_with_loop_option(is_loop?) {|o1,o2|
      view.drawing_color = drawing_colors[index % drawing_colors.length]
      points = adjust_z([o1.point,o2.point])
      view.draw_polyline(points)
      index+=1
    }
  end

  # Draws the curve that was shown in draw_offset
  def finalize_offset()
    offset_points = point_set(:line)
    points = offset_points.map_with_subsequent_with_loop_option(is_loop?).shallow_flatten
    Sketchup.active_model.entities.add_curve points
  end
end

