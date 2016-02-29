require 'tools/offset_tools/offset_configuration_module'
require 'tools/offset_tools/hybrid_linked_way_shapes'
require 'utils/input_point_collector'

# Represents a path that can only occur along ways. If the user draws a path between two ways the path will follow the shortest path of the ways.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Way_Path_Properties
  include Offset_Configuration_Module

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Offset_Configuration_Module)
    base.extend(Class_Methods)
  end

  module Class_Methods

    # Way based paths need at least two points to be valid
    def valid_path_length()
      2
    end

    # When no path yet exists, the user's hover over a way will result in a two point way_shape path if this is true. If not, no path will be constructed until the user has clicked one point and hovers over somewhere else to create a two point path.
    def default_to_partial_way_shape?
      true
    end

  end
end