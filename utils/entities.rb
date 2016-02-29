require 'utils/array_module'
require 'utils/component_instance_behavior'
require 'utils/component_instance_entity'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Sketchup
  class Entities
    include Array_Module

    # Finds all the entities by recursing the component_instances/groups found withing this Entities list. Optionally apply a predicate block to each entity of Comonent_Instance_Entity found
    # The optional with instances causes a Component_Instance_Entity to be returned instead of just the entity, which allows the entity to associate with a distinct Component_Instance in the case that multiple ComponentInstances of the same ComponentDefinition exist
    def find_all_deep(with_instances=false, parent_component_instance=nil, grandparent_transformation=nil)
      results = self.flat_map {|entity|
        transformation = parent_component_instance ? parent_component_instance.transformation : Geom::Transformation.new
        [with_instances ?
          Component_Instance_Entity.new(
            parent_component_instance,
            entity,
            grandparent_transformation ?
                transformation * grandparent_transformation :
                transformation) :
          entity] +
         (entity.kind_of?(Component_Instance_Behavior) ? entity.definition.entities.find_all_deep(with_instances, entity, transformation) : [])
      }
      block_given? ? results.find_all {|result| yield(result)} : results
    end
  end
end