RSpec.describe PublishingApi::ContentState do
  include GdsApi::TestHelpers::PublishingApi

  let(:content_id) { SecureRandom.uuid }
  let(:locale) { "en" }

  describe "#needs_draft_update?" do
    it "returns true if there isn't draft content in the Publishing API" do
      stub_publishing_api_does_not_have_item(content_id, { locale: })
      instance = described_class.new(content_id, locale)

      expect(instance.needs_draft_update?({})).to be(true)
    end

    it "returns true if there are differences in monitored fields in the payload" do
      stub_publishing_api_has_item(
        {
          content_id:,
          base_path: "/test",
          description: "A description",
          details: { item: "a" },
          publication_state: "draft",
        },
        { locale: },
      )

      instance = described_class.new(content_id, locale)

      payload = {
        "base_path" => "/test",
        "description" => "A different description",
        "details" => { "item" => "a" },
      }

      expect(instance.needs_draft_update?(payload)).to be(true)
    end

    it "returns false if there are only acceptable differences in payload" do
      stub_publishing_api_has_item(
        {
          content_id:,
          base_path: "/test",
          details: { item: "a" },
          publication_state: "draft",
          updated_at: "2022-01-01T00:00:00.000Z",
        },
        { locale: },
      )

      instance = described_class.new(content_id, locale)

      payload = {
        "base_path" => "/test",
        "details" => { "item" => "a" },
        "updated_at" => "2020-10-12T00:00:00.000Z",
      }

      expect(instance.needs_draft_update?(payload)).to be(false)
    end
  end

  describe "#needs_live_update?" do
    it "returns true if there isn't live content in the Publishing API" do
      stub_publishing_api_has_item(
        {
          content_id:,
          base_path: "/something",
          publication_state: "draft",
          state_history: {
            "1": "draft",
          },
        },
        { locale: },
      )
      instance = described_class.new(content_id, locale)

      expect(instance.needs_live_update?({})).to be(true)
    end

    it "returns true if there isn't live content returns a 404" do
      # we have to break out of the test helpers as they're not sensitive enough
      # to distinguish between a request with a version param and one without
      get_content_endpoint = "#{GdsApi::TestHelpers::PublishingApi::PUBLISHING_API_ENDPOINT}/v2/content/#{content_id}"

      draft_response = {
        content_id:,
        locale:,
        publication_state: "draft",
        state_history: {
          "2": "draft",
          "1": "published",
        },
      }

      draft_request = stub_request(:get, get_content_endpoint)
        .with(query: { locale: })
        .to_return(status: 200, body: draft_response.to_json, headers: {})

      live_request = stub_request(:get, get_content_endpoint)
        .with(query: { locale:, version: 1 })
        .to_return(status: 404, headers: {})

      instance = described_class.new(content_id, locale)

      expect(instance.needs_live_update?({})).to be(true)

      expect(draft_request).to have_been_made
      expect(live_request).to have_been_made
    end

    it "returns true if there are differences in monitored fields in the payload" do
      stub_publishing_api_has_item(
        {
          content_id:,
          base_path: "/something",
          publication_state: "published",
        },
        { locale: },
      )
      instance = described_class.new(content_id, locale)

      payload = {
        "base_path" => "/different",
      }

      expect(instance.needs_live_update?(payload)).to be(true)
    end

    it "returns false if there are only acceptable differences in payload" do
      stub_publishing_api_has_item(
        {
          content_id:,
          base_path: "/same",
          publication_state: "published",
          updated_at: "2022-01-01T00:00:00.000Z",
        },
        { locale: },
      )

      instance = described_class.new(content_id, locale)

      payload = {
        "base_path" => "/same",
        "updated_at" => "2020-10-12T00:00:00.000Z",
      }

      expect(instance.needs_live_update?(payload)).to be(false)
    end
  end

  describe "#lock_version" do
    it "returns the lock_version from the requested item when it is available" do
      stub_publishing_api_has_item(
        {
          content_id:,
          lock_version: 5,
        },
        { locale: },
      )

      instance = described_class.new(content_id, locale)

      expect(instance.lock_version).to eq(5)
    end

    it "returns 0 when the requested item is not available" do
      stub_publishing_api_does_not_have_item(content_id, { locale: })

      instance = described_class.new(content_id, locale)

      expect(instance.lock_version).to eq(0)
    end
  end
end
