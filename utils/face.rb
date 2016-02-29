# Modifications to Sketchup::Face
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/entity_associating'
require 'utils/basic_utils'

module Sketchup
  class Face
    include Entity_Associating
    include Basic_Utils

    # True if the face or one of its edges is associated to a way_grouping
    def associated_to_way_grouping?
      self.base_associated_to_way_grouping?()  || self.edges.any? {|edge| edge.associated_to_way_grouping?() }
    end

    def associated_way_grouping(travel_network)
      $f=self
      (self.base_associated_to_way_grouping? && self.base_associated_way_grouping(travel_network)) ||
       self.edges.find {|edge| edge.associated_to_way_grouping?()}.if_not_nil {|edge|
         edge.associated_way_grouping(travel_network)
       }
    end

    # The class to which the face is associated, or that of the first associated edge
    def associated_way_class
      (self.base_associated_to_way_grouping? && self.base_associated_way_class()) ||
       self.edges.find {|edge| edge.associated_to_way_grouping?()}.if_not_nil {|edge| edge.associated_way_class()}
    end

    def complete_face(material)
      face_up!
      self.material = material
      # Setting the material to a color does not set the alpha, so do it here
      self.material.alpha = material.alpha/256.to_f
    end

    def face_up!()
      up = Geom::Vector3d.new(0,0,1)
      self.reverse! unless self.normal==up
      self
    end

    # Create a component from the given points with a face
    def self.component_from_perimeter_points(perimeter_points)
      active_model.add_group(perimeter_points)
      group = active_model.entities.add_group()
      edges = group.entities.add_curve(perimeter_points)
      edges.first.explode_curve()
      edges.first.find_faces()
      group.to_component
    end

    # Returns all the edges who have both points on the face, or the faces edges
    def edges_on_face(edges, transformation=Geom::Transformation.new)
      edges.find_all {|edge| edge.divide_by_approximate_length(12).any? {|point|
        self.classify_point(point.transform(transformation)) & 0x7 != 0}}
    end

    # Returns true if any outer_loop edge of the given face is on the edge or withing this face. This divides the edges into foot-long segments and test the points, so it isn't completely reliable
    def intersects?(face, transformation=Geom::Transformation.new)
      face.outer_loop.edges.any? {|edge| edge.divide_by_approximate_length(12).any? {|point|
        self.classify_point(point.transform(transformation)) & 0x7 !=0}}
    end

    # The z position of the face
    def plane_z
      self.plane[3]*self.normal.z*-1
    end

    def inspect()
      "Face with normal #{self.normal.inspect} and plane #{self.plane.inspect} and hash #{hash}"
    end
  end
end