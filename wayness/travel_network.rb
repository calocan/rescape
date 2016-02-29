require 'utils/basic_utils'
require 'wayness/way_grouping'
require 'set.rb'

# Aggregates ways of any times and creates a data structure sorted by the way_definition that pertains to each way.
# An instance represents a complete network of ways of traveling, including walking, driving, and rail.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Travel_Network
  include Basic_Utils
  attr_reader :way_class_to_grouping, :way_class_to_surface_component, :id_to_way_grouping, :way_groupings

  # The ways can be any subclass of Way.
  def initialize(ways)
    # Configure the given ways
    way_class_to_ways = group_ways_by_class(ways)
    # The data structure that relates the primary Way sub classes (e.g. Street) to their Way_Grouping which contains all the way data and points to its visual representation in the model. This is for convenience and may be superseded in the future by way_grouping_by_id
    @way_class_to_grouping = initialize_way_groupings(way_class_to_ways)
    set_way_class_to_grouping(way_class_to_grouping)
  end

  def reinitialize()
    @way_class_to_surface_component = nil
  end

  # Apply the ways of each class to a new Way_Grouping and return a class to Way_Grouping hash
  def initialize_way_groupings(way_class_to_ways)
    way_class_to_ways.map_values_to_new_hash {|way_class, ways|
      Rescape::Config.log.info("Initializing way_grouping for way_class #{way_class.name}")
      $wug=way_grouping = Way_Grouping.new(way_class, ways)
      way_grouping
    }
  end

  # An explicit setter for way_class_to_grouping which calls reinitialize to update dependent data structures
  def set_way_class_to_grouping(way_class_to_grouping)
    Rescape::Config.log.info("Setting way_class_to_grouping with #{way_class_to_grouping.keys.length} way types")
    @way_class_to_grouping = way_class_to_grouping
    @way_groupings = @way_class_to_grouping.values
    @id_to_way_grouping = @way_class_to_grouping.values.to_hash_values {|way_grouping| way_grouping.unique_id}
    reinitialize()
  end

  # Registers a new way_grouping for secondary way_groupings, namely those produced by create offset tools
  def register_way_grouping(way_grouping)
    @id_to_way_grouping[way_grouping.unique_id] = way_grouping
    @way_groupings.push(way_grouping)
  end

  # Returns all Offset_Way_Groupings (such as tram tracks) that were registered with register_way_grouping which are not deleted
  def offset_way_groupings
    @way_groupings.find_all {|way_grouping|
      way_grouping.kind_of?(Offset_Way_Grouping) && !way_grouping.deleted?
    }
  end

  # A utility method to retrieve the last way_grouping that was registered
  def last_registered_way_grouping()
    @way_groupings.last
  end

  # This should be called whenever the user removes a secondary way_grouping, such as by deleting an offset_component
  def remove_way_grouping_by_id(way_grouping_id)
    @id_to_way_grouping[way_grouping_id].clear()
  end

  # Restores all Way_Groupings of this model by searching for Surface_Component component_instances in the model and the Way_Grouping data which they reference
  def restore_way_groupings(model)
    # Find the component_instance entity of any Surface_Components
    surface_component_instances = self.class.find_surface_component_instances(model)
    Rescape::Config.log.info("Found #{surface_component_instances.length} Surface_Component instances for which to restore Way_Grouping data")
    way_class_to_grouping = surface_component_instances.map {|surface_component_instance|
      Rescape::Config.log.info("Found surface_component_instance of hash #{surface_component_instance.hash} for the Way class #{surface_component_instance.way_class_of_surface_component_instance}")
      # Fetch the Way_Grouping.unique_id associated with this instance
      way_grouping_id = surface_component_instance.way_grouping_id
      Rescape::Config.log.info("Surface_component_instance has way_grouping id #{way_grouping_id}")
      # Load the Way_Grouping of this id from the serialized model attribute data
      way_grouping = Way_Grouping.load_from_attribute(model, way_grouping_id)
      Rescape::Config.log.info("Successfully restored way_grouping #{way_grouping.inspect}")
      # Now restore the surface_component of the way_grouping, which is never serialized with the Way_Grouping data
      way_grouping.restore_surface_component(surface_component_instance)
      # Return a hash to be used to construct @way_class_to_grouping
      {way_grouping.way_class => way_grouping}
    }.merge_hashes {|key,a,b| raise "Found duplicate way_groupings of way_class #{key}. Way_Groupings #{a.inspect} and #{b.inspect}"}
    set_way_class_to_grouping(way_class_to_grouping)
  end

  # Sort ways by class and create a class to ways Hash
  def group_ways_by_class(ways)
    ways.to_hash_value_collection {|way| way.class}
  end

  # Combines two travel_networks into a new one
  def combine_with_other_network(travel_network)
    Travel_Network.new(
        [self, travel_network].map {|tn| tn.way_class_to_grouping.values.map {|way_grouping| way_grouping.map}.shallow_flatten}.shallow_flatten)
  end

  # When new ways are provided they must be incorporated into the existing travel network
  # This is not implemented yet.
  def incorporate(new_ways)
    way_class_to_unencountered_ways = group_ways_by_class(new_ways).map_values_to_new_hash {|way_class, ways|
      way_class_to_grouping = self.way_class_to_grouping[way_class]
      (Set.new(ways) - Set.new(way_class_to_grouping || [])).entries
    }
    way_class_to_duplicate_ways = group_ways_by_class(new_ways).map_values_to_new_hash {|way_class, ways|
      way_class_to_grouping = self.way_class_to_grouping[way_class]
      (Set.new(ways) & Set.new(way_class_to_grouping || [])).entries
    }
    Rescape::Config.log.info "Found the following new ways %s" % way_class_to_unencountered_ways.map{|way_class, ways| [way_class, ways.length]}.inspect
    Rescape::Config.log.info "Found the following duplicate ways %s" % way_class_to_duplicate_ways.map{|way_class, ways| [way_class, ways.length]}.inspect

    way_class_to_grouping = initialize_way_groupings(way_class_to_unencountered_ways)
    #TODO merging doesn't work here yet
    way_class_to_grouping = self.way_class_to_grouping.merge(way_class_to_grouping) {|way_class, self_way_grouping, new_way_grouping|
        #self_way_grouping.merge(new_way_grouping)
      new_way_grouping
    }
    set_way_class_to_grouping(way_class_to_grouping)
    Rescape::Config.log.info "Finished incorporating new ways"
  end

  # Associates the primary way_groupings (e.g. Street, Path) with their Way class
  def way_grouping_of_way_class(way_class)
    @way_class_to_grouping[way_class]
  end

  # Returns the primary way_groupings
  def primary_way_groupings
    @way_class_to_grouping.values
  end

  # Re-solves all the way_groupings in the event the remote server went down
  def solve_way_groupings
    primary_way_groupings.each {|way_grouping| way_grouping.solve_all()}
  end

  # Given a way_grouping id for any type of way_grouping that's tracked by the travel network, whether primary ones like Street or secondary ones like a tram offset, this returns the corresponding way_grouping
  def way_grouping_by_id(way_grouping_id)
    @id_to_way_grouping[way_grouping_id].or_if_nil {raise "Expected way_grouping for id #{way_grouping_id} but none was found"}
  end

  # Resolves the way_grouping of a component_instance, either pertaining to an Offset_Surface_Component or standard Surface_Component
  def way_grouping_of_component_instance(component_instance)
    way_grouping_id = component_instance.way_grouping_id
    raise "No way_grouping id found for the given component instance" unless way_grouping_id
    way_grouping_by_id(way_grouping_id)
  end

  def way_class_name_to_way_grouping(way_class_name)
    way_grouping_of_way_class(Kernel.const_get(way_class_name))
  end

  def way_grouping_of_edge(edge)
    way_class_name_to_way_grouping(edge.attribute_dictionary('way')['class'])
  end

  def detect_way_grouping_of_edge(edge)
    associated_neighbor_edge = edge.find_first_associated_neighbor
    raise "No Way_Grouping detected for edge #{edge}" unless associated_neighbor_edge
    way_grouping_of_edge(associated_neighbor_edge)
  end

  def way_point_pair_hash_code_of_edge(edge)
    way_point_pair = edge.attribute_dictionary('way')['way_point_pair']
    raise "Edge %s is not associated to a way_point_pair" % [edge] unless way_point_pair
    way_point_pair
  end

  def way_of_edge(edge)
    way_grouping_of_edge(edge).find_way_point_pair_by_hash(way_point_pair__hash_code_of_edge(edge)).way
  end

  def way_class_to_surface_component
    @way_class_to_surface_component = @way_class_to_grouping.map_values_to_new_hash {|way_class, way_grouping|
      way_grouping.surface_component
    } unless @way_class_to_surface_component
    @way_class_to_surface_component
  end

  # Draws the ways defined by way_class_to_grouping
  def draw
    @way_class_to_grouping.each {|way_class, way_grouping|
      Rescape::Config.log.info("Drawing way_grouping for way_class #{way_class.name}")
      raise "Surface Component of way_grouping #{way_class.name} has parent #{way_grouping.surface_component.parent.unique_id} does not reference the active_model #{Sketchup.active_model.unique_id} as its parent" unless way_grouping.surface_component.parent == Sketchup.active_model
      way_grouping.draw
      Rescape::Config.log.info("Finished drawing way_grouping for way_class #{way_class.name}")
    }
  end

  # For a drawn Travel_Network, returns the Surface_Component instance of the given Way class
  def surface_component_of_way_class(way_class)
    raise "Travel_Network has not been drawn yet." unless @way_class_to_grouping
    @way_class_to_grouping[way_class]
  end

  def draw_center_lines
    @way_class_to_grouping.values.each {|ways| ways.draw_center_lines}
  end

  def erase_center_lines
    @way_class_to_grouping.values.each {|ways| ways.draw_center_lines}
  end

  def inspect
    "#{self.class} with way_to_class_grouping: #{@way_class_to_grouping.inspect}"
  end

  # test method
  def draw_intersections
    @way_class_to_grouping.values.each {|way_grouping|
      way_grouping.draw
    }
    nil
  end

  # Delete Sketchup objects
  def delete_drawing
    @way_class_to_grouping.values.each {|way_grouping|
      way_grouping.delete_drawing
    }
  end

  # Data I/O

  # Saves all the travel network data to the model
  def save
    Sketchup.active_model.add_attribute('rescape', 'travel_network', self.serialize)
  end

  # Load the
  def load

  end

  # Draw the ways loaded in the travel network based on the center lines edges that are selected on the map
  # Do after using Test_Ways.test_draw_center_lines to draw the center_lines
  def draw_loaded_ways_of_selected_center_lines
    self.way_class_to_grouping.values {|way_grouping|
      way_grouping.draw_selected_center_lines
    }
  end

  # Invalidates all way_grouping entity data to force it to regenerate
  def invalidate_all_way_groupings
    way_class_to_grouping.values.each {|way_grouping| way_grouping.invalidate()}
  end
  # Invalidates all surface components
  def invalidate_all_surface_components
    way_class_to_surface_component.values.each {|surface_component| surface_component.invalidate()}
  end

  # Invalidates all the way_grouping entity data and surface_component data, forcing it all to recalculate
  def invalidate_all
    way_class_to_grouping.values.each {|way_grouping|
      invalidate(way_grouping)
    }
  end

  # Invalidate the given way_grouping
  def invalidate(way_grouping)
    way_grouping.surface_component.invalidate()
    way_grouping.invalidate()
  end

  # Purge bad data, such as deleted edges from all way_groupings
  def purge_all
    way_class_to_grouping.values.each {|way_grouping|
      way_grouping.purge()
    }
  end
end