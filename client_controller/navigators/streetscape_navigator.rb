require 'client_controller/navigator'
require 'client_controller/tutorial_state'
require 'client_controller/tutorial_state_step'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Streetscape_Navigator < Navigator
  def initialize_states
    [
        streetscape_introduction(),
        add_sidewalk(),
        add_streetcar_track(),
        add_railroad_track(),
        add_trees()
    ].shallow_flatten
  end

  # Override the default behavior to zoom to the main map, we're we'll do the demo
  def zoom
    zoom_to_entities([get_main_map()])
  end

  def streetscape_introduction
    Tutorial_State.new(lambda{ }, 'streetscape_introduction')
  end

  def add_sidewalk()
    state_name = 'add_sidewalk'
    Tutorial_State.new(lambda {
      @broadcast_log.info("Adding sidewalk", navigator_name, state_name)
      # Zoom to the area of the new edges from the last state
      path_points = [Geom::Point3d.new(-1228.85, 3998.72, 12), Geom::Point3d.new(-7451.94, 2716.8, 12)]
      offset_tool = @toolbar.select_tool('Draw Sidewalk')
      create_pathing_steps(lambda {offset_tool}, state_name, path_points)
    }, state_name)
  end

  def add_streetcar_track()
    state_name = 'add_streetcar_track'
    Tutorial_State.new(lambda {
      @broadcast_log.info('Adding streetcar track', navigator_name, state_name)
      # These static points represent where ways are clicked to place the track
      path_points = [Geom::Point3d.new(-1797.49, 16210.1, 12), Geom::Point3d.new(-544.668, 521.019, 12), Geom::Point3d.new(210.27, -544.293, 12), Geom::Point3d.new(-24.9673, -2028.01, 12), Geom::Point3d.new(-5280.56, -6943.13, 12)]
      # The modifier keys to hold down while laying points
      modifier_keys = [0,0, 0, MK_COMMAND, 0]
      offset_tool = @toolbar.select_tool('Draw Tram Line')
      create_pathing_steps(lambda {offset_tool}, state_name, path_points, modifier_keys)
    }, state_name)
  end


  def add_railroad_track()
    state_name = 'add_railroad_track'
    Tutorial_State.new(lambda {
      @broadcast_log.info('Adding railroad track', navigator_name, state_name)
      # These static points represent where to click to place the track
      way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Standard_Rail]
      path_points = [
        way_grouping.find_way_point_pair_by_hash(216626198).middle_point,
        way_grouping.find_way_point_pair_by_hash(-575532871).middle_point,
        Geom::Point3d.new(969.785, 389.989, 12)]
      offset_tool = @toolbar.select_tool('Draw Rail Line')
      create_pathing_steps(lambda {offset_tool}, state_name, path_points)
    }, state_name)
  end

  def add_trees()
    state_name = 'add_trees'
    Tutorial_State.new(lambda {
      @broadcast_log.info("Adding trees", navigator_name, state_name)
      # These way_point_pair hashes represent where to click to place the track
      way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Path]
      way_point_pairs = [-723763946,506219401].map {|way_point_pair_hash|
        way_grouping.find_way_point_pair_by_hash(way_point_pair_hash)
      }
      path_points = way_point_pairs.map {|way_point_pair| way_point_pair.middle_point}
      zoom_to_entities(get_all_edges_of_way_point_pairs(way_grouping, way_point_pairs))
      # Create a tool using a closure so that it won't get initialized until as late as possible
      # This tool needs a component selected to operate correctly upon activation
      repeated_component_tool = nil
      offset_tool_lambda = lambda {
        repeated_component_tool = repeated_component_tool || @toolbar.select_tool('Draw Repeated Component')
      }
      pathing_steps = create_pathing_steps(offset_tool_lambda, state_name, path_points)
      # Show and select the tree, draw the path, then adjust the spacing of the components and finalize
      [show_and_select_component()] + pathing_steps + adjust_path_steps(offset_tool_lambda, state_name)
    }, state_name)
  end

  def show_and_select_component()
    Tutorial_State_Step.new(lambda {
      layers = @tutorial.get_layers_of_page_config(@tutorial.active_page_config)
      tree = @tutorial_model.entities.find_all {|entity| entity.typename == "ComponentInstance"}.find {|component| layers.member?(component.layer) && component.definition.name=='tree'}
      tree.visible = true
      Sketchup.active_model.selection.clear()
      Sketchup.active_model.selection.add(tree)
    }, 'show_and_select_component')
  end

  def adjust_path_steps(offset_tool_lambda, state_name)
    view = tutorial_model.active_view
    way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Path]
    way_point_pairs = [188434220, -229041682].map {|way_point_pair_hash| way_grouping.find_way_point_pair_by_hash(way_point_pair_hash)}
    offset_points = way_point_pairs.map {|way_point_pair| way_point_pair.middle_point}
    adjust_path(view, offset_tool_lambda, offset_points, navigator_name, state_name, 'spacing_components', 'finalize_path')
  end
end