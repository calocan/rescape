require 'wayness/way_grouping'
require 'utils/entity_associating'
require 'utils/component_instance_entity'

# A module for ComponentInstance, ComponentDefinition, and Group to check for custom properties
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Component_Behavior
  include Entity_Associating

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Entity_Associating)
  end

  # Determines if this component is a satellite image
  def is_map?
    self.name == "Google Earth Snapshot"
  end
  # Determines if this component is was created by offsetting a way
  # TODO this is just a temporary way to identify offset components
  def is_way_offset_component?
    self.get_attribute('offset_component', 'offset_tool_class') != nil
  end
  # Determines if this component belongs to a Surface_Component
  def is_surface_component_instance?
    self.attribute_dictionary(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY) != nil
  end


  # Retrieves the Way_Grouping.way_class stored with this Surface_Component component_instance
  def way_class_of_surface_component_instance
    Marshal.load(self.get_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY, Way_Grouping::ATTRIBUTE_WAY_CLASS_KEY).or_if_nil {raise "Component is not associated to a Way_Grouping way_class"})
  end
  # Get all the faces of the component definition
  def faces
    self.entities.find_all {|face| face.typename=='Face'}
  end

  # Dumbly apply a material to all front faces of the component and reverses faces pointing straight down
  def apply_material(material)
    down = Geom::Vector3d.new(0,0,-1)
    self.all_faces_deep.each {|face|
      face.reverse! if face.normal==down
      face.material = material
      face.back_material = material
    }
  end

  def face_up!
    down = Geom::Vector3d.new(0,0,-1)
    self.all_faces_deep.each {|face|
      face.reverse! if face.normal==down
    }
  end

  # Find the material with the given name and call apply_material
  def apply_material_by_name(material_name)
    material = Sketchup.active_model.materials.find {|material| material.name==material_name || material.display_name==material_name}
    if (material)
      apply_material(material)
    else
      Rescape::Config.log.warn("Couldn't find material #{material_name}. Perhaps it wasn't loaded into this model.")
    end
  end

  # All horizontal faces should face up, but some don't seem to
  NORMALS = [Geom::Vector3d.new(0,0,1), Geom::Vector3d.new(0,0,-1)]
  # Returns the top faces of the component_definition. That is, the face with the highest (z) average bounding box coordinates
  # The optional with_instances returns the ComponentInstance associated with each face. This is useful in the case that the top faces represent different ComponentInstances of the same Component, such as railroad ties
  def top_faces(with_instances=false)
    sorted_face_sets(with_instances).last
  end

  def bottom_faces(with_instances=false)
    sorted_face_sets(with_instances).first
  end

  # Finds the faces of the given height relative to the bottom face
  def faces_of_height(height, with_instances=false)
    bottom = bottom_faces(true).first
    minimum = Geom::Point3d.new(0,0,bottom.entity.plane_z).transform(bottom.transformation).z
    find_height =  minimum+height
    self.entities.find_all_deep(true) {|component_instance_entity|
      entity = component_instance_entity.entity
      entity.typename=='Face' &&
      NORMALS.member?(entity.normal) &&
      find_height==Geom::Point3d.new(0,0,entity.plane_z).transform(component_instance_entity.transformation).z
    }.map {|result| with_instances ? result : result.entity}
  end

  # Return sets of horizontal faces sorted by their height
  # Optionally specify with_instance=true to return sets of Component_Instance_Entity objects that reference to the face and the component_instance whose definition contains that face. It's possibly to have multiple Component_Instance_Entities with the same face when they share a common ComponentDefinition
  def sorted_face_sets(with_instances=false)
    self.entities.find_all_deep(true) {|component_instance_entity|
      entity = component_instance_entity.entity
      entity.typename=='Face' &&
      NORMALS.member?(entity.normal)
    }.
    sort_by_to_sets {|component_instance_entity|
      face = component_instance_entity.entity
      face.plane_z
    }.map {|set| set.map {|result| with_instances ? result : result.entity}}
  end



  def all_faces_deep
    self.entities.find_all_deep {|entity| entity.typename=='Face' }
  end
  def edges
    self.entities.find_all {|entity| entity.typename=='Edge'}
  end

  # Deletes all inner faces of a component
  def delete_inner_faces!
    faces = self.entities.find_all {|e| e.typename=='Face'}
    # Use sets because identical loops are treated as distinct objects when they belong to different faces
    inner_loops = faces.map { |f| f.loops.find_all {|l| l!=f.outer_loop}.map {|l| Set.new(l.edges)}}.shallow_flatten.uniq
    delete_faces = faces.find_all { |f| inner_loops.member? Set.new(f.outer_loop.edges)}
    self.entities.erase_entities delete_faces
  end

end