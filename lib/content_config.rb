require "yaml"

class ContentConfig
  def self.find(content_id, locale)
    all.find { |item| item.content_id == content_id && item.locale == locale }
  end

  def self.all
    @all ||= begin
      data = YAML.load_file("config/content_items.yaml")
      data.map { |attributes| new(attributes) }
    end
  end

  def self.reset
    @all = nil
  end

  attr_reader :contentful_space_id, :contentful_entry_id, :content_id, :publishing_api_attributes

  def initialize(attributes)
    @contentful_space_id = attributes.fetch("contentful_space_id")
    @contentful_entry_id = attributes.fetch("contentful_entry_id")
    @content_id = attributes.fetch("content_id")
    @publishing_api_attributes = attributes.fetch("publishing_api_attributes", {})
  end

  def locale
    publishing_api_attributes.fetch("locale", "en")
  end
end
