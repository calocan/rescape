require 'wayness/way_dynamic_path'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Simple_Way_Dynamic_Path < Simple_Dynamic_Path
  include Way_Dynamic_Path

  def initialize(path_to_point_data, way_grouping)
    super(path_to_point_data)
    @way_grouping = way_grouping
  end

  def way_grouping
    @way_grouping
  end
end
