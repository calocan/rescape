require 'tools/offset_tools/offset_tool_module'
require 'tools/way_tools/hybrid_way_based_path_tool'
require 'tools/offset_tools/hybrid_path_properties'
require 'tools/offset_tools/follow_me_surface'
# An offset tool to offset any component by repeating it at some interval
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Component_Offset_Tool
  include Offset_Tool_Module
  include Hybrid_Path_Properties

  attr_reader :offset_component

  UI_MESSAGES = {
      :title =>
          {:EN=>"Repeat the component along a path",
           :FR=>"Repetez un component au long d'un chemin"},
      :tooltip =>
          {:EN=>"Repeat the component along a path",
           :FR=>"Repetez un component au long d'un chemin"},
      :invalid_select =>
          {:EN=>"Select one component to offset prior to choosing this tool",
           :FR=>"Selectionez un seul component avant de choisir cet util"
          },
      :adjust =>
          {:EN=>"Move the cursor toward the center of the path for fewer instances, or away from the center for more. Or type a number in the box to the right.",
           :FR=>""},
      # In path adjust mode:
      :vcb_path_adjustor_label =>
          {:EN=>'Number of copies',
           :FR=>'Nombre de copies'
          }
  }
  def self.messages
    UI_MESSAGES
  end

  def activate
    # Find the first selected entity that is a component instance or group and is not associated to a way_grouping (i.e. way surfaces and offset surface components)
    @offset_component = Sketchup.active_model.selection.find {|a_selection|
      a_selection.kind_of?(Component_Instance_Behavior) && !a_selection.associated_to_way_grouping?
    }
    unless (@offset_component)
      status_for_invalid_selection(Sketchup.active_model.active_view)
    else
      base_activate()
    end
  end

  # This is only used when the activation fails
  def onMouseMove(flags, x, y, view, demoing=false)
    status_for_invalid_selection(view)
  end

  def status_for_invalid_selection(view)
    view.tooltip = self.class.message(:invalid_select)
    Sketchup::status_text= self.class.message(:invalid_select)
    Sketchup::vcb_value=0
  end

  # Creates a dynamic subclass of Component_Offset_Finisher based on the component chosen by the user
  def self.offset_finisher_class
    Component_Offset_Finisher
  end

  # Since the component is placed relative to the x axis, the component will be laid along the path width-wise. This means that the offset_width has to be the component's height (y axis)
  def offset_width
    @offset_component.bounds.height
  end

  # Tells Way_Selector to activate Path_Adjustor to let the user update the width of the way that is created from the path
  def self.adjust_path_after_creation?
    true
  end

  # Tells the Offset_Finisher to keep the offset point dynamic so that Path_Adjuster can have an effect
  def self.dynamic_final_point_set?
    true
  end

  # Curve all angles
  def self.curve_threshold()
    180.degrees
  end

  # Curve 25 feet around around angles that are over the curve_threshold()
  def self.curve_length()
    25*Geometry_Utils::FEET
  end

  def self.symmetric?
    false
  end

  # Since components aren't usually flat, there's no point in trying to make the product of the tool cut faces into other offset_way_groupings, or visa-versa
  def self.participates_in_cut_faces?
    false
  end
end

