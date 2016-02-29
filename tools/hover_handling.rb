# A module that handles cursor hovering. Right now this works only with the Way_Selector but it could be generalized to work with other tools
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Hover_Handling

  # Determines what the cursor is over and returns a Way_Shape based on that or nil otherwise
  # input_point is the Complex_Point mixer representing the user's cursor
  # The optional fixed_offset_or_vector is either a Length resulting from the user entering a value in the VCB, or a vector resulting from the user pushing one of the arrow keys. It forces the defined Way_Shape to be positioned that length or vector from the nearest data_pair.
  def over_what(input_point, fixed_offset_or_vector=nil)
    $wg=way_grouping = Entity_Map.way_grouping_of_input_point(active_travel_network, input_point).if_not_nil {|way_grouping|
      # Allow a new way_grouping if no way_grouping_of_record exists or no way_shapes have been clicked yet
      (!@way_grouping_of_record || @linked_way_shapes.length==0 || @way_grouping_of_record==way_grouping) ? way_grouping : nil
    }.or_if_nil {
        # Otherwise use the way_grouping_of_record if close hovers are allowed
        (@offset_configuration.allow_close_hovers? && @way_grouping_of_record) ||
        # Otherwise handle no way_grouping
        handle_no_way_grouping(input_point)
    }

    # If the user preselected the desired way_grouping and the cursor was over something else, change to the preselected way_grouping. If the spot's invalid we'll return nil later
    if (@preselected_way_grouping && way_grouping != @preselected_way_grouping)
      way_grouping = @preselected_way_grouping
    end
    # Give unless the following conditions are met
    return nil unless
        # A Way_Grouping of some sort was found
        way_grouping &&
        # The user is not requesting a free-draw, unassociated line, if they are allowed
        !(force_unassociated_point? && @offset_configuration.allow_unassociated_points?(command_down?)) &&
        # The Way_Grouping is ad hoc or it matches the Way_Grouping of the previous way_shapes
        (linked_way_shapes.way_grouping.is_unclassified_initial_way_grouping? || linked_way_shapes.way_grouping == way_grouping) &&
        # Make sure the surface_component didn't lose the reference to its component_instance through a delete
        # This will recover the component_instance if it was lost but the entity still exists
        way_grouping.verify_surface_component()
    # Define the way_shape based on whether the input is over an edge or face.
    # This might also return nil under some conditions, meaning no valid hover_shape exists
    define_hover_shape(way_grouping, input_point, fixed_offset_or_vector)
  end

  # Defines a way_shape based on the user's input_point
  # If way_shape_data_pair_locked? is true, the way_shape's data_pair will be forced to be based on the last hover_shape's data_pair if it exists.
  # way_grouping is the Way_Grouping identified as what the user's cursor hovers over or near
  # See over_what for descriptions of input_point and fixed_offset_or_vector.
  # Returns a Way_Shape or nil if required conditions are not met
  def define_hover_shape(way_grouping, input_point, fixed_offset_or_vector=nil)
    # Reference the unfinalized previously created hover Way_Shape if one exists and we need the new Way_Shape to conform to it because the user wants to maintain the same edge side/center line even if they are closer to another one.
    unfinalized_way_shape = way_shape_data_pair_locked? ? @hover_linked_way_shapes.unfinalized_way_shape : nil
    options = {
        # Forces the way_shape created to have the given way_shape's data_pair, not the usual closest data_pair
        :locked_way_shape => unfinalized_way_shape,
        # Forces the offset distance to be based on the previous way_shape offset distance, rather than based on the cursor offset
        :synced_to_previous_way_shape => way_shape_data_pair_offset_locked? && @linked_way_shapes.way_shapes.length > 0 ? @linked_way_shapes.way_shapes.last : nil,
        # Forces the way_shape to have the given offset length from the chosen data_pair or added relative vector distance
        :fixed_offset => fixed_offset_or_vector,
        # Stored with the way_shape to tell it to connect smoothly with the previous way shape, as opposed to maintaining a path parallel to the ways
        :smooth_connect => false, # This probably isn't needed anymore
        # Force the path between this way_shape and the previous to be along the way. Some tools always require this, for some it is allowed only with command down, and some tools never force drawing along the way path
        :force_path_on_way => !@offset_configuration.allow_unassociated_points?(force_unassociated_point?),
    }

    # Create the way_shape based on the cursor position and the configuration.
    # This might return nil if configuration conditions are not met.
    Way_Shape_Creator.way_shape_from_cursor(
        way_grouping,
        @offset_configuration,
        input_point,
        options).way_shape_around_cursor_point()
  end

  # If the input_point is over an unknown entity, create a way_group from the entity
  def handle_no_way_grouping(input_point)
    entities = Entity_Map.entities_of_input_point(input_point)
    return nil if
        # Skip empty collections
        entities.length==0 ||
            # Skip offset components, maps, and other things that are Rescape-created
            !allowed_offset_component?(entities.first.parent)
    return nil
    # Since this process is intensive, limit it to small surfaces
    raise "Cannot process entities as non way_group for #{entities.length} entities" if entities.length > 30
    Rescape::Config.log.info("Handling non way_group")
    way_grouping = @ad_hoc_way_grouping_cache_lookup.find_or_create(entities) {
      Entity_Map.create_ad_hoc_way_grouping(entities)
    }
    Rescape::Config.log.info("Created way_grouping from non way_group")
    way_grouping
  end

  # Determines whether component hovered over is eligible to receive way_shapes. Right now, we reject maps and offset_based_components already created. TODO We really need to reject any component that isn't a way_grouping's surface_component
  def allowed_offset_component?(component)
    !component.is_map? and !component.is_way_offset_component?
  end

end