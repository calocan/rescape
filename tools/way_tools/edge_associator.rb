require 'tools/tool_utils'

# This tool scans all the edges of all Surface_Component instances
# and forces each edge to associate with part of a way if it hasn't yet done so.
# By default it runs on all Surface_Component instances but it will run for only selected surfaces
# if any surfaces are selected
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Edge_Associator
  include Tool_Utils

  UI_MESSAGES = {
      :title =>
          {:EN=>"Associate Edges",
           :FR=>"?"},
      :tooltip =>
          {:EN=>"Associate Edges with a way",
           :FR=>""},
      :wait =>
          { :EN=>"Please wait while unassociated edges associate",
            :FR=>"Please wait while unassociated edges associate"
          },
      :invalid_selection=>
          {:EN=>"",
           :FR=>""}
  }
  # How close the cursor has to be to an edge in pixels
  PROXIMITY_THRESHOLD = 20

  def self.messages
    UI_MESSAGES
  end

  def initialize(travel_networks)
    @travel_networks = travel_networks
    @travel_network = active_travel_network()
    @input_point = Sketchup::InputPoint.new
    @way_groupings = nil
    @way_point_pair_to_ordered_edges_by_way_grouping = nil
    @edge_to_way_point_pair = nil
    @edge_to_way_point_pair_per_way_grouping = nil
    # When set true, the tool will ignore user input and expect the event handlers to be called programatically
    @demo_mode = nil
    tool_init()
  end

  def activate
    # Remove any bad data, such as deleted edges, from the way_groupings
    @travel_network.purge_all()
    self.class.set_status_to_message(:wait)

    # Get the way_groupings of the selected surface_component instances, or all of them if none are selected
    @selected_surface_component_instances = Sketchup.active_model.selection.find_all {|entity| entity.kind_of?(Component_Instance_Behavior) && entity.associated_to_way_grouping?}
    $ges=@way_groupings = @selected_surface_component_instances.map {|surface_component_instance|
      active_travel_network.way_grouping_by_id(surface_component_instance.way_grouping_id)
    }.or_if_nil {active_travel_network.way_class_to_grouping[Street]}
    Rescape::Config.log.info("Found way_groupings for: #{@way_groupings.map {|way_grouping| way_grouping.way_class.name}.join(", ")}")
    # Associate the edges to the best eligible way_point_pair
    $xmx =@edge_to_way_point_pair_per_way_grouping = @way_groupings.to_hash_keys {|way_grouping|
      way_grouping.entity_map.associate_edges_to_way_point_pair! }
   $xdi= @way_point_pair_to_ordered_edges_by_way_grouping = @edge_to_way_point_pair_per_way_grouping.map_values_to_new_hash {|way_grouping, edge_to_way_point_pair|
      way_point_pairs = edge_to_way_point_pair.values.uniq.compact
      Rescape::Config.log.info("Found #{way_point_pairs.length} way_point_pairs for way_grouping #{way_grouping.inspect}")
      way_point_pairs.to_hash_keys {|way_point_pair|
        get_sorted_edges_when_possible(way_grouping.entity_map, way_point_pair)
      }
    }
    @edge_to_way_point_pair = @edge_to_way_point_pair_per_way_grouping.values.merge_hashes()

    raise "No results found" unless @edge_to_way_point_pair
    self.class.set_status_to_message(:tooltip)
  end

  # Retrieves sorted edges when the edges are connected, otherwise returns them without order
  def get_sorted_edges_when_possible(entity_map, way_point_pair)
    begin
      entity_map.sorted_edges_associated_to_way_point_pair(way_point_pair)
    rescue
      entity_map.edges_associated_to_way_point_pair(way_point_pair)
    end
  end

  def onMouseMove(flags, x, y, view, demoing=false)
    return if @demo_mode && !demoing
    @input_point.pick(view, x, y)
    if (!@active_edge)
      # Highlight a potential active_edge
      @hover_edge = get_hover_edge(@input_point)
      Rescape::Config.log.info("#{@hover_edge.inspect}") if @hover_edge
    else
      # If the user has picked an edge and moved to a way_point_pair, make it the active one so it will be highlighted and traced to
      way_grouping = Entity_Map.way_grouping_of_input_point(active_travel_network, @input_point)
      return unless way_grouping && @way_groupings.member?(way_grouping)
      way_point_pair =  way_grouping.closest_way_point_pair_to_point(@input_point)
      $awpp = @active_way_point_pair = way_point_pair &&
          @active_edge &&
          way_point_pair.project_point_to_pair(@input_point.point).distance(@input_point.point)<20 ?
          way_point_pair : nil
      Rescape::Config.log.info("#{@active_way_point_pair.inspect}") if @active_way_point_pair
    end
  end



  def onLButtonUp(flags, x, y, view, demoing=false)
    return if @demo_mode && !demoing
    @input_point.pick(view, x, y)
    # If the user clicks on the middle of an edge, it means they want to reassociate it to a new way_point_pair
    active_edge = get_hover_edge(@input_point)
    if (active_edge)
      @active_edge = active_edge
      @hover_edge = nil
    elsif (@active_edge && @active_way_point_pair)
      # If the user has dragged to a way_point_pair reassociate the edge to the way_point_pair
      Rescape::Config.log.info("Associating edge #{@active_edge.inspect} to way_point_pair #{@active_way_point_pair.inspect} or its reverse" )
      # Find the way_grouping of the edge
      way_grouping = Entity_Map.way_grouping_of_entities(active_travel_network, [@active_edge])
      # Store the old way_point_pair of the edge
      old_way_point_pair = @active_edge.way_point_pair(way_grouping)
      # Associate the edge to the new way_point_pair
      if (@active_way_point_pair != old_way_point_pair && @active_way_point_pair.reverse != old_way_point_pair)
        way_point_pair = @active_edge.associate_to_way_point_pair_or_reverse!(way_grouping, @active_way_point_pair)
        # Invalidate the surface_component cache since we reassociated an edge
        way_grouping.surface_component.invalidate()
        # Update the local hash data
        @edge_to_way_point_pair[@active_edge] = way_point_pair
        if old_way_point_pair
          deleted = @way_point_pair_to_ordered_edges_by_way_grouping[way_grouping][old_way_point_pair].delete(@active_edge)
          Rescape::Config.log.info("Deleted edge #{@active_edge.inspect} from way_point_pair #{old_way_point_pair.inspect}") if deleted
          raise ("Failed to deleted edge #{@active_edge.inspect} from way_point_pair #{old_way_point_pair.inspect}") unless deleted
        end
        @way_point_pair_to_ordered_edges_by_way_grouping[way_grouping][way_point_pair] = get_sorted_edges_when_possible(way_grouping.entity_map, way_point_pair)

        Rescape::Config.log.info("Associated edge #{@active_edge.inspect} to way_point_pair #{way_point_pair.inspect}")
      else
        Rescape::Config.log.info("No change in association")
      end

      @active_edge = nil
      @hover_edge = nil

    else
      return
    end
  end

  def get_hover_edge(input_point)
    way_grouping = Entity_Map.way_grouping_of_input_point(active_travel_network, input_point)
    return nil unless @way_groupings && @way_groupings.member?(way_grouping)
    way_grouping.entity_map.closest_edge_to_point(@input_point.position, self.class.pixels_to_length(PROXIMITY_THRESHOLD))
  end

  def draw view
    return unless @way_point_pair_to_ordered_edges_by_way_grouping

    # Draw edges that don't associate to any way_point_pair even after the associating is attempted
    @edge_to_way_point_pair_per_way_grouping.each {|way_grouping, hash|
      hash.each {|edge, way_point_pair|
        unless (way_point_pair)
          draw_x(view, edge, way_grouping)
        end
      }
    }

    # Draw the way_point_pairs
    view.line_width = 3
    view.line_stipple = ""
    # Hash each way_point_pair with its reverse version and take unique pairs
    @way_groupings.each {|way_grouping|
      way_grouping.all_way_point_pairs.flat_map {|way_point_pair|
        [way_point_pair, way_point_pair.reverse]
      }.uniq_by_map {|way_point_pair|
        way_point_pair.unordered_hash_key
      }.each {|way_point_pair|
        # Highlight the way_point_pair that is active if there is one
        view.drawing_color = @active_way_point_pair && way_point_pair.points_match?(@active_way_point_pair) ? 'orange' : 'yellow'
        view.draw_line(self.class.adjust_z(way_point_pair.points, way_grouping.surface_component.max_z))
        view.draw_points(self.class.adjust_z([way_point_pair.middle_point], way_grouping.surface_component.max_z), 10, 2, "yellow")
      }
    }

    # Draw lines from the middle of each edge to their associated way_point_pair
    @way_point_pair_to_ordered_edges_by_way_grouping.each {|way_grouping, hash|
      hash.each {|way_point_pair, edges|
        edges.each_with_index {|edge, index|
          v = edge.middle_point.vector_to(way_point_pair.middle_point)
          almost_v = v.clone_with_length(v.length-50)
          view.draw_points(self.class.adjust_z([edge.middle_point], way_grouping.surface_component.max_z), 10, 3, 'red')
          if (edge==@active_edge || edge==@hover_edge)
            view.drawing_color = 'orange'
            draw_line(view, edge.points, way_grouping.surface_component.max_z)
            view.drawing_color = 'blue'
            draw_line(view, [edge.middle_point, edge==@active_edge ? @input_point.point : way_point_pair.middle_point], way_grouping.surface_component.max_z)
            if (edge==@active_edge)
              view.draw_points(self.class.adjust_z([@input_point.point]), 10, 3, 'green')
            end
          else
            view.drawing_color = 'blue'
            draw_line(view, [edge.middle_point, way_point_pair.middle_point], way_grouping.surface_component.max_z)
            view.draw_points(self.class.adjust_z([edge.middle_point.transform(almost_v)], way_grouping.surface_component.max_z), 10, 3, 'green')
          end
        }
      }
    }
  end
  
  def draw_line(view, line, way_grouping)
    view.line_width = 3
    view.line_stipple = ""
    view.draw_polyline(self.class.adjust_z(line, way_grouping))
  end

  def draw_x(view, edge, way_grouping)
    self.class.set_status_text("Edges with X could not be associated to ways.")
    view.line_width = 3
    view.line_stipple = ""
    # Create a vector to make an x based on the edge length or a default length if it's 0
    length = self.class.pixels_to_length(20)
    vector = edge.vector.length > 0 ?
        edge.orthogonal(true).clone_with_length(length) :
        Geom::Vector3d.new(10,10,0).clone_with_length(length)
    view.drawing_color = 'red'
    view.draw_polyline(self.class.adjust_z([edge.start.position.transform(vector), edge.end.position.transform(vector.reverse)], way_grouping.surface_component.max_z))
    view.draw_polyline(self.class.adjust_z([edge.start.position.transform(vector.reverse), edge.end.position.transform(vector)], way_grouping.surface_component.max_z))
  end
end