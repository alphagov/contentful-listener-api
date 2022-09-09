class Result
  def self.content_not_configured(content_id, locale)
    new("Did not update #{content_id}:#{locale} as there isn't a configured Contentful mapping.")
  end

  def self.no_draft_root_entry(content_config)
    new("Did not update the draft content of #{publishing_api_identifier(content_config)} " \
        "as the Contentful draft entry (#{contentful_identifier(content_config)}) " \
        "does not exist.")
  end

  def self.no_live_root_entry(content_config)
    new("Did not update the live content of #{publishing_api_identifier(content_config)} " \
        "as the Contentful entry (#{contentful_identifier(content_config)}) " \
        "is not available as published content.")
  end

  def self.draft_unchanged(content_config)
    new("Did not update the draft content of #{publishing_api_identifier(content_config)} " \
        "as the Publishing API is already up-to-date.")
  end

  def self.draft_updated(content_config)
    new("Updated the draft content of #{publishing_api_identifier(content_config)}")
  end

  def self.live_unchanged(content_config)
    new("Did not update the live content of #{publishing_api_identifier(content_config)} " \
        "as the Publishing API is already up-to-date.")
  end

  def self.live_updated(content_config)
    new("Updated the live content of #{publishing_api_identifier(content_config)}")
  end

  def self.no_affected_content
    new("No content updated, there was no configured content affected by the event.")
  end

  def self.publishing_api_identifier(content_config)
    "#{content_config.content_id}:#{content_config.locale}"
  end

  def self.contentful_identifier(content_config)
    "#{content_config.contentful_space_id}:Entry:#{content_config.contentful_entry_id}"
  end

  attr_reader :message

  def initialize(message)
    @message = message
  end

  def to_s
    message
  end
end
