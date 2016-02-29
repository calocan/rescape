require 'utils/array_module'
require 'matrix'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Geom
  class Vector3d
    def initialize(x,y,z)
      @vector = Vector.elements([x,y,z])
    end
    def x
      @vector[0]
    end
    def y
      @vector[1]
    end
    def z
      @vector[2]
    end
    def length
      @vector.r
    end
    def length=(value)
      if (value==0)
        @vector = Vector.elements([0,0,0])
      else
        scale = value/length
        @vector = @vector*scale
      end
    end
    def normalize
      @vector*(1/length)
    end
    def normalize!
      @vector = normalize
    end
    def to_a
      [x,y,z]
    end
  end
end