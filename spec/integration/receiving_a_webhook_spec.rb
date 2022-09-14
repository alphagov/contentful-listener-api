require "rack/test"

RSpec.describe "Receiving a webhook" do
  include Rack::Test::Methods
  include GdsApi::TestHelpers::PublishingApi
  include StubConfig
  include StubContentful

  def app
    Sinatra::Application
  end

  describe "POST /listener" do
    def webhook_payload(entry_id: "entry-id", space_id: "space-id", environment: "master")
      {
        sys: {
          type: "Entry",
          id: entry_id,
          space: {
            sys: {
              type: "Link",
              linkType: "Space",
              id: space_id,
            },
          },
          environment: {
            sys: {
              "id": environment,
              "type": "Link",
              "linkType": "Environment",
            },
          },
        },
      }
    end

    def stub_publishing_api_editions_for_cms_entity_ids(content_id:, locale:, space_id:, entry_id:)
      stub_publishing_api_get_editions(
        [{ "content_id" => content_id, "locale" => locale }],
        {
          cms_entity_ids: ["#{space_id}:Entry:#{entry_id}"],
          fields: %w[content_id locale],
          states: %w[draft published],
        },
      )
    end

    it "returns a 200 status when content has been updated", vcr: true do
      space_id = "space-1"
      entry_id = "entry-1"
      content_id = SecureRandom.uuid
      locale = "en"

      stub_content_items_config(space_id:, entry_id:, content_id:, locale:)
      stub_access_tokens_config(space_id:)

      stub_publishing_api_editions_for_cms_entity_ids(content_id:, locale:, space_id:, entry_id:)
      stub_publishing_api_does_not_have_item(content_id, { locale: })
      stub_any_publishing_api_put_content.to_return(body: { lock_version: 1 }.to_json)
      stub_any_publishing_api_publish

      vcr_contentful_api_response do
        post "/listener",
             webhook_payload(space_id:, entry_id:).to_json,
             "HTTP_X_CONTENTFUL_TOPIC" => "ContentManagement.Entry.publish"
      end

      expect(last_response.status).to eq(200)
      expect(last_response.body)
        .to eq("Updated the live content of #{content_id}:#{locale}\n" \
               "Updated the draft content of #{content_id}:#{locale}")
    end

    it "returns a 200 status when only draft is updated due to a draft Contentful change", vcr: true do
      space_id = "space-1"
      entry_id = "entry-1"
      content_id = SecureRandom.uuid
      locale = "en"

      stub_content_items_config(space_id:, entry_id:, content_id:, locale:)
      stub_access_tokens_config(space_id:)

      stub_publishing_api_editions_for_cms_entity_ids(content_id:, locale:, space_id:, entry_id:)
      stub_publishing_api_does_not_have_item(content_id, { locale: })
      stub_any_publishing_api_put_content.to_return(body: { lock_version: 1 }.to_json)

      vcr_contentful_api_response do
        post "/listener",
             webhook_payload(space_id:, entry_id:).to_json,
             "HTTP_X_CONTENTFUL_TOPIC" => "ContentManagement.Entry.auto_save"
      end

      expect(last_response.status).to eq(200)
      expect(last_response.body)
        .to eq("Updated the draft content of #{content_id}:#{locale}")
    end

    it "returns a 200 status when trying to update content that isn't configured in this repo" do
      content_id = SecureRandom.uuid
      locale = "en"

      stub_publishing_api_get_editions(
        [{ "content_id" => content_id, "locale" => locale }],
        {
          cms_entity_ids: ["space-id:Entry:entry-id"],
          fields: %w[content_id locale],
          states: %w[draft published],
        },
      )

      post "/listener",
           webhook_payload(space_id: "space-id", entry_id: "entry-id").to_json,
           "HTTP_X_CONTENTFUL_TOPIC" => "ContentManagement.Entry.publish"

      expect(last_response.status).to eq(200)
      expect(last_response.body)
        .to eq("Did not update #{content_id}:#{locale} as there isn't a configured Contentful mapping.")
    end

    it "returns a 200 status when no content is identified for updating" do
      stub_publishing_api_get_editions(
        [],
        {
          cms_entity_ids: ["space-id:Entry:entry-id"],
          fields: %w[content_id locale],
          states: %w[draft published],
        },
      )
      post "/listener",
           webhook_payload(space_id: "space-id", entry_id: "entry-id").to_json,
           "HTTP_X_CONTENTFUL_TOPIC" => "ContentManagement.Entry.publish"

      expect(last_response.status).to eq(200)
      expect(last_response.body)
        .to eq("No content updated, there was no configured content affected by the event.")
    end

    it "returns a 200 status when the webhook is not from an expected environment" do
      post "/listener", webhook_payload(environment: "testing").to_json

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("No work done: testing is not from the expected environment")
    end

    it "returns a 200 status when the webhook is not for a tracked event" do
      post "/listener",
           webhook_payload.to_json,
           "HTTP_X_CONTENTFUL_TOPIC" => "ContentManagement.Entry.test"

      expect(last_response.status).to eq(200)
      expect(last_response.body)
        .to eq("No work done: ContentManagement.Entry.test is not an event that we track")
    end

    it "returns a 400 status when receiving invalid JSON" do
      post "/listener", "invalid json"

      expect(last_response.status).to eq(400)
      expect(last_response.body).to eq("Invalid JSON payload")
    end
  end
end
