require 'utils/basic_utils'
# A class that applies a follow me operation for the given component definition, and optionally
# a given instance of that definition
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Follow_Me_Surface
  include Basic_Utils

  attr_reader :component_definition, :component_instance
  # Accepts parameters to a create 3D component using a two-dimensional component and the follow-me operation or by using a 3D component that is cloned along a path.
  # parent is the ComponentDefinition or the Model to contain the produced ComponentDefinition
  # component_definition is a Sketchup::ComponentDefinition which may be a 2D cross section defined and centered around the origin of the axes. It may alternatively by a 3D component that will be repeated along a path
  # In the former case the ComponentInstance of the component_definition will be made unique and then expanded to 3D with one or more follow-me operations.
  # component_instance is an optional instantiation of the component_definition, used when a component is created in code rather than loaded, thus allowing instantiation beforehand.
  def initialize(parent, component_definition, component_instance=nil)
    @parent = parent
    @component_definition = component_definition
    # Adjust the insertion point if needed.
    if (!@component_definition.kind_of?(Sketchup::Group) && component_definition.insertion_point != Geom::Point3d.new(0,0,0))
      @component_definition.insertion_point = Geom::Point3d.new(0,0,0)
    end
    @component_instance = component_instance
    $follow = self
  end

  # When the component_definition is 3D, it is rotated to match the path direction according to this vector. Thus if a path segment is in the vector direction [1,0,0] the component won't be rotated at all, but if the path is [0,1,0] it will be rotated 90º
  def default_relative_component_rotation_vector
    Geom::Vector3d.new(1,0,0)
  end

  # Applies a follow-me operation of the component_instance or one based on the cross_section_component_definition
  # along the given points. The created ComponentInstance or predefined one will be translated to
  # center around the first point of points.
  # The options argument is a hash that allows different options, specified by the following symbols. All are optional.
  # :unique_components is true by default, and makes the component instances that are placed along the path into unique components, which is required to have unique follow_me operations. This may have a serious performance hit for repeating elements (i.e. when specifying :draw_length and :space_length) so should it be set false in that case. When false only one component_definition will be used and instances will be scaled along the y axis between each point set's start and end point rather than doing a follow_me operation, which requires a unique component_defintion. Since only a scale is performed this latter option only works for things like railroad ties that that don't need to be curved around a path (railroad ties would of course be equal in y scaling.) An example of repeating elements that need to stretch around a path is sidewalk panels, which need to follow paths around corners.
  # :draw_length and :space_length are optional arguments that work in tandem to make multiple component_instances.
  # Alternatively use :number_of_instances to specify an exact number of instances that are evenly spaced
  # :orientation_vector specifies
  # along the points that are each draw_length long and spaced by space_length. This is used for repeating elements
  # such as railroad ties. The component_instances are placed in a group that is converted to a component.
  # :follow_me is an optional argument that is true by default, but when false expects the component_definition to represent a 3D component that doesn't need stretching. Normally the component_definition is for a 2D component that will be stretched along the points using the follow_me operation.
  # :footprints_only is false by default but if set true makes the method only return the sets of points specifying where each instance will lie along the path. The sets of points returned form the bounding_box of each. This is only relevent for repeating components (i.e. draw_length and space_lenth are set) This is useful for tools that are showing what their operation will do without actually doing it.
  # :already_transformed is false by default and indicates that the component definition is already transformed to the right placed to perform the follow me. Normally the component definition is centered around the origin and needs to be translated and rotated to the start of each point set
  # :angle_tolerance defaults to 179.5 and is the threshold for an angle between three points in a point set before the middle point is removed. This eliminates points that form such a straight angle that they are unneeded for the follow me path. This helps remove extraneous points that significantly slow down the follow me operation
  def along(points, options={})
    # Merge the defaults with the options argument, always accepting the options value when it exists
    chosen_options = {:unique_components=>true, :draw_length=>0, :space_length=>0, :number_of_instances=>0, :orientation_vector=>Geom::Vector3d.new(1,0,0), :follow_me=>true, :footprints_only=>false, :already_transformed=>false, :angle_tolerance=>179.5.degrees}.merge(options) {|key, default, arg| arg}
    # Get rid of points that form a 180 degree angle
    modified_points = Geom::Point3d.eliminate_straight_points(points, chosen_options[:angle_tolerance])
    Rescape::Config.log.info("Eliminated #{points.length-modified_points.length} straight points out of #{points.length}") if modified_points.length != points.length

    Rescape::Config.log.info("Creating follow me surface along #{modified_points.length} points") unless chosen_options[:footprints_only]
    # Create one or more sets of points based on the length and spacing of each segment
    # Each set may be two or more points
    point_sets = make_point_sets(modified_points, chosen_options[:draw_length], chosen_options[:space_length], chosen_options[:number_of_instances])
    result =  along_point_sets(
        point_sets,
        chosen_options)
    Rescape::Config.log.info("Finished creating follow me surface along #{modified_points.length} points") unless chosen_options[:footprints_only]
    result
  end

  # Instantiate the cross section definition and follow it along each point set
  # point_sets are and array of array of points where each sub-array indicates a line to follow with two or more points
  # The following keys are relevant in the chosen_options hash:
  # :unique_components is a boolean that if true means to create a unique component instance for each point_set. If false, the default, only one instance will be created and then translated to the start point of the set and scaled along the y axis to reach the last point of the point_set (intermediate points are ignored)
  # :follow_me indicates that the component definition should be follow_me'd along each point set. If false the component definition will be used as is. The former case applies to 2D component definitions that need to be stretched to 3D, like streetcar tracks. The latter applies to components that are already 3D
  # :footprints_only is false by default and dictates that only the bottom points of where each component will be place shall be returned.
  # :already_transformed is false by default and indicates that the component definition is already transformed to the right placed to perform the follow me. Normally the component definition is centered around the origin and needs to be translated and rotated to the start of each point set. This is only relevant when :unique_components is true and there is only one point_set
  def along_point_sets(modified_point_sets, chosen_options)
    unique_components = chosen_options[:unique_components]
    follow_me = chosen_options[:follow_me]
    footprints_only = chosen_options[:footprints_only]
    already_transformed = chosen_options[:already_transformed]

    raise "point_sets have nil or empty sets: #{modified_point_sets.inspect}" if modified_point_sets.any? {|point_set| !point_set or point_set.length==0}
    # Make a dummy so that we can make the clones below unique (more than one instance must exist for unique to clone the definition)
    identity_transformation = Geom::Transformation.new
    $dummy= dummy = self.class.place_instance(@parent, @component_definition, @component_instance, identity_transformation) unless @component_instance
    $ci=component_instances_or_footprints = unique_components ?
        along_point_sets_with_unique_instances(modified_point_sets, follow_me, already_transformed) :
        (follow_me ?
            along_point_sets_with_scaled_instances(modified_point_sets, footprints_only) :
            along_point_sets_for_3d_component(modified_point_sets, footprints_only))
    @parent.entities.erase_entities(dummy) if dummy
    if (footprints_only)
      component_instances_or_footprints
    else
      component_instances_or_footprints.length==1 ?
        component_instances_or_footprints.only :
        @parent.entities.add_group(component_instances_or_footprints).to_component
    end
  end

  def along_point_sets_for_3d_component(point_sets, footprints_only)
    $pps = point_sets
    Rescape::Config.log.info("Placing 3d components") unless footprints_only

    origin = Geom::Point3d.new
    bounds = @component_instance ? @component_instance.bounds : @component_definition.bounds
    # Create a transformation that transforms the position of the instance or definition to the origin
    component_min_center_to_origin = self.class.min_center(bounds).vector_to(origin.transform(bounds.height/2))
    origin_transformation = Geom::Transformation.translation(component_min_center_to_origin)

    $instances = point_sets.map {|points|
      end_points = [points.first, points.last]

      # Create a transformation that moves transforms the component according to @component_instance's transformation (if @component_instance exists), transforms the component to the origin, rotates the component the between the x axis and the vector of the end_points, then translates it to the first point of the path segment
      $full=main_transformation = make_transformation(default_relative_component_rotation_vector(), end_points)*
          origin_transformation*
          (@component_instance && !@component_definition.kind_of?(Sketchup::Group) ? @component_instance.transformation : Geom::Transformation.new())
      footprints_only ?
         # Simply find the footprint of the component, apply the transformation, and return it as five points forming a closed box
         self.class.min_xy_box(@component_definition.bounds).if_not_nil {|ps|
           ps.map {|p| p.transform(main_transformation)}} :
         # Create a component_instance of normal_definition, placing it based on the transformation to the path and scaling or centering
         self.class.place_instance(@parent, @component_definition, nil, main_transformation)
    }
  end

  # Create a single unique instance and then instantiate its definition and transform it for each point_set
  def along_point_sets_with_scaled_instances(point_sets, footprints_only)
    Rescape::Config.log.info("Follow Me for scaled instances")
    definition_face = @component_definition.entities.find {|e| e.typename=='Face'} or raise "cross_section_component_definitions lacks a single face"
    definition_face_normal = definition_face.normal

    # Make a single unique instance extended along the normal
    normal_points = [Geom::Point3d.new(0,0,0), Geom::Point3d.new(0,1,0)]
    identity_transformation = make_transformation(definition_face_normal, normal_points)
    # If we want to apply follow_me to the component instance, do it here on a normalized instance
    # If we don't need to follow_me just take the existing instance
    # We'll then reuse the instance's definition with different transformations to follow the path
    normal_component_instance =  follow_points(
        self.class.place_instance(@parent, @component_definition, nil, identity_transformation),
        normal_points,
        identity_transformation)
    normal_component_instance.make_unique
    $noid=normal_definition = normal_component_instance.definition
    @parent.entities.erase_entities(normal_component_instance)

    point_sets.map {|points|
      end_points = [points.first, points.last]
      # Create a transformation based on the face of the cross section and the points to follow, first scaling the y component to distance between the points. If follow_me is false, just instead of scaling add a translation to center the 3D component
      vector = end_points.first.vector_to(end_points.last)

      full_transformation = make_transformation(definition_face_normal, end_points)*Geom::Transformation.scaling(1,vector.length,1)
      # Create a component_instance of normal_definition, placing it based on the transformation to the path and scaling or centering
      self.class.place_instance(@parent, normal_definition, nil, full_transformation)
    }
  end

  def self.min_xy_box(bounds)
    [[bounds.min.x, bounds.min.y], [bounds.min.x, bounds.max.y], [bounds.max.x, bounds.max.y], [bounds.max.x, bounds.min.y], [bounds.min.x, bounds.min.y]].map {|pair|
      Geom::Point3d.new(pair[0], pair[1], bounds.min.z)
    }
  end

  def self.min_center(bounds)
    bounds.center.constrain_z(bounds.min.z)
  end

  # Place a component for each point set. Create a new unique component definition for each instance using make_unique. If follow_me is true than the 2D component is stretched the length of the point set. Otherwise it's simply placed at the first point of each point_set. The latter case is probably impractical and along_points_sets_with_scaled_instances should be used instead.
  def along_point_sets_with_unique_instances(point_sets, follow_me, already_transformed)
    # Find the single expected face
    definition_face = @component_definition.entities.find {|e| e.typename=='Face'} or raise "cross_section_component_definitions lacks a single face"
    point_sets.map {|points|
      # Create a transformation based on the face of the cross section and the points to follow
      $full_t = full_transformation = already_transformed ?
          Geom::Transformation.new :
          make_transformation(definition_face.normal, points)
      # Instantiate a new component if no @component_instance is defined and make it unique
      component_instance = self.class.place_instance(
          @parent,
          @component_definition,
          @component_instance,
          full_transformation)
      component_instance.make_unique unless @component_instance
      # Expand the component along the points if desired. The given points will be transformed by full_transformation and places as edges in the component_instance. These edges will be used for the followme operation
      follow_me ?
        follow_points(component_instance, points, full_transformation) :
        component_instance
    }
  end

  # Create a transformation that translates and rotates to match the position and orientation of a point_pair. The definition_face_normal is the normal vector from a face. The rotation rotates the normal vector to match the vector of the point_pair. The first point of the point_pair is also used to create a translation to that point.
  def make_transformation(definition_face_normal, point_pair)
    rotation = make_rotation(definition_face_normal, point_pair[0].vector_to(point_pair[1]))
    # Define a translation to the start of the points
    translation_to_line = Geom::Transformation.translation(point_pair[0])
    # Multiply the matrices, performing rotation followed by translation
    translation_to_line * rotation
  end

  def make_rotation(normal_vector, path_vector)
    # To rotate our cross section, determine the angle between the normal of the face and the first points of the line
    $ang=angle_between = Geometry_Utils.radians_between(Geometry_Utils::CCW_KEY, normal_vector, path_vector)
    Geom::Transformation.rotation(Geom::Point3d.new(0,0,0), Geom::Vector3d.new(0,0,1), angle_between)
  end

  def follow_points(component_instance, points, full_transformation)
    # Explode the curve around the face so that the follow-me doesn't have curved surfaces
    component_instance.definition.entities.find {|e| e.typename=='Edge'}.explode_curve()
    # Place the points withing the instance, transforming their viewspace to match
    $d1=edges = place_curve_within_instance(component_instance, full_transformation, points)
    # Find the face pull it along the edges
    $d2=face = component_instance.definition.entities.find {|e| e.typename=='Face'}
    Rescape::Config.log.info("Begin followme")
    unless (face.followme(edges))
      raise "Followme failed!"
    end
    Rescape::Config.log.info("Finished followme")
    component_instance.definition.entities.erase_entities(edges.reject {|edge| edge.deleted?})
    $blick=component_instance
  end

  # Create sets of points based on the given points that define segments of a line along a curve, each having the length defined by draw_length and spacing by space_length. If draw_length==0 this will just return one set with all the points to represent a single continuous component. If number_of_instances is > 0 it takes precedence and the instances are evenly spaced--it must be >= 3 so that there is one at each extreme and at least one in the middle. If number_of_instances is specified and the component will be stretched using follow_me, then draw_length may be specified (but space_length will be ignored.) For non-stretched components, draw_length may be set to 0
  def make_point_sets(points, draw_length, space_length, number_of_instances)
    total_length = Geom::Point3d.total_length(points)
    # We either want to draw on continuous component or draw continual components
    if (number_of_instances > 0)
      raise "number_of_instances must be >= 3 but was #{number_of_instances}" unless number_of_instances >= 3
      # Divide the path by the number_of_instances-2, since the number given to divide is the number of divide points, and the two end points bring it back up to number_of_instances
      placement_points_with_vectors = Simple_Pair.divide(Simple_Pair.make_simple_pairs(points), number_of_instances-2, true)
      half_length = draw_length.to_f/2
      placement_points_with_vectors.map {|point, vector|
      # Center the component around the divide points
        [-half_length, half_length].map {|length|
          point.transform(vector.clone_with_length(length))
        }
      }
    elsif (draw_length > 0)
      # Given a percent find out which edge and how far from the start of the edge
      # Return the point on the edge
      # Round up the segments. We'll take care of overages
      segments = (total_length / (draw_length+space_length)).round
      # Find the start and end distances based on the full length of the curve for each segment
      segment_start_and_end_distances = (0..segments-1).map {|segment_index|
        segment_start = segment_index*(draw_length+space_length)
        [segment_start,
         segment_start+draw_length]
      }
      # Convert distances to sets of point pairs denoting the start and end of each segment
      segment_start_and_end_distances.map {|start_and_end_distance| points_on_curve(points.map_with_subsequent, start_and_end_distance)}
    else
      # Create a single point set from the points
      [points]
    end
  end
  # Retrieves a point along the curve represented by point_pairs
  # distance_along_curve is the distance along the curve for which to retrieve a point
  # include_intermediate_points indicates that
  # found_point works with include_intermediate_points to tell the recursive call whether a point has been found or not
  def points_on_curve(point_pairs, distances_along_curve, include_intermediate_points=true, found_point=false)
    raise "distance along curve is greater than all the edges combined!" if point_pairs.length==0
    return [] if (distances_along_curve.length==0)
    first_pair = point_pairs.first
    pair_length = first_pair[0].distance(first_pair[1])
    first_distance = distances_along_curve.first
    if (pair_length >= first_distance)
      # If the point lies within the first pair of points
      vector = first_pair[0].vector_to(first_pair[1])
      vector.length = first_distance
      point = first_pair[0].transform(vector)
      # Return the point and recursively iterate on distances_along_curve, modifying the first point pair to start at the found point
      ([point] +
      points_on_curve([[point, first_pair[1]]]+point_pairs.rest,
                      distances_along_curve.rest.map{|distance_along_curve| distance_along_curve-first_pair[0].distance(point)},
                      include_intermediate_points,
                      true)).uniq_by_map {|point| point.hash_point}
    else
      if (found_point && point_pairs.rest.length == 0)
        # This end case handles remaining distance points extending beyond the last point_pair point
        # It ignores remaining points and truncates to the last possible point
        [first_pair[1]]
      else
      # If the point lies within the rest of the points, recursively iterate on the point_pairs and substract the last point_pair distance from all the distances_along_curves
      # If include_intermediate_points is true and a point has already been found, add the first_pair to the point results. This
      # may produce duplicate points if multiple pairs are returned, but they will be singularized
      (((include_intermediate_points and found_point) ? first_pair : []) +
      points_on_curve(point_pairs.rest,
                      distances_along_curve.map{|distance_along_curve| distance_along_curve-pair_length},
                      include_intermediate_points,
                      found_point)).uniq_by_map {|point| point.hash_point}
      end
    end
  end


  # Create a curve from points within the definition of the component instance by translating the points to the viewspace of the component_instance.
  # component_transformation is the transformation that was used to transform the component_instance from the origin, which will be applied in inverse to the points
  # points are Geom::Point3d points in the viewspace coordinates of the component_instance's parent
  def place_curve_within_instance(component_instance, component_transformation, points)
    # Translate the points to the viewspace of the component, which means inversing the transformation
    transformed_points = points.map {|p| p.transform(component_transformation.inverse)}
    component_instance.definition.entities.add_curve(transformed_points)
  end

  def transform_component_instance(component_instance, transformation)
    component_instance.transform!(transformation)
    component_instance
  end
end


