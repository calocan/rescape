require 'client_controller/navigator'
require 'client_controller/tutorial_state'
require 'client_controller/tutorial_state_step'
require 'tools/surface_creator'

# Demonstrates adding 3D components to the tutorial model
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Component_Navigator < Navigator
  def initialize_states
    [
        start_component(),
        add_closed_surface(),
        add_partial_closed_surface(),
        add_open_surface(),
        add_vehicles(),
        add_furniture(),
        add_people()
    ].shallow_flatten
  end

  # Override the default behavior to zoom to the main map, we're we'll do the demo
  def zoom
    zoom_to_entities([get_main_map])
  end

  def start_component
    Tutorial_State.new(lambda{ start_component() }, 'component_introduction')
  end

  # Adds a simple closed surface by clicking one point in a circle of edges
  def add_closed_surface()
    path_points = edge_middle_point_of_way_point_pair_hash([710273404])
    add_surface(path_points, 'add_closed_surface')
  end

  # Creates and surface in an open area by clicking two edge points and an open point
  def add_partial_closed_surface()
    path_points = edge_middle_point_of_way_point_pair_hash([-24257422, 201082139, 846149880])
    add_surface(path_points, 'add_partial_closed_surface', add_cycle_track_steps([Geom::Point3d.new(-1396.6, -7163.26, 12), Geom::Point3d.new(-1923.03, -4801.64, 12), Geom::Point3d.new(303.903, -2875.46, 12)], 'add_partial_closed_surface'))
  end

  def add_cycle_track_steps(path_points, state_name)
    tool = nil
    tool_lambda = lambda {
      tool = tool || @toolbar.select_tool_by_class(Cycle_Track_Offset_Tool)}
    [Tutorial_State_Step.new(lambda {
      component_instance = active_model.definitions[-1].instances.only
      selection.clear()
      selection.add(component_instance)
    }, 'select')] +
    create_pathing_steps(tool_lambda,
                         state_name,
                         path_points,
                         path_points.map {|x| 0},
                         'cycle_track')
  end


  # Creates and surface in an open area by clicking two edge points and an open point
  def add_open_surface()
    path_points = edge_middle_point_of_way_point_pair_hash([271403288,1012782353])
    off_way_point = Geom::Point3d.new(911.868, 968.649, Street::DEFAULT_Z_POSITION)
    add_surface([path_points.first, off_way_point, path_points.last], 'add_open_surface', [select_and_apply_material('Vegetation_Blur7')])
  end

  # Creates a surface using the Surface_Creator tool
  # Optionally pass more steps to the state such as applying a material
  def add_surface(path_points, state_name, additional_steps=[])
    Tutorial_State.new(lambda {
      @broadcast_log.info("Add surface", navigator_name, state_name)
      # Select a closed loop way_point_pair
      offset_tool = @toolbar.select_tool_by_class(Surface_Creator)
      create_pathing_steps(lambda {offset_tool}, state_name, path_points) + additional_steps
    }, state_name)
  end

  # Select the only instance of the last create Component and a material to the ComponentDefintion
  def select_and_apply_material(material_name)
    Tutorial_State_Step.new(lambda {
      component_instance = active_model.definitions[-1].instances.only
      #selection.clear()
      #selection.add(component_instance)
      component_instance.definition.apply_material_by_name(material_name)
    }, 'select_and_apply_material')
  end

  def add_vehicles
    Tutorial_State.new(lambda {
      names = ['streetcar', 'bus', 'bike']
      layer = self.tutorial.get_layers_of_page_config(self.page_config).find {|layer| layer.name == 'stored_components'}
      component_name_to_component = get_components_by_names_and_layers(@tutorial_model, names, [layer]).map {|component| component.visible = true}.to_hash_values {|component| component.name}

    }, 'add_vehicles')
  end

  def add_furniture
    Tutorial_State.new(lambda {}, 'add_furniture')
  end

  def add_people
    Tutorial_State.new(lambda {}, 'add_people')
  end
end