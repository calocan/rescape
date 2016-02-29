# Runs Way_Importer externally to avoid problems in Windows
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'utils/Way_Importer'

class Way_Importer_External
  dimensions = ARGV
  raise "Wrong number of dimensions" unless dimensions.length==4
  way_importer = Way_Importer.new([dimensions.map {|s| s.to_f}])
  way_importer.load_data()
end