module PublishingApi
  class ContentPayload
    def initialize(contentful_client:, contentful_entry:, publishing_api_attributes: {})
      @contentful_client = contentful_client
      @contentful_entry = contentful_entry
      @publishing_api_attributes = publishing_api_attributes
    end

    def self.call(...)
      new(...).call
    end

    def call
      publishing_api_attributes.merge({
        "locale" => publishing_api_attributes.fetch("locale", "en"),
        "schema_name" => publishing_api_attributes.fetch("schema_name", "special_route"),
        "document_type" => publishing_api_attributes.fetch("document_type", "special_route"),
        "publishing_app" => "contentful-listener",
        "update_type" => publishing_api_attributes.fetch("update_type", "major"),
        "details" => details,
        "routes" => routes,
        "cms_entity_ids" => establish_cms_entity_ids(details),
      })
    end

    private_class_method :new

  private

    attr_reader :contentful_client, :contentful_entry, :publishing_api_attributes

    def details
      @details ||= build_details(contentful_entry)
    end

    def routes
      return publishing_api_attributes["routes"] if publishing_api_attributes["routes"]

      base_path = publishing_api_attributes["base_path"]

      [{ "path" => base_path, "type" => "exact" }]
    end

    def establish_cms_entity_ids(input, found_entity_ids = [])
      if input.is_a?(Hash)
        found_entity_ids << "#{input['cms_entity']}:#{input['cms_id']}" if input["cms_entity"] && input["cms_id"]

        input
          .except(*%w[cms_entity cms_id])
          .values
          .flat_map { |item| establish_cms_entity_ids(item, found_entity_ids) }
          .uniq
      elsif input.is_a?(Array)
        input.flat_map { |item| establish_cms_entity_ids(item, found_entity_ids) }.uniq
      else
        found_entity_ids
      end
    end

    def build_details(item, entry_ids = [])
      case item
      when String, Numeric, true, false
        item
      when DateTime
        item.rfc3339
      when Array
        item.map { |i| build_details(i, entry_ids) }
      when Hash
        item.transform_values { |i| build_details(i, entry_ids) }
      when Contentful::Entry
        entry_details(item, entry_ids)
      when Contentful::Link
        build_details(item.resolve(contentful_client), entry_ids)
      when Contentful::Asset
        {
          "cms_entity" => "Asset",
          "cms_id" => item.id,
          "url" => item.url
        }
      else
        raise "#{item.class} is not configured to be represented as JSON for Publishing API"
      end
    end

    def entry_details(entry, entry_ids)
      base = {
        "cms_entity" => "Entry",
        "cms_id" => entry.id
      }

      # if we've already visited an entry in this tree we're in a recursive loop
      # so we'll just return a reference
      if entry_ids.include?(entry.id)
        base
      else
        fields = base.merge(entry.fields.transform_keys(&:to_s).except(base.keys))
        build_details(fields, entry_ids + [entry.id])
      end
    end
  end
end
