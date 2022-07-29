require "contentful"
require_relative "publishing_api_content_payload"

client = Contentful::Client.new(access_token: ENV["CONTENTFUL_DRAFT_ACCESS_TOKEN"], space: ENV["CONTENTFUL_SPACE_ID"], api_url: "preview.contentful.com")

payload = PublishingApiContentPayload.new(contentful_client: client, contentful_entry: client.entry("64EsT2ttgsJMDm6VxnOWtX"), base_path: "/", title: "GOV.UK Homepage")
puts JSON.pretty_generate(payload.details)
