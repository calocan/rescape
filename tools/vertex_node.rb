require 'utils/data_pair'
require 'utils/vertex'
# A thin wrapper around Vertex that adds pseudo data_pair behavior
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Sketchup
  class Vertex_Node
    include Data_Pair

    def initialize(vertex)
      @vertex = vertex
    end

    def vertex
      @vertex
    end

    # Return edges or reverse_edges that direct outward from the vertex
    def neighbors
      neighbors_by_data_point(vertex).map {|edge| edge.start==vertex ? edge : edge.reverse}
    end

    # Maps the neighbors by point to {point1=>[neighbors1], point2=>[neighbors2]}
    def neighbors_by_point
      {vertex.position=>neighbors}
    end

    def data_points
      [vertex, vertex]
    end

    def clone_with_new_points(point_pair)
      Partial_Data_Pair.new(self, point_pair)
    end

    def reverse
      self
    end

    def as_node_data_pair(data_point, way_grouping)
      self
    end
  end
end