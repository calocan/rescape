# Groups are a mix of Component and Component_Instance, so have them mixin the Component_Behavior and the Component_Instance_Behavior modules
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/component_behavior'
require 'utils/component_instance_behavior'


module Sketchup
  class Group
    include Component_Behavior
    include Component_Instance_Behavior

    # Since Group has properties of ComponentDefintion, just return self here. If a real definition is needed, which is the case when the entity is added to an Entities collection, then use to_component_definition!
    def definition
      self
    end

    # Transform the group to a ComponentInstance and take the definition
    def to_component_definition!
      group.to_component.definition
    end
  end
end