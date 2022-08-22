require "contentful"
require "gds-api-adapters"

# A class to manage the operation of updating the Publishing API
# for a potential live update.
# It may not have to actually do any work as sub-content can be made live before
# a parent is live
module PublishingApi
  class LiveUpdater
    def initialize(content_config)
      @content_config = content_config
    end

    def self.call(...)
      new(...).call
    end

    def call
      contentful_entry = contentful_client.entry(content_config.contentful_entry_id)

      content_payload = ContentPayload.new(
        contentful_client:,
        contentful_entry:,
        publishing_api_attributes: content_config.publishing_api_attributes
      )

      if content_state.update_live?(content_payload.payload)
        GdsApi.publishing_api.put_content(
          content_config.content_id,
          content_payload.payload,
        )
        # probably should include previous version here
        GdsApi.publishing_api.publish(content_config.content_id, nil, locale: content_config.locale)
      end
    end

    private_class_method :new

  private

    attr_reader :content_config

    def contentful_client
      @contentful_client ||= Contentful::Client.new(access_token: ENV["CONTENTFUL_LIVE_ACCESS_TOKEN"],
                                                    space: ENV["CONTENTFUL_SPACE_ID"])

    end

    def content_state
      @content_state ||= ContentState.new(content_config.content_id, content_config.locale)
    end
  end
end
