require "wayness/surface_definitions/aerial_surface_definition"
require "wayness/surface_definitions/ground_surface_definition"
require "wayness/surface_definitions/rail_surface_definition"
require "wayness/surface_definitions/water_surface_definition"
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Way_Surface_Definitions_Config
  @@way_surface_definitions = [Ground_Surface_Definition, Rail_Surface_Definition, Water_Surface_Definition, Aerial_Surface_Definition]
  def self.get_surface_class (tags)
    @@way_surface_definitions.find { |way_surface_definition| way_surface_definition.surface_keys.find {|key| tags.member?(key)} != nil }
  end
end