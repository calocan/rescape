require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Component_Instance_Behavior
  include Basic_Utils

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Basic_Utils)
  end

# Retrieves the Way_Grouping.unique_id stored with this Surface_Component component_instance
  def way_grouping_id
    self.get_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY, Way_Grouping::ATTRIBUTE_ID_KEY).or_if_nil {raise "Component is not associated to a Way_Grouping unique_id"}
  end

  # Intersect the given component instance with this instance's top_face and add the intersect lines to this instances' definition
  # The intersector is the ComponentInstance with which we wish to intersect
  # intersector_faces are those faces with which to intersect, by default they are the top faces of the intersector
  # returns the intersect lines
  def intersect_faces(intersector, intersector_faces=intersector.definition.top_faces)
    t = Geom::Transformation.new
    $a1=intersector_faces
    $a2=self.definition.top_faces

    $ne=new_edges = self.definition.entities.intersect_with(true,
                                                        t,
                                                        self.definition.entities[0].definition.entities,
                                                        t,
                                                        false,
                                                        self.definition.top_faces + intersector_faces.flat_map {|face| face.edges})
    $new_faces = new_edges.flat_map {|edge| edge.faces}.uniq.find_all {|face| !faces.any? {|f| f.bounds==face.bounds}}
  end

  # Adds a cut face surface to all top faces' component_definitions of this component_instance's definition to match the outline of the given component. The cut face's edges will be hidden so as to appear invisible
  def add_cut_face_based_on_data_pairs(perimeter_data_pairs, cut_face_height=nil, transformation=Geom::Transformation.new)
    $pt = transformation
    # Make sure the z of all perimeter point sets is equal
    $z1=z = perimeter_data_pairs.flat_map {|data_pair| data_pair.points}.map {|point| point.z}.uniq.only("Expected all perimeter points to be of the same height, but got #{perimeter_data_pairs.inspect}")

    # Find all the top faces within the components of the definition and group them by their common component_instance
    (cut_face_height ?
    self.definition.faces_of_height(cut_face_height, true) :
    self.definition.top_faces(true)).
    to_hash_value_collection {|component_instance_top_face|
      component_instance_top_face.component_instance}.
    each {|component_instance, component_instance_top_faces|

      $a1=component_instance
      $a2=component_instance_top_faces
      # TODO component_instances should be made unique if there are multiple component_instances with the same definition. This is a somewhat rare case but possible.

      parent_definition = component_instance.definition
      top_faces = component_instance_top_faces.map {|component_instance_entity| component_instance_entity.entity}
      $ts=face_parent_transformation=component_instance.transformation
      $z2 = top_faces.first.bounds.max.z
      $z3=face_z = Geom::Point3d.new(0,0,top_faces.first.bounds.max.z).transform(face_parent_transformation).z
      # Create a transformation that transforms the perimeter points to the level of the face. The first transformation here moves the points from the origin to their original position, since our cross section transforms the points to the origin.
      $tx=point_set_transformation =
          transformation *
          face_parent_transformation.inverse *
          Geom::Transformation.new(Geom::Vector3d.new(0,0, face_z-z)) *
          Geom::Transformation.new(Geom::Point3d.new().vector_to(perimeter_data_pairs.first.points.first))

      # Create a cross section with no face and invisible edges. Center the points around the origin so that its cut face plane matches the points
      $pdp = perimeter_data_pairs
      $dx=definition = self.class.dynamic_cross_section_from_data_pairs(active_model, perimeter_data_pairs, {:no_face=>true, :transform_to_origin=>true})
 #     definition.edges.each {|edge| edge.visible=false}

      # Create a cross section for each face and glue it to the face. This creates the desired cut
      top_faces.map {|face|
        instance=parent_definition.entities.add_instance(definition, point_set_transformation)
        instance.glued_to=face
      }
    }
  end

end
