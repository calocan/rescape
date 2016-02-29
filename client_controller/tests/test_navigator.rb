require 'client_controller/navigator'
require 'client_controller/tutorial'
require 'client_controller/tutorial_state'
require 'client_controller/tutorial_state_step'
require "test/unit"
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Test_Navigator < Test::Unit::TestCase

  def test_navigation()
    tutorial = Test_Tutorial.new()
    navigator = tutorial.active_navigator
    # No state is active
    assert_raise(RuntimeError) {navigator.current_state}
    # Make the first state active
    navigator.start()
    assert_equal(navigator.current_state.name, 'intro', "Expected foo but got #{navigator.current_state.name}")
    # Call the intro state
    tutorial_state = navigator.start_current_state()
    # Try to call a step of the intro state (there are none)
    assert_raise(RuntimeError) { tutorial_state.next_step() }
    assert(navigator.done?(tutorial_state), "intro should have been done")

    navigator
    # Play with forward and backward
    navigator.forward()
    assert_equal('foo', navigator.current_state.name)
    navigator.backward()
    assert_equal('intro', navigator.current_state.name)
    # Make sure we cannot go any more backward
    assert_raise(RuntimeError) { navigator.backward() }
    navigator.forward()
    assert_equal('foo', navigator.current_state.name)

    # Run every state and step of foo and go to bar
    navigator.run_to_state('bar')
    unrecorded = navigator.get_unrecorded('foo')
    assert_equal(0, unrecorded.length, "Found unrecorded state events for foo: #{unrecorded.inspect}")
    # Make sure we're at bar
    assert_equal(navigator.current_state.name, 'bar', "Expected bar but got #{navigator.current_state.name}")
    # Make sure bar has not started
    assert(!navigator.current_state.started?, "Bar was unexpectedly begun")
    # Start bar state
    bar_state = navigator.start_current_state()
    # Make sure the start code was called
    assert(navigator.recorded?('bar_state_start'), "Bar state lambda not called as expected")
    # Make sure that the two steps remain
    assert_equal(2, bar_state.steps_remaining, "Bar should have both steps remaining, but has #{bar_state.steps_remaining}")
    # Run the A step
    bar_state = navigator.next_step(bar_state)
    assert(navigator.recorded?('bar_state_A_step'), "Bar state step A was not called as expected")
    assert_equal(1, navigator.steps_remaining(bar_state), "Bar should have only one step remaining, but has #{navigator.steps_remaining(bar_state)}")
    # Run the B step
    bar_state = navigator.next_step(bar_state)
    assert(navigator.recorded?('bar_state_B_step'), "Bar state step B was not called as expected")
    assert_equal(0, navigator.steps_remaining(bar_state), "Bar should have no steps remaining, but has #{navigator.steps_remaining(bar_state)}")
    unrecorded = navigator.get_unrecorded('bar')
    assert_equal(0, unrecorded.length, "Found unrecorded state events for bar: #{unrecorded.inspect}")
    assert(navigator.done?(bar_state), "Bar state should be done but it's not")

    # Clear the navigator recorder and run everything again
    navigator.clear_recorder!
    navigator.run_all_states_and_steps()
    assert(navigator.recorded?('intro'), "Intro not visited")
    ['foo', 'bar'].each {|state_name|
      unrecorded = navigator.get_unrecorded(state_name)
      assert_equal(0, unrecorded.length, "Found unrecorded state events for #{state_name}: #{unrecorded.inspect}")
    }
  end
end

class Test_Tutorial < Tutorial
  attr_reader :active_navigator
  attr_writer :active_navigator
  def initialize
    @page_config_label_to_navigator = page_configs().map_to_hash(
        lambda {|page_config| page_config[:label]},
        lambda {|page_config| page_config[:navigator].new(self, page_config, self.broadcast_log)}
    )
    @active_navigator = @page_config_label_to_navigator['First Navigator'].or_if_nil {raise "Bad label"}
  end
  def page_configs()
    [
        {:name=>'first_navigator', :label=>'First Navigator', :navigator=>First_Navigator},
        {:name=>'last_navigator', :label=>'Last Navigator', :navigator=>Last_Navigator}
    ]
  end
end

class First_Navigator < Navigator
  attr_reader :recorder

  def initialize(tutorial, page_config, broadcast_log)
    super(tutorial, page_config, broadcast_log)
    @recorder = []
  end

  def initialize_states
    [
        # This is a trivial state that contains no steps
        Tutorial_State.new(lambda{ introduction() }, 'intro'),
        # These states return steps
        foo(),
        bar(),
    ]
  end

  def zoom()

  end

  def record(key)
    raise "Already inserted key #{key}" if @recorder.member?(key)
    @recorder.push(key)
  end

  def recorded?(key)
    @recorder.member?(key)
  end

  def clear_recorder!
    @recorder = []
  end

  def introduction()
    record('intro')
    nil
  end

  def foo()
    record('foo')
    generic_state('foo')
  end

  def bar()
    record('bar')
    generic_state('bar')
  end

  def generic_state(state_name)
    Tutorial_State.new(lambda{
      record("#{state_name}_state_start")
      [
        Tutorial_State_Step.new(lambda {
          record("#{state_name}_state_A_step")
        }, 'A'),
        Tutorial_State_Step.new(lambda {
          record("#{state_name}_state_B_step")
        }, 'B')
      ]
    }, "#{state_name}")
  end

  def get_unrecorded(state_name)
    [state_name, "#{state_name}_state_start","#{state_name}_state_A_step", "#{state_name}_state_B_step"].reject {|key|
      @recorder.member?(key)
    }
  end
end

class Last_Navigator < First_Navigator

end