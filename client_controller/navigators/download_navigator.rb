require 'client_controller/navigator'
require 'client_controller/tutorial_state'
require 'client_controller/tutorial_state_step'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Download_Navigator < Navigator
  def initialize_states
    [
        Tutorial_State.new(lambda{ download_introduction() }, 'download_introduction'),
        Tutorial_State.new(lambda{ show_main_map() }, 'show_main_map'),
        Tutorial_State.new(lambda{ download_ways() }, 'download_ways'),
        Tutorial_State.new(lambda{ show_extra_maps() }, 'show_extra_maps'),
        Tutorial_State.new(lambda{ show_merged_ways() }, 'show_merged_ways')
    ]
  end

  # Zoom to the maps
  def zoom
    view = @tutorial_model.active_view
    view.zoom(maps())
  end

  # The initial state does nothing
  def download_introduction()
    state_name = 'download_introduction'
    @broadcast_log.info("Introducing download", navigator_name, state_name)
    maps().each {|map| map.visible = false}
  end

  # Show the map upon which we want to download ways
  def show_main_map()
    state_name = 'show_main_map'
    @broadcast_log.info("Displaying main map", navigator_name, state_name)
    origin = Geom::Point3d.new
    maps = maps().or_if_empty {raise "No maps found for the download layer!"}.
        sort_by {|map| map.bounds.center.distance(origin)}
    maps.first.visible = true
    # Hide the others
    maps.rest.each {|map| map.visible = false}
    zoom()
  end

  # Download the way data for the map
  # Clear all the ways from the map if any exist
  def download_ways()
    state_name = 'download_ways'
    @broadcast_log.info("Downloading Ways", navigator_name, state_name)
    active_travel_network.delete_drawing()
    @toolbar.select_tool('Load Ways')
  end

  def show_extra_maps()
    state_name = 'show_extra_maps'
    @broadcast_log.info("Displaying other maps", navigator_name, state_name)
    maps().rest.each {|map| map.visible = true}
    zoom()
  end

  def show_merged_ways()
    state_name = 'show_merged_maps'
    @broadcast_log.info("Downloading more ways and merging", navigator_name, state_name)
  end
end