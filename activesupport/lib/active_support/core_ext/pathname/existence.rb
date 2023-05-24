# frozen_string_literal: true

require "pathname"

class Pathname
  # Returns the receiver if the named file exists otherwise returns +nil+.
  # +pathname.existence+ is equivalent to
  #
  #    pathname.exist? ? pathname : nil
  #
  # For example, something like
  #
  #   content = pathname.read if pathname.exist?
  #
  # becomes
  #
  #   content = pathname.existence&.read
  #
  # @return [Pathname]
  def existence
    self if exist?
  end
end
