#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/vertex'


class Pseudo_Vertex
  include Sketchup::Vertex_Module

  attr_reader :point, :data_pair, :neighbor_data_pairs
  attr_writer :data_pair, :neighbor_data_pairs

  # Initializes the instances with a Geom::Point3d point and an 2-level deep attribute hash
  # data_pair is the containing Pseudo_Edge, and neighbor_data_pair are the neighbor Pseudo_Edges. Both will normally be set after instantiation, since this instance is needed to create the data_pair
  def initialize(point, attribute_hash, data_pair=nil, neighbor_data_pairs=nil)
    @point = point
    @attribute_hash = attribute_hash
    @data_pair = data_pair
    @neighbor_data_pairs = neighbor_data_pairs
  end

  def vertex
    self
  end

  # Conforms to data_pair
  def point
    @point
  end

  # The Pseudo_Edges of the Pseudo_Vertex
  def data_pairs
    [@data_pair] + @neighbor_data_pairs
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