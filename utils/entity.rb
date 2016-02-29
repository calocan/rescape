require 'utils/entity_associating'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Sketchup
  class Entity
    include Entity_Associating

    # A constant used to cache entities in a 3D region box in the given number of inches
    REGION_SIZE=200*12

    def self.edges_of_entities(entities)
      entities.map {|entity|
        case entity.typename
          when 'Edge'
            entity
          when 'Vertex'
            entity.edges
          when 'Face'
            entity.edges
          else
            "Raise the entity type #{entity.typename} is not supported here"
        end
      }.shallow_flatten
    end
  end
end