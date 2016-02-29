#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Toolshed_Observer < Sketchup::ToolsObserver
  def initialize(controller)
    @controller = controller
  end
  def onActiveToolChanged(tools, tool_name, tool_id)
    @controller.toolshed.send_tool_changed_update(tool_name)
  end
end