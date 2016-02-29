# Controls the interplay between the web_guide and the tutorial
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

require 'client_web/guide.rb'
require 'client_web/toolshed.rb'
require 'utils/basic_utils'
require 'client_controller/tutorial'
require 'client_controller/broadcast_log'
require 'client_controller/tutorial_observer' if Rescape::Config.in_sketchup?
require 'client_controller/toolshed_observer' if Rescape::Config.in_sketchup?

class Controller
  include Basic_Utils

  attr_reader :guide, :tutorial, :travel_networks, :last_offset_tool_class, :last_selected_tool, :started_states, :toolshed, :tutorial_observer, :last_selected_page
  attr_writer :last_selected_page

  def initialize(travel_networks)
    @travel_networks = travel_networks
    # Create the web_guide that will display HTML that accompanies the tutorial model
    # This web_guide is hidden until launch_tutorial_and_guide is called
    @guide = create_web_guide()
    # This variable exists only because OnContentsModified is called twice, once with the old page and once with the new, so this is used to ignore the first call
    @last_selected_page = nil
    # Create a tool shed that lets the user pick Rescape tools
    @toolshed = create_toolshed()
    launch_toolshed()
    # The controller tracks the last offset tool selected in the Sketchup or web interface
    # This is used for a special tool that in the Sketchup UI that delegates to the last offset tool
    @last_offset_tool_class = Rescape::Setup.offset_tools.first[:tool]
    @broadcast_log = Broadcast_Log.new(Rescape::Config.log)
    @broadcast_log.register_listener(self)
    @toolshed_observer = Toolshed_Observer.new(self)
    @tutorial_observer = Tutorial_Observer.new(self)
    Sketchup.active_model.tools.add_observer(@toolshed_observer)
  end

  # Creates the web guide and opens it as a window
  def create_web_guide
    # initialize the web guide
    Guide.new(self)
  end

  def launch_tutorial_and_guide
    # Create the tutorial model, a Sketchup::Model with pages that show the user how to use the plugin
    @tutorial = Tutorial.new(travel_networks, @broadcast_log)
    # Add an observer to react to changes to the current page (scene). This observer will make sure the web_guide stays synced to the current tutorial model page.
    @started_states = {}
    @tutorial.tutorial_model.pages.add_observer(@tutorial_observer)
    @last_selected_page = @tutorial.tutorial_model.pages.selected_page
    launch_guide()
  end

  def launch_guide(page_name=nil)
    @guide.do_launch(page_name)
  end

  def create_toolshed
    Toolshed.new(self)
  end

  def launch_toolshed
    @toolshed.do_launch
  end


  # Closes the tutorial stuff
  def self.close
    # Hide the web page
    @guide.hide
    # This doesn't actually do anything, because I don't see how to close an open model file
    @tutorial.close_tutorial_model
  end


  # Handler broadcast messaes from the navigator and forward them to the guide
  def on_info(message, page_name, state_name, step_name=nil)
    if (message==Broadcast_Log::STATE_COMPLETED)
      @guide.send_state_completed_update(page_name, state_name)
    elsif (message==Broadcast_Log::STEP_COMPLETED)
      @guide.send_step_completed_update(page_name, state_name, step_name)
    else
      @guide.send_update(message, page_name, state_name, step_name)
    end
  end

  # Allows the web guide to change the tutorial page
  def set_page(page_name)
    # Set the tutorial to the new page
    @tutorial.select_page_by_name(page_name)
    # After the tutorial is set up, run the first state of the new active navigator
    start_navigator_and_run_initial_state(page_name)
  end

  # The Controller needs to react to page changes from the Tutorial or the Guide
  def start_navigator_and_run_initial_state(page_name)

    clear_navigator_state(page_name)
    @guide.bring_to_front()

    # Check for unrun depending navigators
    tutorial.get_depending_navigators(@tutorial.active_navigator.page_config).if_not_nil { |navigator_hash|
      $zam=navigator_hash
      unrun_depending_navigators = navigator_hash.keys.find_all {|navigator_name|
        required_state_names = navigator_hash[navigator_name]
        $zuk=required_state_names.any? {|state_name| !state_finished?(navigator_name, state_name)}
      }
      if (unrun_depending_navigators.length > 0)
        guide.send_pages_must_run_first(unrun_depending_navigators.map {|navigator_name| tutorial.get_navigator_by_name(navigator_name).label})
      end
    }

    # Start the now active navigator
    @tutorial.active_navigator.start()
    # Start the intro state and run all the steps, which are normally zero steps
    @tutorial.active_navigator.start_current_state_and_run_steps()
  end

  # Allows the web guide to advance the tutorial state forward within the current page
  def forward()
    @tutorial.forward
  end

  # Allows the web guide to advance the tutorial state backward within the current page
  def backward()
    @tutorial.backward
  end

  def verify_active_navigator(navigator)
    if (@tutorial.active_navigator != navigator)
      raise "An inactive navigator was asked to run: #{navigator.class.name}"
    end
  end
  # Raises an exception if the given navigator is not the active one
  def verify_active_navigator_and_current_state(navigator, state_name)
    verify_active_navigator(navigator)
    if (navigator.current_state.name != state_name)
      raise "The given state is not current: #{state_name}. The current state is #{navigator.current_state.name}"
    end
  end

  def start_state(navigator_name, state_name, args)
    navigator = @tutorial.get_navigator_by_name(navigator_name)
    verify_active_navigator_and_current_state(navigator, state_name)
    navigator.run_to_state(state_name).map {|state|
      save_state(navigator_name, state_name, state)
    }
  end

  # Returns the started version of the current state or nonstarted one
  def started_current_state_or_current_state()
    navigator = @tutorial.active_navigator
    try_load_state(navigator.name, navigator.current_state.name) || navigator.current_state
  end

  # Runs to a specific state of a specific navigator. This call comes form the web_guide, hence the string names
  # If the navigator named is not the active_navigator, this raises an error. The navigator will run until reaching that state, or do nothing if it has already reached or passed that state.
  def run_to_state(navigator_name, state_name, args)
    navigator = @tutorial.get_navigator_by_name(navigator_name)
    verify_active_navigator(navigator)
    current_state = started_current_state_or_current_state()
    navigator.run_to_state(state_name, current_state).map {|state|
      save_state(navigator_name, state_name, state)
    }
  end

  def skip_to_state(navigator_name, state_name, args)
    navigator = @tutorial.get_navigator_by_name(navigator_name)
    verify_active_navigator(navigator)
    current_state = started_current_state_or_current_state()
    navigator.skip_to_state(state_name, current_state)
  end

  # Executes all the steps of the states from the current to the target state and also runs the steps of the target state
  def run_to_state_and_run_steps(navigator_name, state_name, args)
    run_to_state(navigator_name, state_name, args)
    save_state(navigator_name, state_name, @tutorial.active_navigator.start_current_state_and_run_steps())
  end
  # Skips to the given state without running anything beforehand and runs all steps
  def skip_to_state_and_run_steps(navigator_name, state_name, args)
    skip_to_state(navigator_name, state_name, args)
    save_state(navigator_name, state_name, @tutorial.active_navigator.start_current_state_and_run_steps())
  end

  # Run the steps of the current state
  def run_steps(navigator_name, args)
    navigator = @tutorial.get_navigator_by_name(navigator_name)
    verify_active_navigator(navigator)
    navigator.run_steps(navigator.current_state)
  end

  # Runs to the state and executes the first step. Useful when the web guide wants the user to click a button to do the first step but also need to catch up the tutorial if the user skipped previous steps
  def run_to_state_and_run_to_step(navigator_name, state_name, step_name, args)
    run_to_state(navigator_name, state_name, args)
    raise "Step name #{step_name} does not exist!" unless @tutorial.active_navigator.current_state.step_names.member?(step_name)
    save_state(navigator_name, state_name, @tutorial.active_navigator.start_current_state_and_run_to_step(step_name))
  end

  # Skips to the state and executes the first step. Useful when the web guide wants the user to click a button to do the first step but also need to catch up the tutorial if the user skipped previous steps
  def skip_to_state_and_run_to_step(navigator_name, state_name, step_name, args)
    state = skip_to_state(navigator_name, state_name, args)
    raise "Step name #{step_name} does not exist!" unless @tutorial.active_navigator.current_state.step_names.member?(step_name)
    started_state = state.started? ? state : @tutorial.active_navigator.start_current_state
    save_state(navigator_name, state_name, @tutorial.active_navigator.run_to_step(started_state, step_name))
  end

  # Runs to the state and executes the first step. Useful when the web guide wants the user to click a button to do the first step but also need to catch up the tutorial if the user skipped previous steps
  def run_to_state_and_run_first_step(navigator_name, state_name, args)
    run_to_state(navigator_name, state_name, args)
    save_state(navigator_name, state_name, @tutorial.active_navigator.start_current_state_and_run_first_step())
  end

  # Runs the next step. This only works if the given state is stored in the state_status hash in a started state
  def next_step(navigator_name, state_name, args)
    navigator = @tutorial.get_navigator_by_name(navigator_name)
    verify_active_navigator_and_current_state(navigator, state_name)
    state = load_state(navigator_name, state_name)
    save_state(navigator_name, state_name, navigator.next_step(state))
  end

  # Save the state of a state that has been started. A started state has zero or more steps remaining to be run
  # Returns the state for chaining purposes
  def save_state(navigator_name, state_name, state)
    navigator_hash = @started_states[navigator_name].or_if_nil{
      hash = {}
      @started_states[navigator_name] = hash
      hash
    }
    navigator_hash[state_name] = state
  end

  # Load the state of a state that has been started. Returns nil if it doesn't exist
  def try_load_state(navigator_name, state_name)
    begin
      load_state(navigator_name, state_name)
    rescue
      nil
    end
  end

  # Load the state of a state that has been started.
  def load_state(navigator_name, state_name)
    navigator_hash = @started_states[navigator_name].or_if_nil{
      raise "Navigator hash has not been created for #{navigator_name}, but a lookup of state #{state_name} was attempted"
    }
    navigator_hash[state_name].or_if_nil {
      raise "Failed to find state #{state_name} in navigator hash for #{navigator_name}"
    }
  end

  # Determines if the state has run for the given navigator_name and state_name
  def state_finished?(navigator_name, state_name)
    navigator_hash = @started_states[navigator_name].or_if_nil{
      return false
    }
    state = navigator_hash[state_name].or_if_nil {
      return false
    }
    state.done?
  end

  # Returns any stored states of the given navigator in order of states. Returns nil for any state not stored
  def load_states(navigator)
    @started_states[navigator.name].if_not_nil {|navigator_hash|
      navigator.state_names.map {|state_name| navigator_hash[state_name]}
    }.or_if_nil{
      navigator.state_names.map {|x| nil}
    }
  end

  # Clear any stored state for a navigator
  def clear_navigator_state(navigator_name)
    @started_states[navigator_name].if_not_nil{|hash| hash.clear()}
  end

  # Tool shed commands
  def select_tool(tool_name)
    if (tool_name != 'last')
      @last_selected_tool = Rescape::Setup.toolbar_manager.get_toolbar(Rescape::Setup::RESCAPE_TOOLBAR).select_tool(tool_name)
      @last_offset_tool_class = Rescape::Setup.is_offset_tool?(@last_selected_tool.class) ? @last_selected_tool.class : @last_offset_tool_class
    else
      @last_selected_tool
    end
  end

  # This is called by top-level tools when popped off the stack (as opposed to an intermediate tool like Path_Adjustor)
  # It doesn't matter if the tool or completed or was cancelled'
  # The message is sent to the toolshed
  def tool_finished()
    @toolshed.deselect_tool()
  end
end

