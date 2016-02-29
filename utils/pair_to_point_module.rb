# Represents the general relationship between a Data_Pair and a point, where normally the point projects orthogonally onto the pair.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Pair_To_Point_Module
  # The Data_Pair
  def pair
    raise "#{self.class} mult implement"
  end
  # The point, Data_Point, Complex_Point or whatever is needed, but anything that represents a physical point that normally projects orthogonally to the pair, or even lies on the pair
  def point
    raise "#{self.class} mult implement"
  end
  # The projection of the point to the pair, or the project of the point to the line of the pair if the point doesn't project orthogonally to the pair
  def point_on_pair
    raise "#{self.class} mult implement"
  end
end