require 'tools/tool_utils'
# Class-level config methods for the Way_Selector based tools
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

module Way_Selector_Config
  include Tool_Utils

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Basic_Utils::Class_Methods)
    base.extend(Tool_Utils::Class_Methods)
    base.extend(Class_Methods)
  end

  module Class_Methods
    UI_MESSAGES = {
        :title =>
            {:EN=>"Offset way creation",
             :FR=>"Création de voie via offset"},
        :select =>
            {:EN=>"Hover on or near the desired way. Click to set a point of the path. Double click to finish the path.",
             :FR=>"" },
        :vcb_label =>
          {:EN=>"Offset Distance:",
          :FR=>"Distance d'Offset:"},
        :calculating =>
          {
            :EN=>"Calculating path, please wait",
            :FR=>"Attendez SVP pour que le chemin soit calculé"
          },
        :finalize =>
          {
             :EN=>"Rendering the surface, please wait",
             :FR=>"Attendez SVP pour que le superficie dépeigne"
          }
    }
    def messages
      UI_MESSAGES
    end

    # Set the vcb to the length of the given hover_shape or to the given text if specified
    def set_vcb_length(hover_shape, text=nil)
      self.set_vcb_status(text || hover_shape.pair_to_point_data.distance.to_l.to_s)
    end
  end
end