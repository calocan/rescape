#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Way_Surface_Selection_Observer < Sketchup::SelectionObserver
  def initialize(way_grouping)
    @way_grouping = way_grouping
    Sketchup.active_model.selection.add_observer(self)
  end
  def onSelectionAdded(selection, element)
    if (element.typename=='Edge')
    end
  end
end