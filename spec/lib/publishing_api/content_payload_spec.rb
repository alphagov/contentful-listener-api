# Don't require verified doubles for this file since the Contentful
# classes unfortunately rely on dynamic methods
# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe PublishingApi::ContentPayload do
  describe ".call" do
    let(:contentful_client) { instance_double("Contentful::Client", configuration: { space: "space-1" }) }
    let(:contentful_entry) { create_contentful_entry("entry-1") }

    before do
      allow(Contentful::Asset).to receive(:===).and_return(false)
      allow(Contentful::Entry).to receive(:===).and_return(false)
      allow(Contentful::Link).to receive(:===).and_return(false)
    end

    def create_contentful_entry(entry_id, fields: {})
      double("Contentful::Entry", id: entry_id, fields:).tap do |d|
        allow(Contentful::Entry).to receive(:===).with(d).and_return(true)
      end
    end

    def create_contentful_asset(asset_id, fields: {})
      double("Contentful::Asset", id: asset_id, fields:, file: nil).tap do |d|
        allow(Contentful::Asset).to receive(:===).with(d).and_return(true)
      end
    end

    def create_contentful_link(resolve_to)
      instance_double("Contentful::Link", resolve: resolve_to).tap do |d|
        allow(Contentful::Link).to receive(:===).with(d).and_return(true)
      end
    end

    it "produces a hash for the Publishing API" do
      response = described_class.call(contentful_client:,
                                      contentful_entry:,
                                      publishing_api_attributes: { "base_path" => "/hubba" })

      expected = hash_including({
        "base_path" => "/hubba",
        "title" => nil,
        "description" => nil,
        "locale" => "en",
        "schema_name" => "special_route",
        "document_type" => "special_route",
        "publishing_app" => "contentful-listener-api",
        "update_type" => "major",
        "routes" => [{ "path" => "/hubba", "type" => "exact" }],
        "cms_entity_ids" => ["space-1:Entry:entry-1"],
      })

      expect(response).to match(expected)
    end

    it "can accept attributes to customise fields" do
      publishing_api_attributes = {
        "title" => "Hub page",
        "description" => "A hub page",
        "locale" => "cy",
        "schema_name" => "hub_page",
        "document_type" => "type_of_hub",
        "update_type" => "republish",
        "routes" => [{ "path" => "/hubba", "type" => "prefix" }],
      }

      response = described_class.call(contentful_client:, contentful_entry:, publishing_api_attributes:)

      expect(response).to match(hash_including(publishing_api_attributes))
    end

    it "uses the contentful entry to produce a details hash" do
      allow(contentful_entry).to receive(:fields).and_return({
        string: "String",
        number: 1.05,
        boolean: false,
        datetime: DateTime.new(2022, 9, 13, 16, 30), # rubocop:disable Style/DateTime -- Contentful gem uses DateTime
        collection: [{ a: 1 }, { a: 2 }],
      })

      response = described_class.call(contentful_client:, contentful_entry:)

      expect(response["details"]).to eq({
        "cms_id" => "space-1:Entry:entry-1",
        "string" => "String",
        "number" => 1.05,
        "boolean" => false,
        "datetime" => "2022-09-13T16:30:00+00:00",
        "collection" => [{ "a" => 1 }, { "a" => 2 }],
      })
    end

    it "raises an error if it encounters a class within an entry that isn't exepcted" do
      allow(contentful_entry).to receive(:fields).and_return({ unexpected: Set.new([]) })

      expect { described_class.call(contentful_client:, contentful_entry:) }
        .to raise_error("Set is not configured to be represented as JSON for Publishing API")
    end

    it "can embed contentful entries" do
      embedded = create_contentful_entry("entry-2", fields: { field: "item" })
      allow(contentful_entry).to receive(:fields).and_return({ embedded: })

      response = described_class.call(contentful_client:, contentful_entry:)

      expect(response["details"]).to eq({
        "cms_id" => "space-1:Entry:entry-1",
        "embedded" => {
          "cms_id" => "space-1:Entry:entry-2",
          "field" => "item",
        },
      })
    end

    it "can cope with recursive references to contentful entries, by only embedding their ids" do
      recursive = create_contentful_entry("entry-2", fields: { embedded: contentful_entry, data: 2 })
      allow(contentful_entry).to receive(:fields).and_return({ embedded: recursive, data: 1 })

      response = described_class.call(contentful_client:, contentful_entry:)

      expect(response["details"]).to eq({
        "cms_id" => "space-1:Entry:entry-1",
        "data" => 1,
        "embedded" => {
          "cms_id" => "space-1:Entry:entry-2",
          "data" => 2,
          "embedded" => { "cms_id" => "space-1:Entry:entry-1" },
        },
      })
    end

    it "can embed contentful assets" do
      asset = create_contentful_asset("asset-1", fields: { title: "Asset title" })
      allow(asset).to receive(:url).and_return("//images.cfassets.net/file.jpg")

      file = double("Contentful::File",
                    content_type: "image/jpeg",
                    details: { "size" => 21_653, "image" => { "width" => 610, "height" => 407 } })

      allow(asset).to receive(:file).and_return(file)

      allow(contentful_entry).to receive(:fields).and_return({ asset: })

      response = described_class.call(contentful_client:, contentful_entry:)

      expect(response["details"]).to eq({
        "cms_id" => "space-1:Entry:entry-1",
        "asset" => {
          "cms_id" => "space-1:Asset:asset-1",
          "title" => "Asset title",
          "file" => {
            "url" => "//images.cfassets.net/file.jpg",
            "content_type" => "image/jpeg",
            "details" => {
              "size" => 21_653,
              "image" => { "width" => 610, "height" => 407 },
            },
          },
        },
      })
    end

    it "can cope with contentful assets that don't have a file" do
      asset = create_contentful_asset("asset-1", fields: { title: "Asset title" })

      allow(contentful_entry).to receive(:fields).and_return({ asset: })

      response = described_class.call(contentful_client:, contentful_entry:)

      expect(response["details"]).to eq({
        "cms_id" => "space-1:Entry:entry-1",
        "asset" => {
          "cms_id" => "space-1:Asset:asset-1",
          "title" => "Asset title",
          "file" => {},
        },
      })
    end

    it "can resolve contentful links that are embedded" do
      resolved = create_contentful_entry("entry-2", fields: { field: "item" })
      link = create_contentful_link(resolved)
      allow(contentful_entry).to receive(:fields).and_return({ embedded: link })

      response = described_class.call(contentful_client:, contentful_entry:)

      expect(response["details"]).to eq({
        "cms_id" => "space-1:Entry:entry-1",
        "embedded" => {
          "cms_id" => "space-1:Entry:entry-2",
          "field" => "item",
        },
      })
    end

    it "combines the contentful entity ids to create a cms_entity_ids field" do
      embedded = create_contentful_entry("entry-2", fields: { field: "item" })
      asset = create_contentful_asset("asset-1", fields: { title: "Asset title" })
      allow(contentful_entry).to receive(:fields).and_return({ embedded:, asset: })

      response = described_class.call(contentful_client:, contentful_entry:)

      expect(response["cms_entity_ids"])
        .to match_array(%w[space-1:Entry:entry-1 space-1:Entry:entry-2 space-1:Asset:asset-1])
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
