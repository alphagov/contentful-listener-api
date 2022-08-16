$LOAD_PATH << "#{__dir__}/lib"
require "gds-api-adapters"
require "contentful"
require "sinatra"
require "sinatra/reloader"
require "publishing_api_content_payload"

post "/listener" do
  webhook = Webhook.new(JSON.parse(request.body.read))

  halt(200, "Not an event we care about") unless webhook.event_of_interest?

  # Potential async opportuntity
  # It's unclear whether we'll be at risk of webhook's timing out if we try
  # do too much with them. We may want to pass an id to a job.

  content_identifier = GovukContentIdentifier.new(webhook.entity_id)

  content_identifier.affected_content.each do |item|
    content_id = item.fetch(:content_id)
    locale = item.fetch(:locale)

    # see if we can find config for the content_id and locale so we have details
    # on the page we'll publish on gov.uk
    content_config = ContentConfig.find(content_id, locale)

    # we can't proceed if we don't know have configuration for this content_id
    # and locale
    next unless content_config

    # Concurrency opportunity: we should do a distributed lock here to prevent
    # concurrent editing of same resource with successive webhooks
    if webhook.live_change?
      PublishingApiLiveUpdater.call(content_config)
    end

    PublishingApiDraftUpdater.call(content_config)
    # end lock
  end

  status 200
  # It'd be nice if we could communicate in our response what we did
  body "Something"
rescue JSON::ParserError
  status 400
  body "Invalid JSON payload"
end

# A class to make it abstract the questions we want to ask of a Contentful
# Webhook payload
class Webhook
  def initialize(payload)
    @payload = payload
  end

  # Work out if this is a topic that we care about
  # We care about topics of entry (and maybe asset)
  # We care about all the actions: create, save, auto_save, archive, unarchive, publish, unpublish, delete
  def event_of_interest?
    true
  end

  def entity_id
    "an-id-to-represent-a-contenful-entry"
  end

  # Work out whether this chnage represents a change to the live version
  # as many will only affect the draft
  def live_change?
    true
  end
end

# A class that is used to communicate with the Publishing API to identify
# whether there are content items that need to be updated as a result of the
# contentful change
class GovukContentIdentifier
  attr_reader :entity_id

  # entity_id is expected to be a unique identifier for Contentful e.g. "entry:1nMBV6lN6G2xuMJCnHIj2i"
  # we may want to pass in some sort of config object to know which documents we care about
  def initialize(entity_id)
    @entity_id = entity_id
  end

  # Fetches content_id/locale pairs from Publishing API for content affected by change
  # also checks our contentful config in case it's a page that hasn't yet been
  # persisted onto Publishing API.
  def affected_content
    (publishing_api_editions + configured_content).uniq
  end

private

  def configured_content
    match = ContentConfig.all.find { |cc| entity_id == "entry:#{cc.contentful_entry_id}" }
    match ? [{ "content_id" => match.content_id, "locale" => match.locale }] : []
  end

  def publishing_api_editions
    pages = GdsApi.publishing_api.get_paged_editions(
      states: %w[draft published],
      cms_entity_ids: [entity_id],
      fields: %w[content_id locale],
    )

    pages.flat_map { |page| page["results"] }
  end
end

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

  attr_reader :contentful_entry_id, :content_id, :locale, :base_path, :title, :description

  def initialize(attributes)
    @contentful_entry_id = attributes.fetch("contentful_entry_id")
    @content_id = attributes.fetch("content_id")
    @locale = attributes.fetch("locale", "en")
    @base_path = attributes.fetch("base_path")
    @title = attributes.fetch("title")
    @description = attributes.fetch("description", "")
  end
end

# A class to manage the operation of updating the Publishing API
# for a potential live update.
# It may not have to actually do any work as sub-content can be made live before
# a parent is live
class PublishingApiLiveUpdater
  attr_reader :content_config, :publishing_api_content

  def initialize(content_config, publishing_api_content)
    @content_config = content_config
    @publishing_api_content = publishing_api_content
  end

  def self.call(...)
    new(...).call
  end

  def call
    contentful_entry = contentful_client.entry(content_config.contentful_entry_id)
    content_payload = PublishingApiContentPayload.new(
      contentful_client:,
      contentful_entry:,
      base_path: content_config.base_path,
      locale: content_config.locale,
      title: content_config.title,
      description: content_config.description,
    )

    if publishing_api_content.update_live?(content_payload.payload)
      GdsApi.publishing_api.put_content(
        content_config.content_id,
        content_payload.payload.merge(previous_version: publishing_api_content.previous_version)
      )
      # probably should include previous version here
      GdsApi.publishing_api.publish(content_id, locale: content_config.locale)
    end
  end

private

  def contentful_client
    @contentful_client ||= Contentful::Client.new(access_token: ENV["CONTENTFUL_LIVE_ACCESS_TOKEN"],
                                                  space: ENV["CONTENTFUL_SPACE_ID"])

  end
end

# A class to manage the operation of updating the Publishing API
# for a change
# This may not actually have to do anything as the draft may already be up-to-date
class PublishingApiDraftUpdater
  attr_reader :content_config

  def initialize(content_config)
    @content_config = content_config
  end

  def self.call(...)
    new(...).call
  end

  def call
    contentful_entry = contentful_client.entry(content_config.contentful_entry_id)
    content_payload = PublishingApiContentPayload.new(
      contentful_client:,
      contentful_entry:,
      base_path: content_config.base_path,
      locale: content_config.locale,
      title: content_config.title,
      description: content_config.description,
    )

    if publishing_api_content.update_draft?(content_payload.payload)
      GdsApi.publishing_api.put_content(
        content_config.content_id,
        # should include previous version
        content_payload.payload
      )
    end
  end

private

  def contentful_client
    @contentful_client ||= Contentful::Client.new(access_token: ENV["CONTENTFUL_DRAFT_ACCESS_TOKEN"],
                                                  space: ENV["CONTENTFUL_SPACE_ID"],
                                                  api_url: "preview.contentful.com")
  end

  def publishing_api_content
    @publishing_api_content ||= PublishingApiContent.new(content_config.content_id, content_config.locale)
  end
end

class PublishingApiContent
  attr_reader :content_id, :locale
  CONTENT_NOT_FOUND = Class.new
  COMPARED_ATTRIBUTES = %w[
    base_path
    title
    description
    details
    publishing_app
    rendering_app
    routes
    schema_name
  ]

  def initialize(content_id, locale = "en")
    @content_id = content_id
    @locale = locale
  end

  def update_draft?(payload)
    return true if draft_content == CONTENT_NOT_FOUND

    content_equivalent?(payload, draft_content)
  end

  def update_live?(payload)
    return true if live_content == CONTENT_NOT_FOUND

    content_equivalent?(payload, live_content)
  end

private

  def content_equivalent?(payload, publishing_api_response)
    payload.slice(*COMPARED_ATTRIBUTES) == publishing_api_response.to_h.slice(*COMPARED_ATTRIBUTES)
  end

  def draft_content
    if most_recent_content == CONTENT_NOT_FOUND
      || !%w[draft published].includes?(most_recent_content["publication_state"])
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
