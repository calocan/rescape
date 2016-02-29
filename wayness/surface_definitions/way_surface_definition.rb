# Defines the different type of way surfaces, such as roads/paths, rail, waterway, aerial
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'utils/Geometry_Utils'

class Way_Surface_Definition

  METER_TO_INCH = 39.3700787
  def self.surface_keys
    raise "abstract"
  end
  DEFAULT_Z_POSITION = 1*Geometry_Utils::FEET
  DEFAULT_Z_LAYER_MULTIPLIER = 15*Geometry_Utils::FEET
  def self.default_z_position
    DEFAULT_Z_POSITION
  end
  def self.default_z_layer_multiplier
    DEFAULT_Z_LAYER_MULTIPLIER
  end

  # Used as the standard height for offset components like cycle tracks, and streetcar tracks so that they generally have the same height off the way surface
  STANDARD_COMPONENT_HEIGHT = Geometry_Utils::FEET*1
  def self.standard_component_height
    STANDARD_COMPONENT_HEIGHT
  end

  def self.supports_way_type(tags)
    get_way_type(tags) != nil
  end
  
  def self.get_way_type(tags)
    way_key = surface_keys().find {|key| tags[key] }
    way_classes().find {|way_class| way_class.way_types.member? tags[way_key] }
  end
  # Based on the osm_way tags hash, find the way class
  def self.get_way_class(tags)
    # The way key is the attribute value of the surface key attribute (e.g. highway=secondary or rail=funicular)
    way_key = surface_keys().map {|key| tags[key] }.compact.first
    way_class = way_classes().find {|way_class| way_class.way_types.member? way_key }
    raise "Could not find way class for surface class: %s and way class key %s" % [self.inspect, way_key] unless (way_class)
    way_class
  end

  def self.create_way(osm_way, points)
    attributes = osm_way.tags.map_values_to_new_hash {|key,value| key=='width' ? value.to_f*METER_TO_INCH : value }
    way_class = get_way_class(osm_way.tags)
    way_class.new(points,attributes)
  end

end