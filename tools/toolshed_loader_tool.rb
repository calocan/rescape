require 'tools/tool_utils'
require 'client_controller/controller'

#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Toolshed_Loader_Tool
  include Tool_Utils

  attr_reader :controller

  def initialize(travel_networks)
    @travel_networks = travel_networks
    @controller = Rescape::Setup.controller
  end

  def activate
    Rescape::Setup.controller = @controller = Rescape::Setup.controller || Controller.new(@travel_network)
    @controller.launch_toolshed()
    finish()
  end

  def deactivate(view)
    Sketchup::active_model.abort_operation()
  end

  UI_MESSAGES = {
      :title =>
          {:EN=>"Open the toolshed",
           :FR=>"Ouvrez le ?"},
      :tooltip =>
          {:EN=>"Open the toolshed",
           :FR=>"Ouvrez le ?"}
  }
  def self.messages
    UI_MESSAGES
  end

end