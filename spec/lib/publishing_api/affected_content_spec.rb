RSpec.describe PublishingApi::AffectedContent do
  include GdsApi::TestHelpers::PublishingApi
  include StubConfig

  describe ".call" do
    it "returns pairs of content_id and locale for matches in Publishing API" do
      entity_id = "space-id:Entry:entry-id"

      matches = [
        { content_id: SecureRandom.uuid, locale: "en" },
        { content_id: SecureRandom.uuid, locale: "cy" },
      ]

      stub_publishing_api_get_editions(
        matches.map { |item| item.transform_keys(&:to_s) },
        {
          cms_entity_ids: [entity_id],
          fields: %w[content_id locale],
          states: %w[draft published],
        },
      )

      expect(described_class.call(entity_id)).to match_array(matches)
    end

    it "includes items that are configured in this project, which may not yet exist in Publishing API" do
      space_id = "space-id"
      entry_id = "entry-id"
      content_id = SecureRandom.uuid
      locale = "en"

      stub_publishing_api_get_editions(
        [],
        {
          cms_entity_ids: ["#{space_id}:Entry:#{entry_id}"],
          fields: %w[content_id locale],
          states: %w[draft published],
        },
      )

      stub_content_items_config(space_id:, entry_id:, content_id:, locale:)

      expect(described_class.call("#{space_id}:Entry:#{entry_id}")).to eq([{ content_id:, locale: }])
    end

    it "de-duplicates items in both Publishing API and configured in this project" do
      space_id = "space-id"
      entry_id = "entry-id"
      content_id = SecureRandom.uuid
      locale = "en"

      stub_publishing_api_get_editions(
        [{ "content_id" => content_id, "locale" => locale }],
        {
          cms_entity_ids: ["#{space_id}:Entry:#{entry_id}"],
          fields: %w[content_id locale],
          states: %w[draft published],
        },
      )

      stub_content_items_config(space_id:, entry_id:, content_id:, locale:)

      expect(described_class.call("#{space_id}:Entry:#{entry_id}")).to eq([{ content_id:, locale: }])
    end
  end
end
