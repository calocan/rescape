# Alerts Rescape about new or opened models to set up a travel network for them
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Application_Observer < Sketchup::AppObserver
  def initialize(travel_networks)
    @travel_networks = travel_networks
  end

  def onNewModel(model)
    self.class.get_or_create_travel_network(@travel_networks, model)
    $s = Sketchup.active_model.selection if (Rescape::Config.debug_rescape)
  end

  # Reacts to a model opening by restoring the way_grouping instances if any Surface_Component Sketchup components exist.
  def onOpenModel(model)
    self.class.get_or_create_travel_network(@travel_networks, model)
    $s = Sketchup.active_model.selection if (Rescape::Config.debug_rescape)
  end

  def onQuit()
    # Stop the remote server
    Rescape::Setup.remote_server.stop_service()
  end

  # Gets or creates a travel network for the given model and adds it to travel_networks if needed
  def self.get_or_create_travel_network(travel_networks, model)
    Rescape::Config.log.info("Loading or creating travel_network for model #{model.unique_id}")
    if (!travel_networks[model.unique_id])
      travel_networks[model.unique_id] = Travel_Network.new([])
    end
    travel_networks[model.unique_id].restore_way_groupings(model)
    # Make sure that the needed materials are loaded too
    # TODO move elsewhere
    model.load_materials()
    travel_networks[model.unique_id]
  end
end