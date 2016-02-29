# Listens for page changes in the tutorial Sketchup model
#
# Author::    Andy Likuski (andy@controller.likuski.org)
# License::   Distributes under the same terms as Ruby


class Tutorial_Observer < Sketchup::PagesObserver
  def initialize(controller)
    @controller = controller
  end
  # The Sketchup event handler when the user hits a page tab or after the page is set programmatically by the guide
  # Note that this event is fired twice for a page change, once with the old page and once with the new page as the selected_page
  # The first event must be ignored
  def onContentsModified(pages)
    # Ignore the first call to onContentsModified which will be the previously selected page
    return unless pages.selected_page && pages.selected_page != @controller.last_selected_page
    # Store the now current page
    @controller.last_selected_page = pages.selected_page
    Rescape::Config.log.info("Received page modified message with active page #{pages.selected_page.label}")
    # Handle the page change by possibly changing navigators in the tutorial
    @controller.tutorial.on_page_selected()
    # Change the guide page to the corresponding page if it didn't instigate the change
    page_name = @controller.tutorial.active_page_config[:name]
    @controller.guide.set_page(page_name)
    # Start the new active navigator
    start_navigator_and_run_initial_state(page_name)
  end
end
