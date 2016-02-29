require 'utils/basic_utils'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


module Web_Utils
  include Basic_Utils

  def self.included(base)
    self.on_extend_or_include(base)
  end
  def self.extended(base)
    self.on_extend_or_include(base)
  end
  def self.on_extend_or_include(base)
    base.extend(Basic_Utils)
  end

  def launch(page_name=nil)
    web_dialog = web_dialog() || construct_web_dialog()
    web_dialog.allow_actions_from_host("localhost")
    web_dialog.allow_actions_from_host("127.0.0.1")
    url = url(page_name)
    Rescape::Config.log.info("Setting guide to file #{url}")
    web_dialog.set_url(url)
    add_action_callbacks(web_dialog)
    make_visible(web_dialog)
    web_dialog
  end

  # Construct the UI::WebDialog. This is only called once per Sketchup seesion
  def construct_web_dialog
    raise "Must be implemented by mixer"
  end

  def web_dialog
    raise "Must be implemented by mixer"
  end

  def url(page_name=nil)
    raise "Must be implemented by mixer"
  end

  def add_action_callbacks(web_dialog)
    raise "Must be implemented by mixer"
  end

  def make_visible(web_dialog)
    raise "Must be impleted by mixer"
  end

  # Add a file:// or file:/// (windows) to the url and escape it
  def format_url(partial_url)
    URI.escape('file://'+ (partial_url[0]=='/' ? partial_url : '/'+partial_url))
  end

  def hash_to_javascript_string(hash)
    "{" + hash.map {|key, value| "#{key.to_s} : '#{value.to_s}'" }.join(", ") + "}"
  end
  def array_to_javascript_string(array)
    "[" + array.map{|item| "'#{item.to_s}'"}.join(", ") + "]"
  end
end