
# Loads way data (streets, paths, rail, etc) from openstreetmap.org or a cached data source
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'config/config'
require 'utils/basic_utils'
require 'utils/Array'
require 'utils/way_parser'
require 'rexml/document'
require 'wayness/Way.rb'
require 'OSM/objects'
require 'OSM/api'

include REXML

class Way_Importer
  include Basic_Utils

  attr_reader :dimension_sets, :doc_hash, :osm_api
  # dimension_sets are lists of four elements lists, where each list is a float of the west, south, east, north bounding box of a download area. Each box will be downloaded separately and the results combined into Way data.
  def initialize(dimension_sets)
    @dimension_sets = dimension_sets
    @doc_hash = {}
    @osm_api = OSM::API.new(Rescape::Config::XAPI_URI)
  end

  def self.model
    Sketchup.active_model
  end

  # Loads data based on the bounds of the given Google Earth maps in the model
  # The maps must each be a group named "Google Earth Snapshot"
  def self.get_data_from_maps(maps=nil, external=false)
    map_coordinate_sets = self.get_map_coordinates(model, maps || self.find_maps(model))
    if (external)
      external_server = Rescape::Setup.get_remote_server()
      way_importer = external_server.import(map_coordinate_sets)
    else
      way_importer = self.new(map_coordinate_sets)
      way_importer.load_data
    end
    Way_Parser.new(way_importer.doc_hash).parse_ways
  end

 # Loads data for a bounding box of lat/lon coordinates
  def self.get_data_for_coordinates(coordinates)
    Rescape::Config.log.info "Loading data based on coordinates %s" % [coordinates.inspect]
    way_importer = self.new([coordinates])
    way_importer.load_data
    Way_Parser.new(way_importer.doc_hash).parse_ways
  end

  # Creates a readable hash code for a lat/lon bounding box.
  def hash_dimensions(dimensions)
     "data_%s_%s_%s_%s" % dimensions.map {|f| format("%.4f",f)}
  end
  
  # Loads way data for each Google Earth map not yet loaded
  def load_data
      @doc_hash = @dimension_sets.reject { |dimensions| @doc_hash[hash_dimensions(dimensions)]}.map_to_hash(
      lambda {|dimensions| hash_dimensions dimensions},
      lambda {|dimensions|
        file_path = Rescape::Config::RESOURCES_DIR + "/%s.marshal"% [hash_dimensions(dimensions)]
        Rescape::Config.log.info "Loading data for bounding box: West:%s, South:%s, East:%s, North:%s" % dimensions
        osm_database = nil
        if File.exists?(file_path)
          Rescape::Config.log.info "Found data in cache: %s" % [file_path]
          File.open(file_path) do |f|
            osm_database = Marshal.load(f)
          end
        else
          Rescape::Config.log.warn("#{Rescape::Config::XAPI_URI}/map?bbox=#{dimensions[0]},#{dimensions[1]},#{dimensions[2]},#{dimensions[3]}")
          osm_database = @osm_api.get_bbox(*dimensions)
          Rescape::Config.log.info "Data loaded from API. Caching to file #{file_path}"
          File.open(file_path, 'w+') do |f|
            Marshal.dump(osm_database, f)
            Rescape::Config.log.info "Data cached to file: %s" % [file_path]
          end
        end
        osm_database
      })
  end

end