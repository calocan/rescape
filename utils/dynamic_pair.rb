# An interface that describes a pair of points that are potentially influenced by another point, such as an Sketcup::InputPoint that dynamically responds to a user's cursor.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Dynamic_Pair

  # The two points of the pair. The points must be Geom::Points or implement the Data_Point interface so that they can be treated Geom::Points. One or both of these points could be dynamic as well if a pair's position was being decided or edited.
  def points
    raise "Mixer must implement"
  end

  # The point that may be dynamic and treated relatives to the points. It could be on the line of the points or offset from the line segment between the points to control the parallel offset of the pair, for instance. It could also be irrelevant and simply default to a static point in between the two points.
  def point
    raise "Mixer must implement"
  end
end