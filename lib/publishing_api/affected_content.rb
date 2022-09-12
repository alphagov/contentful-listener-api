require "gds-api-adapters"
require "content_config"

module PublishingApi
  class AffectedContent
    attr_reader :entity_id

    def initialize(entity_id)
      @entity_id = entity_id
    end

    def self.call(...)
      new(...).call
    end

    def call
      (publishing_api_editions + configured_content).uniq
    end

    private_class_method :new

  private

    def configured_content
      match = ContentConfig.all.find { |cc| entity_id == "#{cc.contentful_space_id}:Entry:#{cc.contentful_entry_id}" }
      match ? [{ content_id: match.content_id, locale: match.locale }] : []
    end

    def publishing_api_editions
      pages = GdsApi.publishing_api.get_paged_editions(
        states: %w[draft published],
        cms_entity_ids: [entity_id],
        fields: %w[content_id locale],
      )

      pages.flat_map { |page| page["results"] }
           .map { |item| item.transform_keys(&:to_sym) }
    end
  end
end
