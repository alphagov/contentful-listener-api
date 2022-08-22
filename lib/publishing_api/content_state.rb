require "gds-api-adapters"

module PublishingApi
  class ContentState
    attr_reader :content_id, :locale
    CONTENT_NOT_FOUND = Class.new
    COMPARED_ATTRIBUTES = %w[
      base_path
      description
      details
      publishing_app
      rendering_app
      routes
      schema_name
      title
      update_type
    ]

    def initialize(content_id, locale = "en")
      @content_id = content_id
      @locale = locale
    end

    def update_draft?(payload)
      return true if draft_content == CONTENT_NOT_FOUND

      !content_equivalent?(payload, draft_content)
    end

    def update_live?(payload)
      return true if live_content == CONTENT_NOT_FOUND

      !content_equivalent?(payload, live_content)
    end

  private

    def content_equivalent?(payload, publishing_api_response)
      payload.slice(*COMPARED_ATTRIBUTES) == publishing_api_response.to_h.slice(*COMPARED_ATTRIBUTES)
    end

    def draft_content
      if most_recent_content == CONTENT_NOT_FOUND ||
        !%w[draft published].include?(most_recent_content["publication_state"])
        CONTENT_NOT_FOUND
      else
        most_recent_content
      end
    end

    def live_content
      @live_content ||= fetch_live_version
    end

    def most_recent_content
      @most_recent_content ||= begin
                                 GdsApi.publishing_api.get_content(content_id, locale: locale)
                               rescue GdsApi::HTTPNotFound
                                 CONTENT_NOT_FOUND
                               end
    end

    def fetch_live_version
      return CONTENT_NOT_FOUND if most_recent_content == CONTENT_NOT_FOUND
      return most_recent_content if most_recent_content["publication_state"] == "published"

      published_version_number = most_recent_content["state_history"].key("published")
      if published_version_number
        GdsApi.publishing_api.get_content(content_id, locale: locale, version: published_version_number)
      else
        CONTENT_NOT_FOUND
      end
    end
  end
end
