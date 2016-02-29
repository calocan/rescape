# Utilities for gathering and displaying data about the region hashes, which is a cache of data about edges per cubic geometric region.
#
# Author::    Andy Likuski (andylikuski.org)
# License::   Distributes under the same terms as Ruby
module Proximity_Data_Utils

  def movement_flags
    raise "Mixer must implement"
  end

  def input_point
    raise "Mixer must implement"
  end

  # Treat the command and alt keys as the same thing, since Windows can't really use the command (Windows) key
  def command_or_alt
    MK_ALT | MK_COMMAND
  end


  # Test if the command or alt button is held
  def command_down?(movement_flags=movement_flags())
    ((movement_flags & command_or_alt) != 0)
  end

  def command_shift_down?(movement_flags=movement_flags())
    ((movement_flags & command_or_alt) != 0) &&
    ((movement_flags & MK_SHIFT) == MK_SHIFT)
  end

  def command_not_shift_down?(movement_flags=movement_flags())
    ((movement_flags & command_or_alt) != 0) &&
    !((movement_flags & MK_SHIFT) == MK_SHIFT)
  end

  def control_down?(movement_flags=movement_flags())
    ((movement_flags & MK_CONTROL) == MK_CONTROL)
  end

  def shift_down?(movement_flags=movement_flags())
    ((movement_flags & MK_SHIFT) == MK_SHIFT)
  end

  # These modifier key input options display data about the cursor's proximity to eligible data_pairs
  def draw_proximity_data(view, hover_shape=over_what(input_point))
    if (control_down? & shift_down?)
      region_hashes = hover_shape.way_point_pair.region_hashes(Sketchup::Entity::REGION_SIZE)
      region_hashes.map {|key|
        square = make_square_from_region_key(key)
        view.draw_polyline(square)
      }
    end
    if (false)
      # Code to draw cache regions of the current hover shape
      hover_shape.way_grouping.way_point_pair_region_lookup.lookup_hash.keys.find {|key|
        square = make_square_from_region_key(key)
        view.draw_polyline(square)
      }
    end
    if (false)
      region_hashes = input_point.position.region_hashes
      region_hashes.map {|key|
        view.drawing_color = 'green'
        # Draw each region with which the input point associates
        square = make_square_from_region_key(key)
        view.draw_polyline(square)
        # Draw the way_point_pairs associated with the regino
        pairs = hover_shape.way_grouping.way_point_pair_region_lookup.lookup_hash[key]
        if (pairs)
          pairs.each {|pair|
            view.drawing_color = 'orange'
            #view.draw_polyline(pair.points)
            view.drawing_color = 'silver'
            point_on_path = pair.project_point_to_pair(input_point.position)
            view.draw_polyline(input_point.position, point_on_path)
          }
          view.drawing_color = 'black'
          match_pairs = Pair_To_Point_Data.sorted_pairs_to_point_data(pairs, input_point.position)
          match_pairs.each {|pair_data|
            view.draw_polyline(pair_data.pair.points)
          }
          match_pairs.map {|pair_data| pair_data.pair}
        end
      }
    end
  end

  def  make_square_from_region_key(key)
    start = Geom::Point3d.new(*key.split(",").map {|x| Sketchup::Entity::REGION_SIZE*x.to_i})
    [start.offset(Geom::Vector3d.new(0,0,100)), start.offset(Geom::Vector3d.new(Sketchup::Entity::REGION_SIZE, 0, 100)), start.offset(Geom::Vector3d.new(Sketchup::Entity::REGION_SIZE,Sketchup::Entity::REGION_SIZE, 100)), start.offset(Geom::Vector3d.new(0, Sketchup::Entity::REGION_SIZE, 100)), start.offset(Geom::Vector3d.new(0,0,100))
    ]
  end

end