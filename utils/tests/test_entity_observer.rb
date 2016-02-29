#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Test_Entity_Observer < Sketchup::EntityObserver

  def initialize
    @travel_network = Rescape::Setup.travel_network
    @way_grouping = @travel_network.way_grouping_of_way_class(Street)
    @component_instance = @way_grouping.surface_component.group
    entity_observers = add_observers(@component_instance)
  end
end
