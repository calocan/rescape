require 'utils/basic_utils'
require 'client_controller/navigators/start_navigator'
require 'client_controller/navigators/download_navigator'
require 'client_controller/navigators/way_navigator'
require 'client_controller/navigators/streetscape_navigator'
require 'client_controller/navigators/component_navigator'
require 'client_controller/navigators/building_navigator'
require 'client_controller/navigators/report_navigator'
require 'client_controller/navigators/sharing_navigator'

# Creates and manages a model a special Sketchup::Model that shows the user how to use Rescape
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Tutorial
  include Basic_Utils

  attr_reader :travel_networks, :broadcast_log, :tutorial_model, :active_page_config, :page_config_label_to_navigator, :active_navigator

  def initialize(travel_networks, broadcast_log)
    @travel_networks = travel_networks
    @tutorial_model = initialize_tutorial_model()
    @default_layer = @tutorial_model.layers[0]
    @broadcast_log = broadcast_log
    reset_navigators()
  end

  # Separated out for debuggin
  def reset_navigators
    @page_config_label_to_navigator = page_configs().map_to_hash(
        lambda {|page_config| page_config[:label]},
        lambda {|page_config| page_config[:navigator].new(self, page_config, broadcast_log)}
    )
    # sets @active_page_config
    on_page_selected()
    @active_navigator = @page_config_label_to_navigator[@active_page_config[:label]]
    nil # Avoid dumping the navigator to the screen
  end

  TUTORIAL_MODEL = 'tutorial_model.skp'
  TUTORIAL_MODEL_AUTOSAVES = 'AutoSave_tutorial_model*.skp'
  TUTORIALS_DIR = 'tutorials'
  MAP = 'Google Earth Snapshot'
  PAGE_CONFIGS = [
      {:label=>'Introduction', :name=>'start', :layers=>[:start, :stored_components], :index=>0, :navigator=>Start_Navigator},
      {:label=>'Download Maps & Ways', :name=>'download', :layers=>[:ways, :way_text, MAP], :index=>1, :navigator=>Download_Navigator},
      {:label=>'Modify Ways', :name=>'modify_ways', :layers=>[:ways, :way_text, MAP], :index=>2, :navigator=>Way_Navigator,:depends_on_navigator_states=>{'download'=>['download_ways']}},
      {:label=>'Streetscape Design', :name=>'streetscape', :layers=>[:streetscape_design, :ways, :way_text, :stored_components, MAP], :index=>3, :navigator=>Streetscape_Navigator, :depends_on_navigator_states=>{'download'=>['download_ways']}},
      {:label=>'3D Components', :name=>'components', :layers=>[:models, :ways, :way_text, :streetscape_design, :stored_components, MAP], :index=>4, :navigator=>Component_Navigator, :depends_on_navigator_states=>{'download'=>['download_ways']}},
      {:label=>'3D Buildings', :name=>'buildings', :layers=>[:buildings, :ways, :way_text, :streetscape_design, :stored_components, MAP], :index=>5, :navigator=>Building_Navigator},
      {:label=>'Reports', :name=>'reports', :layers=>[:reports, :ways, :way_text, MAP], :index=>6, :navigator=>Report_Navigator},
      {:label=>'Sharing', :name=>'sharing', :layers=>[:sharing, :ways, :way_text, MAP], :index=>7, :navigator=>Sharing_Navigator},
  ]
  # Page flags that apply when the page is changed
  PAGES_UNIVERSAL = {:flags=>32} # 32=modify visible layers on page change

  def active_travel_networks
    @travel_networks[Sketchup::active_model.unique_id]
  end

  def page_configs
    PAGE_CONFIGS
  end

  # Loads or creates the tutorial Sketchup model
  def initialize_tutorial_model
    # Delete all the autosaved tutorial files
    Sketchup.find_support_file("tutorials", "plugins/#{Rescape::Config::RESCAPE_DIR}/resources/")
    tutorial_dir = self.class.get_or_create_resource_sub_directory(TUTORIALS_DIR)
    Dir.glob(tutorial_dir + "/#{TUTORIAL_MODEL_AUTOSAVES}").each {|filename|
      File.delete(filename)
    }

    # initialize the tutorial
    tutorial_file = self.class.get_resource_file(TUTORIALS_DIR, TUTORIAL_MODEL)
    Rescape::Config.log.info "Looking for tutorial file #{tutorial_file}"
    $glop=tutorial_model = File.exists?(tutorial_file) ?
        Sketchup.open_file(tutorial_file).
            and_if_true{Sketchup.active_model}.
            or_if_false {raise "The Sketchup file #{tutorial_file} could not be loaded"} :
        Sketchup.file_new.active_model
    unless File.exists?(tutorial_file)
      tutorial_model.save(tutorial_file).or_if_false {raise "The Sketchup file #{tutorial_file} could not be saved"}
      Rescape::Config.log.info "Created and saved tutorial file #{tutorial_file}"
    end
    get_or_create_tutorial_pages(tutorial_model)
    tutorial_model
  end

  def close_tutorial_model
    # It doesn't seem possible to close an open model
  end

  # Return all the navigators in order
  def navigators
    page_configs.map {|page_config| page_config_label_to_navigator[page_config[:label]]}
  end

  def get_or_create_tutorial_pages(tutorial_model)
    page_configs.map {|page_config|
      # Create the page if it doesn't yet exist
      get_or_create_page(tutorial_model, page_config)
      # Create layers for the page
      get_or_create_layers_of_page(tutorial_model, page_config)
    }
    # Default the selected page to the first page
    tutorial_model.pages.selected_page = tutorial_model.pages[0]
  end

  # Inserts a page into the model based on the given page_config, unless it already exists
  def get_or_create_page(tutorial_model, page_config)
    tutorial_model.pages[page_config[:label]].or_if_nil {
      tutorial_model.pages.add(page_config[:label], PAGES_UNIVERSAL[:flags]+page_config[:flags].or_if_nil{0}, page_config[:index])
    }.or_if_nil {
      raise "Unexpected page creation failure for page #{page_config}"
    }
  end

  # Retrieves the Sketchup::Page of the tutorial_model matching the given page_config
  def get_page_of_page_config(page_config)
    @tutorial_model.pages[page_config[:label]]
  end

  # Create the layers for the page if they don't already exist
  def get_or_create_layers_of_page(tutorial_model, page_config)
    get_layer_names_of_page_config(page_config).map {|layer_name|
      # Creates the layer if it doesn't already exist
      tutorial_model.layers.add(layer_name)
    }
  end

  # Retrieves the layer names configured to be shown by this page_config
  def get_layer_names_of_page_config(page_config)
    page_config[:layers].map_to_strings
  end

  # Retrieves the Sketchup::Layer instances configured to be shown by this page_config
  def get_layers_of_page_config(page_config)
    get_layer_names_of_page_config(page_config).map {|layer_name| @tutorial_model.layers[layer_name]}
  end

  # Returns the page  with the given label
  def get_page_config_by_label(label)
    page_configs.find {|page_config| page_config[:label]==label}.or_if_nil { raise "Page with label #{label} was not found."}
  end

  # The programmatic way to select a page, as opposed to the user clicking a new page tab
  def select_page(label)
    Rescape::Config.log.info("Tutorial got select_page for label #{label}")
    page = get_page_by_label(label)
    if (page != @tutorial_model.pages.selected_page)
      # This will trigger the controller's onContentsModified
      Rescape::Config.log.info("Tutorial is changing page to page with label #{label}")
      @tutorial_model.pages.selected_page = page
    end
  end

  def select_page_by_name(name)
    Rescape::Config.log.info("Tutorial got select_page_by_name for page named #{name}")
    select_page(page_configs.find {|page_config| name==page_config[:name]}.or_if_nil {raise "Name #{name} does not match a page_config"}[:label])
  end

  def get_page_by_label(label)
    @tutorial_model.pages[label]
  end

  # Reacts to a page select change, if the selected page has actually changed
  def on_page_selected
    selected_page = get_page_config_by_label(@tutorial_model.pages.selected_page.label)
    Rescape::Config.log.info("Tutorial got on_page_selected with selected page: #{selected_page[:label]}")
    return if selected_page == @active_page_config
    @active_page_config = selected_page
    Rescape::Config.log.info("Tutorial sets its active_page_config to: #{@active_page_config[:label]}")
    @active_navigator = @page_config_label_to_navigator[@active_page_config[:label]].or_if_nil {raise "Page Config not found #{@active_page_config[:label]}"}
    Rescape::Config.log.info("Tutorial is setting its active_navigator to: #{active_navigator.class.name}")
    # Set the layers for this page to visible and all others invisible
    set_layers_to_selected_page()
  end

  # Sets the layers visible for the given page_config and sets the active_layer to the default_layer
  # All other layers are made invisible
  def set_layers_to_selected_page()
    # Make the first layer the active layer
    layers = get_layers_of_page_config(@active_page_config)
    # Reset the active layer to the default layer before changing visabilities
    @tutorial_model.active_layer=@default_layer
    # Make layers matching the @active_page_config visible
    @tutorial_model.layers.each {|layer|
      layer.visible = layer==@default_layer || layers.member?(layer)
    }
    # Make the first layer of this page_config active
    @tutorial_model.active_layer = layers[0]
  end

  # Gets the navigator instance of the given page_config name
  def get_navigator_by_name(name)
    @page_config_label_to_navigator[page_configs.find {|page_config| name==page_config[:name]}.or_if_nil {raise "Name #{name} does not match a page_config"}[:label]]
  end

  # Reacts to user advancing the current tutorial page to the next step
  def forward
    @active_navigator.forward
  end
  def backward
    @active_navigator.backward
  end

  # Gets the navigators and their states upon which the navigator with the given page_config depends
  # Returns a hash of {navigator_name=>[state_name, ...]]}
  def get_depending_navigators(page_config)
    page_config[:depends_on_navigator_states].or_if_nil{{}}
  end

end