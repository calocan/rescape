require "test/unit"
require 'config/config'
require 'utils/point3d'
require 'utils/vector3d'
require 'utils/array'
require 'utils/simple_pair'

class Test_Data_Pair_Class_Methods < Test::Unit::TestCase

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

  def test_pairs_up_to_point()
    points = [[0,0,0], [10,0,0], [20,0,0], [30,0,0]]
    data_pairs = points.map_with_subsequent {|point1, point2|
      Simple_Pair.new([Geom::Point3d.new(*point1), Geom::Point3d.new(*point2)])
    }
    point = Geom::Point3d.new(22,5,0)
    expected_connector_pair = data_pairs.last.clone_with_new_points([data_pairs.last.points.first, point])
    # Test with include_connector=false. We expect just the first two data_pairs
    assert_equal(data_pairs[0..1],
                 Simple_Pair.pairs_up_to_point(data_pairs, point, false))
    # Test with include_connector=false. We expect just the first two data_pairs and a connector pair
    assert_equal(data_pairs[0..1]+[expected_connector_pair],
                 Simple_Pair.pairs_up_to_point(data_pairs, point, true))
  end
  def test_pairs_from_point()
    points = [[0,0,0], [10,0,0], [20,0,0], [30,0,0]]
    data_pairs = points.map_with_subsequent {|point1, point2|
      Simple_Pair.new([Geom::Point3d.new(*point1), Geom::Point3d.new(*point2)])
    }
    point = Geom::Point3d.new(11,5,0)
    expected_connector_pair = data_pairs.last.clone_with_new_points([point, data_pairs.last.points.first])
    # Test with include_connector=false. We expect just the first two data_pairs
    assert_equal(data_pairs[2..2],
                 Simple_Pair.pairs_from_point(data_pairs, point, false))
    # Test with include_connector=false. We expect just the first two data_pairs and a connector pair
    assert_equal([expected_connector_pair]+data_pairs[2..2],
                 Simple_Pair.pairs_from_point(data_pairs, point, true))
  end
  def test_fuse_pair_sets
    points1 = [[10,0,0], [20,0,0], [30,0,0]]
    data_pairs1 = points1.map_with_subsequent {|point1, point2|
      Simple_Pair.new([Geom::Point3d.new(*point1), Geom::Point3d.new(*point2)])
    }

    points2 = [[0,0,0], [10,0,0], [20,0,0]]
    data_pairs2 = points2.map_with_subsequent {|point1, point2|
      Simple_Pair.new([Geom::Point3d.new(*point1), Geom::Point3d.new(*point2)])
    }
    puts Simple_Pair.fuse_pair_sets(data_pairs1, data_pairs2).inspect
  end
end