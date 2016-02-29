# Creates a generic surface based on the user's selection, possibly relative to way edges
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'tools/offset_tools/offset_tool_module'
require 'utils/input_point_collector'
#require 'tools/offset_tools/line_path_properties'
#require 'tools/way_tools/line_editor_tool'
require 'tools/offset_tools/hybrid_path_properties'
require 'tools/way_tools/hybrid_way_based_path_tool'

class Surface_Creator
  include Offset_Tool_Module
  include Hybrid_Path_Properties

  UI_MESSAGES = {
      :title =>
          {:EN=>"Create new surface",
           :FR=>"Creez un nouveau superficie"},
      :tooltip =>
          {:EN=>"Create new surface",
           :FR=>"Creez un nouveau superficie"},
      :invalid_selection=>
          {:EN=>"",
           :FR=>""}
  }
  def self.messages
    UI_MESSAGES
  end


  def self.offset_finisher_class
    Surface_Creator_Finisher
  end

  # The user should only be able to click on edges and draw connecting lines
  def self.select_edges_only?
    true
  end

  # Allow close hovers to edges, but only within the threshold
  def self.allow_hover_over_consecutive_point_in_way_shape?()
    true
  end

  # The threshold for allowing close hovers is 10 pixels
  def self.close_hover_threshold
    10
  end


  # Do not allow an offset from the selected way_point_pairs. This means that the input_point of each selected way_point_pair will always be affixed to the edge, not an offset from that edge
  def self.allow_way_shape_offset?
    false
  end
end

class Surface_Creator_Finisher
  include Hybrid_Way_Based_Path_Tool

  @@surface_color = nil
  def self.surface_color
    @@surface_color ||= Sketchup::Color.new(0, 80, 0, 128)
  end
  # Displays a polyline for the calculated offset
  def draw_offset(view, movement_flags)
    # Draw the points that touch edges
    draw_points(view)

    # Draw the edge path of between the user's points'
    view.drawing_color = "silver"
    view.line_width = 4
    view.line_stipple = ""

    $clck=closed_path = adjust_z(closed_path())
    if (closed_path.length > 1)
      view.draw_polyline(closed_path)
    end
  end

  # Pick a closed path based on the user's selection. A loop can be formed by hovering over an edge of an inner loop or by drawing a path of two or more points. In the latter case the loop uses the path between way_shapes if two way shapes are selected.
  def closed_path()
    if (way_dynamic_path.way_shapes.length == 1)
      # If the sole way_shape's data_pair is part of an inner loop, select those inner loop points
      $eg=edge = way_dynamic_path.way_shapes.only.data_pair
      $qq=potential_closed_path = edge.forms_inner_loop? && way_dynamic_path.stray_points.length==0 ?
        Sketchup::Edge.to_ordered_points(Sketchup::Edge.sort(edge.all_connected_pairs)) :
        way_dynamic_path.all_points()
    else
      # Create a path with all the points and loop the path below.
      $pp = potential_closed_path = Geom::Point3d.unique_consecutive_points(way_dynamic_path.all_points)
    end
    # Return the closed path or close it explicitly
    $zz=Geom::Point3d.is_loop?(potential_closed_path) ?
        potential_closed_path :
        potential_closed_path + [potential_closed_path.first]
  end

  # Once the user has double clicked to complete their path, this
  def finalize_offset()
    $cox=closed_path = closed_path()
    if (closed_path.length >= 3)
      surface_from_closed_path(closed_path)
    end
  end

  # Creates a path and face and puts it in a component
  def surface_from_closed_path(closed_path)

    # Create an offset component without any edges. The perimeter of the surface, being the chosen_path, will be used to create the two ways that go in opposite directions.
    to_offset_component_for_no_edge_tools(closed_path) {|parent|
      # Create a cross section component definition based on the surface component perimeter points
      cross_section_component_definition = self.class.dynamic_cross_section(parent, closed_path)
      # Find the orthogonal vector of the cross section face and make it the desired length upward
      orthogonal_up = cross_section_component_definition.faces.only.face_up!.normal.clone_with_length(Way_Surface_Definition.standard_component_height)
      # Create a point_set consisting of the first point of the path (on the surface) plus the point transformed upward
      point_set = [closed_path[0], closed_path[0].transform(orthogonal_up)]
      # Follow from the surface up to the desired height. Specify :already_transformed=true since the cross_section_component_definition points are already at the desired location, as opposed to being centered about the model origin.
      main = Follow_Me_Surface.new(parent, cross_section_component_definition).along(point_set, {:already_transformed=>true})
      main.definition.apply_material_by_name(Generic_Way_Surface::DEFAULT_WAY_MATERIAL)
      [main]
    }
  end

  # Override this method to make the offset_way used the closed path of the surface. By default this would use just the path points that the user drew.
  def path_for_offset_way(path=closed_path())
    Offset_Way.new(path, {})
  end

end


