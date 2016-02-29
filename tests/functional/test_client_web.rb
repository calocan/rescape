require 'client_web/guide.rb'

class Test_Client_Web
  def test_launch
    guide = Guide.new
    guide.launch
  end
end