# Offers configuration options for an offset tool
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Offset_Configuration_Module

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Class_Methods)
  end

  # Delegate missing instance methods to class methods. All configuration options can be configured at the instance or class level
  def method_missing(m, *args, &block)
    self.class.send(m, *args, &block) unless self.class == Class
  end

  module Class_Methods

    def offset_options
      {:angle_acceptance=>angle_acceptance(), :curve_threshold=>curve_threshold(), :curve_fraction=>curve_fraction(), :curve_length=>curve_length()}
    end

    # Reject angles that are tighter than this
    def angle_acceptance()
      30.degrees
    end

    # The sharpness of angle that the offset can tolerate before adding extra points to the offset
    # The default is 0 radians, meaning any angle can be tolerated
    def curve_threshold()
      0.degrees
    end

    def offset_width()
      0
    end

    # The distance that the surface should be offset from the user's cursor. If the surface should center around a user's cursor (e.g., a lane stripe, then this should be 0). If it should be adjacent to the user's cursor, it should be half the offset_width
    # Defaults to the most common case of offset_width()/2
    def offset_distance
      offset_width()/2
    end

    # If the curve_threshold is exceeded, this percent is used to determine how much of the two angled vectors to curve
    # The default, 100% curves starting from the far end of each vector. 0% produces no curve at all
    def curve_fraction()
      1
    end

    # Overrides the curve fraction to determine how much of a way should be curved at tight angles.
    def curve_length()
      0
    end

    # The method used to create an Sketchup::InputPoint or variant for this offset tool
    def create_input_point(preconsidered_points=nil)
      Sketchup::InputPoint.new
    end

    # Creates a Dynamic_Path instance which is used to store all information about the path selections made by the user
    # The input_point argument must be a class implementing all the methods of Sketchup::InputPoint
    def create_dynamic_path(input_point, way_grouping)
      Linked_Way_Shapes.new(way_grouping ? way_grouping : [], self, input_point)
    end

    # Determines whether or not the Linked_Way_Shapes creates the offset_finisher with a dynamic InputPoint. If true the offset_finisher will offset the chosen_path according to the dynamic position of the InputPoint. False by default.
    def dynamic_final_point_set?
      false
    end

    # Tells the Way_Selector to only select edges, not faces. This also forces the Linked_Way_Shapes to only try to solve paths for edges that are connected directly or indirectly.
    def select_edges_only?
      false
    end

    # Tells the Way_Selector to only select way_point_pairs (i.e. center point pairs.)
    def select_way_point_pairs_only?
      false
    end

    # Determines whether or not way_shapes have a dynamic input_point (true) or whether it is fixed to the way_shape's data_pair). This is set false in situations where the user should only be able to select an edge or way_point_pair rather than a point offset from either.
    def allow_way_shape_offset?
      true
    end

    # Determines whether the tool accepts points that are not associated to a way_point_pair directly or via an edge. Setting this to true allows the user to add additional points in between a selection that corresponds to a way_point_pair. This allows the user to add independent points to a curve and/or add a point that does not lie on or near the face of the way_component.
    def allow_unassociated_points?(enabling_key)
      false
    end

    # Handles an unassociated point when allow_unassociated_points? returns true.
    def handle_unassociated_points(input_point)
      raise "Unassociated points are not supported by this tool"
    end

    # Handles the the side effect of a double click, namely the mouseUp event created by the initial click
    def handle_double_click(input_point)
      input_point
    end

    # Lets tools react before a way_shape is appended to a linked_way_shape. This applies to both mouse hovers and clicks in Way_Selector
    def pre_way_shape_appended(input_point, way_shape)
    end

    # Lets tools react after a way_shape is finalized
    def post_way_shape_finalized(input_point, way_shape)
    end

    # Determines whether the user's data_pair selections should be split to Partial_Data_Pairs (true) or whether they should be treated as whole Data_Pairs (false)
    def allow_partial_data_pairs?
      true
    end

    # Determines whether or not Way_Selector should invoke Path_Adjustor after the user selects or creates a path. Path_Adjuster responds to cursor movement to update the offset of the path, the offset of the path's create surface, or whatever else is needed
    def adjust_path_after_creation?
      false
    end

    # Lets the user draw a path and select it before using the offset tool. The selected path will be used to begin the user's line. This only works for paths that don't need to run aligned to ways.
    def accept_user_selected_path_as_chosen_path?
      false
    end

    # Indicates that the last way_grouping can be used to form a way_shape if the cursor is within offset_width
    # If false then hovers off a way will be treated as an unassociated point if allow_unassociated_point? is true
    def allow_close_hovers?
      true
    end

    # Determines whether consecutive points within the same way_shape are allowed when the cursor is hovering over the way_shape that is the last way_shape in the linked_way_shapes. False by default
    def allow_hover_over_consecutive_point_in_way_shape?()
      false
    end

    # Indicates how close the cursor must be in pixels to a way surface to be considered a close hover. The default of 0 means everything is associated to the closest way_shape no matter how far away.
    def close_hover_threshold
      0
    end

    # Like close hover threshold, but works in conjunction with allow_unassociated_points?=true to determine whether a point on a way surface should be associated with the closest eligible data_pair (way_point_pair or edge) or if it should be considered an unassociated point. If the value is more than zero than the point must be within the value in number of pixels.
    def data_pair_selection_threshold
      0
    end

    # Declares the minimum number of points for a valid path drawn by the user for purposes of rendering and finalizing. This will normally be 1 or two points depending on the type of tool
    def valid_path_length()
      0
    end

    # Determines if the point_set_definition should be considered a symmetric definition (see make_data_point_sets)
    # true by default
    def symmetric?
      true
    end

    # Specifies that when a way-based path can't be solved because edges or ways are disconnected to simply connect them directly rather than fail. This is normally desirable except in cases where it would have ill-effects. For instance, the Edge_Editor tool should not tolerate creating an edge across a way
    def make_unsolvable_way_based_paths_direct?
      true
    end

    # Allow consecutive way_shapes of the same way_point_pair. This  should eventually be true for all offset tools, but certain things like the way_adder probably can't handle it right now
    def allow_consecutive_way_shapes_per_way_point_pair?
      true
    end

    def allow_node_selection?
      false
    end

    def node_selection_threshold
      0
    end

    # Defines the priority for an Offset_Way_Grouping produced by this configuration. When an Offset_Way_Grouping is created, it's cut_priority will be compared to any others that intersect it. The one with the lower priority will create a special 2D component that shadows the surface of the superior Offset_Way_Grouping to make it seem like the superior one is cutting through the inferior one. For instance, a Way_Surface_Offset_Tool will have a lower cut_priority than a Tram_Offset_Tool so that the tram track appears to cut through the way surface. Offset_Finisher_Utilities_Module.to_offset_component for details.
    def cut_priority
      0
    end

    # Determines whether or not the offset tool's Offset_Way_Groupings participates in face cutting with others
    def participates_in_cut_faces?
      true
    end

    # Explicitly give the z of the cut face if it isn't actually top face height (e.g. the bike path ignores the lane strip and returns the height of its main surface.) This is always the relative height, meaning the height that the face returns in its containing instance's viewspace
    def height_of_cut_face
      nil
    end

  end
end