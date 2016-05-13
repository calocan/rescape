# Starts rescape plugin
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

# config must be included first
require 'config/config'
require 'utils/reload'
require 'utils/object'
require 'utils/nil_class'
require 'utils/model'
require 'utils/array'
require 'utils/hash'
require 'client_controller/controller'
require 'logging/log'
require 'tools/toolbar_manager'
require 'wayness/travel_network'
require 'wayness/way_pathing'
require 'wayness/way'
require 'tools/tutorial_loader_tool'
require 'tools/toolshed_loader_tool'
require 'tools/tutorial_advancer'
require 'tools/tutorial_retreater'
require 'tools/way_tools/way_loader_tool'
require 'tools/offset_tools/line_offset_tool'
require 'tools/offset_tools/component_offset_tool'
require 'tools/offset_tools/rail/tram_offset_tool'
require 'tools/offset_tools/rail/standard_rail_offset_tool'
require 'tools/offset_tools/ground/sidewalk_offset_tool'
require 'tools/offset_tools/ground/cycle_track_offset_tool'
require 'tools/offset_tools/way_surface_offset_tool'
require 'tools/offset_tools/last_offset_tool'
require 'tools/way_tools/edge_associator'
require 'tools/way_tools/edge_editor'
require 'tools/way_tools/way_adder'
require 'tools/surface_creator'
require 'utils/entity'
require 'drb'
require 'utils/application_observer' if Rescape::Config.in_sketchup?

