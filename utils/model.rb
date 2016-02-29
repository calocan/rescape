require 'utils/component_behavior'
require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Sketchup
  class Model
    include Component_Behavior
    include Basic_Utils

    # The name of a special Rescape component that stores all the needed materials
    MATERIALS_COMPONENT = 'materials'

    def deserialize(serialized_class, dictionary, key)
      Marshal.load(self.get_attribute(dictionary, key))
    end

    def serialize(instance, dictionary, key)
      marshalled = Marshal.dump(instance)
      self.set_attribute(dictionary, key, marshalled)
      marshalled
    end

    # Gets the unique_id of the model, and sets it if it doesn't exist
    def unique_id
      self.set_attribute('main', 'unique_id', self.hash) unless self.get_attribute('main', 'unique_id')
      self.get_attribute('main', 'unique_id')
    end

    def dumpr
      return true
    end

    # Loads the materials stored in the special component materials.skp
    def load_materials
      definitions=self.definitions
      return if definitions.find {|definition| definition.name.match(MATERIALS_COMPONENT)}
      reload_materials()
    end
    def reload_materials()
      definitions=self.definitions
      self.start_operation("Import Materials")
      # The unless prevents materials.skp from try to load itself if it is loaded into Sketchup
      definitions.load(self.class.get_resource_file('components', "#{MATERIALS_COMPONENT}.skp")) unless self.name==MATERIALS_COMPONENT
      self.commit_operation
    end
  end
end