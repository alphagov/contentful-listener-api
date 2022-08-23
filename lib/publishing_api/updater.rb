require "contentful_client"
require "gds-api-adapters"

module PublishingApi
  class Updater
    def initialize(content_config)
      @content_config = content_config
    end

    def self.update_draft(...)
      new(...).update_draft
    end

    def self.update_live(...)
      new(...).update_live
    end

    def update_draft
      contentful_client = ContentfulClient.draft_client(content_config.contentful_space_id)

      retry_conflicts do |content_state|
        content_payload = build_content_payload(contentful_client, content_state)

        if content_state.needs_draft_update?(content_payload)
          GdsApi.publishing_api.put_content(content_config.content_id, content_payload)
        end
      end
    end

    def update_live
      contentful_client = ContentfulClient.live_client(content_config.contentful_space_id)

      retry_conflicts do |content_state|
        content_payload = build_content_payload(contentful_client, content_state)

        if content_state.needs_live_update?(content_payload)
          response = GdsApi.publishing_api.put_content(content_config.content_id, content_payload)

          GdsApi.publishing_api.publish(content_config.content_id,
                                        nil,
                                        locale: content_config.locale,
                                        previous_version: response["lock_version"].to_s)
        end
      end
    end

    private_class_method :new

  private

    attr_reader :content_config

    def content_state
      @content_state ||= ContentState.new(content_config.content_id, content_config.locale)
    end

    def build_content_payload(contentful_client, content_state)
      attributes = content_config.publishing_api_attributes
                                 .merge(previous_version: content_state.lock_version.to_s)

      ContentPayload.call(
        contentful_client:,
        contentful_entry: contentful_client.entry(content_config.contentful_entry_id),
        publishing_api_attributes: attributes,
      )
    end

    def retry_conflicts
      retries ||= 0
      content_state = ContentState.new(content_config.content_id, content_config.locale)

      yield(content_state)

    rescue GdsApi::HTTPConflict
      # If two jobs try write to the Publishing API concurrently the first one will
      # win and the second will fail as the version is out of date. If this happens
      # we'll retry 3 times.
      (retries += 1) <= 3 ? retry : raise
    end
  end
end
