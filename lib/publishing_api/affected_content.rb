require "gds-api-adapters"
require "content_config"

# A class that is used to communicate with the Publishing API to identify
# whether there are content items that need to be updated as a result of the
# contentful change
module PublishingApi
  class AffectedContent
    attr_reader :entity_id

    # entity_id is expected to be a unique identifier for Contentful e.g. "entry:1nMBV6lN6G2xuMJCnHIj2i"
    # we may want to pass in some sort of config object to know which documents we care about
    def initialize(entity_id)
      @entity_id = entity_id
    end

    def self.call(...)
      new(...).call
    end

    # Fetches content_id/locale pairs from Publishing API for content affected by change
    # also checks our contentful config in case it's a page that hasn't yet been
    # persisted onto Publishing API.
    def call
      (publishing_api_editions + configured_content).uniq
    end

    private_class_method :new

  private

    def configured_content
      match = ContentConfig.all.find { |cc| entity_id == "Entry:#{cc.contentful_entry_id}" }
      match ? [{ content_id: match.content_id, locale: match.locale }] : []
    end

    def publishing_api_editions
      pages = GdsApi.publishing_api.get_paged_editions(
        states: %w[draft published],
        cms_entity_ids: [entity_id],
        fields: %w[content_id locale],
      )

      pages.flat_map { |page| page["results"] }.map(&:symbolize_keys)
    end
  end
end
