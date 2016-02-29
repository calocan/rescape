# Basic functionality additions
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class Object


  # Call and return the block if predicate is true, otherwise return self
  # predicate can be a fixed value or a lambda, which will be evaluated with the object as an argument
  # block is the action to take and is always called with just the object itself as an argument
  def if_cond(predicate, &block)
    (predicate.class==Proc ? predicate.call(self) : predicate) ? block.call(self) : self
  end

  # Chains an action to the object, assuming it isn't nil
  def map_item(*args, &block)
    block.call(self, *args)
  end

  # Performs the given block if called on a non-nil instance. NilClass will do nothing in this case and return nil so that or_if_nil can be called
  def if_not_nil(*args, &block)
    block.call(self, *args)
  end

  # Matches the NilClass method but does nothing
  def or_if_nil(*args, &block)
    self
  end

  # Returns the object as a single item array or as an array with the item the given number of times
  def as_array(number_of_items=1)
    (1..number_of_items).map {|i| self}
  end

  # Makes the item an array if it is a not one
  def as_array_if_singular
    self.kind_of?(Array) ? self : self.as_array()
  end

  # Enforce all instance_variables being non-nil except those given as exceptions
  def validate_instance_variables(exceptions=[])
    nil_symbols = self.instance_variables.map {|s| s.to_sym}.reject_any(exceptions).find_all {|symbol| nil==self.instance_variable_get(symbol)}
    raise "The following instance variable are unacceptably nil: #{nil_symbols.join(', ')}" if nil_symbols.length > 0
  end

  def validate_arguments(arguments)
    indices = (0..arguments.length-1).find_all {|index| arguments[index]==nil}
    raise "The arguments of the following indices are unacceptably nil: #{indices}" if indices.length > 0
  end

  # Conforms to the TrueClass interface, but simply returns itself without calling the block.
  def and_if_true(&block)
    self
  end

  # Conforms to the FalseClass interface, but simply returns itself without calling the block.
  def or_if_false(&block)
    self
  end

  # Runs the block in a begin/rescue block and returns nil if it throws
  def self.try(&block)
    begin
      block.call
    rescue
      nil
    end
  end

  # Run the try_lambda in a try block and calls the rescue_lambda if it raises an exception. The rescue_lambda expects the exception as an argument. The function returns the results of the try_lambda or rescue_lambda
  def self.try_or_rescue(try_lambda, rescue_lambda)
    begin
      try_lambda.call
    rescue Exception => e
      rescue_lambda.call(e)
    end
  end
end