#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/edge'

class Pseudo_Edge
  include Sketchup::Edge_Module

  attr_reader :face, :data_pair, :attribute_hash

  # Creates a pseudo Edge that has all the basic properties of a real edge for cases when we want to treat an offset component as a surface_component where its outermost point sets are treated as edges even though no actual edges exist.
  # pseudo_vertices are two Pseudo_Vertices representing the vertices of the Edge
  # face is the real Sketchup::Face that these edges should pretend to be associated with
  def initialize(pseudo_vertices, face, attribute_hash={})
    @data_pair = Linked_Simple_Pair.new(pseudo_vertices)
    @face = face
    @attribute_hash = attribute_hash
  end

  def data_points
    @data_pair.data_points
  end

  def vector
    @data_pair.vector
  end

  def points
    data_points.map {|data_point| data_point.point}
  end

  # Overrides the Edge_Module call which delegates to Edge.other_vertex
  def other_data_point(data_point)
    self.data_pair.other_data_point(data_point)
  end

  # Conforms with the Edge_Module interface
  def edge
    self
  end

  def vertices
    self.data_points
  end

  # The Sketchup::Face with which the edges pretend to associate
  def lone_edge_face
    @face
  end

  def create_eligible_faces(parent=Sketchup.active_model)
    raise "Not possible to find faces for a #{self.class}"
  end

  # Get the value from attribute_hash
  def get_attribute(group_name, attribute_name)
    @attribute_hash[group_name].if_not_nil{|hash| hash[attribute_name]}
  end

  # Store the value from attribute_hash
  def set_attribute(group_name, attribute_name, attribute_value)
    sub_hash = @attribute_hash[group_name].or_if_nil {
      @attribute_hash[group_name] = {}
    }
    sub_hash[attribute_name] = attribute_value
  end
end
