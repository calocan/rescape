require 'utils/basic_utils'
class Test_Way_Cases
  include Basic_Utils

  FOOT = 12
  def self.test_simple_roads
    @travel_network = active_travel_network
    @travel_network.incorporate(get_streets(50*FOOT,20*FOOT))
    #@travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  def self.test_touching_roads
    @travel_network = active_travel_network
    @travel_network.incorporate(get_streets(100*FOOT,100*FOOT))
    @travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  def self.test_long_with_too_short_road
    @travel_network = active_travel_network
    @travel_network.incorporate(get_long_and_short_streets(50*FOOT))
    #@travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  def self.test_road_jog
    @travel_network = active_travel_network
    @travel_network.incorporate(get_jogging_streets(50*FOOT))
    @travel_network.draw_intersections
    @travel_network.draw
    @travel_network
  end

  def self.test_overlapping_roads
    @travel_network = active_travel_network
    @travel_network.incorporate(get_streets(110*FOOT,100*FOOT))
    @travel_network.draw_center_lines
    #@travel_network.draw
    @travel_network
  end
  
  def self.test_three_way_intersection
    @travel_network = active_travel_network
    @travel_network.incorporate(get_three_streets(50*FOOT))
    #@travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  
  def self.test_diverging_roads
    @travel_network = active_travel_network
    @travel_network.incorporate(get_diverging_roads(50*FOOT))
    @travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  def self.test_wide_diverging_roads
    @travel_network = active_travel_network
    @travel_network.incorporate(get_diverging_roads(100*FOOT))
    #@travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  def self.test_parallel_roads
    @travel_network = active_travel_network
    @travel_network.incorporate(get_parallel_roads(50*FOOT))
    #@travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  def self.test_obtuse_roads
    @travel_network = active_travel_network
    @travel_network.incorporate(get_obtuse_roads(50*FOOT))
    #@travel_network.draw_center_lines
    @travel_network.draw
    @travel_network
  end
  def self.test_loop_road
    @travel_network = active_travel_network
    @travel_network.incorporate(get_loop_road(50*FOOT))
    @travel_network.draw
    @travel_network
  end

  def self.get_streets(width1, width2)
        [Street.new(
          [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,100*FOOT,0*FOOT)],
          {'name'=>'test_street_name1','highway'=>'secondary','width'=>width1}
          ),
        Street.new(
          [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(0*FOOT,100*FOOT,0*FOOT)],
          {'name'=>'test_street_name2','highway'=>'secondary','width'=>width2})]
  end

  def self.get_long_and_short_streets(width)
        [Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,0*FOOT,0*FOOT)],
             {'name'=>'test_street_name1','highway'=>'secondary','width'=>width}
         ),
         Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(0*FOOT,10*FOOT,0*FOOT)],
             {'name'=>'test_street_name2','highway'=>'secondary','width'=>width}
         ),
        Street.new(
            [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(0*FOOT,-100*FOOT,0*FOOT)],
            {'name'=>'test_street_name3','highway'=>'secondary','width'=>width}
        )
        ]
  end
  def self.get_jogging_streets(width)
        [Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,0*FOOT,0*FOOT)],
             {'name'=>'test_street_name1','highway'=>'secondary','width'=>width}
         ),
         Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(0*FOOT,10*FOOT,0*FOOT)],
             {'name'=>'test_street_name2','highway'=>'secondary','width'=>width}
         ),
         Street.new(
             [Geom::Point3d.new(0*FOOT,10*FOOT,0*FOOT), Geom::Point3d.new(-100*FOOT,10*FOOT,0*FOOT)],
             {'name'=>'test_street_name3','highway'=>'secondary','width'=>width}
         ),
         Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(0*FOOT,-100*FOOT,0*FOOT)],
             {'name'=>'test_street_name4','highway'=>'secondary','width'=>width}
         )
        ]
  end

  def self.get_three_streets(width)
        [Street.new(
          [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,100*FOOT,0*FOOT)],
          {'name'=>'test_street_name1','highway'=>'secondary','width'=>width}
          ),
        Street.new(
          [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(0*FOOT,100*FOOT,0*FOOT), Geom::Point3d.new(50*FOOT,100*FOOT,0*FOOT)],
          {'name'=>'test_street_name2','highway'=>'secondary','width'=>width}
          ),
        Street.new(
        [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(-100*FOOT,-100*FOOT,0*FOOT), Geom::Point3d.new(-100*FOOT,-200*FOOT,0*FOOT)],
          {'name'=>'test_street_name3','highway'=>'secondary','width'=>width}
        )]
  end
  
  def self.get_diverging_roads(width)
        [Street.new(
          [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,-10*FOOT,0*FOOT), Geom::Point3d.new(200*FOOT, -30*FOOT,0*FOOT), Geom::Point3d.new(300*FOOT, -60*FOOT,0*FOOT)],
          {'name'=>'test_street_name1','highway'=>'secondary','width'=>width}
          ),
         Street.new(
          [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,10*FOOT,0*FOOT), Geom::Point3d.new(200*FOOT,30*FOOT,0*FOOT), Geom::Point3d.new(300*FOOT,60*FOOT,0*FOOT)],
          {'name'=>'test_street_name2','highway'=>'secondary','width'=>width}
          )]
  end
  def self.get_parallel_roads(width)
        [Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,-10*FOOT,0*FOOT), Geom::Point3d.new(200*FOOT, -30*FOOT,0*FOOT), Geom::Point3d.new(300*FOOT, -60*FOOT,0*FOOT)],
             {'name'=>'test_street_name1','highway'=>'secondary','width'=>width}
         ),
         Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(-100*FOOT,10*FOOT,0*FOOT), Geom::Point3d.new(-200*FOOT,30*FOOT,0*FOOT), Geom::Point3d.new(-300*FOOT,60*FOOT,0*FOOT)],
             {'name'=>'test_street_name2','highway'=>'secondary','width'=>width}
         )]
  end
  def self.get_obtuse_roads(width)
        [Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,-10*FOOT,0*FOOT), Geom::Point3d.new(200*FOOT, -30*FOOT,0*FOOT), Geom::Point3d.new(300*FOOT, -60*FOOT,0*FOOT)],
             {'name'=>'test_street_name1','highway'=>'secondary','width'=>width}
         ),
         Street.new(
             [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(-100*FOOT,00*FOOT,0*FOOT), Geom::Point3d.new(-200*FOOT,20*FOOT,0*FOOT), Geom::Point3d.new(-300*FOOT,60*FOOT,0*FOOT)],
             {'name'=>'test_street_name2','highway'=>'secondary','width'=>width}
         )]
  end
  def self.get_loop_road(width)
    [Street.new(
         [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT, 100*FOOT,0*FOOT)],
         {'name'=>'test_street_name1','highway'=>'secondary','width'=>width}
     ),
     Street.new(
         [Geom::Point3d.new(0*FOOT,0*FOOT,0*FOOT), Geom::Point3d.new(0*FOOT,100*FOOT,0*FOOT), Geom::Point3d.new(100*FOOT,100*FOOT,0*FOOT)],
         {'name'=>'test_street_name2','highway'=>'secondary','width'=>width}
     )]
  end
end
