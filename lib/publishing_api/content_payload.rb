module PublishingApi
  class ContentPayload
    def initialize(contentful_client:, contentful_entry:, publishing_api_attributes: {})
      @contentful_client = contentful_client
      @contentful_entry = contentful_entry
      @publishing_api_attributes = publishing_api_attributes
    end

    def payload
      @payload ||= publishing_api_attributes.merge({
        locale: publishing_api_attributes.fetch("locale", "en"),
        schema_name: publishing_api_attributes.fetch("schema_name", "special_route"),
        document_type: publishing_api_attributes.fetch("document_type", "special_route"),
        publishing_app: "contentful-listener",
        update_type: publishing_api_attributes.fetch("update_type", "major"),
        details: details,
        routes: build_routes,
      })
    end

    def details
      @details ||= build_details(contentful_entry)
    end

  private

    attr_reader :contentful_client, :contentful_entry, :publishing_api_attributes

    def build_routes
      return publishing_api_attributes["routes"] if publishing_api_attributes["routes"]

      base_path = publishing_api_attributes["base_path"]

      [{ path: base_path, type: "exact" }]
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
          cms_entity: "asset",
          cms_id: item.id,
          url: item.url
        }
      else
        raise "#{item.class} is not configured to be represented as JSON for Publishing API"
      end
    end

    def entry_details(entry, entry_ids)
      base = {
        cms_entity: "entry",
        cms_id: entry.id
      }

      # if we've already visited an entry in this tree we're in a recursive loop
      # so we'll just return a reference
      if entry_ids.include?(entry.id)
        base
      else
        fields = base.merge(entry.fields.except(base.keys))
        build_details(fields, entry_ids + [entry.id])
      end
    end
  end
end
