require 'tools/tool_utils'
require 'tools/proximity_data_utils'

# A tool that adjusts a path created by the user. It is used after Way_Selector to offset the path selected or created in Way_Selector
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Path_Adjustor
  include Tool_Utils
  include Proximity_Data_Utils

  attr_reader :reference_input_point, :movement_flags, :offset_finisher
  def initialize(offset_finisher)
    $adjustor = self
    @offset_finisher = offset_finisher
    # We always expect the offset finisher's point to be a Sketchup::InputPoint or a wrapper of it. It needs to be dynamic so that the user can adjust the path width
    @complex_point = offset_finisher.point
    @reference_input_point = nil
    @movement_flags = nil
    @demo_mode = nil
    # Track modifier keys
    @movement_flags = movement_flags
    # Pop back to the Offset_Finisher
    @pop_level = 1
    tool_init()
  end

  def activate
    @offset_finisher.offset_configuration.set_status_to_message(:adjust)
  end

  def onUserText(text, view, demoing=false)
    return if @demo_mode && !demoing
    value = @offset_finisher.handle_path_adjust_vcb_value(view, text, self)
    @offset_finisher.class.set_vcb_status(value.to_s, :vcb_path_adjustor_label)
  end

  def onMouseMove(flags, x, y, view, demoing=false)
    return if @demo_mode && !demoing
    @offset_finisher.handle_set_path_adjust_vcb_value()
    @movement_flags = flags
    # Initialize the reference_input_point to the incoming value of the @complex_point
    unless @reference_input_point
      @reference_input_point = Sketchup::InputPoint.new
      @reference_input_point.pick view, x, y, @complex_point.underlying_input_point
      # Sketchup sometimes interprets a vertical line from the path--reject such interpretations
      return if @reference_input_point.position.z != @complex_point.underlying_input_point.position.z
    end

    self.class.pick_input_point_with_reference(view, @complex_point, @reference_input_point, x, y)
    view.invalidate
  end

  # Finalize the offset of the path
  def onLButtonUp(flags, x, y, view, demoing=false)
    return if @demo_mode && !demoing
    @movement_flags = flags
    self.class.pick_input_point_with_reference(view, @complex_point, @reference_input_point, x, y)
    finalize_path_adjustment()
  end

  def finalize_path_adjustment
    #Sketchup::active_model.start_operation(self.class.name, true)
    begin
      Rescape::Config.log.info("Committing path adjustment")
      @offset_finisher.finalize_offset()
      #Sketchup::active_model.commit_operation()
      Rescape::Config.log.info("Path adjustment committed")
    rescue
      #Sketchup::active_model.abort_operation()
      Rescape::Config.log.error("Path adjustment aborted")
      raise
    end
    Rescape::Config.log.info("Finishing path adjustment tool")
    finish()
  end

  # Abort the current operation if one exists
  def deactivate(view)
    Sketchup::active_model.abort_operation()
  end

  def draw(view)
    # Draw the data_pair of the hover_shape so the user knows the offset reference
    @offset_finisher.draw_data_pair(view, @offset_finisher.pair_of_point_on_path, false)
    # Draw the orthogonal from the data_pair the user's cursor
    @offset_finisher.draw_path_to_point(view, @offset_finisher.path_to_point_data, false)
    # Draw the specific behavior of this offset_finisher
    @offset_finisher.draw_path_adjustment(view, @movement_flags)
  end

end