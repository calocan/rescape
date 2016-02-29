#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
require 'utils/basic_utils'

module Entity_Associating
  include Basic_Utils
  # True if the entity is associated to any way_grouping by means of an attribute
  def associated_to_way_grouping?
    base_associated_to_way_grouping?
  end
  def base_associated_to_way_grouping?
    self.get_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY, Way_Grouping::ATTRIBUTE_ID_KEY) != nil
  end

  def associated_way_grouping(travel_network=active_travel_network())
    base_associated_way_grouping(travel_network)
  end
  def base_associated_way_grouping(travel_network=active_travel_network())
    way_grouping_id = self.get_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY, Way_Grouping::ATTRIBUTE_ID_KEY)
    raise "Entity #{self.inspect} is not associated to a way_grouping_id" unless way_grouping_id
    travel_network.way_grouping_by_id(way_grouping_id)
  end

  # The class to which the entity is associated--resolved using the Kernel
  def associated_way_class
    base_associated_way_class
  end
  def base_associated_way_class
    Kernel.const_get(self.get_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY, Way_Grouping::ATTRIBUTE_WAY_CLASS_KEY))
  end

  # Associates the edge with the given way_grouping
  def associate_to_way_grouping!(way_grouping)
    self.set_attribute(Way_Grouping::ATTRIBUTE_DICTIONARY_KEY, Way_Grouping::ATTRIBUTE_ID_KEY, way_grouping.unique_id)
  end

end