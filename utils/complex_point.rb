require 'utils/data_point'

# An interface describing complex behavior centered around a point
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Complex_Point
  include Data_Point

  # The static version of the point, meaning that know dynamic position changing can occur
  def freeze
    raise "Mixer must implement"
  end

  # Indicates if the data_point is static or fluid, the latter meaning that its position can be updated, namely by user input.
  # True by default
  def frozen?
    true
  end

  # Clones the complex_point in case the original needs to be frozen but the dynamic behavior is needed elsewhere
  def clone
    raise "Mixer must implement"
  end

  # Always returns a type Sketchup::InputPoint no matter how it is wrapped
  def underlying_input_point
    raise "Mixer must implement"
  end
end