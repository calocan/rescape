#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Test_Edges
  def test_sorting
    edges = Sketchup.active_model.selection
    Sketchup::Edge.sort(edges)
  end
end