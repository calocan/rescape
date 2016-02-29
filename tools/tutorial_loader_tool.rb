require 'tools/tool_utils'
require 'client_controller/controller'

#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Tutorial_Loader_Tool
  include Tool_Utils

  attr_reader :controller, :travel_networks

  def initialize(travel_networks)
    @travel_networks = travel_networks
    @controller = Rescape::Setup.controller
  end

  def activate
    self.class.set_status_to_message(:loading)
    Rescape::Setup.controller = @controller = Rescape::Setup.controller || Controller.new(@travel_network)
    if (@controller.tutorial && active_model==@controller.tutorial.tutorial_model)
      # Just launch the guide if the tutorial model is open. The only way we can detect this is to compare it to the active_model, so it may miss a model in the background
      @controller.launch_guide()
    else
      # Otherwise launch both
      @controller.launch_tutorial_and_guide()
    end
    finish()
  end

  def deactivate(view)
    Sketchup::active_model.abort_operation()
  end

  UI_MESSAGES = {
      :title =>
          {:EN=>"Open the tutorial",
           :FR=>"Ouvrez le didacticiel"},
      :loading =>
          {:EN=>"Please wait for the tutorial to load",
           :FR=>"Veuillez attender le didacticiel"},
      :tooltip =>
          {:EN=>"Open the tutorial",
           :FR=>"Ouvrez le didacticiel"}
  }
  def self.messages
    UI_MESSAGES
  end

end