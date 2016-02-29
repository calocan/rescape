# A module describing a path created by a user that may have dynamic points, meaning points that update according to the user's input.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Dynamic_Path
  # A collection of Dynamic_Pair instances in the order selected by the user
  def dynamic_pairs
    raise "Mixer must implement"
  end

  # A collection of Data_Pair instances based on the dynamic_pairs plus any pairs in between the dynamic_pairs that all make up a complete path
  def data_pairs
    raise "Mixer must implement"
  end

  # The unique set of points based on the points of the data_pairs
  def all_points
    raise "Mixer must implement"
  end

  # A Sketchup::InputPoint that is responding to user input, or a normal Geom::Point somewhere along the path if no more dynamic input is to be considered. Whatever is used must implement Data_Point's interface
  def data_point
    raise "Mixer must implement"
  end
end