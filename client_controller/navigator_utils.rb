require 'client_controller/tutorial_state'
require 'client_controller/tutorial_state_step'

# Add support methods for common Navigator steps
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Navigator_Utils

  # Create the steps needed to draw the offset path given by the path_points and modifier_keys
  # offset_tool_lambda is a lambda that references or selects the needed tool (in cases that it can't be selected beforehand). In the latter case the lambda should select the tool once and store it locally:
  #offset_tool_lambda = lambda {
  #  tool = tool || @toolbar.select_tool_by_class(Offset_Tool_Class)
  #}
  def create_pathing_steps(offset_tool_lambda, state_name, path_points, modifier_keys=path_points.map {|x| 0}, step_suffix="path")
    view = tutorial_model.active_view
    step_index = 1
    [
        # lay the points down along or across the ways
        path_points.dual_map(modifier_keys) {|point, modifier_key|
          step_name = "add_point_to_#{step_suffix}_#{step_index}"
          step_index += 1
          Tutorial_State_Step.new(lambda {
            @broadcast_log.info("Adding point to path", navigator_name, state_name, step_name)
            screen_point = view.screen_coords(point)
            way_selector = offset_tool_lambda.call().active_tool
            way_selector.set_demo_mode(true)
            way_selector.onMouseMove(modifier_key, screen_point.x, screen_point.y, view, true)
            # Don't bother click the last point since we'll be double clicking this spot in the finish path step
            if (path_points.last != point)
              @broadcast_log.info("Clicking point #{point}", navigator_name, state_name, step_name)
              way_selector.onLButtonUp(modifier_key, screen_point.x, screen_point.y, view, true)
              @broadcast_log.info("Chosen path is now #{way_selector.linked_way_shapes.all_points.length}", navigator_name, state_name, step_name)
            end
          }, step_name)
        },
        # Double click to finish the track
        Tutorial_State_Step.new(lambda {
          @broadcast_log.info("Finishing path", navigator_name, state_name, 'finishing_path')
          screen_point = view.screen_coords(path_points.last)
          way_selector = offset_tool_lambda.call().active_tool
          way_selector.onMouseMove(modifier_keys.last, screen_point.x, screen_point.y, view, true)
          way_selector.onLButtonDoubleClick(0, screen_point.x, screen_point.y, view, true)
        }, "finishing_#{step_suffix}")
    ].shallow_flatten
  end

  # Adjust a path with Path_Adjustor
  # way_selector_lambda returns the Way_Selector tool, which must have Path_Adjustor as its active tool
  # offset_points are the points to use for the steps of the path adjustment
  # navigator_name is the Navigator name
  # state_name is the Tutorial_State name
  # adjust_step_name is the name to give the adjust steps, with _1..n added based on the number of offset_points
  # finalize_step_name is the name of the finalization step
  def adjust_path(view, way_selector_lambda, offset_points, navigator_name, state_name, adjust_step_name, finalize_step_name)
    # Adjust path with the given points
    [offset_points.map_with_index {|offset_point, index|
      step_name = adjust_step_name
      Tutorial_State_Step.new(lambda {
        @broadcast_log.info("Adjusting path", navigator_name, state_name, step_name)
        path_adjustor = way_selector_lambda.call().active_tool
        path_adjustor.set_demo_mode(true)
        screen_point = view.screen_coords(offset_point)
        path_adjustor.onMouseMove(0, screen_point.x, screen_point.y, view, true)
      }, "#{step_name}_#{index+1}")
    },
     # Finalize the path
     Tutorial_State_Step.new(lambda {
       @broadcast_log.info("Finalizing path", navigator_name, state_name, finalize_step_name)
       path_adjustor = way_selector_lambda.call().active_tool
       screen_point = view.screen_coords(offset_points.last)
       path_adjustor.onLButtonUp(0, screen_point.x, screen_point.y, view, true)
     }, finalize_step_name)].shallow_flatten()
  end

  # Returns all entities of the given model having the given names and belonging to the given layers
  def get_components_by_names_and_layers(model, names, layers)
    model.entities.find_all {|entity| names.member?(entity.name) && layers.member?(entity.layer)}
  end

  def get_first_edge_of_way_point_pair_hashes(way_grouping, way_point_pair_hashes)
    way_point_pair_hashes.map {|hash|
      way_grouping.entity_map.edges_associated_to_way_point_pair(way_grouping.find_way_point_pair_by_hash(hash)).first}
  end
  # Get the first (or only) edge middle_point of each way_point_pair_hash
  def edge_middle_point_of_way_point_pair_hash(way_point_pair_hashes)
    way_grouping = @tutorial.active_travel_network.way_class_to_grouping[Street]
    way_point_pair_hashes.map {|way_point_pair_hash|
      way_grouping.entity_map.edges_associated_to_way_point_pair(
          way_grouping.find_way_point_pair_by_hash(way_point_pair_hash)).first.middle_point
    }
  end
  def get_all_edges_of_way_point_pairs(way_grouping, way_point_pairs)
    way_point_pairs.flat_map {|way_point_pair|
      way_grouping.entity_map.edges_associated_to_way_point_pair(way_point_pair)}
  end
end