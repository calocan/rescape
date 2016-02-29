require 'tools/offset_tools/hybrid_path_properties'
require 'tools/offset_tools/line_linked_way_shapes'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Line_Path_Properties
  include Hybrid_Path_Properties

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Hybrid_Path_Properties)
    base.extend(Class_Methods)
  end

  module Class_Methods

    # Allow the user to click a point unassociated with an edge. We always want this enabled for line editing tools
    def allow_unassociated_points?(enabling_key)
      true
    end

    # Uses a Line_Linked_Way_Shapes instance that represents the user's chosen path of points chosen between way_shapes rather than the way_point_pair based points between way_shapes
    def create_dynamic_path(input_point, way_grouping=nil)
      Line_Linked_Way_Shapes.new(way_grouping ? way_grouping : [], self, input_point)
    end

    # Since these tools create new ways or edit, we don't want a way shape to appear when the user first hovers over a way. We only want the intersection point with the nearest edge or center line so the user can begin a path from the way.
    def default_to_partial_way_shape?
      false
    end

    # The user's path must have at least one point to be valid and hence be drawn. Most tools will require more than one point for finalizing a tool use
    def valid_path_length
      1
    end

    # Don't associate off-way hovers with the closest way
    def allow_close_hovers?
      false
    end
  end
end