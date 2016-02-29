require "test/unit"
require "utils/sorting"
require "utils/Array"

class MyTest < Test::Unit::TestCase

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

  def test_make_chains
    x = Sorting::make_chains([1,2,3,4,5], lambda {|last_match, item| last_match + 2 == item} )
    assert_equal([[1,3,5], [2,4]], x)
    x = Sorting::make_chains([1,2,3,4,5], lambda {|last_match, item| last_match+5  == item} )
    assert_equal([[1],[2],[3],[4],[5]], x)
  end


end

