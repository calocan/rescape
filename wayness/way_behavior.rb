require 'utils/array_module'
require 'tools/offset_tools/offset_configuration_module'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

# A module used by all classes that have an underlying Way, including Way itself
# Users must implement a way method that returns the underlying way. All other methods
# may be overridden from the default behavior
module Way_Behavior
  include Enumerable
  include Array_Module

  def way
    raise "mixin way method reached, you must override this method"
  end

  def points
    way.points
  end

  def attributes
    way.attributes
  end

  def reverse_way
    way.reverse_way
  end

  def id
    way.id
  end

  def each
    points.each {|point| yield point}
  end

  def [](index)
    points[index]
  end

  def length
    points.length
  end

  def +(other)
    self.points + other.points 
  end

  def origin
    points[0]
  end

  # The type of way as defined by Open Street Map
  def way_type
    surface_key = way.class.surface_class.surface_keys().find {|key| attributes[key] }
    attributes[surface_key]
  end

  # A description of the way's direction to distinguish it from its reverse version
  def direction
    self.way_point_pairs.map {|way_point_pair| way_point_pair.cardinal_direction}.uniq_consecutive.join('->')
  end

  # If no width attribute is specified the default is used for the Way class
  def width
    (attributes['width'] != nil and attributes['width'] != 0) ? attributes['width'].to_f : default_width()
  end

  def z_position
    # Get the layer attribute that indicates the relative vertical position of the way
    layer = (attributes['layer'] != nil and attributes['layer'] != 0) ? attributes['layer'].to_f : 0
    # Multiply layer indices >= 0 by layer+1, since 0 is the default value and should thus map to 1, the identity multiplier
    layer_multiplier = layer*self.class.default_z_layer_multiplier()
    layer_multiplier+self.class.default_z_position()
  end

  def name
    attributes['name'] || Way::UNIDENTIFIED_WAY
  end

  def default_width
    raise "default_width is an abstract method" if self.class==Way
    way.default_width
  end

  def clone_with_new_points(points, name=nil)
    raise "clone_with_new_points is an abstract method" if self.class==Way
    way.internal_clone_with_new_points(points, name)
  end

  # Returns the ordered points of the way as pairs
  def get_point_pairs
    points.map_with_subsequent { |point1, point2| [point1,point2]}
  end

  def is_loop?
    self.is_loop? {|point| point.hash_point}
  end

  # Creates way_points from each point of the way and then combines them into pairs. Pairs are fundamental structures since they mimic a Sketchup Edge
  def way_point_pairs
    points.map_with_subsequent {|point1, point2| make_way_point_pair(point1, point2)}
  end


  # Creates a limited set of way_point_pairs based on the given way_points, which must correspond to points of this way
  # This results in pairs that may not be adjacent in the way, but they are useful for omitting undesired points
  def make_limited_way_point_pairs(allowed_way_points)
    allowed_way_points.map_with_subsequent {|way_point1, way_point2| make_way_point_pair(way_point1.point, way_point2.point)}
  end

  def as_way_points()
    points.map {|point| Way_Point.new(point, way)}
  end

  def make_way_point_pair(point1, point2)
    Way_Point_Pair.new(
        Way_Point.new(point1, way),
        Way_Point.new(point2, way))
  end

  # Gets the total length of the way by summing the distance between points
  def total_length
    way_point_pairs.inject(0) {|sum, way_point_pair| sum+way_point_pair.vector.length}
  end

  # Get the value of an attribute that may be overridden
  def attribute_value(attribute_key)
    way.methods.member?(attribute_key) ? way.method(attribute_key).call : attributes[attribute_key]
  end

  def index(point)
    way.map{|p| p.hash_point}.index(point.hash_point)
  end

  # Serializable attributes to assign to Sketchup entities, namely edges, that associate the edge with the Way
  def attributes_for_entity
    Hash[*['class', way.class.name]+attributes.map{|key,value| serialize_attribute(key,value)}.shallow_flatten]
  end
  # Serialize attributes if needed
  def serialize_attribute(key, value)
    if (key=="node_values")
      [key, value.map {|node_value| node_value.id}]
    else
      [key,value]
    end
  end

  # Way equality is based on the ordered points
  # Classes mixing in Way_Behavior can override the points method to return other points without
  # effecting the hash nor therefore equality.
  def hash
    way.map {|point| point.hash_point}.hash
  end

  # By default any class mixing in Way_Behavior defines it equality based on the underlying ways
  def ==(other)
    other ? way.hash==other.way.hash : false
  end

  def inspect
    "%s named %s (%s) of %s points with hash %s" % [way.class, way.name, way.direction, way.length, way.hash]
  end

  def draw_center_line(parent=Sketchup.active_model)
    parent.entities.add_curve points
    #vector = self.first.vector_to(self.last)
    #Sketchup.active_model.entities.add_text(way.inspect, way.middle_point)
  end

  # Returns the point in the middle of the first and last point of the way
  def middle_point()
    vector = way.first.vector_to(way.last)
    way.first.offset(vector, vector.length/2)
  end

  # Returns the middle point of the path made by the way
  def true_middle_point
    Way_Point_Pair.divide(way_point_pairs(), 1)[1]
  end

  # Divide the way into new ways of the same class by the given intersection_points, which must all lie along the way's path
  def divide_at_points(intersection_points)
    Way_Point_Pair.divide_into_partials_at_points(
                                                      self.way_point_pairs,
                                                      intersection_points,
                                                      true).map {|way_point_pairs|
      self.clone_with_new_points(Way_Point_Pair.to_unique_points(way_point_pairs))
    }
  end

  def self.included(base)
    self.on_extend_or_include(base)
  end
  
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Class_Methods)
  end

  module Class_Methods

    # The surface type to which this subclass of Way class pertains
    def surface_class
      raise "surface_class is an abstract method" if self.class==Way
      self.surface_class
    end

    # Indicates in inches the default z position of the way, or the position if the way 'layer' attribute is 0 or undefined
    def default_z_position
      raise "default_z_position is an abstract method" if self.class==Way
      # Default to the Way class's surface class definition if this method isn't overridden by the way class
      self.surface_class.default_z_position
    end

    # Indicates the multiplier to apply to the way's z position if the 'layer' attribute is not 0. Thus layer=1 means the z position would be default_z_position + 1*default_z_layer_multiplier
    def default_z_layer_multiplier
      raise "default_z_layer_mulitplier is an abstract method" if self.class==Way
      # Default to the Way class's surface class definition if this method isn't overridden by the way class
      self.surface_class.default_z_layer_multiplier
    end

    # The way_type identifiers contained by this subclass of Way
    def way_types
      raise "way_types is an abstract method" if self.class==Way
      self.way_types
    end

    # The way_color with which to draw way surfaces for this subclass of Way
    # TODO rename fill_color
    def way_color
      raise "way_color is an abstract method" if self.class==Way
      self.way_color
    end

    # Gets the total length of all the given ways
    def composite_length(ways)
      ways.inject(0) {|sum, way| sum+way.total_length}
    end

    # Determines whether or not Way_Grouping instances that use this way_class save their data to the model or not. Only temporary ways, like Lane will not be stored
    def save_to_model?
      true
    end
  end
end