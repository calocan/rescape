require 'tools/tool_utils'
require 'wayness/way'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Toggle_Labels
  include Tool_Utils
  def initialize(travel_networks)
    @travel_networks = travel_networks
    @pop_level = 1
  end
  def activate
    self.class.set_status_to_message(:title)
    layer = active_model.layers[Way::WAY_TEXT_LAYER]
    layer.visible = !layer.visible?
    self.finish()
  end
  UI_MESSAGES = {
      :title =>
          {:EN=>"Toggle labels",
           :FR=>""},
      :tooltip =>
          {:EN=>"Toggle labels",
           :FR=>""}
  }
  def self.messages
    UI_MESSAGES
  end
end