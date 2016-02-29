require "utils/Geometry_Utils.rb"
require 'wayness/side_point_pair'
require 'wayness/end_point_pair'

# A Sketchup representation of one side of a continuous list of Way instances. The shape drawn is a polygon that
# traces the perimeter of the counterclockwise side of the connected Way instances and the center line of the ways
# Way_Component instances are exploded to form a polygons representing a connected road network of one way
# class. Making Way_Component instances that represent one side of a continuous list of ways is solely for algorithmic
# simplicity. They have no important meaning for traveling, since they literally represent traveling on the left
# side of the way and making continuous left turns without crossing other ways.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Way_Component

  attr_reader :surface_component, :side_point_manager, :continuous_ways, :way_points, :loop
  # Creates a way that can be rendered.
  # side_points must be an Associated_Points instance that associates each pair of side points to a way instance
  def initialize(surface_component, way_grouping, continuous_ways, transformation_lambda_wrapper=nil, way_preprocessor=nil)
    @way_grouping = way_grouping
    @way_class = way_grouping.way_class
    @continuous_ways = continuous_ways
    @transformation_lambda_wrapper = transformation_lambda_wrapper
    @way_preprocessor = way_preprocessor
    @way_points = continuous_ways.map {|way| way.map {|point| Way_Point.new(point,way)}}.shallow_flatten
    @way_color = @way_class::way_color
    @side_point_manager = initialize_side_point_manager()
    @loop = @side_point_manager.length > 0 ? @side_point_manager.first.point.matches?(@side_point_manager.last.point) : false
    @surface_component = surface_component
  end

  # Generates side_points for the continuous_ways
  def initialize_side_point_manager
    @continuous_ways.side_point_manager(@transformation_lambda_wrapper, @way_preprocessor)
  end

  # Retrieves the points to be used to draw the side of the way
  def get_perimeter_points
     side_point_points = @side_point_manager.map{|sp| sp.point}
     (@loop ? side_point_points :
         [@way_points.first.point,
          side_point_points,
          @way_points.last.point].shallow_flatten).uniq_by_map_allow_loop {|point| point.hash_point}
  end


  # Returns perimeter points matching the given ways only. Order of the points is preserved
  # Only center points adjacent to a valid side_point is returned
  def get_perimeter_points_of_ways(ways)
    limited_side_point_points = @side_point_manager.find_all {|side_point|
      side_point.ways_of_side_point.any? {|way| ways.member?(way)}
    }.map {|side_point| side_point.point}
    side_point_points = @side_point_manager.to_points

    # Return the limited points plus the end points if the extreme points next to end points were not eliminated
    loop_or_end_points(limited_side_point_points, side_point_points)
  end

  def loop_or_end_points(limited_side_point_points, side_point_points=limited_side_point_points)
    (@loop ? limited_side_point_points :
        [
            side_point_points.first==limited_side_point_points.first ? @way_points.first.point : [],
            limited_side_point_points,
            side_point_points.last==limited_side_point_points.last ? @way_points.last.point : []
        ].shallow_flatten).uniq_by_map_allow_loop { |point| point.hash_point }
  end

  # Get the perimeter points as pairs
  def get_perimeter_data_pairs
    # TODO shouldn't the argument be @continuous_ways?
    get_perimeter_data_pairs_of_ways(@continuous_ways)
  end


  # Get the perimeter points as pairs that match the given ways
  def get_perimeter_data_pairs_of_ways(ways)
    side_point_pairs = @side_point_manager.side_point_pairs
    limited_side_point_pairs = side_point_pairs.find_all {|side_point_pair|
      ways.member?(side_point_pair.way_point_pair.way)
    }

    # Return the limited pairs plus the end_point_pairs if the extreme points next to end points were not eliminated
    loop_or_end_pairs(limited_side_point_pairs, side_point_pairs)
  end

  def loop_or_end_pairs(limited_side_point_pairs, side_point_pairs=limited_side_point_pairs)
    (@loop ? limited_side_point_pairs :
        [
            side_point_pairs.first==limited_side_point_pairs.first ? End_Point_Pair.new([@way_points.first, limited_side_point_pairs.first.first]) : [],
            limited_side_point_pairs,
            side_point_pairs.last==limited_side_point_pairs.last ? End_Point_Pair.new([limited_side_point_pairs.last.last, @way_points.last]) : []
        ].shallow_flatten)
  end

  # Retrieves perimeter points not identical to their reference point
  # This is useful when some offset pairs are have 0 length offsets and are only being used to constrain the other points
  def get_perimeter_points_with_nonzero_offset
    ineligible_points = @side_point_manager.reject {|sp| sp.point.matches?(sp.way_point.point) }.map {|sp| sp.point}
    get_perimeter_points.reject {|point| point.member?(ineligible_points)}
  end

  # Retrieves a limited set of the side_points of the @side_point_manager, filtered by a predicate that operates on each side_point_pair of the side_point_manager and returns the unique points of successful side_point_pairs
  def get_limited_perimeter_points(&side_point_pair_predicate)
    Side_Point_Pair.to_unique_points(@side_point_manager.side_point_pairs.find_all {|side_point_pair| side_point_pair_predicate.call(side_point_pair)})
  end

  # Draws the perimeter points as a polygon and finds and creates the face that they create
  # TODO Change name to render or something
  def draw
    Rescape::Config.log.info("Drawing way_component for ways #{@continuous_ways.map {|way| way.name}.join(',')}")
    $pog=perimeter_points = get_perimeter_points()
    edges = @surface_component.component_instance.definition.entities.add_curve(perimeter_points)
    if (edges)
      point_pair_to_side_point_pair = Side_Point_Pair.hash_by_point_pair(@side_point_manager.side_point_pairs)
      # Write attributes to the edge
      edges.find_all{|edge| edge.typename=='Edge'}.each  { |edge|
        side_point_pair = Side_Point_Pair.lookup_by_point_pair(point_pair_to_side_point_pair, edge)
        if (side_point_pair)
          edge.associate_to_way_point_pair!(@way_grouping, side_point_pair.way_point_pair, false)
        else
          # Mark the end edge as an end
          edge.mark_as_end_edge(Side_Point.find_all_matches(@side_point_manager, edge.data_points))
        end
        # Associate the edge to the way_grouping
        edge.associate_to_way_grouping!(@way_grouping)
      }
    else
      Rescape::Config.log.warn "Adding curve failed for points #{perimeter_points.inspect} failed"
    end
    Rescape::Config.log.info("Finished drawing way_component")
    edges
  end
end