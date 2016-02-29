

# Manages the plugin toolbars
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require "tools/managed_toolbar.rb"

class Toolbar_Manager
  attr_reader :managed_toolbars
  def initialize
    @managed_toolbars = []
    @default_menu_name = "Tools"
  end
  def get_toolbar(name)
    managed_toolbar = @managed_toolbars.find {|managed_toolbar| managed_toolbar.name == name}
    unless managed_toolbar
      managed_toolbar = Managed_Toolbar.new(name, @default_menu_name)
      @managed_toolbars.push managed_toolbar
    end
    managed_toolbar
  end
  def hide_all
    @managed_toolbars.each {|mt| mt.hide}
  end
end