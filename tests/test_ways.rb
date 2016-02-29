require 'utils/Array.rb'
require 'utils/Way_Importer.rb'
require 'utils/basic_utils.rb'
require 'wayness/Travel_Network.rb'
require 'find'

class Test_Ways
  include Basic_Utils

  attr_reader :load_method, :travel_network
  attr_writer :load_method
  

  def initialize
    @model = Sketchup.active_model
    @entities = Sketchup.active_model.entities
    @load_method = self.method(:load_travel_network_based_on_map)
    reset
  end

  def reset
    raise "active_travel_network is undefined, call Rescape::Setup.reset" unless Rescape::Setup.travel_network
    @travel_network = active_travel_network()
  end
  
  def load_travel_network
    @load_method.call
  end
  
  def load_travel_network_based_on_map 
     @travel_network.incorporate(Way_Importer::get_data_from_maps())
  end
  def set_from_map
     @load_method = self.method(:load_travel_network_based_on_map)
  end

  def load_travel_network_from_selection
    #group = @model.selection.find{|e| e.typename=="Group"}
    #edges = @model.selection.find_all{|e| e.typename=="Group"}.map{|group| group.entities.find_all{|e| e.typename=="Edge"}}.shallow_flatten
    edges = @model.selection.find_all{|e| e.typename=="Edge"}
    @travel_network.incorporate(edges.map {|edge|
      self.class.curve_or_make_curve(@entities,edge)}.uniq.map{|curve|
      Street.new(curve.vertices.map {|vertex| vertex.position}, {'name'=>"Way %s" % curve.hash, 'highway'=>'secondary'})
    })
  end
  def set_from_selection
     @load_method = self.method(:load_travel_network_from_selection)
  end

  def load_travel_network_based_on_file(coordinates)
    lambda { @travel_network.incorporate(Way_Importer::get_data_for_coordinates(coordinates)) }
  end
  def set_from_file(underline_separated_list)
     # file example: -71.0918_42.3792_-71.0879_42.3818
     coordinates = underline_separated_list.split('_')
     @load_method = load_travel_network_based_on_file(coordinates)
  end
  
  def test_draw_center_lines
  load_travel_network
   @travel_network.draw_center_lines
   nil
  end
  
  def test_draw_linked_ways    
    load_travel_network
    @travel_network.way_class_to_grouping.map {|way_type, ways|
      linked_ways = ways.linked_ways
      raise "Ready to draw?"
      linked_ways.draw  
    }
  end

  def test_get_continuous_ways
    load_travel_network
    @travel_network.way_class_to_grouping.map {|way_type, ways|
      linked_ways = ways.linked_ways
      linked_ways.get_continuous_way_sets
    }
  end

  # Load without drawing for cases when the file is re-opened
  def test_load_ways
    load_travel_network
    # Try to find components to associate to the way_grouping
    active_travel_network.way_class_to_grouping.each {|the_class, way_grouping|
    surface_component_instance = @entities.find {|e| e.typename=='Group' and the_class.name==e.get_attribute('way_grouping', 'class')}
      way_grouping.restore_surface_component(surface_component_instance) if surface_component_instance
    }
  end

  def test_draw_ways
    load_travel_network
    @travel_network.draw
    nil
  end
end
