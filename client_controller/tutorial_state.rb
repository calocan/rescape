# A flexible class that accepts a lambda and comforms to the lambda's call interface. call returns 0 or more Tutorial_State_Step which is a subclass of this class. The returned steps are wrapped in a new instance of this class so that subsequent calls to next_step will call the first step and return a new instance of this class with one less step.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Tutorial_State
  attr_reader :steps_lambda, :name
  # Initializes the instance with a lambda that when run returns 0 or more Tutorial_State_Step instances.
  # The steps_remaining is populated by internal calls to the constructor to indicate how many steps remain. Never set it explicitly
  def initialize(steps_lambda, name, steps_remaining=nil)
    @steps_lambda = steps_lambda
    @name = name
    @steps_remaining = steps_remaining
  end

  # Do this after the call() method (therefore to each state.call and each step.call)
  # Invalidating the view hopefully updates what model changes or tool actions occur.
  def default_post_call_actions()
    Sketchup.active_model.active_view.invalidate()
  end

  # Delegate the call to the underlying lambda returning 0 or more Tutorial_State_Step instances
  # The returned result is new instance of this class with the states in a lambda. This instance is then used by calling next_step to run a step and return a new instance of this class with one less step.
  # Note that the subclass Tutorial_State_Step will also use this to call a step, in which case their are no sub-steps produced (although it's theoretically possible)
  def call(*args)
    steps = extract_steps(*args)
    called_state = self.class.new(
        # Create a shell lambda with the array of steps
        lambda {steps},
        name,
        steps.length)
    default_post_call_actions()
    called_state
  end

  # Extracts the steps by calling the steps_lambda
  def extract_steps(*args)
    steps = @steps_lambda.call(*args)
    # Only set the remaining steps if the returned value is an array of State_Lambda derivatives
    (steps.kind_of?(Array) && steps.all?{|step| step.kind_of?(Tutorial_State)}) ? steps : []
  end

  # Determines if call has been called for thie Tutorial_State, meaning it's read to call next_step
  def started?
    @steps_remaining!=nil
  end

  # Indicates if the steps are all run. Raises an error is call() hasn't been called
  def done?
    steps_remaining==0
  end

  # Calls the first step and returns a Tutorial_State with one less step
  # It is assumed that the results of the step are unneeded
  def next_step(*args)
    raise "No steps defined or remaining" unless steps_remaining != 0
    steps = extract_steps(*args)
    steps.first.steps_lambda.call(*args)
    self.class.new(lambda {steps.rest}, name, steps.rest.length)
  end

  # Returns the name of the next step provided the state has been called
  def next_step_name(*args)
    raise "No steps defined or remaining" unless steps_remaining != 0
    step_names(*args).first
  end

  # The names of all steps provided the state has been called
  def step_names(*args)
    steps = extract_steps(*args)
    steps.map {|step| step.name}
  end

  # Calls next_step until no steps remain.
  # Returns the state after all steps are run
  # The block runs a command with the just-run step name as an argument after next_step is called (for logging)
  def run_steps(*args, &block)
    if (self.steps_remaining > 0)
      state = self.next_step(*args)
      block.call(self.next_step_name)
      state.run_steps(*args, &block)
    end
    self
  end

  # Runs up to an through the given step
  # The block runs a command with the just-run step name as an argument after next_step is called (for logging)
  def run_to_step(step_name, *args, &block)
    if (self.steps_remaining > 0)
      state = self.next_step(*args)
      block.call(self.next_step_name)
      # If the step we just ran matched our step_name then return the results, else keep going
      (step_name == self.next_step_name) ?
        state :
        state.run_to_step(step_name, *args, &block)
    else
      self
    end
  end

  # Returns the number of steps remaining for instances created by call() or next_step()
  # Raises an error is called for instances where steps_remining is nil
  def steps_remaining
    raise "steps_remaining is unknown because instance was not created by call() or next_step()" unless @steps_remaining
    @steps_remaining
  end

  # Uniquely identity the lambda based the steps and name hash
  def hash
    [@steps_lambda, @name].hash
  end
end