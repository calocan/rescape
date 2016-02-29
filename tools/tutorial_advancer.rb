require 'tools/tool_utils'
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Tutorial_Advancer
  include Tool_Utils
  def initialize(travel_networks)
    @travel_networks = travel_networks
  end

  def activate
    Rescape::Setup.controller.tutorial.active_navigator.forward
    #self.finish()
  end

  UI_MESSAGES = {
      :title =>
          {:EN=>"Advance the tutorial",
           :FR=>"Avancez le didacticiel"},
      :tooltip =>
          {:EN=>"Advance the tutorial",
           :FR=>"Avancez le didacticiel"}
  }
  def self.messages
    UI_MESSAGES
  end
end