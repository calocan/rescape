require 'tools/offset_tools/offset_finisher_module'
require 'tools/offset_tools/hybrid_path_properties'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Way_Based_Path_Tool
  include Offset_Finisher_Module
  include Offset_Configuration_Module

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Offset_Finisher_Module)
    base.extend(Offset_Configuration_Module)
    base.extend(Class_Methods)
  end

  # Way based paths need at least two points to be valid
  def valid_path_length()
    2
  end

  module Class_Methods
  end
end