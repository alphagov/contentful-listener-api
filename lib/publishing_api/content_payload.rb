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
        "title" => publishing_api_attributes.fetch("title", details["title"]),
        "description" => publishing_api_attributes.fetch("description", details["description"]),
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

    def establish_cms_entity_ids(input)
      case input
      when Hash
        found_entity_ids = [input["cms_id"]].compact

        recursive_entity_ids = input.except(*%w[cms_id])
                                    .values
                                    .flat_map { |item| establish_cms_entity_ids(item) }

        (found_entity_ids + recursive_entity_ids).uniq
      when Array
        input.flat_map { |item| establish_cms_entity_ids(item) }.uniq
      else
        []
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
        item.transform_keys(&:to_s).transform_values { |i| build_details(i, entry_ids) }
      when Contentful::Entry
        entry_details(item, entry_ids)
      when Contentful::Link
        build_details(item.resolve(contentful_client), entry_ids)
      when Contentful::Asset
        asset_details(item)
      else
        raise "#{item.class} is not configured to be represented as JSON for Publishing API"
      end
    end

    def entry_details(entry, entry_ids)
      base = { "cms_id" => cms_id("Entry", entry.id) }

      # if we've already visited an entry in this tree we're in a recursive loop
      # so we'll just return a reference
      if entry_ids.include?(entry.id)
        base
      else
        fields = base.merge(entry.fields.transform_keys(&:to_s).except(*base.keys))
        build_details(fields, entry_ids + [entry.id])
      end
    end

    def asset_details(asset)
      base = { "cms_id" => cms_id("Asset", asset.id) }

      asset_fields = asset.fields.transform_keys(&:to_s).except(*(base.keys + %w[file]))

      file_attributes = if asset.file
                          {
                            "content_type" => asset.file.content_type,
                            "details" => asset.file.details,
                            "url" => asset.url,
                          }
                        else
                          {}
                        end

      base.merge(asset_fields).merge({ "file" => file_attributes })
    end

    def cms_id(entity, entity_id)
      "#{contentful_client.configuration[:space]}:#{entity}:#{entity_id}"
    end
  end
end
