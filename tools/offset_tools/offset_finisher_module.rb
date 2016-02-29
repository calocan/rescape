# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'tools/tool_utils.rb'
require 'tools/offset_tools/offset_finisher_utilities_module'
require 'tools/offset_tools/offset_configuration_module'
require 'tools/offset_tools/offset_finisher_point_sets'
require 'utils/simple_pair'
require 'utils/simple_pair'
require 'tools/offset_tools/linked_way_shapes'
require 'tools/offset_tools/way_offset_creation'
require 'tools/proximity_data_utils'
require 'utils/path_to_point_data_for_live_path'

module Offset_Finisher_Module
  include Offset_Configuration_Module
  include Offset_Finisher_Utilities_Module
  include Offset_Finisher_Point_Sets
  include Way_Offset_Creation
  include Proximity_Data_Utils

  attr_reader :way_dynamic_path, :path_to_point, :active_tool, :cache_container, :movement_flags, :dynamic_point
  # TODO rename draw_selection. This is the method used to draw the path as the user selects it
  def draw_offset(view, movement_flags)
    raise "Must be implemented by mixer"
  end

  # Determines if a path adjustment is needed given the path drawn by the user. This is only queried if offset_configuration_module.adjust_path_after_creation returns true. True by default
  def needs_path_adjustment?()
    true
  end

  # This is the method used to offset the complete path or the edges of the path's created surface
  def draw_path_adjustment(view, movement_flags)
    raise "Must be implemented by mixers who return adjust_path_after_creation as true"
  end

  def finalize_offset()
    raise "Must be implemented by mixer"
  end

  def offset_distances
    raise "Must be implemented by mixer"
  end

  # Initializes the mixer of an Offset_Finisher_Module with a Way_Dynamic_Path instance
  # The offset_configuration determines the properties of the tool, as defined in Offset_Configuration_Module
  # way_dynamic_path stores information about the path chosen by the user
  # cache_container is an Offset_Finisher_Cache_Lookups_Module instance that references caches that the offset_finisher uses for efficiency across multiple instantiations.
  # movement_flags is passed in by the Way_Selector to indicate which modifier keys are pressed
  def initialize(offset_configuration, way_dynamic_path, cache_container, movement_flags)
    $ooo = self
    @offset_configuration = offset_configuration
    @way_dynamic_path = way_dynamic_path
    all_points = way_dynamic_path.all_points
    raise "Duplicate points" if all_points.uniq_consecutive.length != all_points.length
    # Copy the path data from way_dynamic_path and optionally finalize the dynamic input point (way_dynamic_path.data_point)
    # If the input_point is finalized then no more offsetting is supported. If it remains dynamic then the point is cloned so that it can be used to offset the entire chosen_path, which is desirable for paths like new roads where the user needs to set the width dynamically.
    data_pairs = way_dynamic_path.data_pairs()
    @dynamic_point = way_dynamic_path.data_point
    @path_to_point =  Path_To_Point_Data_For_Live_Path.new(
        all_points,
        @offset_configuration.class.dynamic_final_point_set? ?
          way_dynamic_path.data_point.clone() :
          way_dynamic_path.data_point.freeze(),
        data_pairs)

    # Indicates the number of tools to pop from the stack when this tool completes
    @pop_level = 1
    @movement_flags = movement_flags
    # Caches
    @cache_container = cache_container
    init()
    tool_init()
    self.validate_instance_variables()
  end

  # Mixers can implement this to do their own initializations
  def init()
  end

  def way_grouping
    way_dynamic_path.way_grouping
  end

  def path_to_point_data
    raise "path_to_point_data should never be nil" unless @path_to_point
    @path_to_point
  end

  def is_loop?
    @path_to_point.path.is_loop? {|point| point.hash_point}
  end

  #Implementation of the offset_utilities_module
  def point_as_static
    @path_to_point.point.position
  end

  def point
    @path_to_point.point
  end

  def chosen_path
    raise "Chosen Path must be at least two points: #{path_to_point_data.path}" unless path_to_point_data.path.length > 1
    @path_to_point.path
  end

  def point_on_path
    @path_to_point.point_on_path
  end

  def pair_of_point_on_path
    @path_to_point.pair
  end

  def data_pairs
    @path_to_point.data_pairs
  end

  def activate
    initial_status()
  end

  def initial_status
    Sketchup::vcb_label=self.class.message(:distance)
  end

  def status_for_valid_offset(view)
    view.tooltip = self.class.message(:click_to_finish)
    Sketchup::status_text= self.class.message(:click_to_finish)
    Sketchup::vcb_value=vector_from_path_to_input_point().length
  end

  # Set ths status for an invalid offset drag. By default this is only when the offset
  # is extended to the point that less than two points exist.
  # This might be extended to include offsets that are off the way.
  def status_for_invalid_offset(view)
    view.tooltip = self.class.message(:too_far)
    Sketchup::status_text= self.class.message(:too_far)
    Sketchup::vcb_value=0
  end

  # Debugging
  # Draws data_pairs of linked_way_shapes that are not offset from their original position by linked_way_shapes.input_point
  def draw_optional_views(view, movement_flags)
    view.drawing_color = "green"
    view.line_width = 4
    view.line_stipple = ""
    points_of_data_pairs = Simple_Pair.to_unique_points(way_dynamic_path.data_pairs_without_offset)
    view.draw_polyline(adjust_z(points_of_data_pairs)) if points_of_data_pairs.length >= 2

    way_grouping.all_way_point_pairs.map {|way_point_pair|
      view.drawing_color = 'red'
      view.draw_polyline(adjust_z(way_point_pair.points))

      view.drawing_color = 'blue'
      edges = way_grouping.entity_map.sorted_edges_associated_to_way_point_pair(way_point_pair)
      points = Sketchup::Edge.to_unique_points(edges)
      view.draw_polyline(adjust_z(points)) if points.length > 1
    }
