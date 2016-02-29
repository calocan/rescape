# A Lane is represents any kind of generic path or lane drawn on a way surface. Examples are a tracks on a rail surface,
# a bike lane on the street, a bus lane, streetcar lane, etc.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Lane < Way

  def default_width
    raise "Lane has no default width!"
  end

  # Unlike normal ways, Lane points should already have a z_position transform, so do nothing here
  def z_position_constraint(points)
    points
  end

  def self.surface_type

  end

  def self.way_types
    []
  end

  def self.way_color
    "green"
  end

  def self.save_to_model?
    false
  end
end