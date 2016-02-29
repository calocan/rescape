require 'utils/data_point'

# The simplist implementation of the Data_Point module.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Simple_Data_Point
  include Data_Point

  attr_reader :point
  def initialize(point)
    @point = point
  end

  # Doesn't need to clone, just creates a new instance
  def clone_with_new_point(point)
    self.class.new(point)
  end
end