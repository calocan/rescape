# Manages a Sketchup Command class, which lacks simple read attributes like a name.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Managed_Command
  attr_reader :name, :command
  def initialize(name, command)
    @name = name
    @command = command
  end

  # Executes the command
  def execute()
    @command.call()
  end
end