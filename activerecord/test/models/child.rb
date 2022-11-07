# frozen_string_literal: true

class Child < ActiveRecord::Base
  belongs_to :parent, inverse_of: :child, autosave: true
end
