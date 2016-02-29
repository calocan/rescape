require "utils/edge_associating"
require "utils/linked_data_pair"
require 'wayness/side_point_pair'
require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Sketchup

  module Edge_Module
    include Linked_Data_Pair
    include Edge_Associating
    include Basic_Utils

    def self.included(base)
      self.on_extend_or_include(base)
    end
    def self.extended(base)
      self.on_extend_or_include(base)
    end
    def self.on_extend_or_include(base)
      base.extend(Data_Pair)
      base.extend(Edge_Associating)
      base.extend(Class_Methods)
    end

    # A reference to the underlying edge to assist complex types, namely Reverse_Edge
    def edge
      raise "Mixer must implement"
    end

    # The high-level class of points, Vertex instances here
    def data_points
      [self.start, self.end]
    end

    def other_data_point(data_point)
      (data_points.index(data_point)==0) ? data_points[1] : data_points[0]
    end

    # Unfortunately edge.split only returns one of the split parts of the edge. This method wraps it and finds both results and raises and error if the split failed
    def smart_split(points_or_fractions)
      points = points_or_fractions.first.class==Float ? points_or_fractions.map {|fraction| self.points.first.transform(self.vector.clone_with_length(self.vector.length*fraction))} : points_or_fractions
      Rescape::Config.log.info("Splitting edge #{self.inspect} at points #{points.inspect}")
      points.each {|point|
        raise "The given point is not on the edge. Edge: #{self.inspect}, Point: #{point.inspect}" unless point_between?(point)
      }
      # Calculate the expected split pairs
      sorted_points = points.sort_by {|point| self.points.first.distance(point)}
      expected_edge_pairs = divide_into_partials_at_points(sorted_points)
      # Do the actual split using the Sketchup split function, which sadly only returns the trimmed edge or nil if it fails
      # Sort the split points from farthest away to closest to suit Sketchup's split function which always returns the trimmed edge from the start point to the split point. This allows us to keep splitting the original edge
      sorted_points.reverse.map {|point|
        self.split(point).or_if_nil {
          raise "Split failed for edge #{self} at point #{point}"
        }
      }
      connected_edges = [self] + self.neighbors_up_to_degree(points_or_fractions.length)
      edges = Simple_Pair.find_all_matches(connected_edges, expected_edge_pairs)
      raise "Split failed. Found #{edges.length} instead of #{points_or_fractions.length+1} edges with points: #{edges.map {|e| e.points}.inspect}. Expected edges with points: #{expected_edge_pairs.map{|x| x.points}.inspect}" unless edges.length == points_or_fractions.length+1
      Rescape::Config.log.info("Split adjacent edge #{self.inspect} into edges #{edges.inspect}")
      edges
    end

    # Required implementation of interface method of Data_Pair
    def shares_how_many_points(pairs)
      self.data_points.find_all {|data_point| self.class.shares_this_point?(pairs, data_point)}.length
    end

    def reverse
      Reverse_Edge.new(self)
    end

    # Delegates to other_vertex
    def other_data_point(data_point)
      self.other_vertex(data_point)
    end

    # Determines whether or not the edge is part of an inner loop, assuming one side of it abuts a face.
    def forms_inner_loop?()
      # Find the face of the edge and get its outer loop edges to see if this edge doesn't belong to them
      !lone_edge_face.outer_loop.edges.member?(edge)
    end

    # Find the face of the edge when only one is expected
    def lone_edge_face
      self.edge.faces.only("Expected on face")
    end

    # Uses Sketchup's find_face command to create new faces, returning any previously nonexistant faces that were created
    # The optional block can be called to post process the faces, for instance deleting undesired ones that were created. It returns true for faces that are allowed. Others will be deleted
    def create_eligible_faces(parent=Sketchup.active_model)
      faces = Set.new(self.edge.faces)
      self.edge.find_faces
      new_faces = Set.new(self.edge.faces) - faces
      keep_faces = block_given? ? Set.new(new_faces.find_all {|face| yield(face) }) : new_faces
      if ((new_faces-keep_faces).length > 0)
        parent.entities.erase_entities((new_faces - keep_faces).map)
      end
      keep_faces.to_a
    end

    # Uses a Partial_Data_Pair to simulate an Edge with new points
    # This could be changed to use a Pseudo_Edge
    def clone_with_new_points(point_pair)
      Partial_Data_Pair.new(self, point_pair)
    end

    # The orthogonal that points toward the associated way_point_pair
    # of if inward is false, the orthogonal that points away from the associated way_point_pair
    def directional_orthogonal(travel_network=active_travel_network, inward=true)
      way_grouping = travel_network.way_grouping_of_edge(self)
      if (associated_to_way_point_pair?)
        way_point_pair = way_point_pair(way_grouping)
        vector = edge.middle_point.vector_to(way_point_pair.middle_point)
        edge.orthogonal((edge.rotation_to(vector)==Geometry_Utils::CCW_KEY) ^ !inward)
      else
        raise "Cannot determine inward_orthogonal for unassociated edge"
      end
    end

    def inspect
      "%s with points %s and %s" % [self.class, self.points.inspect, self.associated_to_way_point_pair? ? "associated to way_point_pair hash #{self.way_point_pair_hash}" : "not associated to a way_point_pair"]
    end

    module Class_Methods

      # Overrides the default Data_Pair method to convert ordered edges to ordered points when the orientation of each edge is arbitrary
      def to_ordered_points(ordered_edges)
        ordered_edges.length == 1 ?
            ordered_edges.only.points :
            ordered_edges.map_with_subsequent {|edge1, edge2| # we don't want the loop option here, only below on uniq
            # Find the closest vertices between the two edge, which may or my not be connected
              data_points = edge1.closest_data_points(edge2)
              # Put the farthest vertices at each end and the closest together
              # We concat the four edge points knowing that duplicate points will be deleted
              ([edge1.other_data_point(data_points[0])] + data_points.uniq + [edge2.other_data_point(data_points[1])]).map {|v| v.position}
            }.shallow_flatten.uniq_by_map_allow_loop {|p| p.hash_point}
      end

    end
  end

  class Edge
    include Edge_Module

    # This method exists to conform to the Edge_Module interface
    def edge
      self
    end
  end

  class Reverse_Edge
    include Edge_Module

    attr_reader :edge
    def initialize(edge)
      @edge = edge
    end

    def reverse
      @edge
    end

    def start
      @edge.end
    end

    def end
      @edge.start
    end

    # Returns a node version of the way_point_pair. This can be either the intersection of way_point_pairs or the intersection of ways
    # The return type is either a Node_Way, Node_Way_Point
    def as_node_data_pair(vertex, way_grouping)
      Vertex_Node.new(vertex)
    end

    def ==(reverse_edge)
      return false unless reverse_edge
      self.edge==reverse_edge.edge
    end
    # Send methods defined by edge, such as get_attribute to the edge, assuming that for them orientation is irrelevant
    def method_missing(m, *args, &block)
      @edge.send(m, *args, &block)
    end
  end
end