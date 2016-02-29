require 'utils/vector3d_substitute' if !Rescape::Config.in_sketchup?
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Geom
  class Vector3d

    def normalized?
      self == self.normalize
    end

    # Sets a cloned vector length and returns the clone
    def clone_with_length(length)
      clone = self.clone
      clone.length = length
      clone
    end
    # Sets a clone vector length to the length plus the given length, which may be negative
    def clone_with_additional_length(additional_length)
      clone = self.clone
      clone.length += additional_length
      clone
    end
    # Hashes it's vector by it's properties since hash specific to the instance
    def hash_vector
      self.to_a.hash
    end

  end
end