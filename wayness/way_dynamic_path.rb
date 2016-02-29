require "utils/dynamic_path"
require 'utils/simple_dynamic_path'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Way_Dynamic_Path
  include Dynamic_Path

  def way_grouping
    raise "Mixer must implement"
  end
end
