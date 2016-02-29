require 'tools/offset_tools/offset_tool_module'

# Last Offset Tool is a meta tool that is wired in the Setup to always select the last offset tool from the Controller. Therefore this class is only a name resolution stub for the icon files. It must exist but does nothing.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Last_Offset_Tool
  include Offset_Tool_Module

  # Default messages in case a tool doesn't define any
  UI_MESSAGES = {
      :title =>
          {:EN=>"Offset way creation",
           :FR=>"Création de voie via offset"},
      :tooltip =>
          {:EN=>"Reuse the last-used layout tool",
           :FR=>"Reultilizer l'outile de dessin le plus récemment utilizé"}
  }
  def self.messages
    UI_MESSAGES
  end
end