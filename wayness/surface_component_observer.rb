#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


=begin
class Surface_Component_Observer < Sketchup::EntityObserver

  def initialize(component)
    @surface_component = component
  end

  def onChangeEntity(entity)

   # @surface_component.way_grouping.entity_map.associate_edges_to_way_point_pair([entity]) if entity.typename=='Edge'
  end

  def onEraseEntity(entity)
    @surface_component.invalidate
  end

  def remove_observers()
    @surface_component.entities.map {|entity| entity.remove_observer(self)}
  end
end
=end