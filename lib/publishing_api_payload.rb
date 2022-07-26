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

  # TODO: include contentful ids in hashes and deal with recursive references
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
