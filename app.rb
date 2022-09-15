$LOAD_PATH << "#{__dir__}/lib"
require "govuk_app_config/govuk_error"
require "govuk_app_config/govuk_healthcheck"
require "rack/logstasher"
require "gds_api/middleware/govuk_header_sniffer"
require "sinatra"
require "sinatra/reloader" if development?

require "content_config"
require "healthcheck/contentful_check"
require "publishing_api"
require "result"
require "webhook"

# This file will be auto reloaded in development and this can be configured twice
GovukError.configure unless GovukError.is_configured?
use Sentry::Rack::CaptureExceptions

configure :production do
  # disable rack common logger so we can use a JSON one
  set :logging, nil

  # JSON logstash logging for production env
  use Rack::Logstasher::Logger, Logger.new($stdout), extra_request_headers: { "GOVUK-Request-Id" => "govuk_request_id" }

  # HTTP headers that are passed on to subsequent apps
  use GdsApi::GovukHeaderSniffer, "HTTP_GOVUK_REQUEST_ID"
end

not_found { "Resource not found\n" }

get "/healthcheck/live" do
  [200, { "Content-Type" => "text/plain" }, "OK"]
end

get "/healthcheck/ready" do
  GovukHealthcheck.rack_response(Healthcheck::ContentfulCheck).call
end

post "/listener" do
  begin
    webhook = Webhook.new(request.env["HTTP_X_CONTENTFUL_TOPIC"], JSON.parse(request.body.read))
  rescue JSON::ParserError
    halt(400, "Invalid JSON payload")
  end

  halt(200, "No work done: #{webhook.environment} is not from the expected environment") unless webhook.expected_environment?
  halt(200, "No work done: #{webhook.topic} is not an event that we track") unless webhook.event_of_interest?

  # Potential async opportuntity
  # It's unclear whether we'll be at risk of webhook's timing out if we try
  # do too much with them. We may want to pass an id to a job.

  affected_content = PublishingApi::AffectedContent.call(webhook.entity_id)

  all_results = affected_content.flat_map do |item|
    content_id = item.fetch(:content_id)
    locale = item.fetch(:locale)

    content_config = ContentConfig.find(content_id, locale)

    next [Result.content_not_configured(content_id, locale)] unless content_config

    results = []
    results << PublishingApi::Updater.update_live(content_config) if webhook.live_change?
    results << PublishingApi::Updater.update_draft(content_config)
    results
  end

  all_results << Result.no_affected_content if all_results.empty?

  status 200
  body all_results.map(&:to_s).join("\n")
end
