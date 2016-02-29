# The most basic behavior of a Way_Point_Pair that is
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Way_Point_Pair_Basic_Behavior
  def way
    raise "Must be implemented by mixer"
  end

  # This is a reference the underlying way_point_pair for classes that reference one, like Way_Shape. Way_Point_Pair responds to this by returning itself
  def way_point_pair(way_grouping=nil)
    raise "Must be implemented by mixer"
  end
end