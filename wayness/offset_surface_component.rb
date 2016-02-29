# This class extends surface component in order to represent an offset component (e.g. streetcar tracks) as a Surface_Component
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'wayness/surface_component'
require 'wayness/offset_way_component'
require 'utils/pseudo_vertex'
require 'utils/entity_associating'

class Offset_Surface_Component < Surface_Component

  def initialize(parent, way_grouping, transformation_lambda_wrapper=nil, way_preprocessor=nil, component_instance=nil)
    super(parent, way_grouping, transformation_lambda_wrapper, way_preprocessor, component_instance)
  end

  def create_component_instance(component_instance=nil)
    unless (component_instance)
      @component_instance = parent.entities.add_group().to_component
      @component_instance.add_observer(@observer)
      @component_instance
    end
  end

  def draw
    entities = super()
    # Hide our surface since it's just used to define edges
    ([self.way_face] + self.way_face.edges).each {|entity|
      entity.visible=false
    }
  end

  # Retrieves the way face of the surface component. Offset_Surface_Components should only have one face based on drawing the ways.
  def way_face
    faces.only("#{self.inspect} didn't have a way_face'")
  end

  # Offset Surface Components probably don't need way_text
  def draw_way_text
    #noop
  end

  # Returns all the perimeter data pairs. These can be used to represent the outline of the surface, whether for a looped surface or not.
  def all_perimeter_data_pairs
    get_perimeter_data_pair_sets.shallow_flatten
  end

  # Generate the Way_Component based on the points of the continuous_way
  def make_way_component(continuous_ways)
    Offset_Way_Component.new(self, @way_grouping, continuous_ways, @transformation_lambda_wrapper, @way_preprocessor)
  end

  # Create the subcomponents by calling the block with the @component_instance.definition as the argument
  # The sub_components will be added to this definition.
  def create_components(&block)
    # Call the block to create the sub_components within the surface_component.component_instance
    sub_components = block.call(@component_instance.definition)
    # Mark each sub component with the way_grouping id so that when the user hovers over one it will be associated to this way_grouping
    sub_components.each {|sub_component|
      sub_component.associate_to_way_grouping!(self.way_grouping)
    }
    # Draw the main surface of the way to act as the edges
    self.draw

    # Mark this as an offset_component
    @component_instance.set_attribute('offset_component', 'offset_tool_class', 'true')
  end

  def intersects_offset_surface_component?(offset_surface_component)
    transformation = transformation_to_this_component(offset_surface_component)
    !self.component_instance.bounds.intersect(offset_surface_component.component_instance.bounds).empty? &&
    self.way_face.intersects?(offset_surface_component.way_face, transformation)
  end

  # Adds a cut_face as a 2D ComponentInstance if the give Offset_Surface_Component's outline intersects this instance's offset_component
  def add_cut_face(offset_surface_component)
    if (intersects_offset_surface_component?(offset_surface_component))
      Rescape::Config.log.info("#{self.inspect} intersects with #{offset_surface_component.inspect}, which has a equal or higher cut priority. Creating a cut path through the former.")
      self.component_instance.add_cut_face_based_on_data_pairs(
          offset_surface_component.all_perimeter_data_pairs,
          way_grouping.offset_configuration.height_of_cut_face,
          transformation_to_this_component(offset_surface_component))
    end
  end

end