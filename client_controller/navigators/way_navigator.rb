require 'client_controller/navigator'
require 'utils/Geometry_Utils'
require 'tools/way_tools/edge_associator'
require 'tools/way_tools/edge_editor'
require 'tools/way_tools/way_adder'
require 'client_controller/tutorial_state'
require 'client_controller/tutorial_state_step'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Way_Navigator < Navigator
  def initialize_states
    [
        start_ways(),
        add_way(),
        modify_edges(),
        # widen_edges()
        # narrow_edges()
        add_internal_way(),
        associate_edges()
    ].shallow_flatten
  end

  # Override the default behavior to zoom to the main map, we're we'll do the demo
  def zoom
    view = @tutorial_model.active_view
    view.zoom(get_main_map())
  end

  # The introduction state
  def start_ways
    Tutorial_State.new(lambda{
      # Show any maps that are still invisible
      maps().each {|map| map.visible = true}
    }, 'start_ways')
  end

  # The Add Way tool demo state
  def add_way
    state_name = 'add_way'
    Tutorial_State.new(lambda{
      @broadcast_log.info("Adding ways", navigator_name, state_name)
      way_editor = @toolbar.select_tool('Add Ways')
      way_selector = way_editor.active_tool
      view = tutorial_model.active_view
      # Grab the edge we're interested in
      way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Street]
      # The following checks to see if we've already created the demo way
      begin
        way_grouping.find_way_point_pair_by_hash(254803034)
        # Already exists, just return an empty collection of steps. We might in the future want to delete the way and redraw it
        return []
      rescue
        # Should throw if the way_point_pair doesn't exist
      end

      # Retrieve the way_point_pairs by their hashes, which are based on the way_points
      way_point_pairs = [-215573295, -667804152].map {|hash| way_grouping.find_way_point_pair_by_hash(hash)}
      #zoom_to_entities(get_all_edges_of_way_point_pairs(way_grouping, way_point_pairs))
      # Find the point between the middle of the two way_point_pairs
      middle_point_pair = Simple_Pair.new([way_point_pairs.first.middle_point, way_point_pairs.last.middle_point])
      # Create an intermediate point that is offset a bit from the middle of the middle_point_pair
      intermediate_point = middle_point_pair.middle_point.transform(middle_point_pair.orthogonal(false).clone_with_length(middle_point_pair.vector.length/4))
      # Create a couple offset distance examples
      offset_points = [10,20].map {|feet| intermediate_point.transform(intermediate_point.vector_to(middle_point_pair.middle_point).clone_with_length(feet*Geometry_Utils::FEET)) }

      way_selector.set_demo_mode(true)
      [
        # Select 3 points, one on each way_point_pair and one in between
        [way_point_pairs.first.middle_point, intermediate_point].map_with_index {|point, index|
          step_name = "add_point_to_line_for_way_#{index+1}"
          Tutorial_State_Step.new(lambda {
            @broadcast_log.info("Adding point to line", navigator_name, state_name, step_name)
            screen_point = view.screen_coords(point)
            way_selector.onMouseMove(0, screen_point.x, screen_point.y, view, true)
            way_selector.onLButtonUp(0, screen_point.x, screen_point.y, view, true)
          }, step_name)
        },
        # Double click to transition to offsetter
        Tutorial_State_Step.new(lambda {
          @broadcast_log.info("Finishing line", navigator_name, state_name, 'finish_line')
          screen_point = view.screen_coords(way_point_pairs.last.middle_point)
          way_selector.onMouseMove(0, screen_point.x, screen_point.y, view, true)
          way_selector.onLButtonDoubleClick(0, screen_point.x, screen_point.y, view, true)
        }, 'finish_line'),
        adjust_path(view, lambda {way_selector}, offset_points, navigator_name, state_name, 'offset_way', 'finalize_way')].shallow_flatten
    },
    state_name)
  end

  # Checks if what modify_edges creates has already been created
  def modify_edges_complete?
    way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Street]
    points = [Geom::Point3d.new(3139.92, 365.657, 12), Geom::Point3d.new(3139.92, -56.1827, 12)]
    way_grouping.entity_map.edge_lookup_by_points(points) != nil
  end

  # The Modify Way tool demo state
  def modify_edges
    state_name = 'modify_edges'
    Tutorial_State.new(
      lambda {
        @broadcast_log.info("Modifying Edges", navigator_name, state_name)
        if (modify_edges_complete?)
          return []
        end
        edge_editor = @toolbar.select_tool('Edit Edges by Drawing')
        way_selector = edge_editor.active_tool
        view = tutorial_model.active_view
        # Grab the edge we're interested in
        way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Street]
        # Retrieve the edges by the way_point_pair hashes, which are consistent each time the ways are drawn
        edges = [-140541864, -864927477].map {|hash|
          way_grouping.entity_map.edges_associated_to_way_point_pair(way_grouping.find_way_point_pair_by_hash(hash)).first}
        middle_point_pair = Simple_Pair.new([edges.first.middle_point, edges.last.middle_point])
        intermediate_point = middle_point_pair.middle_point.transform(middle_point_pair.orthogonal(false).clone_with_length(middle_point_pair.vector.length/4))
        way_selector.set_demo_mode(true)
        [
          # Select 3 points, one on each way_point_pair and one in between
          [edges.first.middle_point, intermediate_point].map_with_index {|point, index|
            step_name = "add_point_to_line_for_edge_modify_#{index+1}"
            Tutorial_State_Step.new(lambda {
              @broadcast_log.info("Adding point to line", navigator_name, state_name, step_name)
              screen_point = view.screen_coords(point)
              way_selector.onMouseMove(0, screen_point.x, screen_point.y, view, true)
              way_selector.onLButtonUp(0, screen_point.x, screen_point.y, view, true)
            }, step_name)
          },
          # Double click to transition to offsetter
          Tutorial_State_Step.new(lambda {
            @broadcast_log.info("Finishing line", navigator_name, state_name, 'finish_line_for_edge_modify')
            screen_point = view.screen_coords(edges.last.middle_point)
            way_selector.onMouseMove(0, screen_point.x, screen_point.y, view, true)
            way_selector.onLButtonDoubleClick(0, screen_point.x, screen_point.y, view, true)
          }, 'finish_line_for_edge_modify')
        ].shallow_flatten
      },
      state_name)
  end

  # The Add Way tool demo state for adding an internal way
  def add_internal_way
    state_name = 'add_internal_way'
    Tutorial_State.new(lambda{
      @broadcast_log.info("Adding internal way", navigator_name, state_name)
      # Grab the edge we're interested in
      way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Street]
      # The following checks to see if we've already created the demo way
      begin
        way_grouping.find_way_point_pair_by_hash(-790791307)
        # Already exists, just return an empty collection of steps. We might in the future want to delete the way and redraw it
        return []
      rescue
        # Should throw if the way_point_pair doesn't exist
      end
      way_editor = @toolbar.select_tool_by_class(Way_Adder)
      way_selector = way_editor.active_tool
      view = tutorial_model.active_view
      # Retrieve the way_point_pairs by their hashes, which are based on the way_points
      way_point_pairs = [183722199, -6982635].map {|hash| way_grouping.find_way_point_pair_by_hash(hash)}
      # Create an intermediate point that is offset a bit from two way_point_pairs
      intermediate_point = Geom::Point3d.new(2603.23, -916.28, 12)

      way_selector.set_demo_mode(true)
      [
          # Select 3 points, one on each way_point_pair and one in between
          [way_point_pairs.first.middle_point, intermediate_point].map_with_index {|point, index|
            step_name = "add_point_to_line_for_way_#{index+1}"
            Tutorial_State_Step.new(lambda {
              @broadcast_log.info("Adding point to line", navigator_name, state_name, step_name)
              screen_point = view.screen_coords(point)
              way_selector.onMouseMove(0, screen_point.x, screen_point.y, view, true)
              way_selector.onLButtonUp(0, screen_point.x, screen_point.y, view, true)
            }, step_name)
          },
          # Double click to transition to offsetter
          Tutorial_State_Step.new(lambda {
            @broadcast_log.info("Finishing line", navigator_name, state_name, 'finish_line')
            screen_point = view.screen_coords(way_point_pairs.last.middle_point)
            way_selector.onMouseMove(0, screen_point.x, screen_point.y, view, true)
            way_selector.onLButtonDoubleClick(0, screen_point.x, screen_point.y, view, true)
          }, 'finish_line'),
      ].shallow_flatten
    },
    state_name)
  end

  def associate_edges
    state_name = 'associate_edges'
    Tutorial_State.new(
      lambda {
        view = tutorial_model.active_view
        edge_associator = nil
        @broadcast_log.info("Associating Edges", navigator_name, state_name)
        [Tutorial_State_Step.new(lambda {
          @tutorial_model.selection.clear()
          @tutorial_model.selection.add(active_travel_network.way_class_to_surface_component[Street].component_instance)
        }, 'click_component'),
        Tutorial_State_Step.new(lambda {
          # Zoom to the area of the new edges from the last state
          set_camera(Geom::Point3d.new(1873.41, -764.996, 9690.45), Geom::Point3d.new(1873.41, -764.996, 6235.97), Geom::Vector3d.new(0, 1, 0))
          edge_associator = @toolbar.select_tool_by_class(Edge_Associator)
        }, 'click_edge_associator'),
        Tutorial_State_Step.new(lambda {
          # Click the edge at the given point
          point = Geom::Point3d.new(3139.92, -282.249, 12)
          edge_associator.set_demo_mode(true)
          screen_point = view.screen_coords(point)
          edge_associator.onMouseMove(0, screen_point.x, screen_point.y, view, true)
          edge_associator.onLButtonUp(0, screen_point.x, screen_point.y, view, true)
        }, 'click_edge'),
        Tutorial_State_Step.new(lambda {
          way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Street]
          point = get_edge_associator_way_point(way_grouping)
          screen_point = view.screen_coords(point)
          edge_associator.onMouseMove(0, screen_point.x, screen_point.y, view, true)
        }, 'hover_center_line'),
        Tutorial_State_Step.new(lambda {
          way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Street]
          point = get_edge_associator_way_point(way_grouping)
          screen_point = view.screen_coords(point)
          edge_associator.onLButtonUp(0, screen_point.x, screen_point.y, view, true)
          # Move away a little so the user can see the operation is complete
          edge_associator.onMouseMove(0, screen_point.x+20, screen_point.y, view, true)
        }, 'click_center_line')]
      }, state_name)
  end

  def get_edge_associator_way_point(way_grouping)
    begin
      way_grouping.find_way_point_pair_by_hash(-207491037).middle_point
    rescue
      Geom::Point3d.new(2752.04, -134.553, 12)
    end
  end
end