require 'utils/edge_associating'

# This class uses spatial analysis to associate edges to the closest center line segment of a shape, where the shape represents a Way_Grouping and the center line segments represent Way_Point_Pairs
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Edge_Association_Resolver

  def initialize(edge, way_grouping)
    @edge=edge
    @way_grouping=way_grouping
  end

  # Uses spatial analysis and neighbors to find the best way_point_pair with which to associate this edge
  def best_way_point_pair()
    # Find the closest associated edge from each end of the edge
    # Also make sure that the associated way_point_pair still exists
    $edge = @edge
    edge_groups = @edge.breadth_first_search_from_each_end {|neighbor| neighbor.associated_to_way_grouping? && neighbor.way_point_pair(@way_grouping) != nil}
    return nil unless edge_groups.find {|edges| edges.length > 0}
    dual_way_of_edge = lambda {|edge|
      way_point_pair = edge.way_point_pair(@way_grouping)
      raise "Way_Grouping #{@way_grouping.inspect} does not contain way of edge with way_point_pair data #{edge.get_attribute(Edge_Associating::WAY_DICTIONARY,Edge_Associating::WAY_POINT_PAIR_DATA_KEY).inspect} for edge #{edge.inspect}" if way_point_pair==nil
      @way_grouping.linked_way_of_way(way_point_pair.way).as_dual_way
    }
    edge_to_closest_linked_way_start = lambda {|edge|
      dual_way = dual_way_of_edge.call(edge)
      way_point_pair = edge.way_point_pair(@way_grouping)
      dual_way.linked_ways.entries.sort_by {|linked_way|
        way_point_pair.points.map {|point| linked_way.points.index(point) }.min
      }.first
    }
    dual_ways =
        # Take unique dual_ways that the edges of each group associates to and look for common dual_ways
    edge_groups.intersect_groups(lambda {|edge|
      [dual_way_of_edge.call(edge)] }).
        or_if_empty {
        # If no common ones are found, take closest associated linked_way of each edge and
    # then return it as a dual_way along with its neighbors as dual_ways.
    # Then look for intersecting dual_ways
      edge_groups.intersect_groups(lambda {|edge|
        linked_way = edge_to_closest_linked_way_start.call(edge)
        [linked_way.as_dual_way] + linked_way.neighbors.map {|lw| lw.as_dual_way} }) }.
        or_if_empty {
        # If still no common dual_ways are found, take the path between the first dual_way of each group
      dual_ways = edge_groups.map {|edge_group| dual_way_of_edge.call(edge_group.first)}
      @way_grouping.solve_shortest_path_between_dual_ways(dual_ways)
    }
    find_best_way_point_pair_of_ways(dual_ways)
  end

  def find_best_way_point_pair_of_ways(dual_ways)
    face = @edge.faces.first
    return nil unless face
    # Find the closest two ways, since the top two ways must be reverse of one another
    dual_ways.map {|dual_way| dual_way.linked_way_for_side_pair(@edge).way_point_pairs}.
        shallow_flatten.sort_by {|way_point_pair|
    # Compare the number of points between the edge and way_point_pair that are on the edge's face
      ps = points_between(@edge.middle_point, way_point_pair.middle_point, 10)
      points_score = 100*12*(10 - ps.find_all {|p|
        face.classify_point(p)==Sketchup::Face::PointInside}.length)
      # Magnify the points_score and add the distance score
      distance_score = @edge.distance_to_way_point_pair(way_point_pair)
      points_score+distance_score
    }.first
  end
  # Find count points between the two points
  def points_between(point1, point2, count)
    (1..count).map {|i| Geom::Point3d.linear_combination(i/count+1, point1, count+1-i/count+1, point2)}
  end

end

