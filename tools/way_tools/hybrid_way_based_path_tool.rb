require 'tools/offset_tools/offset_finisher_module'
# The Offset_Finisher extensions for offset tools that mixin the Hybrid_Path_Properties. This currently doesn't add any special functionality
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Hybrid_Way_Based_Path_Tool
  include Offset_Finisher_Module

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Offset_Finisher_Module)
    base.extend(Class_Methods)
  end

  # Overrides the default method to draw the current point
  def draw_points(view)
    # Draw the input point of the each way_shape
    dynamic_pairs = way_dynamic_path.dynamic_pairs
    dynamic_pairs.each_with_index {|dynamic_pair,i|
      view.draw_points(adjust_z([dynamic_pair.point.position]), 10, 5, "red") # size, style, color
    }
    # Draw the current cursor point if it differs from the point of the last way_shape
    if (way_dynamic_path.stray_points.length > 1)
      view.draw_points(adjust_z([way_dynamic_path.stray_points.last]), 10, 5, "red") # size, style, color
    end
  end

  module Class_Methods

  end
end