require 'init/setup'
require 'utils/external_server.rb'
#
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

begin
  external_server = DRbObject.new_with_uri(Rescape::Config::DRB_URI)
  external_server.stop_service()
rescue
end
$external_server = External_Server.new
DRb.start_service(Rescape::Config::DRB_URI, $external_server)
DRb.thread.join
