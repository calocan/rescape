# Basic extensions to the TrueClass
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class TrueClass
  # Calls the given block on a true result
  def and_if_true(&block)
    block.call
  end
  # Does nothing, this conforms to the FalseClass interface and just returns itself
  def or_if_false(&block)
    self
  end
end