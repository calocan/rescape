require 'utils/array_module'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Geom
  class Point3d < Array
    include Array_Module
    attr_reader :x, :y, :z
    def initialize(x,y,z)
      @x = x
      @y = y
      @z = z
      super([x,y,z])
    end

    def vector_to(point)
      Geom::Vector3d.new(point.x-x, point.y-y, point.z-z)
    end

    def distance(point)
      Math.sqrt((point.x-self.x)**2 + (point.y-self.y)**2 ** (point.z-self.z)**2)
    end

    def self.linear_combination(f1, point1, f2, point2)
      vector = point1.vector_to(point2)
      vector.length = vector.length*f1
      Geom::Point3d.new(*point1.dual_map(vector.to_a) {|c, cv|
        c+cv})
    end

    def inspect()
      "#{self.class} of coordinates #{[x,y,z].inspect}"
    end
  end
end