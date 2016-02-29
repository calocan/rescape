require "utils/edge"
require 'utils/pair_region_lookup'
require 'wayness/surface_component_observer'
require 'wayness/surface_component_integrator'
require 'wayness/Way_Component'
require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Surface_Component
  include Surface_Component_Integrator
  include Basic_Utils

  attr_reader :way_grouping, :observer, :parent, :transformation_lambda_wrapper, :way_preprocessor
  # Creates a Surface_Component instance that encapsulates a Sketchup ComponentInstance class--the drawn version of the surface
  # parent is the Sketchup entity within which to place the ComponentInstance.
  # way_grouping holds all the way data from which to draw the ComponentInstance
  # transformation_lambda_wrapper is an optional Lambda_Wrapper that describes how to translate the way center line to the outside of the surface. It is a lambda function that accepts as an argument a pair of points to translate. It normally transforms orthogonal to the line of the pair (see Geometry_Utils:get_offset_intersection)
  # component_instance is an optional pre-created ComponentInstance to use rather creating a new one.
  def initialize(parent, way_grouping, transformation_lambda_wrapper=nil, way_preprocessor=nil, component_instance=nil)
    @parent = parent
    @way_grouping = way_grouping
    @transformation_lambda_wrapper = transformation_lambda_wrapper
    @way_preprocessor=way_preprocessor
    # Create an observer to track changes to the component_instance. It will later track all the edges as they are created.
    #@observer = Surface_Component_Observer.new(self)
    create_component_instance()
    set_attributes()
  end

  # Creates the component_instance unless a non-nil value is passed to the method
  def create_component_instance(component_instance=nil)
    unless (component_instance)
      @component_instance = parent.entities.add_group()
      @component_instance.add_observer(@observer)
      @component_instance
    end
  end

  # Get the highest point of the component_instance, used for drawing paths on top of the component
  def max_z
    component_instance.definition.entities.length > 0 ?
      component_instance.bounds.max.z :
      nil
  end

  # Sets attributes of the component_instance so that it can be reassociated to the underlying way_grouping data when needed, such as after the file is saved and reloaded. Way_Grouping data is stored as attribute data of the model so that if the component_instance is erased, the data can be maintained and used to recreate the surface_component.
  def set_attributes
    @component_instance.set_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY,Way_Grouping::ATTRIBUTE_WAY_CLASS_KEY, Marshal.dump(@way_grouping.way_class))
    @component_instance.set_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY,Way_Grouping::ATTRIBUTE_ID_KEY, @way_grouping.unique_id)
  end

  # Determines whether or not the component instance has been drawn with entities.
  # Returns false if it doesn't yet exist, has been deleted or is empty
  def component_instance_rendered?
    @component_instance && !@component_instance.deleted? && @component_instance.definition.entities.length > 0
  end

  # Returns @component_instance unless it was deleted, in which case it searches the parent entities for an existing one. This is needed after a delete/undo
  def component_instance(no_recreated_allowed=false)
    if (component_instance_deleted?)

      if (no_recreated_allowed)
        raise "The component instance was deleted unexpectedly #{component_instance}"
      end

      Rescape::Config.log.warn("Lost component_instance, recovering")
      # The component_instance will either be a Group or Component_Instance
      @component_instance = @parent.entities.find {|entity|
        test_entity = entity.kind_of?(Component_Instance_Behavior) ?
            entity : # Group
            (entity.kind_of?(Component_Behavior) && (entity.instances.length == 1) ? # ComponentDefinition, find sole ComponentInstance
                entity.instances.only :
                nil)
        test_entity &&
        test_entity.associated_to_way_grouping? &&
        test_entity.associated_way_grouping(active_travel_network()) == @way_grouping
      }
      Rescape::Config.log.warn("Found component_instance #{@component_instance.inspect}") if @component_instance
      invalidate()
    else
      @component_instance
    end
  end

  def component_instance_deleted?
    !@component_instance || @component_instance.deleted?
  end

  # Invalidates any caches after an update to @component_instance occurs
  def invalidate
    @way_grouping.entity_map.invalidate()
  end

  # The edges of the surface_component associated to the way_grouping
  def associated_edges
    self.edges {|edge|
      edge.associated_to_way_point_pair?()}
  end

  # Returns the edges of the component_instance if it exists, and optionally takes a block to filter each edge
  def edges
    filter = lambda {|edge| block_given? ? yield(edge) : edge}
    component_instance ?
        component_instance.definition.entities.find_all {|entity|
          entity.typename=='Edge' and filter.call(entity)
        } :
        []
  end

  # Gets the side_point representation of the edges
  def side_points
    @way_grouping.side_point_manager(@transformation_lambda_wrapper)
  end

  # Gets the side_point_pair representation of the edges
  def side_point_pairs
    @way_grouping.side_point_manager(@transformation_lambda_wrapper).side_point_pairs
  end

  # Generate the Way_Component based on the points of the continuous_way
  def make_way_component(continuous_ways)
    Way_Component.new(self, @way_grouping, continuous_ways, @transformation_lambda_wrapper, @way_preprocessor)
  end

  # Applies the desired block to map the set of way_component instances
  def map_way_components()
    block = block_given? ? lambda {|way_component| yield(way_component)} : lambda {|way_component| way_component}
    way_components = @way_grouping.continuous_way_sets.map {|continuous_ways|
      make_way_component(continuous_ways)
    }.compact
    way_components.map {|way_component|
      block.call(way_component)}
  end

  def get_perimeter_point_sets
    map_way_components {|way_component| way_component.get_perimeter_points}
  end

  # Returns only the way_components containing one or more of the given ways
  # The optional block takes the way_component and matching ways for each way_component that matches and maps it to something else to be returned.
  def get_way_components_of_ways(ways)
    block = block_given? ? lambda {|way_component, matching_ways| yield(way_component, matching_ways)} : lambda{|way_component, x| way_component }
    map_way_components {|way_component|
      way_component.continuous_ways.matching_ways(ways).if_not_empty {|matching_ways|
        [block.call(way_component, matching_ways)]
      }
    }.shallow_flatten
  end

  # Returns only the perimeter point sets associated with the given ways
  def get_perimeter_point_sets_of_ways(ways)
    get_way_components_of_ways(ways) {|way_component, matching_ways|
      way_component.get_perimeter_points_of_ways(matching_ways)
    }
  end

  # Returns all perimeter data_pairs as sets
  def get_perimeter_data_pair_sets()
    map_way_components {|way_component|
      way_component.get_perimeter_data_pairs()
    }
  end

  # Returns only the perimeter data_pairs associated with the given ways
  def get_perimeter_data_pair_sets_of_ways(ways)
    get_way_components_of_ways(ways) {|way_component, matching_ways|
      way_component.get_perimeter_data_pairs_of_ways(matching_ways)
    }
  end

  # Draw populates the @component_instance with entities
  # TODO rename to something like render_ways
  def draw
    component_instance = component_instance(true)
    Sketchup::active_model.start_operation(self.class.name, true)
    map_way_components {|way_component|
      way_component.draw}
    # Create faces and explode curves
    self.edges.each {|edge|
      if edge.typename=='Edge'
        edge.find_faces # create any the faces that ddn't form automatically
        edge.explode_curve
        # Delete any zero length edges that occasionally get created by odd angles
        component_instance.definition.entities.erase_entities(edge) if edge.vector.length==0
      end
    }
    # Delete inner faces
    component_instance.definition.delete_inner_faces!()

    # Complete the face by coloring it, etc.
    component_instance.definition.entities.each {|face|
      if (face.typename=='Face')
        face.complete_face(@way_grouping.way_class.way_color)
        face.associate_to_way_grouping!(@way_grouping)
      end
    }
    Sketchup::active_model.commit_operation()
    draw_way_text()
    component_instance.definition.entities.each {|e| e.add_observer(@observer)}
    component_instance.definition.entities
  end


  def draw_way_text
    # Draw the way names as 2D text if the way has a name
    # Add the layer if it doesn't exist
    Sketchup::active_model.start_operation(self.class.name, true)
    active_model.layers.add(Way::WAY_TEXT_LAYER)
    @way_grouping.dual_ways.map {|dual_way|
      way = dual_way.linked_ways.first.way
      if (way.name != Way::UNIDENTIFIED_WAY && way.length >= 2)
        # Get the middle of the way, the middle of the middle way_point_pair if even, or else the middle way point
        text=component_instance.definition.entities.add_text(way.name, way.true_middle_point, Geom::Vector3d.new(0,0,0))
        text.display_leader=false
        text.material='purple'
        text.layer=Way::WAY_TEXT_LAYER
      end
    }.compact
    Sketchup::active_model.commit_operation()
  end

  # Return the faces of the component_instance
  def faces
    component_instance.definition.entities.find_all {|face| face.typename=='Face'}
  end

  # Associates the given edge to the best given way_point_pair. This should only be called internally since the cache needs to be invalidated afterward
  def associate_edge_to_way_point_pair(edge, way_point_pairs=[])
    unless (edge.associated_to_way_point_pair?())
      # Find the closest pairs to each point of the edge using the region cache
      pairs = way_point_pairs.or_if_empty {edge.points.map {|point| @way_grouping.entity_map.edge_region_lookup().closest_pair_to_point(point).way_point_pair(@way_grouping)}}
      # Associate the edge to one of the pairs
      edge.associate_to_best_way_point_pair!(@way_grouping, pairs)
    else
      edge.way_point_pair(@way_grouping)
    end
  end

  # Remove the physical presence of the Surface_Component in preparation for deleting this instance
  def erase_from_model(model)
    model.entities.erase_entities(@component_instance) if @component_instance && !@component_instance.deleted?
  end

  # Returns the transformation from the given Surface_Component to this Surface_Component for the internal entities of the given Surface_Component. This transformation would transform those entities by their own component's transformation, thus transforming their relative position with the component to the real world coordinate, and then they are transferred to the coordinates of this component
  def transformation_to_this_component(offset_surface_component)
    self.component_instance.transformation * offset_surface_component.component_instance.transformation
  end

  def inspect
    "#{self.class} of way_grouping #{@way_grouping.inspect}" + (@transformation_lambda_wrapper ? " with transformation properties #{@transformation_lambda_wrapper.properties.inspect}" : "") + " of hash #{self.hash}"
  end
end