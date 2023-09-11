# frozen_string_literal: true

# The base class for all Active Storage controllers.
class ActiveStorage::BaseController < ActionController::Base
  protect_from_forgery with: :exception

  self.etag_with_template_digest = false
end
