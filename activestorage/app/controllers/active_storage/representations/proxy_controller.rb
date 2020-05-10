# frozen_string_literal: true

# Proxy files through application. This avoids having a redirect and makes files easier to cache.
class ActiveStorage::Representations::ProxyController < ActiveStorage::BaseController
  include ActiveStorage::SetBlob
  include ActiveStorage::SetHeaders

  def show
    http_cache_forever(public: true) {}
    representation = @blob.representation(params[:variation_key]).processed

    set_content_headers_from_blob(representation.image.blob)

    stream(representation.blob)
  end
end
