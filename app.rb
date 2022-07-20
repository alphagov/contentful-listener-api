require "sinatra"
require "sinatra/reloader"

post "/listener" do
  payload = JSON.parse(request.body.read)

  # Work out if this is a topic that we care about
  # We care about topics of entry (and maybe asset)
  # We care about all the actions: create, save, auto_save, archive, unarchive, publish, unpublish, delete

  # When we have an action of create, save or auto_save we want to update the draft
  # When it's the others we may need to update both draft and live

  # let's work out if there is a publishing api document affected

  # pretend we're updating the homepage

rescue JSON::ParserError
  status :bad_request
  body "Invalid JSON payload"
end

class PublishingApiPayload
  def initialize(contentful_client:, contentful_entry:,  base_path:, title:, description: "")
    @contentful_client = contentful_client
    @contentful_entry = contentful_entry
    @base_path = base_path
    @title = title
    @description = description
  end

  def payload
    {
      base_path: base_path,
      locale: "en",
      schema_name: "special_route",
      document_type: "special_route",
      publishing_app: "contentful-listener",
      rendering_app: "frontend",
      update_type: "major",
      title: title,
      description: description,
      details: details,
      routes: [{ path: base_path, type: "exact" }],
    }
  end

  def details
    @details ||= build_details(contentful_entry)
  end

private

  attr_reader :contentful_client, :contentful_entry, :base_path, :title, :description

  def build_details(item)
    case item
    when String, Numeric, true, false
      item
    when DateTime
      item.rfc3339
    when Array
      item.map { |i| build_details(i) }
    when Hash
      item.transform_values { |i| build_details(i) }
    when Contentful::Entry
      build_details(item.fields)
    when Contentful::Link
      build_details(item.resolve(contentful_client))
    when Contentful::Asset
      { url: item.url }
    else
      raise "#{item.class} is not configured to be represented as JSON for Publishing API"
    end
  end
end
