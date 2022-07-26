$LOAD_PATH << "#{__dir__}/lib"
require "sinatra"
require "sinatra/reloader"
require "contentful"

post "/listener" do
  webhook = Webhook.new(JSON.parse(request.body.read))

  halt(200, "Not an event we care about") unless webhook.event_of_interest?

  # Potential async opportuntity
  # It's unclear whether we'll be at risk of Webhook's timing out if we try
  # do too much with them. We may want to pass an id to a job.

  content_identifier = GovukContentIdentifier.new(webhook.entity_id)

  content_identifier.affected_content.each do |item|
    content_id = item.fetch(:content_id)
    locale = item.fetch(:locale)

    # see if we can find config for the content_id and locale so we have details
    # on the page we'll publish on gov.uk
    content_config = nil # find item or handle it not existing

    # Concurrency opportunity: we should do a distributed lock here to prevent
    # concurrent editing of same resource with successive webhooks
    if webhook.live_change?
      PublishingApiLiveUpdater.call(content_id:, locale:, content_config:)
    end

    PublishingApiDraftUpdater.call(content_id:, locale:, content_config:)
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
  # entity_id is expected to be a unique identifier for Contentful e.g. "entry:1nMBV6lN6G2xuMJCnHIj2i"
  # we may want to pass in some sort of config object to know which documents we care about
  def initialize(entity_id)
    @entity_id = entity_id
  end

  def affected_content
    # This method should return pairs of content_id and locale that are affected
    # by a change to the entity.
    # This would require a new field adding to Publishing API to track the
    # Contentful entities used in an edition (potentially an array called cms_entity_ids)
  end
end

# A class to manage the operation of updating the Publishing API
# for a potential live update.
# It may not have to actually do any work as sub-content can be made live before
# a parent is live
class PublishingApiLiveUpdater
  attr_reader :content_id, :locale, :content_config

  def initialize(content_id:, locale:, content_config:)
    @content_id = content_id
    @locale = locale
    @content_config = content_config
  end

  def self.call(...)
    new(...).call
  end

  def call
    # get live version from Publishing API or nil
    # build up our payload using contentful client
    # check if we actually need to update Publishing API (whether data is actually different)
    # if so update the draft
    # then publish the change
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
  attr_reader :content_id, :locale, :content_config

  def initialize(content_id:, locale:, content_config:)
    @content_id = content_id
    @locale = locale
    @content_config = content_config
  end

  def self.call(...)
    new(...).call
  end

  def call
    # get draft version from Publishing API or nil
    # build up our payload using contentful client
    # check if we actually need to update Publishing API (whether data is actually different)
    # if so update the draft
  end

private

  def contentful_client
    @contentful_client ||= Contentful::Client.new(access_token: ENV["CONTENTFUL_DRAFT_ACCESS_TOKEN"],
                                                  space: ENV["CONTENTFUL_SPACE_ID"])

  end
end
