# Encapsulates a Sketchup toolbar and keeps track of its name and the commands register to it.
# Sketchup's API should do this but it's underdeveloped.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require "tools/managed_command.rb"

class Managed_Toolbar
  attr_reader :name, :toolbar, :managed_commands, :tool_class_to_name, :select_tool_lambdas

  def initialize (name, parent_menu_name)
    @name = name
    @toolbar =  UI::Toolbar.new name
    @managed_commands = []
    # Used to select tools programmatically
    @select_tool_lambdas = {}
    # Maps the class of the tool the registered name, for use by tool classes that don't know their registered name
    @tool_class_to_name = {}
    @parent_menu_name = parent_menu_name
    @sub_menu = create_sub_menu()
  end

  # Register the tool for use. Some tools are put into the Sketchup toolbar and menu and some are limited to the web interface. Those limited to the web interface are selectable programmatically.
  # sketchup_ui_enabled if true means that a toolbar and menu item is created for the tool
  # custom_lambda is a special lambda to call to activate meta tools, such as the Last Offset Tool
  def register_tool(name, tool_class, sketchup_ui_enabled, travel_networks, custom_lambda=nil)
    select_tool_lambda = custom_lambda || lambda {
      tool_instance = tool_class.new(travel_networks)
      Rescape::Config.log.info("Selecting tool #{name}")
      Sketchup.active_model.select_tool(tool_instance)
      tool_instance
    }
    command = tool_class.configure(select_tool_lambda, name, tool_class)
    # Create and configure the Toolbar
    unless !sketchup_ui_enabled || @managed_commands.find {|managed_command| managed_command.name==name}
      # Create a toolbar item and menu item for the command
      @managed_commands.push(Managed_Command.new(name, command))
      @toolbar.add_item(command)
      add_to_menu(command)
    end
    # Always enable programmatic selection, replacing it if it's re-registered
    @select_tool_lambdas[name] = select_tool_lambda
    @select_tool_lambdas[tool_class] = select_tool_lambda
    @tool_class_to_name[tool_class] = name
  end

  # Selects the named tools and returns the instance of the tool
  def select_tool(name)
    Rescape::Config.log.info("Calling select for tool #{name}")
    @select_tool_lambdas[name].or_if_nil{
      raise "Tool not found with name #{name}. Tools: #{@select_tool_lambdas.keys.inspect}"}.
    call()
  end

  # Returns true if the given tool is registered
  # The argument can be the tool name or class
  def contains_tool?(tool_class_or_name)
    @select_tool_lambdas.member?(tool_class_or_name)
  end

  # Maps the tool class to the name
  def tool_name(tool_class)
    @tool_class_to_name[tool_class].or_if_nil {raise "The tool class #{tool_class} is not registered"}
  end

  # Selects the tool based on the given Tool class
  def select_tool_by_class(tool_class)
    select_tool(tool_name(tool_class))
  end

   def show
     @toolbar.show
   end

   def hide
    @toolbar.hide  
   end

   def create_sub_menu()
     UI.menu(@parent_menu_name).add_submenu(@name)
   end
  
   def add_to_menu(command)
    # Add the Command to the Tools menu
    @sub_menu.add_item(command)
   end
end