class Component_Offset_Finisher
  include Hybrid_Way_Based_Path_Tool

  DEFAULT_GAUGE = 4*Geometry_Utils::FEET + 8.5
  def default_gauge
    DEFAULT_GAUGE
  end

  # Displays a polyline for the calculated offset
  def draw_offset(view, movement_flags)
    draw_footprints(view)
  end

  # The length of each footprint when adjusting the spacing of the offsets
  def default_length
    @offset_configuration.offset_component.bounds.width
  end

  # Set the number of instances to the given value from the vcb box
  # Returns the value set in case the caller needs to adjust the VCB vlaue
  def handle_path_adjust_vcb_value(view, text, path_adjustor)
    begin
      @number_of_instances_override = [[3, text.to_i()].max(), max_number_of_instances()].min()
      view.invalidate
      @number_of_instances_override
    rescue
      @number_of_instances_override = nil
    end
  end

  # This will change the number of components based on the user's cursor distance from the center of the path (just like the Sketchup Edge divide tool, but cooler)
  def draw_path_adjustment(view, movement_flags)
    # Find the center of the path
    number_of_instances = calculate_number_of_instances()
    draw_footprints(view, number_of_instances)
  end

  # Calculates the maximum number of instances that fit on the path
  # The minimum number is three (one at each end and one in the middle of the path)
  def max_number_of_instances()
    composite_length = Simple_Pair.composite_length(self.data_pairs)
    [(composite_length/default_length).ceil, 3].max()
  end

  # Calculate the number of instances based on the user's cursor distance from the center of the path (just like the Sketchup Edge divide tool).
  # @number_of_instance_override will be returned if set
  def calculate_number_of_instances
    if (@number_of_instances_override)
      number_of_instances = @number_of_instances_override
    else
      center_point = Simple_Pair.divide(self.data_pairs, 1)[1]
      # Find the distance from the center to the path_to_point.point_on_path
      $pp = self.path_to_point_data
      $x1=self.path_to_point_data.point_on_path
      distance = center_point.distance(self.path_to_point_data.point_on_path)
      $x2= center_point
      half_path_length = Simple_Pair.composite_length(self.data_pairs) / 2
      max_number_of_instances = max_number_of_instances()
      # Based on the percentage of cursor to the center point over half the path length, and the max number of instances, calculate how many the user wants.
      number_of_instances = ([(distance / half_path_length.to_f), 1].min * (max_number_of_instances-3)).floor + 3
    end
    self.class.set_vcb_status(number_of_instances)
    number_of_instances
  end

  def point_set_definition
    {:inner_side => -@offset_configuration.offset_width/2, :outer_side => @offset_configuration.offset_width/2}
  end

  def orientation_vector
    point_sets[:inner_side].first.vector_to(point_sets[:outer_side].first)
  end

  # Draws the final component based on the offset input
  def finalize_offset()
    to_offset_component([:inner_side, :outer_side]) {|parent|
      point_sets = find_or_create_point_sets()
      $pew=parent
      $coo=component = Follow_Me_Surface.new(Sketchup.active_model, @offset_configuration.offset_component.definition, @offset_configuration.offset_component).
          along(point_sets[:center], {:unique_components=>false, :draw_length=>default_length(), :space_length=>default_length(), :number_of_instances=>calculate_number_of_instances(), :orientation_vector=>orientation_vector, :follow_me=>false})
      new_component = parent.entities.add_instance(component.definition, component.transformation)
      Sketchup.active_model.entities.erase_entities(component)
      component = new_component
      [component]
    }
  end

  def draw_footprints(view, number_of_instances=0)
    view.drawing_color = "white"
    view.line_width = 3
    view.line_stipple = "-"
    # Base all other lines on the vector, which is the outmost line
    parent = Sketchup::active_model
    point_sets = find_or_create_point_sets()
    $point_sets = point_sets

    [:inner_side, :outer_side].each {|key|
      view.draw_polyline adjust_z(point_sets[key])
    }
    # Draw footprints representing where the components will lay
    if (number_of_instances > 0)
      foot_print_point_sets =  cache_container.path_adjustor_cache_lookup.find_or_create(number_of_instances) {
        Follow_Me_Surface.new(parent,
                              @offset_configuration.offset_component.definition,
                              @offset_configuration.offset_component).
          along(point_sets[:center],
                {:unique_components=>false,
                 :draw_length=>default_length(),
                 :draw_space=>default_length(),
                 :number_of_instances=>number_of_instances,
                 :orientation_vector=>orientation_vector,
                 :follow_me=>false,
                 :footprints_only=>true})
      }
      view.drawing_color = "red"
      view.line_stipple = ""
      view.line_width = 5
      foot_print_point_sets.each {|point_set|
        view.draw_polyline(adjust_z(point_set))
      }
    end
  end

end
