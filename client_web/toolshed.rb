require 'client_web/web_utils'

#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Toolshed
  include Web_Utils

  attr_reader :web_dialog

  def initialize(controller)
    @controller = controller
    # The UI::WebDialog instance
    @web_dialog = nil
    # The name of the current page
    @web_page_name = nil
  end

  def do_launch
    @web_dialog = launch()
  end

  def construct_web_dialog
    UI::WebDialog.new("Rescape Tool Shed", false, "WEB_DIALOG_SIZE", 200, 200, 0, 0, true)
  end

  def url(page_name=nil)
    # This is the development url. Leave it here for when guide.lzx is being edited
    # (This requires Open Laszlo Server to be running with a symbolic link at my-apps/rescape to rescape/server/public)
    if (Rescape::Config.debug_laszlo)
      "http://127.0.0.1:8080/lps-4.9.0/my-apps/rescape/toolshed.lzx?lzoptions=proxied(false)%2Cruntime(dhtml)%C2usemastersprite(false)" #lzt=html&debug=true"
    else
      partial_url = self.class.get_server_file('', "toolshed.html")
      format_url(partial_url)
    end
  end

  def add_action_callbacks(web_dialog)
    web_dialog.add_action_callback("select_tool") {|dialog, param_string|
      Rescape::Config.log.info("Tool shed called select_tool: #{param_string}")
      tool_name = param_string
      @controller.select_tool(tool_name)
    }
  end

  # Tells the web_dialog that the selected tool should be disabled because it completed or was aborted
  # Tools like layout tools that remain selected after use will not receive this command
  def deselect_tool()
    Rescape::Config.log.info("Telling tool shed to deselect the current tool")
    script = "canvas.deselectTool()"
    Rescape::Config.log.info("Calling script on #{self.class.name} #{script}")
    @web_dialog.execute_script(script)
  end

  # Allows the controller to notify the tool shed when a tool has been chosen in Sketchup
  def send_tool_changed_update(tool_name)
    script = "canvas.toolChanged('#{tool_name}')"
    Rescape::Config.log.info("Calling script on #{self.class.name} #{script}")
    @web_dialog.execute_script(script)
  end

  def make_visible(web_dialog)
    unless (web_dialog.visible?)
      web_dialog.set_position(0,0)
      web_dialog.set_size(400,600)
      web_dialog.show
      web_dialog.bring_to_front
    end
  end
end