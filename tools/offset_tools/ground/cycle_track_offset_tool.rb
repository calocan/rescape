require 'wayness/surface_definitions/Ground/cycle_track'
require 'tools/way_tools/hybrid_way_based_path_tool'
require 'tools/offset_tools/follow_me_surface'
require 'wayness/surface_definitions/Rail/tram'
require 'utils/Geometry_Utils'
require 'tools/offset_tools/offset_tool_module'
require 'tools/offset_tools/hybrid_path_properties'

# A specialized offset_tool that offsets lines to create cycle tracks
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

  class Cycle_Track_Offset_Tool
    include Offset_Tool_Module
    include Hybrid_Path_Properties

    UI_MESSAGES = {
        :title =>
            {:EN=>"Create a cycletrack",
             :FR=>"Créez un *"},
        :tooltip =>
            {:EN=>"Use an offset to create a cycletrack",
             :FR=>"Employez un offset pour créer un *"}
    }
    def self.messages
      UI_MESSAGES
    end

    def self.offset_finisher_class
      Cycle_Track_Offset_Finisher
    end

    # Curve all angles
    def self.curve_threshold()
      180.degrees
    end

    # Curve only 10 percent of the offset lines
    def self.curve_fraction()
      0.1
    end

    # The width of the total offset area
    def self.offset_width()
      Cycle_Track::WAY_WIDTH_HASH['cycleway']
    end

    # Use the top of track for the cut face, not the lane stripe top
    def self.height_of_cut_face
      Cycle_Track::DEFAULT_Z_POSITION
    end
  end

  class Cycle_Track_Offset_Finisher
    include Hybrid_Way_Based_Path_Tool

    DEFAULT_GAUGE = 4*Geometry_Utils::FEET + 8.5
    def default_gauge
      DEFAULT_GAUGE
    end

    # Displays a polyline for the calculated offset
    def draw_offset(view, movement_flags)
      view.line_width = 4
      view.line_stipple = ""
      # Base all other lines on the vector, which is the outmost line
      point_sets = find_or_create_point_sets()

      view.drawing_color = Cycle_Track.center_line_color
      view.draw_polyline(adjust_z(point_sets[:center]))

      view.drawing_color = Cycle_Track.default_color
      [:side1, :side2].each {|key|
        view.draw_polyline(adjust_z(point_sets[key]))
      }
    end

    def point_set_definition
      {:side=>@offset_configuration.offset_width()/2, :center_line=>Cycle_Track::CENTER_LINE_WIDTH/2}
    end

    # Draws the final component based on the offset input
    def finalize_offset()
      to_offset_component([:side]) {|parent|

        point_sets = find_or_create_point_sets()

        cross_section_component_definition = cross_section_component_definition(
            parent,
            point_sets[:side1].first.distance(point_sets[:side2].first),
            0,Way_Surface_Definition.standard_component_height)
        main = Follow_Me_Surface.new(parent, cross_section_component_definition).along(point_sets[:center])
        main.definition.apply_material_by_name(Cycle_Track::DEFAULT_MATERIAL_NAME)

        # Draw a thin center line atop the main component
        center_line_component_definition = cross_section_component_definition(
            parent,
            point_sets[:center_line1].first.distance(point_sets[:center_line2].first),
            Way_Surface_Definition.standard_component_height,0.25)

        center_line = Follow_Me_Surface.new(parent, center_line_component_definition).along(point_sets[:center])
        center_line.definition.apply_material(Cycle_Track.center_line_color)
        [main, center_line]
      }
    end

    def cross_section_component_definition(parent, width, bottom, height)
      bottom_points = [Geom::Point3d.new(0-width/2,0,bottom), Geom::Point3d.new(width/2,0,bottom)]
      top_points = bottom_points.map {|bottom_point| bottom_point.transform([0,0,height])}
      self.class.dynamic_cross_section(parent, bottom_points + top_points.reverse + [bottom_points.first])
    end
end