a end

  # Draw the given data_pair that indicates the part of the user's selected path which is the offset reference for their input point
  # refence_locked indicates that the user has the way_shape reference (either to an edge side or way_point_pair), so it should be rendered to indicate that
  # offset_locked indicates that additionally the user has locked the offset distance from the reference
  def draw_data_pair(view, data_pair, reference_locked=false, offset_locked=false)
    return if select_edges_only?
    view.drawing_color = 'yellow'
    view.line_width = 5
    view.line_stipple = (reference_locked || offset_locked) ? '' : '-'
    points = [data_pair.points.first, data_pair.points.last]
    view.draw_polyline(adjust_z(points))
  end

  # Draw the point from the path to the input_point of the way_shape
  # reference_locked indicates that the user has locked the way_shape, so it should be rendered to indicate that
  # offset_locked indicates that the user has additionally locked the offset distance from the reference
  def draw_path_to_point(view, path_to_point_data, reference_locked=false, offset_locked=false)
    return if select_edges_only?
    view.drawing_color = offset_locked ? 'red' : 'black'
    view.line_width = 3
    view.line_stipple = (reference_locked || offset_locked) ? '' : '-'
    points = path_to_point_data.path_to_point_points
    view.draw_polyline(adjust_z(points))
  end
  # The z to draw at should be determined by the current cursor position, which should be based on the surface it is hovering over
  def determine_z_for_drawing(points)
    way_dynamic_path && way_dynamic_path.way_grouping ?
      way_grouping.max_z_at_point(dynamic_point.unconstrained_point, points.first) :
      point_as_static.z
  end

  # Raises transforms a path of points to the given z, useful for when an offset on a component needs to be drawn on top of that component. By default z is the height of the way_grouping.surface_component
  def adjust_z(points, z=determine_z_for_drawing(points))
    self.class.adjust_z(points, z)
  end

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Offset_Configuration_Module)
    base.extend(Offset_Finisher_Utilities_Module)
    base.extend(Class_Methods)
  end

  module Class_Methods

    UI_MESSAGES = {
        :click_to_finish =>
            {:EN=>"Click to finish",
             :FR=>"Cliquez pour finalizer"},
        :too_far =>
            {:EN=>"The offset is too far away from the line",
             :FR=>"L'offset est trop loin du ligne"},
        :distance =>
            {:EN=>"Distance",
             :FR=>"Distance"},
        :adjust =>
            {:EN=>"Now adjust the surface",
             :FR=>"Réglez maintenant la supericie"},
        # The VCB labels, override these when needed
        # In selection mode:
        :vcb_label =>
            {:EN=>'Offset Distance',
             :FR=>'Distance de Deplacement'
            },
        # In path adjust mode:
        :vcb_path_adjustor_label =>
            {:EN=>'Length',
             :FR=>'Longeur'
            }
    }

    def messages
      UI_MESSAGES
    end

  end
end