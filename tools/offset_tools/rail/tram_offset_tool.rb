require 'tools/offset_tools/offset_tool_module'
require 'tools/offset_tools/offset_finisher_module'
require 'tools/offset_tools/follow_me_surface'
require 'wayness/surface_definitions/Rail/tram'
require 'utils/Geometry_Utils'
require 'tools/way_tools/hybrid_way_based_path_tool'
require 'tools/offset_tools/hybrid_path_properties'

# A specialized offset_tool that offsets tram/streetcar/light_rail or other on street rail tracks
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Tram_Offset_Tool
  include Offset_Tool_Module
  include Hybrid_Path_Properties

  UI_MESSAGES = {
      :title =>
          {:EN=>"Create a tram line",
           :FR=>"Créez une voie de tramway"},
      :tooltip =>
          {:EN=>"Use an offset to create a tramway line",
           :FR=>"Employez un offset pour créer une voie de tramway"}
  }
  def self.messages
    UI_MESSAGES
  end

  def self.offset_finisher_class
    Tram_Offset_Finisher
  end

  # Curve all angles
  def self.curve_threshold()
    180.degrees
  end

  # Curve 25 feet around around angles that are over the curve_threshold()
  def self.curve_length()
    25*Geometry_Utils::FEET
  end

  def self.offset_width()
    Tram::DEFAULT_WIDTH
  end

  # This priority means that render tram tracks will appear to cut through lower priority components by forcing the components to draw a special cut field that shadows the track
  def self.cut_priority()
    10
  end
end

class Tram_Offset_Finisher
  include Hybrid_Way_Based_Path_Tool

  DEFAULT_GAUGE = 4*Geometry_Utils::FEET + 8.5
  def default_gauge
    DEFAULT_GAUGE
  end

  def draw_offset(view, movement_flags)
    view.line_width = 2
    view.line_stipple = "-"

    # Base all other lines on the vector, which is the outmost line
    point_sets = find_or_create_point_sets()

    view.drawing_color = "brown"
    [:side1, :side2].each {|key|
      view.draw_polyline adjust_z(point_sets[key])
    }

    view.drawing_color = "silver"
    view.line_width = 4
    view.line_stipple = ""

    [:track1, :track2].each {|key|
      view.draw_polyline adjust_z(point_sets[key])
    }
  end

  # Creates parallel lines represented by points. The outermost line, the edge of the streetcar surface,
  # defines the inner ones, so that if outer line points need to be left out of the offset at greater distances,
  # the same points will be eliminated from the inner lines.
  def point_set_definition
    {:side => @offset_configuration.offset_width/2, :track =>Tram::DEFAULT_GAUGE/2}
  end

  def edge_point_sets
    [:side]
  end

  # Draws the final component based on the offset input
  def finalize_offset()
      to_offset_component(edge_point_sets) {|parent|

        point_sets = find_or_create_point_sets()

        # Create the tram bed
        tram_bed =  Follow_Me_Surface.new(parent, tram_bed_cross_section_component_definition()).along(point_sets[:center])
        tram_bed.definition.apply_material_by_name(Tram::DEFAULT_BED_MATERIAL_NAME)

        # Create the rails
        rail_height = Geom::Vector3d.new(0,0,Tram::RAIL_BASE_START_HEIGHT)
        rails = [:track1, :track2].map{|key|
          Follow_Me_Surface.new(parent, rail_cross_section_component_definition()).along(point_sets[key])}.map {|rail| rail.transform!(rail_height)}
        rails.each {|rail| rail.definition.apply_material_by_name(Tram::DEFAULT_RAIL_MATERIAL_NAME)}

        rails + [tram_bed]
      }
  end


  # Loads the simple rail cross section, which will follow path to make a 3D rail
  def rail_cross_section_component_definition()
    component_file = self.class.get_resource_file('components', 'Rail Cross Section.skp')
    Sketchup::active_model.definitions.load(component_file)
  end

  def tram_bed_cross_section_component_definition()
    component_file = self.class.get_resource_file('components', 'Tram Bed Cross Section.skp')
    Sketchup::active_model.definitions.load(component_file)
  end

  # Creates the cement bed cross section of the tram tracks. The cement bed is Tram::DEFAULT_HEIGHT high
  def cement_cross_section_component_definition(parent, width)
    bottom_points = [Geom::Point3d.new(0-width/2,0,0), Geom::Point3d.new(width/2,0,0)]
    top_points = bottom_points.map {|bottom_point| bottom_point.transform([0,0,Tram::DEFAULT_HEIGHT])}
    self.class.dynamic_cross_section(parent, bottom_points + top_points.reverse + [bottom_points.first])
  end

end

