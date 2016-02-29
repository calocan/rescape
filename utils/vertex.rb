require "utils/linked_data_point"
require "utils/entity_associating"

#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Sketchup
  module Vertex_Module
    include Entity_Associating
    include Linked_Data_Point

    def self.included(base)
      self.on_extend_or_include(base)
    end
    def self.extended(base)
      self.on_extend_or_include(base)
    end
    def self.on_extend_or_include(base)
      base.extend(Entity_Associating)
      base.extend(Linked_Data_Point)
    end

    def vertex
      raise "Mixer must implement"
    end

    # Conforms to data_pair
    def point
      self.vertex.position
    end

    # The Edges of the Vertex
    def data_pairs
      self.vertex.edges
    end

    # Since vertices can't be instantiated, create a Simple_Data_Point
    def clone_with_new_point(point)
      Simple_Data_Point.new(point)
    end

    # True if the vertex is associated to any way_grouping
    def associated_to_way_grouping?
      self.get_attribute('way', 'class') != nil or self.data_pairs.any? {|edge| edge.associated_to_way_grouping?() }
    end

    # The class to which the entity is associated--resolved using the Kernel
    def associated_way_class
      self.get_attribute('way', 'class') != nil ?
          Kernel.const_get(self.get_attribute('way', 'class')) :
          self.data_pairs.find {|edge|  edge.associated_to_way_grouping?}.associated_way_class()
    end
  end

  class Vertex
    include Vertex_Module

    def vertex
      self
    end
  end
end