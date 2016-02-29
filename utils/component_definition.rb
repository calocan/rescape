require 'utils/component_behavior'
# Addons to Sketchup::ComponentDefinition. This may be unneeded if Sketchup::ComponentInstance is always referenced instead
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Sketchup
  class ComponentDefinition
    include Component_Behavior

  end
end