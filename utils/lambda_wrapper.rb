# A simple wrapper for a lambba function to allow caching by properties of the lambda
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Lambda_Wrapper
  attr_reader :lambda, :properties, :depth
  # Initializes the instance with the underlying lambda function and a list of properties that uniquely describe the lambda.
  # properties are not the arguments of the lambda function, which will vary independent of the properties. Properties are simply used to identify a unique hash for the lambda so that dependent data structures can be cashed based on properties of this lambda. If hashing is not important set this to nil
  # The optional depth argument reveals the depth of embedded lambdas. It defaults to 1 to indicate that the lambda returns a concrete value. Depth 2 indicates that calling the lambda returns a lambda which when called returns a concrete value, and so on. The arguments that each level lambda requires must be known by the caller.
  def initialize(lambda, properties=nil, depth=1)
    @lambda = lambda
    @properties = properties
    @depth=depth
  end
  # Delegate the call to the underlying lambda
  def call(*args)
    @lambda.call(*args)
  end
  # Uniquely identity the lambda based on @properties, otherwise hash the object_id to create a hash that's always unique
  def hash
    @properties ? @properties.hash : self.object_id.hash
  end
end