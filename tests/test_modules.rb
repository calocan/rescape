#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby



module C
  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    puts "C #{base} #{base.respond_to?('foo')}"
    base.extend(Class_Methods)
  end
  def bar()
    puts "CBar"
  end

  module Class_Methods
    def self.extended(base)
      puts "classC #{base} #{base.respond_to?('foo')}"
    end
    def foo
      print 'C'
    end
    def c
      print "c call"
    end
  end
end

module B
  include C
  def self.included(base)
    on_extend_or_include(base)
  end
  def self.extended(base)
    on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    puts "B #{base} #{base.respond_to?('foo')}"
    puts "B #{base} #{base.kind_of?(C)}"
    base.extend(C)
    base.extend(Class_Methods)
  end

  def bar()
    puts "BBar"
  end

  def ci
    puts "CI"
  end

  module Class_Methods
    def self.extended(base)
      puts "classB #{base} #{base.respond_to?('foo')}"
    end
    def foo
      print 'B'
    end
    def b
      print "b call"
    end
  end
end

module A
  include B
  def self.included(base)
    puts "A #{base} #{base.respond_to?('foo')}"
    base.extend(B)
    base.extend(Class_Methods)
  end

  def bar()
    puts "ABar"
  end

  module Class_Methods
    def self.extended(base)
      puts "classA #{base} #{base.respond_to?('foo')}"
    end

    def foo
      print 'A'
    end
  end
end

class Test_Modules
  include A
  def initialize
    # Should be 'A''
    puts self.class.foo()
  end

end

=begin
x=Test_Modules.new()
x.class.c
x.class.b
x.bar()
x.ci()
=end

