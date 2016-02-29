# Loads external way data.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'tools/tool_utils'
require 'utils/Array.rb'
require 'utils/Way_Importer.rb'
require 'utils/basic_utils.rb'
require 'wayness/Travel_Network.rb'
require 'find'

class Way_Loader_Tool
  include Tool_Utils

  # Initialize the tool to either load from the Google Earth maps that are present, from a given selection, or
  # from the given coordinates
  def initialize(travel_networks, load_method_key=:load_travel_network_based_on_map, load_args=nil)
    @travel_networks = travel_networks
    @load_method = self.method(load_method_key)
    @load_args = load_args
    @model = Sketchup.active_model
    @entities = Sketchup.active_model.entities
  end

  def activate
    self.class.set_status_to_message(:loading)
    @model.start_operation(self.class.name, true)
    draw_ways()
    @model.commit_operation()
    self.pop_tool()
  end

  # Load and draw all the ways based on the @load_method and add them to the travel network
  # Duplicate ways will be rejected by the travel network
  def draw_ways
    load_travel_network()
    Rescape::Config.log.info("Drawing travel network")
    active_travel_network.draw
    Rescape::Config.log.info("Finished drawing travel network")
    nil
  end

  # Load ways based on the @load_method and optional @load_args
  def load_travel_network()
    if (@load_args)
      @load_method.call(*@load_args)
    else
      @load_method.call()
    end
  end

  # Add ways to the travel network based on the coordinates of all Google Satellite Images present
  # This is the default way to load ways and launches a process on the external server to do so.
  # If the external server fails it resorts to local
  def load_travel_network_based_on_map
    selected_maps = @model.selection.find_all {|group| group.typename=='Group' && group.is_map?}
    begin
      active_travel_network().incorporate(selected_maps.length>0 ?
                                    Way_Importer::get_data_from_maps(selected_maps, true) :
                                    Way_Importer::get_data_from_maps(nil, true))
    rescue
      active_travel_network().incorporate(selected_maps.length>0 ?
                                              Way_Importer::get_data_from_maps(selected_maps, false) :
                                              Way_Importer::get_data_from_maps(nil, false))
    end
  end

  # Add ways to the travel network based on the given user selection
  # This is a way to load ways for testing
  def load_travel_network_from_selection
    edges = @model.selection.find_all{|e| e.typename=="Edge"}
    active_travel_network.incorporate(edges.map {|edge|
      Basic_Utils::curve_or_make_curve(@entities,edge)}.uniq.map{|curve|
      Street.new(curve.vertices.map {|vertex| vertex.position}, {'name'=>"Way %s" % curve.hash, 'highway'=>'secondary'})
    })
  end

  # Add ways to the travel network based on the given underscore-separated coordinate string
  # This is a way to load ways for testing, especially when reloading an existing cached file of data
  # string example: -71.0918_42.3792_-71.0879_42.3818
  def load_travel_network_based_on_file(coordinates_string)
    coordinates = coordinates_string.split('_')
    lambda { active_travel_network.incorporate(Way_Importer::get_data_for_coordinates(coordinates)) }
  end

  # Test method to only draw the way center lines, which are not normally drawn
  def test_load_travel_network
    load_travel_network
    active_travel_network.draw_center_lines
    nil
  end

  # Test method to draw the continuous ways without combining all continous ways to make a surface
  def test_get_continuous_ways
    load_travel_network
    active_travel_network.way_class_to_grouping.map {|way_type, ways|
      linked_ways = ways.linked_ways
      linked_ways.get_continuous_way_sets
    }
    nil
  end

  UI_MESSAGES = {
      :title =>
          {:EN=>"Load ways based on Google Earth images",
           :FR=>"Téléchargez des voies répresentées par les images de Google Earth"},
    :tooltip =>
      {:EN=>"Load ways based on Google Earth images",
       :FR=>"Téléchargez des voies répresentées par les images de Google Earth"},
    :loading =>
      {
       :EN=>"Loading ways, please wait (this may take several minutes)",
        :FR=>"Attendez, s.v.p, lorsque les voies téléchargent (ceci pouvait durer quelques minutes)"
      }
  }

  def self.messages
    UI_MESSAGES
  end

end