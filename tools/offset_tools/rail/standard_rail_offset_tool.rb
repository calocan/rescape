require 'tools/offset_tools/offset_tool_module'
require 'tools/offset_tools/offset_finisher_module'
require 'tools/offset_tools/follow_me_surface'
require 'wayness/surface_definitions/Rail/standard_rail'
require 'utils/Geometry_Utils'

# A specialized offset_tool that offsets rail tracks
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Standard_Rail_Offset_Tool
  include Offset_Tool_Module
  include Hybrid_Path_Properties

  UI_MESSAGES = {
      :title =>
          {:EN=>"Create a rail line",
           :FR=>"Créez une voie de *"},
      :tooltip =>
          {:EN=>"Use an offset to create a rail line",
           :FR=>"Employez un offset pour créer une voie de *"}
  }
  def self.messages
    UI_MESSAGES
  end

  def self.offset_finisher_class
    Standard_Rail_Offset_Finisher
  end

  # Curve all angles
  def self.curve_threshold()
    180.degrees
  end
  # Curve 50 percent of the offset lines when curve_threshold is violated
  def self.curve_fraction()
    0.5
  end

  def self.offset_width()
    Standard_Rail::DEFAULT_WIDTH
  end

  # Tracks aren't flat, so this isn't needed (Unless we add a track bed)
  def self.participates_in_cut_faces?
    false
  end
end

class Standard_Rail_Offset_Finisher
  include Hybrid_Way_Based_Path_Tool

  DEFAULT_GAUGE = 4*Geometry_Utils::FEET + 8.5
  def default_gauge
    DEFAULT_GAUGE
  end

  # Displays a polyline for the calculated offset
  def draw_offset(view, movement_flags)
    view.drawing_color = "brown"
    view.line_width = 2
    view.line_stipple = "-"
    # Base all other lines on the vector, which is the outmost line
    point_sets = find_or_create_point_sets()
    [:side1, :side2].each {|key|
      view.draw_polyline(adjust_z(point_sets[key]))
    }

    view.drawing_color = "silver"
    view.line_width = 4
    view.line_stipple = ""

    [:rail1, :rail2].each {|key|
      view.draw_polyline(adjust_z(point_sets[key]))
    }
    view.drawing_color = "brown"
=begin
    point_sets[:tie1].map_with_subsequent {|p1,p2| Simple_Pair.new([p1,p2])}.map {|pair|
      pair.divide_into_partials_by_approximate_length(10*Standard_Rail::DEFAULT_TIE_REPEAT)}.shallow_flatten.each {|pair|
      view.draw_polyline([pair.points.first, pair.points.first.transform(pair.orthogonal().clone_with_length(Standard_Rail::DEFAULT_TIE_WIDTH))])
    }
=end
  end

  # Creates parallel lines represented by points. The outermost line, the edge of the streetcar surface,
  # defines the inner ones, so that if outer line points need to be left out of the offset at greater distances,
  # the same points will be eliminated from the inner lines.
  # We have 5 sets of points based on the outer_lane: the center points, the track points, and the side points
  # that represent the required width of the right-of-way.
  # Returns a hash of point sets {:outer_side_points=>points1, :outer_track_points=>points2, :inner_track_points=>points3, :inner_side_points=>point4}
  def point_set_definition
    {:side=>Standard_Rail::DEFAULT_WIDTH/2, :rail=>Standard_Rail::DEFAULT_GAUGE/2, :tie=>Standard_Rail::DEFAULT_TIE_WIDTH/2}
  end

  # Draws the final component based on the offset input
  def finalize_offset()
      to_offset_component([:side]) {|parent|
        point_sets = find_or_create_point_sets()
        cement_tie_definition = cement_tie_cross_section_component_definition(Sketchup.active_model,
                                                                              point_sets[:tie1].first.distance(point_sets[:tie2].first))
        cement_ties = Follow_Me_Surface.new(Sketchup.active_model, cement_tie_definition).along(point_sets[:center], {:unique_components=>false, :draw_length=>Standard_Rail::DEFAULT_TIE_LENGTH, :space_length=>Standard_Rail::DEFAULT_TIE_SPACING})
        $newd=new_ties = parent.entities.add_instance(cement_ties.definition, cement_ties.transformation)
        cement_ties.definition.entities.map {|cement_tie| cement_tie.definition}.uniq.each {|cement_tie_definition|
          cement_tie_definition.apply_material_by_name(Standard_Rail::DEFAULT_TIE_MATERIAL_NAME)
        }
        Sketchup.active_model.entities.erase_entities(cement_ties)
        cement_ties = new_ties

        rail_height = Geom::Vector3d.new(0,0,Standard_Rail::RAIL_BASE_START_HEIGHT)
        rails = [:rail1, :rail2].map{|key|
          Follow_Me_Surface.new(parent, rail_cross_section_component_definition()).along(point_sets[key])}.map {|rail| rail.transform!(rail_height)}
        rails.each {|rail| rail.definition.apply_material_by_name(Standard_Rail::DEFAULT_RAIL_MATERIAL_NAME)}

        rails + [cement_ties]
      }
  end

  # Loads the simple rail cross section, which will follow path to make a 3D rail
  def rail_cross_section_component_definition()
    component_file = self.class.get_resource_file('components', 'Rail Cross Section.skp')
    Sketchup::active_model.definitions.load(component_file)
  end

  def cement_tie_cross_section_component_definition(parent, width)
    bottom_points = [Geom::Point3d.new(0-width/2,0,0), Geom::Point3d.new(width/2,0,0)]
    top_points = bottom_points.map {|bottom_point| bottom_point.transform([0,0,7])}
    self.class.dynamic_cross_section(parent, bottom_points + top_points.reverse + [bottom_points.first])
  end

end

