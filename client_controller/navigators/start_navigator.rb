require 'client_controller/navigator'
require 'client_controller/tutorial_state'
require 'client_controller/tutorial_state_step'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Start_Navigator < Navigator
  def initialize_states
    [Tutorial_State.new(lambda{ greeting() }, 'greeting')]
  end

  # Displays the greeting message and deletes all the other entities of other layers, except the maps, since we can't download those automatically
  def greeting
    # Delete all the entities in the tutorial except the maps and entities in the non-default layer
    keep_layers = self.tutorial.get_layers_of_page_config(self.page_config)
    tutorial_model.entities.erase_entities(tutorial_model.entities.reject {|entity|
      (entity.typename=='Group' && entity.is_map?) || keep_layers.member?(entity.layer)
    })
    # Make sure all the components in the special stored_components layer are invisible
    tutorial_model.entities.each {|entity| entity.visible = false if entity.layer.name == :stored_components.to_s}
  end
end