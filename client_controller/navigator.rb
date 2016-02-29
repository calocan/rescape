require 'tools/tool_utils'
require 'client_controller/navigator_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Navigator
  include Tool_Utils
  include Navigator_Utils

  attr_reader :tutorial, :tutorial_model, :page_config, :states

  def initialize(tutorial, page_config, broadcast_log)
    @tutorial = tutorial
    @tutorial_model = tutorial.tutorial_model
    @page_config = page_config
    @current_state = nil
    @broadcast_log = broadcast_log
    @toolbar = Rescape::Setup.toolbar_manager.get_toolbar(Rescape::Setup::RESCAPE_TOOLBAR)
  end

  # The name that represents the navigator and the tutorial page
  def name
    @page_config[:name]
  end

  # The more friendly name shown as the page name on the tutorial model
  def label
    @page_config[:label]
  end

  def navigator_name
    name()
  end

  def initialize_states
    raise "Must be implemented by subclass"
  end

  # Returns the names of all the states
  def state_names
    initialize_states.map {|state| state.name}
  end

  # Represents the current state of the states
  def current_state
    raise "No current_state, call start() first" unless @current_state
    @current_state
  end

  # Zoom the the extents by default
  def zoom
    view = @tutorial_model.active_view
    view.zoom_extents
    view.invalidate()
  end

  # Zooms to the given entities
  def zoom_to_entities(entities)
    view = @tutorial_model.active_view
    view.zoom(entities)
    view.invalidate()
  end

  def set_camera(eye=[0,0,1], target=[0,0,0], up=[0,1,0])
    view = @tutorial_model.active_view
    camera = view.camera
    camera.set(eye, target, up)
  end

  # Start this navigator, which means creating the states and setting the @current_state to the first one
  def start
    # By default we zoom to the extents, but this can be overridden
    set_camera()
    zoom()
    pop_all_tools()
    @states = initialize_states()
    Rescape::Config.log.info("Loading start page for #{self.class}")
    @current_state = @states.first
  end

  # Advances the navigator to the next Tutorial_State.
  def forward
    index = @states.index(@current_state)+1
    previous_state = @current_state
    @current_state = index < @states.length ? @states[index] : @current_state
    Rescape::Config.log.info("Forward to state #{@current_state.name}")
    raise "No more states" unless previous_state != @current_state
  end

  # Backs up the navigator to the previous frame
  def backward
    index = @states.index(@current_state)-1
    previous_state = @current_state
    @current_state = index >= 0 ? @states[index] : @current_state
    raise "Already at first state" unless previous_state != @current_state
    Rescape::Config.log.info("Backward to state #{@current_state.name}")
  end

  # Returns true if the current_state as the last state
  def last_state?
    @states.index(@current_state) == @states.length-1
  end

  # Run through all the states of the page in order perform operations needed by subsequent pages
  def run_all_states_and_steps
    Rescape::Config.log.info("Running all states and steps for #{self.class}")
    start()
    (0..@states.length-1).each {|index|
      run_steps(start_current_state())
      forward() unless index==@states.length-1
    }
  end

  # Calls the current_state's lambda.
  # The returned result will be a cloned Tutorial_State instance containing 0 or more Tutorial_State_Step instances in a lambda shell. Each step can be run by calling next_step()
  def start_current_state
    raise "Current state has already been begun" if @current_state.started?
    Rescape::Config.log.info("Starting current state #{@current_state.name}")
    @current_state.call()
  end

  # Run all the steps of the give state
  def run_steps(tutorial_state)
    Rescape::Config.log.info("Running all steps #{tutorial_state.step_names.join(", ")} for state #{tutorial_state.name}")
    state = tutorial_state.run_steps() { |step_name|
      @broadcast_log.info(Broadcast_Log::STEP_COMPLETED, navigator_name, tutorial_state.name, step_name)
    }
    @broadcast_log.info(Broadcast_Log::STATE_COMPLETED, navigator_name, tutorial_state.name)
    state
  end

  def run_to_step(tutorial_state, step_name)
    Rescape::Config.log.info("Running to step #{step_name} for state #{tutorial_state.name}")
    state = tutorial_state.run_to_step(step_name) { |step_name|
      @broadcast_log.info(Broadcast_Log::STEP_COMPLETED, navigator_name, tutorial_state.name, step_name)
    }
    state
  end

  # Starts the current state and runs all the steps, returning the state with no steps left
  def start_current_state_and_run_steps
    run_steps(start_current_state())
  end

  # Starts the current state and runs the first step, returning the state ready to run the next step
  def start_current_state_and_run_to_step(step_name)
    run_to_step(start_current_state(), step_name)
  end

  # Starts the current state and runs the first step, returning the state ready to run the next step
  def start_current_state_and_run_first_step
    next_step(start_current_state())
  end

  # Calls the next step of the Tutorial_State, returning a Tutorial_State with that step removed
  def next_step(tutorial_state)
    Rescape::Config.log.info("Stepped state #{tutorial_state.name} to step #{tutorial_state.next_step_name}")
    state = tutorial_state.next_step()
    @broadcast_log.info(Broadcast_Log::STEP_COMPLETED, navigator_name, tutorial_state.name, tutorial_state.next_step_name)
    if (state.done?)
      # Broadcast a state completed message if the last step was run
      @broadcast_log.info(Broadcast_Log::STATE_COMPLETED, navigator_name, tutorial_state.name)
    end
    state
  end

  # Returns the number of steps remaining provided the state has begun
  def steps_remaining(tutorial_state)
    tutorial_state.steps_remaining()
  end

  # Returns whether or not the give state is done provided the state has begun
  def done?(tutorial_sate)
    tutorial_sate.done?
  end

  # Run all states and their steps up to the named state, or do nothing if that state has been reached or surpassed
  # The optional current_state represents started version of the current_state, if one exists. If it does not exist, the current state will be started and stepped through. If it does exist any remaining steps will be run.
  # Doesn't start and run the steps of the named state unless run_state is true
  # Returns all states in a finished state up to the target state. Also returns the target state in a finished state if run_state is true
  def run_to_state(state_name, current_state=self.current_state, run_state=false)
    state = get_state_by_name(state_name)
    state_index = @states.index(state)
    current_index = @states.index(@current_state)
    states = []
    if (current_index < state_index)
      started_current_state = current_state.started? ? current_state : start_current_state()
      # Run all the steps of the current state unless at our destination
      state = run_steps(started_current_state)
      # Go to the next state
      forward()
      # Return the finished state
      states = [state] + run_to_state(state_name, self.current_state, run_state)
    end
    # Optionally run the target state
    run_state ? (states + [run_steps(start_current_state())]) : states
  end

  # Skip up to the given state without running the states in between.
  # Optionally pass in a state that may already be started. This will be returned if it matches the state_name, rather than returning an unstarted version of the state
  def skip_to_state(state_name, current_state=self.current_state)
    @broadcast_log.info("Skipping from current state to state #{state_name}", self.name, current_state.name)
    state = get_state_by_name(state_name)
    state_index = @states.index(state)
    current_index = @states.index(@current_state)
    if (current_index < state_index)
      forward()
      skip_to_state(state_name, current_state)
    else
      current_state
    end
  end

  # A Collection of all the Google Earth Images present in the layers configured to be shown by this page
  def maps
    layers = tutorial.get_layers_of_page_config(page_config)
    self.class.find_maps(tutorial_model, false).find_all {|map| layers.member?(map.layer)}
  end

  def visible_maps
    layers = tutorial.get_layers_of_page_config(page_config)
    self.class.find_maps(tutorial_model, true).find_all {|map| layers.member?(map.layer)}
  end

  # Get the main map, i.e, that centered closest to the origin
  def get_main_map
    origin = Geom::Point3d.new
    maps.sort_by {|x| origin.vector_to(Simple_Pair.new([x.bounds.min, x.bounds.max]).middle_point).length}.first
  end

  # Find the Tutorial_State instance matching this name
  def get_state_by_name(state_name)
    @states.find {|state| state.name==state_name}.or_if_nil {raise "No state with the name #{state_name} exists for this navigator #{self.class}"}
  end
end