require 'tools/tool_utils'
require 'wayness/Side_Point_Generator'
require 'wayness/continuous_ways'
require 'utils/lambda_wrapper'
require 'utils/edge'

# This module adds essential functionality to the Offset_Finisher module, converting a chosen path by the user into points offset from that path.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Offset_Finisher_Utilities_Module
  include Tool_Utils

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Tool_Utils)
  end

  def path_to_point_data
    raise("Mixer must implement")
  end

  # The always static version of point, such as InputPoint.position
  def point_as_static()
    raise("Mixer must implement")
  end

  def offset_configuration()
    @offset_configuration
  end

  def valid_path?
    @offset_configuration.valid_path_length <= self.way_dynamic_path.all_points.length()
  end

  # The default criteria for drawing is that the vector created by the drag
  # have a length > 0 and that at least 2 side points are generated by that vector.
  def valid_vector_for_drawing?()
    vector = vector_from_path_to_input_point()
    vector.length > 0
  end

  # Creates a lane to encapsulate the chosen_path within a generic way
  # Optionally provide an alternate path, such as a subset of the chosen_path
  def path_as_lane(path=chosen_path)
    raise "Path must be at least 2 points" unless path and path.length > 1
    cache_container.lane_cache_lookup.find_or_create(path) {|the_path|
      Lane.new(the_path, {})
    }
  end

  # Create a side point generator based on the chosen_path
  # Optionally provide an alternate path, such as a subset of the chosen_path
  def side_point_generator(path=chosen_path)
    lane = path_as_lane(path)
    cache_container.side_point_generator_cache_lookup.find_or_create(lane) {|the_lane|
      Side_Point_Generator.new(Continuous_Ways.new(the_lane.class, [the_lane]), @offset_configuration.offset_options())
    }
  end

  # Create a lane based on the path
  def path_for_offset_way(path=chosen_path)
    #vector = Geom::Vector3d.new
    #center_side_points = offset_points_based_on_vector(vector, side_point_generator(path))
    #Offset_Way.new(center_side_points.map {|side_point| side_point.point}, {})
    Offset_Way.new(point_sets[:center], {})
  end

  # Creates the symmetrical versions of the point set key
  def symmetric_key_names(key)
    (1..2).map {|index| (key.to_s+index.to_s).to_sym}
  end

  def create_points_based_on_vector(side_point_generator, vector, length)
    v = vector.clone_with_length(length)
    offset_points_based_on_vector(v, side_point_generator)
  end

  # Returns the side_points based on the input_vector, that is the vector from the path to the cursor point
  # The side_point_generator is by default the one created for this class
  def offset_points_based_on_input_vector(side_point_generator=side_point_generator())
    offset_points_based_on_vector(
        vector_from_path_to_input_point(),
        side_point_generator
    )
  end

  # Returns the side_points for the given vector
  # The side_point_generator is by default the one created for this class but can be overridden if different offset properties are desired.
  def offset_points_based_on_vector(vector,
    side_point_generator=side_point_generator())

    # Get the lambda function that returns an orthogonal translation for a pair of points
    point_pair_transformation_lambda = transformation_lambda_from_path_along_vector(vector)
    # Generate the points. Any point that is a side_point_parent is replaced by its children. This handles angle tolerances by adding curve points.
    side_point_generator.make_side_points(point_pair_transformation_lambda)
  end

  def way_point_pair_level_lambda(point_pair_translation_lambda)
    nil
  end
  # Defines an optional lambda function to determine whether or not a give a given point_pair should be translated by the calculated translation (true) or be limited to the identity translation (false)
  def predicate_lambda
    nil
  end

  # Used in conjunction with predicate_lambda to define a transformation lambda for pairs that do not pass the predicate_lambda. This is useful for a case where reference way_point_pair are being used to restrict an offset of other pairs but the way_point_pair already has a fixed edge defined.
  def nonmatching_transformation_lambda
    nil
  end

  def transformation_lambda_from_path_along_input_vector(mirrored_offset=false)
    transformation_lambda_from_path_along_vector(vector_from_path_to_input_point(), mirrored_offset)
  end

  # Calculates the transformation lambda based on the input vector
  # Returns a lambda that expects a pair of points as its arguments and returns a Sketchup transformation object to transform them based on the path
  # If the vector length is 0 the operation will proceed without any actual transformation
  # mirrored_offset indicates that something is being offset in both directions, namely a Way_Grouping, and therefore the offset direction should be forced to counterclockwise of the reference pair (path_to_point_data.pair) direction, which represents a "positive" offset. Way_Groupings always contain duplicate paths that are opposite of each other, so mirrored_offset force both directions to offset counterclockwise no matter what side the user's input_point is of the path.
  def transformation_lambda_from_path_along_vector(offset_vector, mirrored_offset=false)
    # Get the path point pair's vector where the user clicked. This is just used to determine the sign of the orthogonal translation
    reference_data_pair = path_to_point_data.pair
    # If mirrored_offset is true then we need the counterclockwise angle between the reference_data_pair_vector and the offset_vector to be 90°, not 270°, so we reverse the reference_data_pair vector is that angle is greater than ∏
    reference_data_pair_vector = (mirrored_offset and
        Geometry_Utils.radians_between(
          Geometry_Utils::CCW_KEY,
          reference_data_pair.vector,
          offset_vector) > Math::PI) ?
      reference_data_pair.vector.reverse : reference_data_pair.vector

    # Get the orthogonal translation based on the input_vector and the closest pair on the path
    # The predicate_lambda is an optional function that limits which pairs are actually offset
    # nonmatching_transformation_lambda() optionally supplies a transformation lambda to those points pairs that do not pass the predicate_lambda, which otherwise are simply not transformed and left as the original point pair.
    Geometry_Utils.orthogonal_point_translation_lambda_from_vectors(offset_vector, reference_data_pair_vector, offset_vector.length, predicate_lambda(), nonmatching_transformation_lambda())
  end

  # Calculates the vector from the user's click on the path, point_on_path(), to the orthogonal point based on their current cursor position or whatever is represented by point(). point() may not be on the orthogonal projection of point_on_path(), but what matters is the direction and distance to the line of the pair of chosen_path() between which point_on_path() lies.
  # When we don't want any offset of the path this will return a 0 vector
  def vector_from_path_to_input_point
    path_to_point_data.point_on_path.vector_to(calculate_orthogonal_point())
  end

  # Calculates the orthogonal point from point_on_path() to the static version of the point(). point() does not necessarily lie on the orthogonal projection of point_on_path(). What is important is the distance and direction of point() from the path(). That is the distance and direction that point on path is translated.
  def calculate_orthogonal_point
    self.class.orthogonal_point_from_path(path_as_lane().points, path_to_point_data.point_on_path, point_as_static())
  end

  # Draw the offset path at a distance determined by the user's drag
  def draw(view, movement_flags)
    if (valid_path?)
      draw_offset(view, movement_flags)
    end
    #draw_optional_views(view, movement_flags)
  end

  # Set the status for a valid offset drag. The distance indicates how far the user
  # has dragged the offset from the start point orthogonal to the matching point pair.
  # Draws the points that the user clicks on the way_shapes
  def draw_points(view)
    # Draw the input point of the each way_shape
    dynamic_pairs = way_dynamic_path.dynamic_pairs
    dynamic_pairs.each_with_index {|dynamic_pair,i|
      view.draw_points(adjust_z([dynamic_pair.point.position]), 10, 5, "red") # size, style, color
    }
  end

  # Draws the line as the user creates it. Depending on the type of way_dynamic_path this will either draw the exact path chosen by the user or the path along the ways between the user's clicks'
  def draw_line(view)
    draw_points(view)
    points = way_dynamic_path.all_points
    view.drawing_color = "yellow"
    view.line_width = 4
    view.line_stipple = ""
    view.draw_polyline(adjust_z(points)) if points.length >= 2
  end

  def draw_debug_data(view)
    view.drawing_color = 'blue'
    #view.draw_polyline($parx.flat_map {|x| [x.points[1], x.middle_point]})
    view.drawing_color = 'pink'
    #view.draw_polyline($ch1.flat_map {|x| [x.points[1], x.middle_point]})
    view.drawing_color = 'green'
    #view.draw_polyline($e1.flat_map {|x| [x.points[1], x.middle_point]})
  end

  $dropped = []
  $origin_intersections = []
  $offset_intersections = []
  def draw_debug_data_dropped_pairs(view)
    colors=['black', 'white']
    way_dynamic_path.data_pairs_without_offset.each_with_index {|data_pair, index|
      view.drawing_color = colors[index % 2]
      view.draw_line(data_pair.points)
    }
    view.drawing_color = "gray"
    $dropped.each {|dropped| view.draw_line(dropped.points) }
    $dropped.clear()
    view.draw_points(adjust_z($origin_intersections), 10, 5, "blue") if $origin_intersections.length > 0 # size, style, color
    $origin_intersections.clear()
    view.draw_points(adjust_z($offset_intersections), 10, 5, "purple") if $offset_intersections.length > 0 # size, style, color
    $offset_intersections.clear()
  end


  # Given a parent entity and a set of sub components create a group from the components and then transform it into a component_instance.

  # This method is used in the finalize method of the the offset tools
  # set_names_for_edges specify which two set names should be used to form the boundaries of the offset_component. List only the base name for the symmetric case (:side rather than :side1, :side2). If they are omitted then no edges will be created.
  # The edges are used by the component like way edges so that other offsets can be performed from relative to the edges. The edges will also be used to make a face (just like ways) that is used as a glue surface
  # sub_components are the prebuilt sub components to place in the offset_component
  def to_offset_component(set_names_edges=[], data_point_sets=nil, &block)

    # Take the data_point_sets specified for use as edges and extract side_point_pairs
    if (set_names_edges.length > 0)
      data_point_sets = data_point_sets || find_or_create_data_point_sets()
      set_names = (@offset_configuration.symmetric? ?
        self.symmetric_key_names(set_names_edges.only) : set_names_edges)
      $zuz=simple_pair_sets = set_names.map_with_index {|set_name, i|
          point_set = data_point_sets[set_name].map {|data_point| data_point.point}.
                                                         or_if_nil {raise "No data_point_set named #{set_name}"}
          # Make sure the point set correspond with the way that it will associate with. This means we reverse the set to be associated with the reverse way, assuming the sets all run in the direction of the way
          Simple_Pair.make_simple_pairs(i==0 ? point_set : point_set.reverse)
      }
    else
      raise "Sets for edges are expected. Use to_offset_component_for_no_edge_tool instead"
    end

    offset_way_grouping = create_offset_way_grouping(simple_pair_sets, &block)

    # Create a way_grouping based on the center points. This will create two ways, one for each direction
    intersect_with_other_offset_way_groupings(offset_way_grouping)

    offset_way_grouping.surface_component.component_instance
  end

  # Create an Offset_Way_Grouping for tools that don't create a way surface with edges, namely the Surface_Creator
  def to_offset_component_for_no_edge_tools(perimeter_point_set, &block)
    offset_way_grouping = create_offset_way_grouping() {|parent|
      # Use the perimeter_point set to way_face, since we have no edges whither to extrude the way
      self.class.dynamic_cross_section(parent, perimeter_point_set, {:explode_instance=>true})
      block.call(parent)
    }
    # Create a way_grouping based on the center points. This will create two ways, one for each direction
    intersect_with_other_offset_way_groupings(offset_way_grouping)

    offset_way_grouping.surface_component.component_instance
  end

  def create_offset_way_grouping(simple_pair_sets=[[],[]], &block)
    offset_way = path_for_offset_way()
    $asa=offset_way_grouping = Offset_Way_Grouping.new(Offset_Way, [offset_way], nil, simple_pair_sets, @offset_configuration)
    # Register the Way_Grouping with the Travel_Network so that it can be used for offsets itself and so way_point_pairs can be resolved to the Way_Grouping
    active_travel_network.register_way_grouping(offset_way_grouping)
    # Pass the creation block to create the sub_components and the way surface, which is just used as an outline of the offset_surface_component
    offset_way_grouping.surface_component.create_components(&block)
    offset_way_grouping
  end

  def intersect_with_other_offset_way_groupings(offset_way_grouping)
    return unless offset_way_grouping.offset_configuration.participates_in_cut_faces?
    # Iterate through the other offset_way_groupings to create a cut surface in any eligible component with which this component intersects
    $ofgs=active_travel_network.offset_way_groupings.each { |existing_offset_way_grouping|

      if (offset_way_grouping != existing_offset_way_grouping &&
          existing_offset_way_grouping.offset_configuration.participates_in_cut_faces?)
        if (existing_offset_way_grouping.offset_configuration.cut_priority <= offset_way_grouping.offset_configuration.cut_priority)
          existing_offset_way_grouping.surface_component.add_cut_face(offset_way_grouping.surface_component)
        else
          offset_way_grouping.surface_component.add_cut_face(existing_offset_way_grouping.surface_component)
        end
      end
    }

  end

end