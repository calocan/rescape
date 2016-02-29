# Provides basic extensions to high-level Sketchup methods
module Basic_Utils

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Class_Methods)
  end

  def active_travel_network
    Rescape::Setup.travel_networks[active_model.unique_id].or_if_nil{
      # This only is needed for the default model that loads, because Sketchup doesn't trigger the application observer
      Application_Observer.get_or_create_travel_network(travel_networks, active_model)
    }
  end

  def selection
    Sketchup::active_model.selection
  end

  def active_model
    Sketchup::active_model
  end

  module Class_Methods

    # Pick the input_point based on the reference_input_point
    def pick_input_point_with_reference(view, input_point, reference_input_point, x, y)
      if (reference_input_point)
        input_point.wrapped_pick(view, x, y, reference_input_point)
      else
        input_point.wrapped_pick(view, x, y)
      end
    end

    def curve_or_make_curve(entities, edge)
        edge.curve ? edge.curve : entities.add_curve([edge.start.position, edge.end.position])[0].curve
    end

    # Looks in the rescape resources directory for a file under the given sub directory
    # Returns nil if the file does not exist
    def get_resource_file(resource_sub_dir, file, check_existence = false)
      path="#{Rescape::Config::RESOURCES_DIR}/#{resource_sub_dir}/#{file}"
      raise "Resource file #{path} does not exist" if check_existence && !File.exists?(path)
      path
    end

    def get_or_create_resource_sub_directory(resource_sub_dir)
      get_or_create_dir("#{Rescape::Config::RESOURCES_DIR}/#{resource_sub_dir}")
    end

    def get_cache_file(cache_sub_dir, file, check_existence=false)
      path="#{Rescape::Config::CACHES_DIR}/#{cache_sub_dir}/#{file}"
      raise "Cache file #{path} does not exist" if check_existence && !File.exists?(path)
      path
    end

    def get_or_create_cache_sub_directory(cache_sub_dir)
      get_or_create_dir("#{Rescape::Config::CACHES_DIR}/#{cache_sub_dir}")
    end

    def get_or_create_dir(dir)
      if ( !File.exists?(dir) )
        Dir.mkdir(dir)
      end
      dir
    end

    # Returns the top-level resource directory for the rescape plugin
    def get_base_resource_dir()
    # Note that Sketchup defaults to its OWN resource dir if only 'resources' is used for the first argument!
      Sketchup.find_support_file("#{Rescape::Config::RESCAPE_DIR}/resources", "plugins")
    end

    def get_server_file(server_sub_dir, file)
      Sketchup.find_support_file(file, "plugins/#{Rescape::Config::RESCAPE_DIR}/server/public/#{server_sub_dir}")
    end

    # Finds all the Google Earth maps loaded in the model
    # Model is a Sketchup::Model, supply Sketchup.active_model for the current model
    # The only_visible argument is true by default and limits the results to visible maps
    # If groups is supplied only the given groups are searched, rather than all the groups of the given model
    def find_maps(model, only_visible=true, groups=nil)
      (groups || model.entities.find_all {|entity| entity.typename == "Group"}).find_all { |group| (!only_visible || group.visible?) && group.is_map? }
    end

    # Retrieves the coordinates of each map as an array of min longitude, min latitude, max longitude, max latitude
    def get_map_coordinates(model, maps)
      maps.map { |map|
        map_face_vertices = map.entities.detect {|entity| entity.typename == "Face"}.vertices
        map_face_points =  map_face_vertices.map { |vertex|  vertex.position }
        map_face_latlongs = map_face_points.map {|point| model.point_to_latlong [point.x, point.y] }
        lats = map_face_latlongs.map {|point| point.y}
        lons = map_face_latlongs.map {|point| point.x}
        [lons.min.to_f,lats.min.to_f,lons.max.to_f,lats.max.to_f]
      }
    end

    # Finds any group in the given model that represents a Surface_Component's component_instance. This is used to restore way_grouping data when a file is reloaded. The component_instances are identified as such if they contain the 'way_grouping' attribute dictionary.
    # The optional groups parameter limits the groups that are searched to the given groups
    def find_surface_component_instances(model, groups=nil)
      (groups || model.entities.find_all {|entity| entity.typename == "Group"}).find_all { |group| group.is_surface_component_instance? }
    end

    # Generates a simple unique id based on the current time and random
    def simple_unique_id(random)
      time=Time.now
      (time.to_i.to_s + time.usec.to_s).to_i
    end

    # Converts the given number of pixels to a length based on the active view
    def pixels_to_length(pixels)
      Sketchup.active_model.active_view.pixels_to_model(pixels, Geom::Point3d.new(0,0,0))
    end

    # Combines two parallel points sets into one peremeter point set by reversing the second set and forming a loop
    def point_sets_to_perimeter_points(point_set_pair)
      point_set_pair.first + point_set_pair.last.reverse + [point_set_pair.first.first]
    end

    # Given a parent component/model and set of ordered_points that are closed, creates a component
    # definition by creating a group, making it a component, then returning the definition and deleting the component instance
    #   :transform_to_origin, false by default, will transform all points to the origin by the transformation from the first point of ordered_points to the origin. This yields a definition whose axis is set to the first point instead of two the model origin
    #   :no_face, false by default, means no face shall be created, just the component with edges
    #   :keep_instance indicates that the instance create shall remain in the parent, rather than being deleted and its definition returned, which is the default behavior
    #   :explode_instance indicates that the group with the cross section components will be exploded into the parent, false by default. In this case, no definition will be returned
    def dynamic_cross_section(parent, ordered_points, options={})
      internal_dynamic_cross_section(parent, Geom::Point3d.to_simple_pairs(ordered_points), options)
    end

    def dynamic_cross_section_from_data_pairs(parent, data_pairs, options={})
      internal_dynamic_cross_section(parent, data_pairs, options)
    end

    def cross_section_defaults
      {:transform_to_origin=>false, :no_face=>false, :keep_instance=>false, :explode_instance=>false, :transformation=>Geom::Transformation.new}
    end

    def internal_dynamic_cross_section(parent, data_pairs, options)
      options.merge!(cross_section_defaults) {|key, left, right| left}


      # Create an origin transform for the fist point of the first set.
      # We want to draw the points relative to the origin of the parent and then transform them so that the component's horizontal axes are at the level of the points
      transform = options[:transform_to_origin] ?
          Geom::Transformation.new(data_pairs.first.points.first.vector_to([0,0,0])) :
          options[:transformation]

      group = parent.entities.add_group
      data_pairs.each {|data_pair|
        group.entities.add_line(data_pair.points.map {|point| point.transform(transform)})
      }

      unless (options[:no_face])
        # Create all the faces and then get rid of any inner faces. We should be left with one face
        group.entities[0].find_faces
        group.delete_inner_faces!
        raise "The cross section should have one and only one face but had #{group.faces.length}" unless group.faces.length == 1
      end

      if (options[:explode_instance])
        group.explode
      else
        $comp=component = group.to_component
        definition = component.definition
        # Give this surface the ability to cut an opening
        definition.behavior.cuts_opening = true
        definition.behavior.is2d = true
        parent.entities.erase_entities(component) unless options[:keep_instance]
        definition
      end
    end

    # Given a cross_section_component_definition and optionally a component_instance of that definition, create an instance if the component_instance is nil. Otherwise do nothing
    def place_instance(parent, component_or_group, component_instance, full_transformation)
      #Create a new instance if one is not yet defined.
      component_instance ?
          component_instance :
          parent.entities.add_instance(
              component_or_group.kind_of?(Sketchup::Group) ?
                  component_or_group.to_component.definition :
                  component_or_group,
              full_transformation)
    end

  end
end