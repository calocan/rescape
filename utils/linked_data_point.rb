# A Data_Point that knows about the Data_Pairs which it represents as well as the other Data_Point of the main Data_Pair it represents
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/data_point'

module Linked_Data_Point
  include Data_Point

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Data_Point)
  end

  # Some Data_Points like, Sketcup::Vertex, knows about its Data_Pairs. Others do not
  def data_pairs
    raise "Must be implemented by mixer"
  end
end