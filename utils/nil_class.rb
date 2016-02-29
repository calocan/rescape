#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class NilClass
  # Calls the following method when an value is nil
  def or_if_nil(*args, &block)
    block.call(*args)
  end

  # Matches object's method but raises since object shouldn't be nil
  def map_item(&block)
    raise "Unexpected nil value"
  end

  # Matches object's method but just returns self
  def if_not_nil(*args, &block)
    self
  end

  # Conforms to the TrueClass interface, but simply returns itself without calling the block.
  def and_if_true(&block)
    self
  end

  # Conforms to the FalseClass interface, but simply returns itself without calling the block.
  def or_if_false(&block)
    self
  end

  # Returns the nil as an empty collection to complement object.as_array which returns a single item array
  def as_array
    []
  end
end