require 'client_web/web_utils'

# A web based guide to using Rescape that appears within a web dialog box and works in conjunction with the tutorial
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby
class Guide
  include Web_Utils

  attr_reader :web_dialog, :web_page_name

  def initialize(controller)
    @controller = controller
    # The UI::WebDialog instance
    @web_dialog = nil
    # The name of the current page
    @web_page_name = nil
  end

  # After launch is called, set the start page
  def do_launch(page_name=nil)
    @web_dialog = launch(page_name)
  end

  def construct_web_dialog
    UI::WebDialog.new "Rescape Guide", false, "WEB_DIALOG_SIZE", 200, 200, 0, 0, true
  end

  def url(page_name=nil)
    # This is the development url. Leave it here for when guide.lzx is being edited
    # (This requires Open Laszlo Server to be running with a symbolic link at my-apps/rescape to rescape/server/public)
    if (Rescape::Config::debug_laszlo)
      "http://127.0.0.1:8080/lps-4.9.0/my-apps/rescape/guide.lzx?lzoptions=proxied(false)%2Cruntime(dhtml)%C2usemastersprite(false)&debug=true&page=#{page_name || 'start'}" #lzt=html&debug=true&page=#{page_name || 'start'}"
    else
      partial_url = self.class.get_server_file('', "guide.html")
      format_url(partial_url) + "?page=#{page_name || 'start'}"
    end
  end

  def add_action_callbacks(web_dialog)
    web_dialog.add_action_callback("set_page") {|dialog, page_name|
      # Update this instance to the new page. This will prevent the controller from sending a page change message back to the guide
      @web_page_name = page_name
      Rescape::Config.log.info("Guide called page #{page_name}")
      @controller.set_page(page_name)
    }
    web_dialog.add_action_callback("forward") {|dialog, arg|
      Rescape::Config.log.info("Guide called forward")
      @controller.forward
    }
    web_dialog.add_action_callback("backward") {|dialog, arg|
      Rescape::Config.log.info("Guide called backward")
      @controller.backward
    }
    # Run a particular state for a particular navigator. This verifies that the web_guide knows what state the tutorial is in.
    web_dialog.add_action_callback("run_to_state") {|dialog, param_string|
      Rescape::Config.log.info("Guide called run_to_state: #{param_string}")
      (navigator_name, state_name, *args) = param_string.split(',')
      @controller.run_to_state(navigator_name, state_name, args)
    }
    web_dialog.add_action_callback("run_to_state_and_run_steps") {|dialog, param_string|
      Rescape::Config.log.info("Guide called run_to_state_and_run_steps: #{param_string}")
      (navigator_name, state_name, *args) = param_string.split(',')
      @controller.run_to_state_and_run_steps(navigator_name, state_name, args)
    }
    web_dialog.add_action_callback("skip_to_state_and_run_steps") {|dialog, param_string|
      Rescape::Config.log.info("Guide called skip_to_state_and_run_steps: #{param_string}")
      (navigator_name, state_name, *args) = param_string.split(',')
      @controller.skip_to_state_and_run_steps(navigator_name, state_name, args)
    }
    web_dialog.add_action_callback("run_to_state_and_run_to_step") {|dialog, param_string|
      Rescape::Config.log.info("Guide called run_to_state_and_run_to_step: #{param_string}")
      (navigator_name, state_name, step_name, *args) = param_string.split(',')
      @controller.run_to_state_and_run_to_step(navigator_name, state_name, step_name, args)
    }
    web_dialog.add_action_callback("skip_to_state_and_run_to_step") {|dialog, param_string|
      Rescape::Config.log.info("Guide called skip_to_state_and_run_to_step: #{param_string}")
      (navigator_name, state_name, step_name, *args) = param_string.split(',')
      @controller.skip_to_state_and_run_to_step(navigator_name, state_name, step_name, args)
    }
    web_dialog.add_action_callback("run_to_state_and_run_first_step") {|dialog, param_string|
      Rescape::Config.log.info("Guide called run_to_state_and_run_first_step: #{param_string}")
      (navigator_name, state_name, *args) = param_string.split(',')
      @controller.run_to_state_and_run_first_step(navigator_name, state_name, args)
    }
    web_dialog.add_action_callback("run_next_step") {|dialog, param_string|
      Rescape::Config.log.info("Guide called run_to_state_and_run_next_step: #{param_string}")
      (navigator_name, state_name, *args) = param_string.split(',')
      @controller.run_next_step(navigator_name, state_name, args)
    }
  end

  # Sets the web_dialog to the given page
  def set_page(web_page_name)
    return if web_page_name==@web_page_name
    Rescape::Config.log.info("Setting guide to page #{web_page_name}")
    @web_page_name = web_page_name
    script = "canvas.setPage('#{web_page_name}')"
    Rescape::Config.log.info("Calling script on guide #{script}")
    @web_dialog.execute_script(script)
    # Always make the guide visible on a page change in case the user accidently closed it
    make_visible(web_dialog)
  end

  # Allows the controller to send the web guide a message that is the result of an action occurring in a particular navigator and state. If the state has steps it can include the step that ran
  def send_update(message, page_name, state_name, step_name=nil)
    script = "canvas.stateStatusUpdate('#{message}', '#{page_name}', '#{state_name}', '#{step_name || String.new()}')"
    Rescape::Config.log.info("Calling script on #{self.class.name} #{script}")
    @web_dialog.execute_script(script)
  end

  # Allows the controller to tell the web guide that there are no more steps to run for the given state.
  def send_state_completed_update(page_name, state_name)
    script = "canvas.stateCompletedUpdate('#{page_name}', '#{state_name}')"
    Rescape::Config.log.info("Calling script on #{self.class.name} #{script}")
    @web_dialog.execute_script(script)
  end

  # Allows the controller to tell the web guide that a step completed and there are more to run.
  def send_step_completed_update(page_name, state_name, step_name)
    script = "canvas.stepCompletedUpdate('#{page_name}', '#{state_name}', '#{step_name}')"
    Rescape::Config.log.info("Calling script on #{self.class.name} #{script}")
    @web_dialog.execute_script(script)
  end

  def send_pages_must_run_first(page_labels)
    script = "canvas.pagesMustRunFirst('#{page_labels.join(',')}')"
    Rescape::Config.log.warn("Calling script on #{self.class.name} #{script}")
    @web_dialog.execute_script(script)
  end


  def make_visible(web_dialog)
    unless (web_dialog.visible?)
      web_dialog.set_position(0,0)
      web_dialog.set_size(400,600)
      bring_to_front(web_dialog)
    end
  end

  def bring_to_front(web_dialog=@web_dialog)
    web_dialog.show
    web_dialog.bring_to_front
  end
end