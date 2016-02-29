require "test/unit"
#require "../shortest_path"
#require "../Array"

class Test_Shortest_Path < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Fake test
  def test_shortest_path
    list = [{:node=>1, :neighbors=>[2,3,4], :weight=>1}, {:node=>2, :neighbors=>[5,6,7], :weight=>2}, {:node=>3, :neighbors=>[5,6,7], :weight=>3}, {:node=>5, :weight=>5, :neighbors=>[]}]
    shortest_path = Shortest_Path.new(list,
                                      lambda {|current_item, next_item| current_item[:weight] + next_item[:weight]},
                                      lambda {|item|
                                        item[:neighbors].map{|neighbor_id| list.find {|remaining_item|
                                          remaining_item[:node]==neighbor_id}}} )
    puts shortest_path.solve([list.first, list.last]).find{|hash| hash[:item][:node]==5}.inspect
  end

  def test_all
    list = [{:node=>1, :neighbors=>[2,3], :weight=>1}, {:node=>2, :neighbors=>[5], :weight=>2}, {:node=>3, :neighbors=>[5], :weight=>3}, {:node=>5, :weight=>5, :neighbors=>[]}]
    shortest_path = Shortest_Path.new(list,
                                      lambda {|current_item, next_item| current_item[:weight]},
                                      lambda {|item|
                                        item[:neighbors].map{|neighbor_id| list.find {|remaining_item|
                                          remaining_item[:node]==neighbor_id}.as_dual_way}} )
    solutions = shortest_path.solve_all()
    solutions.each{|ij, solution|
      (i,j) = ij
      puts "Shortest for %s is %s" % [ [i[:node],j[:node]].inspect, solution[:path].map{|c| c[:node]}.inspect]
    }
  end

end