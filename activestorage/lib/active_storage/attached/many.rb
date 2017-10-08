# frozen_string_literal: true

module ActiveStorage
  # Decorated proxy object representing of multiple attachments to a model.
  class Attached::Many < Attached
    delegate_missing_to :attachments

    # Returns all the associated attachment records.
    #
    # All methods called on this proxy object that aren't listed here will automatically be delegated to +attachments+.
    def attachments
      record.public_send("#{name}_attachments")
    end

    # Associates one or several attachments with the current record, saving them to the database.
    # Examples:
    #
    #   document.images.attach(params[:images]) # Array of ActionDispatch::Http::UploadedFile objects
    #   document.images.attach(params[:signed_blob_id]) # Signed reference to blob from direct upload
    #   document.images.attach(io: File.open("/path/to/racecar.jpg"), filename: "racecar.jpg", content_type: "image/jpg")
    #   document.images.attach([ first_blob, second_blob ])
    #   document.images.attach(remote_url: "https://example.com/doc.png", filename: "doc.png", content_type: "image/jpg")
    def attach(*attachables)
      attachables.flatten.collect do |attachable|
        if attachable[:remote_url].present?
          remote_file = download_remote_file(attachable)
          attachable[:io] = remote_file
          attachable.delete(:remote_url)
        end
        attachments.create!(name: name, blob: create_blob_from(attachable))
      end
    end

    # Returns true if any attachments has been made.
    #
    #   class Gallery < ActiveRecord::Base
    #     has_many_attached :photos
    #   end
    #
    #   Gallery.new.photos.attached? # => false
    def attached?
      attachments.any?
    end

    # Directly purges each associated attachment (i.e. destroys the blobs and
    # attachments and deletes the files on the service).
    def purge
      if attached?
        attachments.each(&:purge)
        attachments.reload
      end
    end

    # Purges each associated attachment through the queuing system.
    def purge_later
      if attached?
        attachments.each(&:purge_later)
      end
    end
  end
end
