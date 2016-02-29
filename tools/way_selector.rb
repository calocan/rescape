require 'tools/hover_handling'
require 'tools/offset_tools/linked_way_shapes'
require 'tools/tool_utils'
require 'tools/offset_tools/path_adjustor'
require 'wayness/entity_map'
require 'wayness/way_point_pair'
require 'wayness/way_shape'
require 'tools/way_tools/way_shape_creator'
require 'wayness/travel_network'
require 'tools/way_selector_config'
require 'tools/proximity_data_utils'
require 'wayness/simple_way_dynamic_path'
require 'tools/offset_tools/offset_finisher_cache_lookups_module'

# A tool that detects a certain number or any number of edge clicks or face clicks
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Way_Selector
  include Hover_Handling
  include Offset_Finisher_Cache_Lookups_Module
  include Proximity_Data_Utils
  include Way_Selector_Config

  # Implementation of the Proximity_Data_Utils module
  attr_reader :travel_networks, :offset_configuration, :movement_flags, :demo_mode, :input_point, :active_tool, :hover_linked_way_shapes, :linked_way_shapes, :preselected_way_grouping, :lock_way_shape

  def initialize(travel_networks, offset_configuration)
    $selector = self
    @travel_networks = travel_networks
    @offset_configuration = offset_configuration
    # Way_select is always delegated to by another tool, set the pop_level to one and then have the pushing tool take care of popping itself
    @pop_level = 1
    # A hash of way_groupings created from unknown surfaces keyed by the edges of the user selection
    @ad_hoc_way_grouping_cache_lookup = Cache_Lookup.new("Ad hoc Way_Grouping", lambda {|entities|
      # Hash the edges in order to cache way_groupings
      edges = Sketchup::Entity.edges_of_entities(entities)
      Sketchup::Edge.unordered_pairs_hash(edges)
    })
    reinitialize()
    tool_init()
    init_caches()
  end

  # Initializes or reinitializes the tool after its child is popped
  def reinitialize()
    @finished = false
    # Dynamic variables. input_point depends on user input
    @input_point = nil
    # hover_linked_way_shapes responds to input_point
    @hover_linked_way_shapes = nil
    # linked_way_shapes reflects hover_linked_way_shapes after a valid mouse click
    @linked_way_shapes = nil
    # The way_grouping of hover_linked_way_shapes or the else most recent way_grouping over which the user hovered
    @way_grouping_of_record = nil
    # The input flags of the last mouse move
    @movement_flags = 0
    # When set true, the tool will ignore user input and expect the event handlers to be called programatically
    @demo_mode = nil
  end

  def activate
    self.class.set_status_to_message(:select)
    # See if the user preselected points to serve as the path. This is only applicable to paths that allow unassociated points (though this could be modified to associate each points with way_shapes)
    if (@offset_configuration.accept_user_selected_path_as_chosen_path? and Sketchup::active_model.selection.all? {|entity| entity.typename=='Edge'})
      points = Sketchup::Edge.to_ordered_points(Sketchup::Edge.sort(Sketchup::active_model.selection.map))
      Sketchup::active_model.selection.clear()
      # Create an input points with the preselected points considered. For tools that allow points not related to a way_point_pair, these points will become part of the users path
      @input_point = @offset_configuration.create_input_point(points)
    else
      # Create an input point to track the cursor movements and clicks
      @input_point = @offset_configuration.create_input_point()
    end
    @preselected_way_grouping = identify_selected_way_grouping()
    @input_point.or_if_nil {raise "@input_point is unacceptably nil"}
    # Create a dynamic path of the various parts of a way that a user selects. Each selection is a Way_Shape which represents a way_point_pair plus a data_pair/offset combination. The data_pair may be the same way_point_pair or an edge of the way_point_pair. The offset is the orthogonal distance from the data_pair corresponding to the input_point position.
    # The Linked_Way_Shapes instance dynamically solves the paths between the way_shapes based on the way_point_pair of each.
    # The hover_linked_way_shapes additionally includes the way_shape represented by the current position of the user's cursor.
    @hover_linked_way_shapes = @linked_way_shapes = @offset_configuration.create_dynamic_path(@input_point, @preselected_way_grouping)
  end

  # If the user has selected one entity that is associated to a way_grouping, use that way_grouping as that of the linked_way_shapes so that only one surface can be selected. This is useful when there are several surfaces present but the user only wants one to be used for a path. The function returns the first selected item that has an associated way_grouping. This allows tools like Component_Offset_Tool and other tools to accept something else selected as its target
  def identify_selected_way_grouping()
    selection().length > 0 ?
      selection.map.find {|a_selection|
        a_selection.associated_to_way_grouping?()
      }.if_not_nil {|entity| entity.associated_way_grouping(active_travel_network)} :
    nil
  end

  # Invoked when the user enters values in the VCB
  # This is the default behavior for the Way_Selector but this code could be modified to allow the offset_configuration to determine what to expect from the VCB
  # Expect a measurement indicating how far from the current wqy_shape's data_pair to offset, thus overriding the task normally accomplished by the @input_point position. The @input_point position still determines the horizontal position along the way_point_pair, just not the offset distance. Also, @input_point position still determines which data_pair to use, whether on of the edge sets or the center points (the way_point_pair points)
  # Entering text into the VCB is equivalent to clicking the mouse in that it finalizes and active way_shape. If there is no active way_shape it adjusts the previous one.
  def onUserText(text, view, demoing=false)
    return if @demo_mode && !demoing
    text.to_l.if_not_nil {|fixed_offset|
      (@hover_linked_way_shapes, hover_shape) = create_way_shape_from_input(@input_point, fixed_offset)
      # The the VCB to reflect the value typed by the user
      self.class.set_vcb_length(hover_shape, text)
      view.invalidate
      self.class.set_status_to_message(:select)
    }
  end

  # Utility function to attempt to create and finalize a way_shape based on user input
  def create_way_shape_from_input(input_point, fixed_offset_or_vector)
    (@hover_linked_way_shapes, hover_shape) = create_and_attempt_to_append_hover_shape(input_point, fixed_offset_or_vector)
    # Attempt to finalize the hover_shape and add/replace it to/in the @linked_way_shapes
    #attempt_way_shape_finalization()
    [@hover_linked_way_shapes, hover_shape]
  end

  def onMouseMove(flags, x, y, view, demoing=false)
    return if @finished || (@demo_mode && !demoing)
    self.class.pick_input_point_with_reference(view, @input_point, @reference_input_point, x, y)
    Rescape::Config.log.info("MouseMove picked point #{@input_point.position} in demo mode") if demoing
    @movement_flags = flags
    (@hover_linked_way_shapes, hover_shape) = create_and_attempt_to_append_hover_shape(@input_point)
    Rescape::Config.log.info("MouseMove attempt to add hover_shape #{hover_shape ? 'succeeded' : 'failed'} in demo mode") if demoing
    self.class.set_vcb_length(hover_shape) if hover_shape
    view.invalidate
    self.class.set_status_to_message(:select)
  end

  # Respond to the arrow keys to adjust the current or last placed way_shape
  # Depending on the orientation of the way_shape being operated on, the arrow keys either change the offset of the way_shape or the position along the way. It's equivalent to moving the mouse on an active way_shape, although this will also adjust the last placed way_shape.
  def onKeyDown(key, repeat, flags, view, demoing=false)
   return if @finished || (@demo_mode && !demoing)
   @movement_flags = flags
   feet = Geometry_Utils::FEET
   vector = {VK_LEFT=>[-feet,0,0], VK_RIGHT=>[feet,0,0], VK_DOWN=>[0,-feet,0], VK_UP=>[0,feet,0]}.find {
       |arrow, vector| arrow==key}.if_not_nil {|match|
      Geom::Vector3d.new(match[1])
   }
   return unless vector

   (@hover_linked_way_shapes, hover_shape) = create_way_shape_from_input(@input_point, vector)
   # Set the vcb length to the effective offset of the hover_shape
   self.class.set_vcb_length(@hover_linked_way_shapes.way_shapes.last)
   view.invalidate
   self.class.set_status_to_message(:select)
   end

  # Attempts to append the hover shape to linked_way_shapes based on the input_point and the optional fixed_offset distance, which modifies the actual position of input_point relative to the closest edge or way_point_pair
  # The optional fixed_offset_or_vector contains either 1) a Length which results when the user enters a value in the VCB or 2) a vector indicating a nudge direction caused by the user hitting an arrow key. It forces the hover_shape to offset the Length indicated from the closest data_pair (edge or center). This is also used to adjust the last way_shape that was finalized by clicking the mouse, in which case the way_shape will be repositioned relative to the data_pair of that way_shape.
  # Returns a pair of values: the new hover_linked_way_shapes, which may include the hover_shape, and the hover_shape itself
  def create_and_attempt_to_append_hover_shape(input_point, fixed_offset_or_vector=nil)
    # Append the hover shape to the linked_way_shapes if applicable
    self.class.set_status_to_message(:calculating)
    if (fixed_offset_or_vector && @hover_linked_way_shapes.length > 0)
      # User entered value in VCB or used the arrow keys
      $h1=@previous_way_shape = @hover_linked_way_shapes.way_shapes.last
      $h2= hover_shape = @previous_way_shape.clone_with_new_offset_position(fixed_offset_or_vector)
    else
      hover_shape = over_what(input_point, fixed_offset_or_vector)
    end
    hover_linked_way_shapes = rush_linked_way_shapes(@linked_way_shapes.way_shapes.last, hover_shape, fixed_offset_or_vector ? true : false)
    if (hover_shape)
      @way_grouping_of_record = hover_linked_way_shapes.way_grouping.is_unclassified_way_grouping? ?
          hover_shape.way_grouping :
          hover_linked_way_shapes.way_grouping
    end
    [hover_linked_way_shapes, hover_shape]
  end

  # Accepts the new hover shape if the shape it defines does not match the old one, meaning that it represents a different data_pair. If it represents the same data_pair but a different offset it need not replace the old one, because the old one will simply offset to the new position on its own based on the input_point
  # If finalize is set true, the given hover shape is finalized before being appended to the linked_way_shapes, so that it will no longer respond to the position of the input_point
  # If override_constraints is set true then the hover_shape is appended regardless of other conditions. This exists so that the user can reposition a shape by inputting into the VCB after it has been locked in place by their click.
  def rush_linked_way_shapes(previous_hover_shape, hover_shape, override_constraints=false)
    if (hover_shape and
        (override_constraints ||
        (@offset_configuration.allow_consecutive_way_shapes_per_way_point_pair? or !previous_hover_shape or !previous_hover_shape.is_match?(hover_shape)) and # The hover_shape has a different way_point_pair than the last, or multiple per way_point_pair are permitted
        @linked_way_shapes.can_append?(hover_shape))) # The hover_shape is valid
      # Call the pre add hook for tools that need to take action before a way_shape is appended
      @offset_configuration.pre_way_shape_appended(@input_point, hover_shape)
      # Append the way_shape. Don't allow a way_shape replacement if there is a lock in place, meaning that the previous way_shape can't be replaced by a way_shape that is nearly identical to it. If there is no lock, it means the user has left the current way_point_pair. If they come back to the previous way_shape afterward, it is assumed they want to replace it.
      @linked_way_shapes.append(
        hover_shape,
        !override_constraints && circumstantial_way_shape_lock!(previous_hover_shape, hover_shape)
      )
    else
      # If the hover_shape cannot be added return the unaltered linked_way_shapes
      @linked_way_shapes
    end
  end

  # Determines if the Way_Shape defined by the user's cursor is locked by a temporary circumstance, meaning that until a condition is met a new way_shape will be allowed to replace the previous. Locking happens after a user clicks a shape until the user leaves the current way_point_pair. This avoids the way_shape selected with a click immediately changing. Once the user leaves the way_point_pair area the shape is unlocked so that it will move if the user changes their mind and returns to that way_point_pair
  def circumstantial_way_shape_lock!(previous_hover_shape, hover_shape)
     # If the user just clicked a way_shape don't move it until we move outside the way_point_pair's domain
    if (@lock_way_shape and previous_hover_shape and !previous_hover_shape.is_way_point_pair_match?(hover_shape))
      @lock_way_shape = false
    else
    end
    @lock_way_shape
  end

  # Determines if the Way_Shape defined by the user's cursor is locked to the current edge or way_point_pair (center pair), meaning that the same data_pair will be used for the way_shape until the user moves to another way_point_pair region. Locking is activated if the Shift key is depressed, meaning the user wishes to lock the inference, just like for other Sketchup tools. If command is not pressed then the offset distance will also be locked.This allows the user to potentially drag the way shape off of the way if the cursor maintains an orthogonal vector to the data_pair, and if the tool permits it.
  # This allows the user to potentially drag the way shape off of the way if the cursor maintains an orthogonal vector to the data_pair, and if the tool permits it.
  def way_shape_data_pair_offset_locked?
    shift_down? && !command_down? && !control_down?
  end
  # Like way_shape_data_pair_offset_locked?, but the offset distance can change (the edge or way_point_pair is locked)
  def way_shape_data_pair_locked?
    command_shift_down? && !control_down?
  end
  # If allowed by the tool, tells the selector to ignore way_point_pair and edges and simply draw the path from the last point directly to the users cursor. This allows the user to ignore the way pathing when desired.
  def force_unassociated_point?
    command_not_shift_down?
  end

  # The user wants to add the current way_shape to the linked_way_shapes
  def onLButtonUp(flags, x, y, view, demoing=false)
    return if @finished || (@demo_mode && !demoing)
    @movement_flags = flags
    Rescape::Config.log.info("LButtonUp in demo mode") if demoing
    self.class.pick_input_point_with_reference(view, @input_point, @reference_input_point, x, y)
    # Store the current position in a reference InputPoint. This is used for subsequent picks in onMouseMove to ensure that the calculated point is in reference to the last clicked point, so that it doesn't do strange things like interpret a different z position.
    @reference_input_point = Sketchup::InputPoint.new
    @reference_input_point.pick view, x, y, @input_point.input_point
    Rescape::Config.log.info("LButtonUp picked input point position #{@input_point.position.inspect} in demo mode") if demoing

    # Finalize the current way_shape and added it to the @linked_way_shapes
    if (@hover_linked_way_shapes != @linked_way_shapes)
      Rescape::Config.log.info("LButtonUp attempting way_shape finalization in demo mode") if demoing
      attempt_way_shape_finalization()
    elsif (@offset_configuration.allow_unassociated_points?(force_unassociated_point?))
      Rescape::Config.log.info("LButtonUp handling unassociated point in demo mode") if demoing
      # If the tool allows points in between way_shape selections, handle them here
      @offset_configuration.handle_unassociated_points(@input_point)
    else
      Rescape::Config.log.info("LButtonUp no new way_shape was added in demo mode") if demoing
    end
    view.invalidate
    self.class.set_status_to_message(:select)
  end

  # Finalize the user's current way_shape by copying it to the "permanent" set of way_shapes in linked_way_shapes.
  # The shape will be finalized so that it's position can no longer change with cursor movement, then appended to or replace the last linked_way_shapes shape.
  def attempt_way_shape_finalization
      @offset_configuration.pre_way_shape_appended(@input_point, @hover_linked_way_shapes.way_shapes.last)
      @linked_way_shapes = @linked_way_shapes.append(@hover_linked_way_shapes.way_shapes.last.finalize())
      Rescape::Config.log.info("Appended #{@hover_linked_way_shapes.way_shapes.last.inspect} to linked_way_shapes. Length is now #{@linked_way_shapes.way_shapes.length}")
      # Alert the finisher in case it needs to reset a complex @input_point
      @offset_configuration.post_way_shape_finalized(@input_point, @linked_way_shapes.way_shapes.last)

      @hover_linked_way_shapes = @linked_way_shapes
      @lock_way_shape=true
  end

  # The user wants to finish selecting and finalize the chosen path
  def onLButtonDoubleClick(flags, x, y, view, demoing=false)
    return if @finished || (@demo_mode && !demoing)
    @finished=true
    @movement_flags = flags
    # Simulate a left button click if demoing, since that's what happens when you double click in real life
    onLButtonUp(flags, x, y, view, demoing) if demoing

    # Delete the single click result that is registered by the double click
    @offset_configuration.handle_double_click(@input_point)

    # Create the offset_finisher based on the linked_way_shapes
    offset_finisher = @offset_configuration.offset_finisher_class.new(@offset_configuration, @linked_way_shapes, self, @movement_flags)
    if (@offset_configuration.adjust_path_after_creation? && offset_finisher.needs_path_adjustment?)
      self.push_tool(Path_Adjustor.new(offset_finisher))
    else
      # Use the way_selector's generic finalize message
      self.class.set_status_to_message(:finalize)
      Sketchup::active_model.start_operation(self.class.name, true)
      begin
        offset_finisher.finalize_offset()
        Sketchup::active_model.commit_operation()
        offset_finisher.finish()
      rescue
        Sketchup::active_model.abort_operation()
        raise
      end
    end
  end

  # Abort the current operation if one exists
  def deactivate(view)
    Sketchup::active_model.abort_operation()
  end

  def draw view
    start_draw_error_data(view)
    if (@hover_linked_way_shapes.way_shapes.length > 0)
      hover_shape = @hover_linked_way_shapes.way_shapes.last

      # Create the offset_finisher_class which handles drawing the offset of the current path drawn by the user
      offset_finisher = @offset_configuration.offset_finisher_class.new(
          @offset_configuration, @hover_linked_way_shapes, self, @movement_flags)

      # If a hover shape is defined
      # Draw the data_pair of the hover_shape so the user knows the offset reference
      offset_finisher.draw_data_pair(view, hover_shape.data_pair, way_shape_data_pair_locked?, way_shape_data_pair_offset_locked?)
      # Draw the orthogonal from the data_pair the user's cursor
      offset_finisher.draw_path_to_point(view, hover_shape.pair_to_point_data, way_shape_data_pair_locked?, way_shape_data_pair_offset_locked?)
      # If a previous way_shape exists and way_shape_data_pair_offset_locked? is true, draw the offset of the previous way_shape to indicate that the current way_shape offset is locked to the previous
      if (@hover_linked_way_shapes.length > 1 && way_shape_data_pair_offset_locked?)
        offset_finisher.draw_path_to_point(view, @hover_linked_way_shapes.way_shapes[-2].pair_to_point_data, way_shape_data_pair_locked?, way_shape_data_pair_offset_locked?)
      end

      # Draw the linked_way_shapes
      offset_finisher.draw(view, @movement_flags)

      # Proximity detection test tools. This enables tests to see the reason why things are being selected
      draw_proximity_data(view, hover_shape)

    elsif (@offset_configuration.allow_unassociated_points?(force_unassociated_point?))
      # For tools that allow points not associated with way_shapes, we need to draw even if there are no way_shapes defined yet.
      offset_finisher = @offset_configuration.offset_finisher_class.new(
          @offset_configuration,
          @hover_linked_way_shapes,
          self,
          @movement_flags)
      offset_finisher.draw(view, @movement_flags)
    end
    end_draw_error_data(view)
  end

  # Used to draw any custom defined error data for debugging
  def start_draw_error_data(view)
    view.drawing_color = 'red'
    view.draw_polyline($error_data_pairs.flat_map {|x| x.points}) if $error_data_pairs
    view.draw_points($error_points, 5, 5, 'pink') if $error_points
  end

  # Clears error data if the draw() method succeeds to the very end
  def end_draw_error_data(view)
    $error_data_pairs = nil
    $error_points = nil
  end


  # If the offset_configuration's allow_way_shape_offset? is true, this enables the VCB so that the user can enter a precise offset position.
  def enableVCB?
    @offset_configuration.allow_way_shape_offset?
  end
end
