require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Test_Offsets
  include Basic_Utils
  def initialize()
    raise "global travel network is nil" unless active_travel_network
    @travel_network = Rescape::Setup.travel_network
  end

  def test_all
    way_grouping = @travel_network.way_grouping_of_way_class(Street)
    solutions = way_grouping.solve_all_shortest()
    solutions.each{|ij, solution|
      (i,j) = ij
      puts "Shortest for %s is %s" % [ [i.name,j.name].inspect, solution[:path].map{|c| c.name}.inspect]
    }
  end
end