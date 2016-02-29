require 'tools/tool_utils'
require 'tools/offset_tools/linked_way_shapes_pathing'
require 'utils/edge'
require 'wayness/way_point_pair'
require 'utils/simple_pair'
require 'tools/way_tools/way_shape_creator'
require 'tools/offset_tools/offset_path_data'
require 'wayness/linked_way'
require 'wayness/side_point_pair'
require 'wayness/way_dynamic_path'

# Creates an offset path using shapes select by the user. The path between each shape is calculated using information about the ways on which the shapes lie.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Linked_Way_Shapes < Array
  include Tool_Utils
  include Linked_Way_Shapes_Pathing
  include Way_Dynamic_Path

  attr_reader :way_shapes, :offset_configuration, :finalized_way_based_data_pair_sets

  # Provide zero or more way_shapes to start a Linked_Way_Shapes instance
  # Alternatively supply a way_grouping without way_shapes to indicate that way_shapes added to this instance must be associated with the given way_grouing
  # Merge must be used to add subsequent way shapes
  def initialize(way_shapes_or_way_grouping, offset_configuration, data_point, finalized_way_based_data_pair_sets=[])
    if (way_shapes_or_way_grouping.kind_of?(Way_Grouping))
      @way_shapes = []
      @way_grouping = way_shapes_or_way_grouping
    else
      @way_shapes = way_shapes_or_way_grouping
      @way_grouping  = resolve_way_grouping(way_shapes)
    end
    super(@way_shapes)
    @offset_configuration = offset_configuration

    # Solve the path between each way_shape up until the penultimate shape. The last shape is dynamic and must be solved dynamically
    @finalized_way_based_data_pair_sets = finalized_way_based_data_pair_sets.or_if_empty { @way_shapes.length > 2 ?
        @way_shapes.all_but_last.map_with_subsequent {|way_shape1, way_shape2|
          solve_and_offset_path([way_shape1, way_shape2]) } :
        [] }
    raise "finalized_way_based_data_pair_sets length #{@finalized_way_based_data_pair_sets.length} are not two fewer than number of way_shapes #{@way_shapes.length}" if @way_shapes.length >= 2 && (@way_shapes.length != @finalized_way_based_data_pair_sets.length+2)
    @data_point = data_point
    # This simple cache keeps track of the path between the last two way_shapes, since the point of the final way_shape can dynamically change based on the user's cursor movement
    @active_data_pair_set_cache = Cache_Lookup.new('active_data_pair_set_cache', lambda {|way_shapes| way_shapes.last.point.hash_point})

    self.validate_instance_variables()
  end

  # The number of way_shapes
  def length
    @way_shapes.length
  end

  # Resolves the common way_grouping.way_class of the way_shapes
  def resolve_way_grouping(way_shapes)
    way_shapes.reject {|way_shape| way_shape.way_grouping.is_unclassified_way_grouping?}.map {|way_shape| way_shape.way_grouping}.uniq_by_hash.none_or_one("Expected a common way_group among way_shapes").or_if_nil {
      Way_Grouping.create_empty_and_unclassified_way_grouping
    }
  end

  ## Begin Way_Dynamic_Path Implementation

  # All of the Pair_To_Point data of the way_shapes chosen by the user, which each implement the Dynamic_Pair interface.
  def dynamic_pairs
    @way_shapes.map {|way_shape| way_shape.pair_to_point_data}
  end

  # All the side_point_pairs generated based on the way_shapes
  def data_pairs
    data_pair_sets().shallow_flatten.uniq_allow_loop
  end

  # Returns all unique points of the side_point_pair sets in order
  def all_points
    Side_Point_Pair.to_unique_points(data_pairs)
  end

  # The possibly dynamic Data_Point which may be a Sketchup::InputPoint that changes dynamically with use input or may be a static Geom::Point3d
  def data_point
    @data_point
  end

  def way_grouping
    @way_grouping
  end

  # Returns the side_point_pair set between each way_shape, or the side_point_pair of the lone way_shape as of set
  # The last pair is always re-solved in case the offset of the final way_shape is dynamic
  def data_pair_sets
    way_based_data_pair_sets()
  end

  # This is the default version of data_pair_sets. Subclasses can override data_pair_sets but can still access this original funcionality
  def way_based_data_pair_sets
    @way_shapes.length > 0 ?
      @finalized_way_based_data_pair_sets + [load_or_solve_active_data_pair_set(@way_shapes)] :
      []
  end

  # Since the final way_shape point can change dynamically based on user input, we cache the solved path between the last two way_shapes based on the current point of the way_shape
  def load_or_solve_active_data_pair_set(way_shapes)
    @active_data_pair_set_cache.find_or_create(way_shapes) {|the_way_shapes|
      solve_active_data_pair_set(the_way_shapes)
    }
  end

  # Returns the first point of the active_data_pair_set to reveal the start of the dynamic part of the path.
  def first_point_of_active_data_pair_set
    data_pair_sets.last.first.first
  end

  # Returns all points without the last data_pair_set. This is used to enhance performance in cases where only the last data_pair_set has changed (e.g the user is moving the cursor)
  def all_points_without_active_data_pair_set
    Side_Point_Pair.to_unique_points(data_pair_sets.all_but_last.shallow_flatten)
  end

  # Return just the points of the active_data_pair set
  def points_of_active_data_pair_set
    Side_Point_Pair.to_unique_points(data_pair_sets.last)
  end
  def points_of_last_data_pair_sets
    Side_Point_Pair.to_unique_points(data_pair_sets[-2..-1].shallow_flatten)
  end

  ## End Way_Dynamic_Path Implementation

  # Debug method
  # Solves the path and returns the data_pairs without offsetting them
  def data_pairs_without_offset
    @way_shapes.map_with_subsequent {|way_shape1, way_shape2|
      solve_without_offset([way_shape1, way_shape2])
    }.shallow_flatten
  end

  # Determines whether or not the way_shape is eligible to be appended to the Linked_Way_Shapes. Namely, it must (as of now) be of the same way_grouping or this instance's way_grouping must be generic
  def can_append?(way_shape)
    @way_grouping.is_unclassified_way_grouping? or way_shape.way_grouping == @way_grouping
  end

  # Returns the last way shape if and only if it is unfinalized (way_shape)
  def unfinalized_way_shape
    way_shapes.last and !way_shapes.last.finalized? ? way_shapes.last : nil
  end

  # Append a new way_shape. If the first way_shape matches the last way_shape of this instance, it will replace it. This allows the user to change the position of the last way_shape. Returns the new Linked_Way_Shapes instance
  # previous_way_shape_locked, default false, indicates that the appended way_shape is not elligible to replace the prevsiou one, even if they match within the defined threshold
  def append(way_shape, previous_way_shape_locked=false)
    raise "Appended way_shape way_grouping does not match other way_shapes" unless can_append?(way_shape)

    if (!previous_way_shape_locked and (@way_shapes.length == 0 or (@way_shapes.length==1 and matches_previous?(way_shape))))
      # Place or replace the only way_shape
      self.class.new([way_shape], @offset_configuration, @data_point)
    elsif (!previous_way_shape_locked and @way_shapes.length > 0 and matches_previous?(way_shape))
      # New shape overlaps previous, replace
      self.class.new(way_shapes.all_but_last()+[way_shape], @offset_configuration, @data_point, @finalized_way_based_data_pair_sets)
    else
      # New shape does not overlap existing or previous_way_shape_locked=true, append
      self.class.new(way_shapes+[way_shape], @offset_configuration, @data_point, way_shapes.length > 1 ? way_based_data_pair_sets : [])
    end
  end

  # Remove the last way_shape if one exists, returning a new instance or self
  def remove_last
    self.length > 0 ?
      self.class.new(
          way_shapes.all_but_last(),
          @offset_configuration,
          @data_point,
          @finalized_way_based_data_pair_sets.all_but_last()) :
      self
  end

  # Appends the first way shape to the end to form a loop. There must be at least two way_shapes present.
  def loop()
    raise "Attempt to loop linked_way_shapes with less that two way_shapes" if @way_shapes.length < 2
    append(@way_shapes.first)
  end

  # Detects if another select way_shape matches this one by sharing the same way_point_pair and having a pair_to_point_data with the same pair and point withing a certain threshold
  def matches?(way_shapes, way_shape)
    way_shapes.any? {|existing_way_shape| way_shape.matches_within_threshold?(existing_way_shape)}
  end

  def matches_previous?(way_shape)
    matches?(@way_shapes.length > 0 ? [@way_shapes.last] : [], way_shape)
  end

end
