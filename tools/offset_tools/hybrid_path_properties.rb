require 'tools/offset_tools/offset_configuration_module'
require 'tools/offset_tools/hybrid_linked_way_shapes'
require 'utils/input_point_collector'

# Represents a path that can occur both along ways and in between them. Paths between ways that do not follow the ways are enabled by holding a modifier key
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Hybrid_Path_Properties
  include Offset_Configuration_Module

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Offset_Configuration_Module)
    base.extend(Class_Methods)
  end

  module Class_Methods

    # Way based paths need at least two points to be valid
    def valid_path_length()
      2
    end

    # Uses an Input_Point_Collector to store intermediate selected points between way_shape selections
    def create_input_point(preconsidered_points=[])
      Input_Point_Collector.new(Sketchup::InputPoint.new, preconsidered_points)
    end

    # When the user clicks a point unassociated with the way_component, namely something off the face of the way_component, we add the point to the Input_Point_Collector instance.
    def handle_unassociated_points(input_point)
      input_point.finalize_current_position()
    end

    # When the user double clicks to finish, a regular click comes and that points gets added to the collector, or a new collector is created if the user clicks on a way. The current input_point_collector given here will have a position that is likely different than the position of that initial click if the user selected a way and the position was modified to be affixed to the way. We need to disregard this current position because it will either be a duplicate or unwanted point
    def handle_double_click(input_point_collector)
      # TODO this may or may not be needed
    end

    # Before a way_shape is appended to the linked_way_shapes, either as a hover or click we set the z constraint to the way_shape's z position. This makes all the selected points leading up this way_shape adjust their height to it. This is needed because there's no guarantee that the user's free-hand points will have the right z.
    def pre_way_shape_appended(input_point_collector, way_shape)
      # Constrain the input_point_collector points to the z of the way_shape
      $hoc = way_shape
      input_point_collector.set_z_constraint(way_shape.points.first.z) unless input_point_collector.constrained_z?
    end

    # Each time a way_shape is selected, we clear the previous points from our Input_Point_Collector
    # When the way_shape was created, the current state of the Input_Point_Collector was frozen into a Static_Point_Collector, so we can safely reuse this instance for new points.
    def post_way_shape_finalized(input_point_collector, way_shape)
      input_point_collector.reset(false)
    end

    def accept_user_selected_path_as_chosen_path?
      true
    end

    # When no path yet exists, the user's hover over a way will result in a two point way_shape path if this is true. If not, no path will be constructed until the user has clicked one point and hovers over somewhere else to create a two point path.
    def default_to_partial_way_shape?
      true
    end

    # Always allow unassociated points
    def allow_unassociated_points?(enabling_key)
      true
    end


    # Uses a Hybrid_Linked_Way_Shapes instance that represents the user's chosen path of points chosen between way_shapes rather than the way_point_pair based points between way_shapes
    def create_dynamic_path(input_point, way_grouping=nil)
      Hybrid_Linked_Way_Shapes.new(way_grouping ? way_grouping : [], self, input_point)
    end

  end
end