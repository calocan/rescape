require 'utils/complex_point'
require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Sketchup

  class InputPoint
    include Complex_Point
    include Basic_Utils

    def point
      self.position
    end

    # The input_point's position unconstrained for InputPoint wrapper's who normally constrain point to a certain z
    def unconstrained_point
      self.position
    end

    # Returns the static version of this point, here the position
    def freeze
      self.position
    end

    # Indicates that all instances of this class have a dynamic position
    def frozen?
      false
    end

    # Compliance with Complex_Point interface.
    def underlying_input_point
      self
    end

    # Compliance with InputPoint wrappers for which this method must be called to expose the underlying InputPoint
    def input_point
      self
    end

    # Wrap the original pick method so that we can store the last position
    def wrapped_pick(view, x, y, reference_input_point=nil)
      previous_point = self.point
      changed = pick(view, x, y, reference_input_point)
      # only change the @previous_point if a new position was chosen
      @previous_point = previous_point if changed
      changed
    end

    # Returns the vector from the previous position to indicate the direction of the mouse
    def vector_from_previous_point
      @previous_point.vector_to(self.point)
    end

    # Change the InputPoint position
    def clone_with_new_point(point)
      Input_Point_Wrapper.new(self.class.new(), point.position, false)
=begin
      # This method isn't quite accurate enough
      input_point = self.class.new
      view = Sketchup::active_model.active_view
      screen_point = view.screen_coords(point)
      self.class.pick_input_point_with_reference(view, input_point, input_point, screen_point.x, screen_point.y)
      input_point
=end
    end

    # Makes a new InputPoint and puts it in a wrapper with its current position to simulate cloning
    def clone()
      Input_Point_Wrapper.new(self.class.new(), self.position, false)
    end
  end

  # Wraps an input point in order to record a previous position. This is used to simulate cloning an InputPoint since the position can't be set precisely on a new InputPoint.
  class Input_Point_Wrapper
    include Data_Point

    # Intializes the instance with an input_point and position representing the position of another InputPoint upon which this input_point is based. The optional boolean fixed determines whether the dynamic position of the given input_point is ever used. If true, the given position is always returned by the position method. If false, the given position is only returned until input_point.position is set to something other than the original input_point position
    def initialize(input_point, position, fixed=true)
      @input_point = input_point
      @original_input_point_position = @input_point.position
      @position = position
      @fixed = fixed
    end

    # Overrides the input_point's position. Note that Data_Point already delegates calls to position to point
    def point
      (@fixed or @input_point.position == @original_input_point_position) ?
        @position :
        @input_point.position
    end

    # Returns the static version of this point
    def freeze
      point
    end

    def underlying_input_point
      @input_point
    end

    def clone_with_new_point(point)
      self.class.new(@input_point, point.position, @fixed)
    end

    def clone
      self.class.new(@input_point, @position, @fixed)
    end

    # Delegate any other method to the underlying point
    def method_missing(m, *args, &block)
      @input_point.send m, *args, &block
    end
  end
end