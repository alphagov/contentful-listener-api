require "contentful"
require "gds-api-adapters"

# A class to manage the operation of updating the Publishing API
# for a change
# This may not actually have to do anything as the draft may already be up-to-date
module PublishingApi
  class DraftUpdater
    def initialize(content_config)
      @content_config = content_config
    end

    def self.call(...)
      new(...).call
    end

    def call
      attributes = content_config.publishing_api_attributes.merge(previous_version: content_state.lock_version.to_s)

      content_payload = ContentPayload.new(
        contentful_client:,
        contentful_entry: contentful_client.entry(content_config.contentful_entry_id),
        publishing_api_attributes: attributes,
      )

      if content_state.update_draft?(content_payload.payload)
        GdsApi.publishing_api.put_content(
          content_config.content_id,
          content_payload.payload,
        )
      end
    end

    private_class_method :new

  private

    attr_reader :content_config

    def contentful_client
      @contentful_client ||= Contentful::Client.new(access_token: ENV["CONTENTFUL_DRAFT_ACCESS_TOKEN"],
                                                    space: ENV["CONTENTFUL_SPACE_ID"],
                                                    api_url: "preview.contentful.com")
    end

    def content_state
      @content_state ||= ContentState.new(content_config.content_id, content_config.locale)
    end
  end
end
