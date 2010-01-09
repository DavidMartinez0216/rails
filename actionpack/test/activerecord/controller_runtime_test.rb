require 'active_record_unit'
require 'active_record/railties/controller_runtime'
require 'fixtures/project'

ActionController::Base.send :include, ActiveRecord::Railties::ControllerRuntime

class ARLoggingController < ActionController::Base
  def show
    render :inline => "<%= Project.all %>"
  end
end

class ARLoggingTest < ActionController::TestCase
  tests ARLoggingController

  def setup
    super
    set_logger
  end

  def wait
    ActiveSupport::Notifications.notifier.wait
  end

  def test_log_with_active_record
    # Wait pending notifications to be published
    wait
    get :show
    wait
    assert_match /ActiveRecord runtime/, @controller.logger.logged[3]
  end

  private
    def set_logger
      @controller.logger = MockLogger.new
    end

end
