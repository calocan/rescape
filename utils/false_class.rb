# Basic extensions to the TrueClass
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class FalseClass
  # Does nothing, this conforms to the TrueClass interface and just returns itself
  def and_if_true(&block)
    self
  end
  # Calls the given block on a false result
  def or_if_false(&block)
    block.call
  end
end