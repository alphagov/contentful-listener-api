$LOAD_PATH << "#{__dir__}/lib"
require "content_config"
require "publishing_api"
require "sinatra"
require "sinatra/reloader"
require "webhook"

post "/listener" do
  webhook = Webhook.new(request.env["HTTP_X_CONTENTFUL_TOPIC"], JSON.parse(request.body.read))

  halt(200, "No work done: #{webhook.topic} is not an event that we track") unless webhook.event_of_interest?

  # Potential async opportuntity
  # It's unclear whether we'll be at risk of webhook's timing out if we try
  # do too much with them. We may want to pass an id to a job.

  affected_content = PublishingApi::AffectedContent.call(webhook.entity_id)

  affected_content.each do |item|
    content_config = ContentConfig.find(item.fetch(:content_id), item.fetch(:locale))

    next unless content_config

    PublishingApi::Updater.update_live(content_config) if webhook.live_change?
    PublishingApi::Updater.update_draft(content_config)
  end

  status 200
  # It'd be nice if we could communicate in our response what we did
  body "Something"
rescue JSON::ParserError
  status 400
  body "Invalid JSON payload"
end
