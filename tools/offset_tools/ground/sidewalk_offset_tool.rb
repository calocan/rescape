require 'tools/offset_tools/offset_tool_module'
require 'tools/way_tools/way_based_path_tool'
require 'tools/offset_tools/follow_me_surface'
require 'wayness/surface_definitions/Rail/tram'
require 'utils/Geometry_Utils'
require 'tools/offset_tools/way_path_properties'

# A specialized offset_tool that offsets tram/streetcar/light_rail or other on street rail tracks
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Sidewalk_Offset_Tool
  include Offset_Tool_Module
  include Way_Path_Properties

  UI_MESSAGES = {
      :title =>
          {:EN=>"Create a sidewalk",
           :FR=>"Créez un trottoir"},
      :tooltip =>
          {:EN=>"Use an offset to create a sidewalk",
           :FR=>"Employez un offset pour créer un trottoir"}
  }
  def self.messages
    UI_MESSAGES
  end

  def self.offset_finisher_class
    Sidewalk_Offset_Finisher
  end

  # Don't tolerate anything but the gentlist angles
  def self.curve_threshold()
    150.degrees
  end
  # Curve only 10 percent of the offset lines
  def self.curve_fraction()
    0.1
  end

  # The width of the total offset area
  def self.offset_width()
    8*12 #TODO move
  end

  def self.select_edges_only?
    true
  end

  def self.allow_way_shape_offset?
    false
  end

  # Sidewalks are not symmetric
  def self.symmetric?
    false
  end

end

class Sidewalk_Offset_Finisher
  include Way_Based_Path_Tool

  # Displays a polyline for the calculated offset
  def draw_offset(view, movement_flags)
    view.drawing_color = "silver"
    view.line_width = 4
    view.line_stipple = ""
    # Base all other lines on the vector, which is the outmost line
    $zee=point_sets = find_or_create_point_sets()

    [:inner_side, :inner_curb, :outer_curb].each {|key|
      view.draw_polyline(adjust_z(point_sets[key]))
    }
  end

  # Creates point sets for the outside, inside, and center of the sidewalk
  # The sidewalk is asymmetric, meaning the edge of the curb is the outermost points and the insidemost part of the sidewalk is negatively reciprocal to the edge of the curb.
  def point_set_definition
    sidewalk_width = @offset_configuration.offset_width()
    curb_width = 6 # The granite slab that holds the cement
    # Point set distances from outermost to innermost
    {:outer_curb=>sidewalk_width/2,
     :curb_center=>sidewalk_width/2-curb_width/2,
     :inner_curb=>sidewalk_width/2-curb_width,
     :main_center=>-(curb_width)/2,
     :inner_side=>-sidewalk_width/2}
  end

  # Draws the final component based on the offset input
  def finalize_offset()
    to_offset_component([:outer_curb, :inner_side]) {|parent|
      point_sets = find_or_create_point_sets()
      curb = pull_surface_up(parent, [point_sets[:inner_curb], point_sets[:outer_curb]], Way_Surface_Definition.standard_component_height)
      main = pull_surface_up(parent, [point_sets[:inner_side], point_sets[:inner_curb]], Way_Surface_Definition.standard_component_height)
      [curb, main]
    }
  end

  def pull_surface_up(parent, point_sets, height)
    surface_point_sets = point_sets.is_loop? ?
      point_sets :
      [point_sets[0]+point_sets[1].reverse+[point_sets[0][0]]].uniq_consecutive_by_map {|point|
          point.hash_point}
    # Create a cross section component definition based on the surface component perimeter points
    cross_section_component_definition = self.class.dynamic_cross_section(parent, surface_point_sets.shallow_flatten)
    # Find the orthogonal vector of the cross section face and make it the desired length upward
    orthogonal_up = cross_section_component_definition.faces.only.face_up!.normal.clone_with_length(height)
    # Create a point_set consisting of the first point of the path (on the surface) plus the point transformed upward
    point_set = [surface_point_sets[0][0], surface_point_sets[0][0].transform(orthogonal_up)]
    Follow_Me_Surface.new(parent, cross_section_component_definition).along(point_set, {:already_transformed=>true})
  end

  # Creates the cement bed cross section of the tram tracks
  def cross_section_component_definition(parent, width)
    bottom_points = [Geom::Point3d.new(0-width/2,0,0), Geom::Point3d.new(width/2,0,0)]
    top_points = bottom_points.map {|bottom_point| bottom_point.transform([0,0,6])}
    self.class.dynamic_cross_section(parent, bottom_points + top_points.reverse + [bottom_points.first])
  end

end

