# Represents a Component_Instance associated to one of the entities of its definition
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Component_Instance_Entity
  # transform should be the full transformation to get from the desired viewspace to the viewspace of this component_instance
  attr_reader :component_instance, :entity, :transformation
  def initialize(component_instance, entity, transformation)
    @component_instance = component_instance
    @entity = entity
    @transformation = transformation
  end
end