module Rescape
  class Setup
    class << self; attr_accessor :travel_networks, :toolbar_manager, :config, :controller, :remote_server end
    RESCAPE_TOOLBAR = 'Rescape'

    def self.reset
      Reload.all
      self.toolbar_manager = Toolbar_Manager.new
      # Create a hash of Travel_Networks keyed by Sketchup::Model hash
      self.travel_networks = {}

      reset_controller()

      # Add an application observer
      if (Rescape::Config.in_sketchup?)
        @application_observer = Application_Observer.new(self.travel_networks)
        Sketchup.add_observer(@application_observer)
        configure_tools(self.toolbar_manager, self.travel_networks)
      end

      if (Rescape::Config.debug_rescape)
        if (Rescape::Config.in_sketchup?)
          $s = Sketchup.active_model.selection
          $controller = self.controller if Rescape::Config.in_sketchup?
        end
        $setup = self
      end
      reset_remote_server()
    end

    def self.reset_controller
      self.controller = Controller.new(self.travel_networks) if Rescape::Config.in_sketchup?
    end

    def self.redo_tools()
      self.toolbar_manager.hide_all
      self.toolbar_manager = Toolbar_Manager.new
    end

    def self.reset_remote_server
      # Start the DRb server to offload travel_network processing to external processes
      if (Rescape::Config.in_sketchup?)
        command = "ruby 'utils/restart_external_server.rb' '#{Rescape::Config::DRB_URI}'"
        Rescape::Config.log.info("Running script: #{command}")
        # Run an external process to start the server
        Thread.new do
          Dir.chdir(Rescape::Config::BASE_DIR)
          system(command)
        end
        self.remote_server =DRbObject.new(nil, Rescape::Config::DRB_URI)
      else
        # Processes running outside of Sketchup will not have a remote server
        self.remote_server = nil
      end
    end

    # Reports if the remote server was expected but lost
    def self.lost_server?
      if (self.remote_server)
        begin
          self.remote_server.connected?
          false
        rescue
          Rescape::Config.log.warn("Lost the server")
          true
        end
      else
        false
      end
    end

    # Gets the remote server or restarts the service
    def self.get_remote_server
      if (self.lost_server?)
        # Something killed the server, try to restart it
        self.reset_remote_server
        # Pause a second to allow it to finish starting
        sleep(1)
        # Give up with we couldn't start it
        self.lost_server? ?
          nil :
          self.remote_server
      else
        self.remote_server
      end
    end

    def self.main_tools(managed_toolbar)
      [
          # Getting Started tools
          {:name=>'Tutorial', :tool=>Tutorial_Loader_Tool, :sketchup_ui_enabled=>true},
          {:name=>'Toolshed', :tool=>Toolshed_Loader_Tool, :sketchup_ui_enabled=>true},

          # Way tools
          {:name=>'Load Ways', :tool=>Way_Loader_Tool, :sketchup_ui_enabled=>true},
          {:name=>'Add Ways', :tool=>Way_Adder, :sketchup_ui_enabled=>true},
          #{:name=>'Remove Ways', :tool=>Way_Remover, :sketchup_ui_enabled=>true},
          #{:name=>'Adjust Ways', :tool=>Way_Adjustor, :sketchup_ui_enabled=>true},
          {:name=>'Edit Edges by Drawing', :tool=>Edge_Editor, :sketchup_ui_enabled=>true},
          #{:name=>'Edit Edges by Offset', :tool=>Edge_Offset_Editor, :sketchup_ui_enabled=>true},
          {:name=>'Edit Edge Associations', :tool=>Edge_Associator, :sketchup_ui_enabled=>true},

          # Surface tools
          {:name=>'Surface Creator', :tool=>Surface_Creator, :sketchup_ui_enabled=>true},
          {:name=>'Draw Way Surface', :tool=>Way_Surface_Offset_Tool, :sketchup_ui_enabled=>true},

          # Layout tools
          {:name=>'Draw Repeated Component', :tool=>Component_Offset_Tool, :sketchup_ui_enabled=>true},
          # This special tool grabs the last layout tool used, since the layout tools only visible in the web interface
          {:name=>'Last Used Layout Tool', :tool=>Last_Offset_Tool, :sketchup_ui_enabled=>true, :custom_lambda=>lambda{
            Rescape::Config.log.info("Selecting tool #{name}")
            managed_toolbar.select_tool_by_class(self.controller.last_offset_tool_class)}},
          # Toggle tools
          {:name=>'Toggle Labels', :tool=>Toggle_Labels, :sketchup_ui_enabled=>true}
      ]
    end

    def self.offset_tools
      # None of these tools are shown in the Sketchup toolbar or menu, only the web interface.
      # There should be dozens of these, so it doesn't scale to give them Sketchup ui access (perhaps sub menus though)
      [
        {:name=>'Line Offset', :tool=>Line_Offset_Tool},
        {:name=>'Draw Sidewalk', :tool=>Sidewalk_Offset_Tool},
        {:name=>'Draw Cycle Track', :tool=>Cycle_Track_Offset_Tool},
        {:name=>'Draw Way Surface', :tool=>Way_Surface_Offset_Tool},
        {:name=>'Draw Tram Line', :tool=>Tram_Offset_Tool},
        {:name=>'Draw Rail Line', :tool=>Standard_Rail_Offset_Tool},
      ]
    end

    # Determines if the give tool name or class is one of the offset_tools
    def self.is_offset_tool?(name_or_class)
      self.offset_tools.any?{|hash| name_or_class.kind_of?(String) ? hash[:name]==name_or_class : hash[:tool]==name_or_class}
    end

    def self.configure_tools(toolbar_manager, travel_networks)
        # Refactor when there are more tools...
        managed_toolbar = toolbar_manager.get_toolbar(RESCAPE_TOOLBAR)
        (main_tools(managed_toolbar)+offset_tools()).each {|tool_hash|
          name = tool_hash[:name]
          tool = tool_hash[:tool]
          custom_lambda = tool_hash[:custom_lambda]
          sketchup_ui_enabled = tool_hash[:sketchup_ui_enabled] || false
          managed_toolbar.register_tool(name, tool, sketchup_ui_enabled, travel_networks, custom_lambda)
        }
        managed_toolbar.show
    end

    self.reset
  end
end

