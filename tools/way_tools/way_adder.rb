# Edits one or more edges by allowing the user to draw one or more line segments that replaces one ore more edges
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'tools/offset_tools/offset_tool_module'
require 'utils/input_point_collector'
require 'tools/offset_tools/line_path_properties'
require 'tools/way_tools/line_editor_tool'
require 'tools/way_tools/edge_associator'

class Way_Adder
  include Offset_Tool_Module
  include Line_Path_Properties

  UI_MESSAGES = {
      :title =>
        {:EN=>"Add Ways",
         :FR=>"?"},
      :tooltip =>
        {:EN=>"Add ways",
         :FR=>""},
      :invalid_selection=>
        {:EN=>"",
         :FR=>""},
      :adjust =>
        {:EN=>"Select the surface width from the center",
         :FR=>"Selecionez la lagueur de la superficie du centre"
        },
      # In path adjust mode:
      :vcb_path_adjustor_label =>
        {:EN=>'Width from center',
         :FR=>'Langeur du centre'
        }
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

  # Associate a point to the way_point_pair if it is within this number of pixels. Otherwise make it unassociated
  def self.data_pair_selection_threshold
    20
  end

  # Do not allow an offset from the selected way_point_pairs. This means that the input_point of each selected way_point_pair will always be affixed to that way_point_pair wherever the user clicked or hovers the cursor
  def self.allow_way_shape_offset?
    false
  end

  # The user may select nodes or pairs
  def allow_node_selection?
    false
  end

  # The node must be within 5 pixels for selection
  def node_selection_threshold
    5
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
    # Draw the intersection points
    #way_grouping.intersection_points.each {|point|
      #view.draw_points(point, 20, 5, 'blue')
    #}
    # Draw the line created by the user
    draw_line(view)
  end

  # Only enable path_adjustment if the newly drawn way goes outside the face of the surface.
  # If it's completely inside we just want to draw a new way without edges (e.g. a new way through a plaza area)
  def needs_path_adjustment?
    $fx=faces = way_dynamic_path.way_grouping.surface_component.faces
    # See if any points or mid points lie outside the faces of the surface_component instance
    !data_pairs.flat_map {|data_pair| data_pair.points + data_pair.divide(4)}.
        uniq_by_hash{|point| point.hash_point}.
        all?{|point|
      (faces.inject(0) {|previous, face| previous | face.classify_point(point)} &
        (Sketchup::Face::PointInside | Sketchup::Face::PointOnVertex | Sketchup::Face::PointOnEdge)) > 0
    }
  end

  # Use the VCB value during path adjust the width of the offset by setting an instance variable and overriding vector_from_path_to_input_point
  def handle_path_adjust_vcb_value(view, text, path_adjustor)
    begin
      offset_width_override = text.to_l()
      return unless offset_width_override > 0
      @offset_width_override = offset_width_override
    rescue
      @offset_width_override = nil
    end
  end
  # Override the default method to possibly change the length of the vector to the offset_width_override during the path adjust phase
  def vector_from_path_to_input_point
    vector = path_to_point_data.point_on_path.vector_to(calculate_orthogonal_point())
    @offset_width_override ? vector.clone_with_length(@offset_width_override) : vector
  end

  # After drawing the path the user must set the width of the new way using the Path_Adjustor tool.
  # This should have a mode to path adjust symmetrically from the center and also asymmetrically in the direction of the user's cursor
  # This displays the tool's offset
  def draw_path_adjustment(view, movement_flags)
    view.drawing_color = "yellow"
    view.line_width = 4
    view.line_stipple = ""
    view.draw_polyline(adjust_z(chosen_path))

    view.drawing_color = "brown"
    view.line_width = 2
    view.line_stipple = "-"
    # Create a surface component from the path drawn by the user and the position of their cursor relative to the path
    surface_component = integrated_surface_component_from_chosen_path(true)
    # Draw each line of the point set
    surface_component.get_perimeter_point_sets.each {|set|
      view.draw_polyline(adjust_z(set))
    }
    # Draw the current position of the cursor in case this is demo mode
    view.draw_points(adjust_z([@path_to_point.point.position]), 10, 5, "red") # size, style, color
  end

  # Once the user has double clicked to complete their path and optional path adjustment, this creates a new way and edits the surface based on the path adjustment. If there is no path adjustment because the way is completely internal to the surface, this only creates the new way
  # If the path is completely internal, this will push the edge_associator onto the tool stack afterward so that the user can associate existing edges to the new way
  def finalize_offset()
    needs_path_adjustment = needs_path_adjustment?
    ad_hoc_surface_component = needs_path_adjustment ? integrated_surface_component_from_chosen_path(true) : nil
    way_grouping.integrate!(data_pairs(), dual_ways_to_intersection_points(), ad_hoc_surface_component)
  end
end
