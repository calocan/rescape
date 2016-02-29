require 'tools/offset_tools/offset_finisher_module'
require 'utils/input_point_collector'
require 'utils/cache_lookup'
require 'tools/offset_tools/line_path_properties'

# Assists the editor tools that draw lines. Mixers must implement the Offset_Finisher_Module as well.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Line_Editor_Tool
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

  # Create a cache of the ad hoc Way_Groupings that are created
  def init()
    # Already done in offset_finisher_cache_lookups_module
    #@way_grouping_cache_lookup = Cache_Lookup.new("#{self.class} Way_Grouping cache lookup", lambda {
        #|data_pairs| Simple_Pair.unordered_pairs_hash(data_pairs)
    #})
  end

  # Overrides the default method to draw all the points on the path that user chooses
  def draw_points(view)
    view.draw_points(adjust_z(way_dynamic_path.all_points), 10, 5, "red") # size, style, color
  end


  module Class_Methods

  end
end