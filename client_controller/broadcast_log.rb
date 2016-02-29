# Wraps the calls of a normal Log4r log, passing data to broadcast listeners as well
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class Broadcast_Log
  STATE_COMPLETED = "state completed"
  STEP_COMPLETED = "step completed"
  def initialize(log)
    @log = log
    @listeners = []
  end

  def register_listener(listener)
    @listeners.push(listener)
  end

  # Sends a status update
  def info(message, navigator_name, state_name, step_name=nil)
    @listeners.each {|listener| listener.on_info(message, navigator_name, state_name, step_name)}
    @log.info(message)
  end

  # Send any other log events to the @log
  def method_missing(m, *args, &block)
    @log.send(m, *args, &block)
  end
end