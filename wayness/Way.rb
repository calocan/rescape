require "wayness/way_behavior"
# A way is simply a travel path of at minimum two points on the map. It may represent a full street or part of
# a street in between two intersections. Each intermediate point is normally a curve in the path, but may also
# be an intermediate point on a straight line to represent an intersection or nothing at all. Ways are normally
# created by downloading data from an external data source but may also be hand drawn. Ways are associated with
# a surface_type which is its general category (e.g. ground surface, rail, water) and also
# a more specific way type that indicates a distinct use (e.g. highway, bridle path, or monorail)
#
# The id is the unique identifier of the Way. hash is always based on the points of Way.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Way
  include Way_Behavior

  attr_reader :points, :attributes, :reverse_way, :id
  # The name of a way that doesn't not have a name in the imported data
  UNIDENTIFIED_WAY = 'unidentified way'
  # The Layer name to which way Text objects are assigned.
  WAY_TEXT_LAYER = 'way_text'

  def initialize(points, attributes={}, reverse=nil, id=nil)
      points.map_with_subsequent {|point1, point2| raise "Identical ordered points: %s" % [points.inspect] if point1.hash_point==point2.hash_point}
      if (!points.all? {|point| point.is_a?(Geom::Point3d)})
          raise "Points are not all points! Points: %s" % [points.map {|point| point.inspect}]
      end
      @attributes = attributes
      @points = z_position_constraint(points)
      @reverse_way = reverse || self.class.new(points.reverse, attributes, self)
      # It is necessary to set an id instead of relying on the hash since Sketchup hashes arrays differently than ruby in an external process, so way.hash can not be used to identify a way outside of Sketchup
      @id = id || self.hash
  end

  # For marshaling only
  def update_reverse_way(way)
    @reverse_way = way
  end

  # Constrains the point to a certain height
  def z_position_constraint(points)
    points.map {|point| point.constrain_z(way.z_position())}
  end

  # Conforms with the Way_Behavior interface, returning itself
  def way
    self
  end

  # Called from Way_Behavior
  def internal_clone_with_new_points(points, name=nil)
    new_attributes = attributes.clone
    if (name)
      new_attributes[:name] = name
    end
    self.class.new(points.to_a, new_attributes)
  end

  def marshal_dump
    {:id=>@id, :attributes=>@attributes, :points=>@points}
  end

  def marshal_load(hash)
    id = hash[:id]
    points = hash[:points]
    attributes = hash[:attributes]
    initialize(points, attributes, nil, id)
  end

end
