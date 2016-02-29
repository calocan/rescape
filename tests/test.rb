# This class is used to run unit tests of any class

require 'test/unit/ui/console/testrunner'
require 'test/unit'

class SketchupConsoleOutput
  def puts s
    print s.to_s + "\n"
  end

  def write s
    print s
  end

  def flush
#nop
# The testrunner expects to be able to call this method on the supplied io object.
  end
end

def runTest(clazz)
  runner = Test::Unit::UI::Console::TestRunner.new(clazz, Test::Unit::UI::NORMAL, SketchupConsoleOutput.new)
  runner.start
end

