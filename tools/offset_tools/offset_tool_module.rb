# Implements the functionality of Offset_Tool so that it can be mixed in to specialized offset tools
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

#require 'LibTraductor.rb'			# for language translation
require 'utils/sorting.rb'
require 'utils/edge'
require 'tools/tool_utils'
require 'wayness/entity_map'
require 'tools/way_selector'

module Offset_Tool_Module
  include Tool_Utils

  attr_reader :active_tool

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Tool_Utils)
    base.extend(Class_Methods)
  end

  def initialize(travel_networks)
    $offset_tool_module = self
    @travel_networks = travel_networks
    @entities = Sketchup.active_model.entities
    # TODO no cursor exist yet, so this just uses the tool icon
    @cursor_lookup = [:drag, :forbidden].to_hash_keys{|name| self.class.create_cursor(self.class.get_resource_file('icons', "#{self.class.name.downcase}.icns"))}
    @already_pushed = false
    tool_init()
  end

  def activate
    if (@already_pushed)
      self.pop_tool
    else
      @already_pushed = true
      base_activate()
    end
  end

  # Defined to allow mixers to call the base activate handler
  def base_activate
    onSetCursor()
    Rescape::Config.log.info("Activating tool #{self.class.name}")
    delegate_to_tool()
  end

  # Delegate to the Way_Selector tool to select a path
  def delegate_to_tool()
    self.push_tool(Way_Selector.new(@travel_networks, self))
  end

  def onSetCursor
    UI::set_cursor @cursor_lookup[:drag]
  end


  module Class_Methods

    # Default messages in case a tool doesn't define any
    UI_MESSAGES = {
        :title =>
            {:EN=>"Offset way creation",
             :FR=>"Création de voie via offset"},
        :tooltip =>
            {:EN=>"Use an offset to create a ...",
             :FR=>"Employez un offset pour créer une offset"}
    }
    def messages
      UI_MESSAGES
    end

    def message(key)
      messages[key].if_not_nil{|hash| hash[lang()]}.or_if_nil{raise "Unknown messages key #{key}"}
    end

    def offset_finisher_class
      raise "Method must be implemented by mixer class"
    end

    # Answers whether or not the offset has a set width. This will be true of most offsets, like cycle tracks and rail beds.
    # But roads themselves have no set width because their width is always chosen by the user
    # A road lane would have a set width.
    def has_set_width?()
      true
    end

    # The offset width to use for an offset which has a set with, as answered by has_set_width?
    def offset_width()
      0
    end
  end
end