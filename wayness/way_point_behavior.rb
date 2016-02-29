require 'utils/data_point'
# Exposes the underlying Way_Point of implementers
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Way_Point_Behavior
  include Data_Point

  def way_point
    raise "Mixer must implement"
  end

  def point
    way_point.point
  end

  def clone_with_new_point(point)
    way_point.clone_with_new_point(point)
  end
end