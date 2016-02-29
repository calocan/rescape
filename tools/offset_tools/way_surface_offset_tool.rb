require 'tools/way_tools/hybrid_way_based_path_tool'
require 'utils/Geometry_Utils.rb'
require 'wayness/surface_definitions/Ground/Street'
require 'wayness/surface_definitions/generic_way_surface'
require 'tools/offset_tools/offset_tool_module'
require 'tools/offset_tools/offset_finisher_module'
require 'tools/offset_tools/hybrid_path_properties'
require 'tools/proximity_data_utils'

# Draws a surface along a way, and allows the user to offset its width afterward
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Way_Surface_Offset_Tool
  include Offset_Tool_Module
  include Hybrid_Path_Properties
  include Proximity_Data_Utils

  UI_MESSAGES = {
    :title =>
      {:EN=>"Create a way surface",
       :FR=>"Créez une superficie de voie"},
    :tooltip =>
      {:EN=>"Create a way surface",
       :FR=>"Créez une superficie de voie"},
    :adjust =>
      {:EN=>"Select the surface width (hold shift to offset in both directions)",
       :FR=>"Selecionez la lagueur de la superficie (depresser shift dessiner les deux sens)"
      },
    # In path adjust mode:
    :vcb_path_adjustor_label =>
      {:EN=>'Number of copies',
       :FR=>'Nombre de copies'
      }
  }
  def self.messages
    UI_MESSAGES
  end

  def self.offset_finisher_class
    Way_Surface_Offset_Finisher
  end

  # Roads do no have a set width, as they are usually the varying surface upon which other offsets are drawn
  def self.has_set_width?()
    false
  end

  # This is just the draw width, the user can adjust it after with the surface adjustor tool
  def self.offset_width()
    0
  end

  def self.adjust_path_after_creation?
    true
  end

  # Tells the Offset_Finisher to keep the offset point dynamic so that Path_Adjuster can have an effect
  def self.dynamic_final_point_set?
    true
  end

  # Pretend this is never symmetric, even though it is when the user holds down the modifier key
  def symmetric?
    false
  end
end

class Way_Surface_Offset_Finisher
  include Hybrid_Way_Based_Path_Tool

  def init
    @pop_level = 2
  end

  def draw_offset(view, movement_flags)
    view.line_width = 5
    view.line_stipple = ""

    # Base all other lines on the vector, which is the outmost line
    point_sets = find_or_create_point_sets()

    view.drawing_color = "silver"
    view.draw_polyline(adjust_z(point_sets[:center]))
  end

  # Defined dynamically by the path_adjustment offset width
  def point_set_definition
    vector = vector_from_path_to_input_point()
    {:side1=>vector.length, :side2=>-vector.length, :half_way=>vector.length/2}
  end

  def edge_point_sets
    [:side]
  end
  def mirrored_offset()
    shift_down?()
  end

  def handle_set_path_adjust_vcb_value()
    self.class.set_vcb_status(vector_from_path_to_input_point.length)
  end


  # After drawing the path the user must set the width of the new way using the Path_Adjustor tool.
  # This displays the tool's offset
  def draw_path_adjustment(view, movement_flags)
    # Update the movement_flags to catch a modifier key
    @movement_flags = movement_flags

    view.drawing_color = "yellow"
    view.line_width = 4
    view.line_stipple = ""
    view.draw_polyline(adjust_z(chosen_path))

    view.drawing_color = "brown"
    view.line_width = 2
    view.line_stipple = "-"

    make_surface_point_sets(mirrored_offset).each {|set|
      view.draw_polyline(adjust_z(set))
    }

    # Draw the current position of the cursor in case this is demo mode
    view.draw_points(adjust_z([@path_to_point.point.position]), 10, 5, "red") # size, style, color
  end

  # Creates point sets for both the case where a mirrored_offset is desired (edges off both directions of the path) and a non mirrored_offset (edges on one side only)
  def make_surface_point_sets(mirrored_offset)
    surface_component = make_surface_component(mirrored_offset)
    if (mirrored_offset)
      surface_component.get_perimeter_point_sets
    else
      # Just grab the first way_component of the two
      way_component = surface_component.get_way_components_of_ways([surface_component.way_grouping[0]]).only
      perimeter_point_sets = way_component.get_perimeter_points
      way_points = way_component.way_points.map {|way_point| way_point.point}
      # Handler the  possibility of a loop by creating two sets if there is a loop
      way_component.loop ?
          [perimeter_point_sets, way_points] :
          [perimeter_point_sets+way_points.reverse].uniq_consecutive_by_map {|point|
            point.hash_point}
    end
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
    # Finalize the offset
    view.invalidate()
    path_adjustor.finalize_path_adjustment()
    @offset_width_override
  end
  # Override the default method to possibly change the length of the vector to the offset_width_override during the path adjust phase:w
  def vector_from_path_to_input_point
    vector = path_to_point_data.point_on_path.vector_to(calculate_orthogonal_point())
    @offset_width_override ? vector.clone_with_length(@offset_width_override) : vector
  end

  def make_surface_component(mirrored_offset)
    ad_hoc_way_grouping = make_ad_hoc_way_grouping_from_chosen_path()
    make_ad_hoc_surface_component(ad_hoc_way_grouping, mirrored_offset)
  end

  # Draws the final component based on the offset input
  def finalize_offset()
    data_point_sets = find_or_create_data_point_sets
    # If the offset is only in one direction then pass the center key as the second edge set key.
    to_offset_component(mirrored_offset ? [:side1, :side2] : [:side1, :center], data_point_sets) {|parent|

      surface_point_sets = make_surface_point_sets(mirrored_offset)
      # Create a cross section component definition based on the surface component perimeter points
      cross_section_component_definition = self.class.dynamic_cross_section(parent, surface_point_sets.shallow_flatten)
      # Find the orthogonal vector of the cross section face and make it the desired length upward
      orthogonal_up = cross_section_component_definition.faces.only.face_up!.normal.clone_with_length(Way_Surface_Definition.standard_component_height)
      # Create a point_set consisting of the first point of the path (on the surface) plus the point transformed upward
      point_set = [point_sets[:center][0], point_sets[:center][0].transform(orthogonal_up)]
      main = Follow_Me_Surface.new(parent, cross_section_component_definition).along(point_set, {:already_transformed=>true})
      main.definition.apply_material_by_name(Generic_Way_Surface::DEFAULT_WAY_MATERIAL)

      [main]
    }
  end

  # Override this method to make the offset_way centered between :side1 and the center in the non mirror mode
  def path_for_offset_way(path=chosen_path)
    mirrored_offset ?
        Offset_Way.new(point_sets[:center], {}) :
        Offset_Way.new(point_sets[:half_way], {})
  end
end

