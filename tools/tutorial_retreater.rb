require 'tools/tool_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Tutorial_Retreater
  include Tool_Utils
  def initialize(travel_networks)
    @travel_networks = travel_networks
  end
  def activate
    Rescape::Setup.controller.tutorial.active_navigator.backward
    #self.finish()
  end

  UI_MESSAGES = {
      :title =>
          {:EN=>"Reverse the tutorial",
           :FR=>"Faites marche arriere le didacticiel"},
      :tooltip =>
          {:EN=>"Reverse the tutorial",
           :FR=>"Faites marche arriere le didacticiel"}
  }
  def self.messages
    UI_MESSAGES
  end

end