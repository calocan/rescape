require 'config/config'
require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
module Tool_Utils
  include Basic_Utils

  attr_reader :travel_networks, :active_tool, :parent_tool
  attr_writer :active_tool, :parent_tool

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Basic_Utils)
    base.extend(Class_Methods)
  end

  def tool_init
    @active_tool = self
    @parent_tool = self
  end

  # Respond when user presses Escape
  def onCancel flags, view
    (1..(@pop_level || 1)).each {|x| self.pop_tool()}
    # Indicate that the top-level tool finished
    Rescape::Setup.controller.tool_finished()
  end

  def finish
    (1..(@pop_level || 1)).each {|x| self.pop_tool()}
    # Indicate that the top-level tool finished
    Rescape::Setup.controller.tool_finished()
  end

  def pop_all_tools()
    Rescape::Config.log.info("Popping all tools")
    Sketchup.active_model.tools.pop_tool && pop_all_tools()
  end
  def pop_tool()
    begin
      Rescape::Config.log.info("Popping tool for #{self.class} with id #{Sketchup.active_model.tools.active_tool_id}")
      Sketchup.active_model.tools.pop_tool
    rescue
      Rescape::Config.log.warn("Failed to pop tool for #{self.class}")
      raise
    end
  end

  def push_tool(tool)
    self.active_tool = tool
    tool.parent_tool = self
    Rescape::Config.log.info("#{self.class} is pushing tool #{tool.class}")
    Sketchup.active_model.tools.push_tool(tool)
  end

  def set_demo_mode(on=true)
    @demo_mode = on
  end

  # Reinitialize tools that need to be reset after their child tool is popped
  def reinitialize()
  end

  module Class_Methods

    # Configure a tool.
    # instantiate is a lambda that instantiates the tool. A UI::Command is created to call this
    # name is the name of the command
    # tool_class is the class upon which the instantiate lambda is based. It is used to define the icon file
    def configure(instantiate, name, tool_class)
      # Create the Command object
      offset_cmd = UI::Command.new(name) {
        instantiate.call
      }
      # Configure the icon files. Windows can't handle .icns files
      suffix = Rescape::Config.darwin? ? 'icns' : 'png'
      configure_ui(offset_cmd, "#{tool_class.name.downcase}.#{suffix}")
    end

    def configure_ui(offset_cmd, icon_file)
      # Configure the command's appearance
      icon = self.get_resource_file('icons', icon_file)
      raise "Icon not found for #{icon_file}" unless icon
      offset_cmd.small_icon = icon
      offset_cmd.large_icon = icon
      tooltip = self.message(:tooltip)
      offset_cmd.tooltip = tooltip
      offset_cmd
    end

    def lang
      :EN
    end

    # Tools must override
    def messages
      raise "Must override to supply UI messages for tool class #{self.name}"
    end

    def message(key)
      raise "Message #{key} not found" unless messages[key]
      messages[key][lang]
    end

    def default_message(key)
      messages[key][lang]
    end

    def set_status_to_message(key)
      set_status_text(messages[key][lang])
    end

    # Set the vcb to the given value.
    # Optionally provide a message key for the vcb label. Defaults to :vcb_label
    def set_vcb_status(value, vcb_label_key=:vcb_label)
      Sketchup.vcb_label = message(vcb_label_key)
      Sketchup.vcb_value = value
    end

    # Get an orthogonal translation of point_on_path based on the line of the path it is on.
    # The translation is the distance and direction to reference_point from the point that reference_point would intersect the line at its closest. reference_point may or may not be aligned with point_on_path.
    def orthogonal_point_from_path(path, point_on_path, reference_point)
      pair = point_on_path.closest_pair_of_path(path)
      orthogonal_point_from_pair(pair, point_on_path, reference_point)
    end

    # Returns an orthogonal transformation of point_between_pair according to the vector made by the pair of points
    # The distance and direction of the projection equals the distance from reference_point to its intersection on the pair's line
    def orthogonal_point_from_pair(pair, point_between_pair, reference_point)
      reference_point_on_pair = reference_point.project_to_line(pair)
      vector = reference_point_on_pair.vector_to(reference_point)
      t = Geom::Transformation.translation vector
      point_between_pair.transform t
    end

    # Sets the status text
    def set_status_text(text)
      Sketchup::status_text = text
    end

    def create_cursor(file)
      UI::create_cursor(self.get_resource_file('icons', file), 10, 10)
    end

    # Draws a line over the edge of the input point
    def draw_edge_hover(input_point)
      if (input_point.edge)
        view.line_width = 2
        view.line_stipple = "-.-"
        view.drawing_color = 'red'
        view.draw_line(adjust_z([input_point.edge.start.position, input_point.edge.end.position]))
      end
    end

    # Draws a point over the vertex of the input point
    def draw_vertex_hover(input_point)
      if (input_point.vertex)
        view.draw_points(adjust_z([input_point.vertex.position]), 5, 5, "red") # size, style, color
      end
    end

    # Transforms the set of points to the given z value without transforming x and y
    def adjust_z(points, z)
      return points unless z
      points.map {|point| point.transform(Geom::Point3d.new(0, 0, z-point.z))}
    end

  end
end