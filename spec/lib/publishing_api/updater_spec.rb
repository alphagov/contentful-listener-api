RSpec.describe PublishingApi::Updater do
  include GdsApi::TestHelpers::PublishingApi

  let(:content_id) { SecureRandom.uuid }
  let(:content_config) do
    ContentConfig.new({ "contentful_space_id" => "space-1",
                        "contentful_entry_id" => "entry-1",
                        "content_id" => content_id })
  end
  let(:content_state) { instance_double("PublishingApi::ContentState", lock_version: 1) }
  let(:contentful_client) { instance_double("Contentful::Client") }
  let(:contentful_entry) { instance_double("Contentful::Entry") }

  before do
    allow(ContentfulClient).to receive(:draft_client).and_return(contentful_client)
    allow(ContentfulClient).to receive(:live_client).and_return(contentful_client)
    allow(PublishingApi::ContentState).to receive(:new).and_return(content_state)
    allow(PublishingApi::ContentPayload)
      .to receive(:call)
      .with(contentful_client:, contentful_entry:, publishing_api_attributes: hash_including(previous_version: "1"))
      .and_return({})
  end

  describe ".update_draft" do
    it "returns a no draft root entry result if the entry is not found in Contentful" do
      allow(contentful_client).to receive(:entry).and_return(nil)

      result = described_class.update_draft(content_config)

      expect(result).to eq(Result.no_draft_root_entry(content_config))
    end

    it "returns a draft unchanged result if our draft payload matches the Publishing API data" do
      allow(contentful_client).to receive(:entry).and_return(contentful_entry)
      allow(content_state).to receive(:needs_draft_update?).and_return(false)

      result = described_class.update_draft(content_config)

      expect(result).to eq(Result.draft_unchanged(content_config))
    end

    it "returns a draft updated result if the Publishing API is updated" do
      allow(contentful_client).to receive(:entry).and_return(contentful_entry)
      allow(content_state).to receive(:needs_draft_update?).and_return(true)
      request = stub_publishing_api_put_content(content_id, {})

      result = described_class.update_draft(content_config)

      expect(result).to eq(Result.draft_updated(content_config))
      expect(request).to have_been_made
    end

    it "retries if the Publishing API has a conflict" do
      allow(contentful_client).to receive(:entry).and_return(contentful_entry)
      allow(content_state).to receive(:needs_draft_update?).and_return(true)

      request = stub_any_publishing_api_put_content.to_return(status: 409).then.to_return(status: 200)

      result = described_class.update_draft(content_config)

      expect(result).to eq(Result.draft_updated(content_config))
      expect(request).to have_been_made.times(2)
    end

    it "aborts if the Publishing API doesn't resolve the conflict after 3 attempts" do
      allow(contentful_client).to receive(:entry).and_return(contentful_entry)
      allow(content_state).to receive(:needs_draft_update?).and_return(true)

      request = stub_any_publishing_api_put_content.to_return(status: 409)

      expect { described_class.update_draft(content_config) }
        .to raise_error(GdsApi::HTTPConflict)

      expect(request).to have_been_made.times(3)
    end
  end

  describe ".update_live" do
    it "returns a live skipped draft only result if the live entry is configured as draft only" do
      content_config = ContentConfig.new({ "contentful_space_id" => "space-1",
                                           "contentful_entry_id" => "entry-1",
                                           "content_id" => content_id,
                                           "draft_only" => true })

      result = described_class.update_live(content_config)

      expect(result).to eq(Result.live_skipped_draft_only(content_config))
    end

    it "returns a no live root entry result if the live entry is not found in Contentful" do
      allow(contentful_client).to receive(:entry).and_return(nil)

      result = described_class.update_live(content_config)

      expect(result).to eq(Result.no_live_root_entry(content_config))
    end

    it "returns a live unchanged result if our draft payload matches the Publishing API data" do
      allow(contentful_client).to receive(:entry).and_return(contentful_entry)
      allow(content_state).to receive(:needs_live_update?).and_return(false)

      result = described_class.update_live(content_config)

      expect(result).to eq(Result.live_unchanged(content_config))
    end

    it "returns a live updated result if the Publishing API is updated" do
      allow(contentful_client).to receive(:entry).and_return(contentful_entry)
      allow(content_state).to receive(:needs_live_update?).and_return(true)
      put_content_request = stub_publishing_api_put_content(content_id, {}, { body: { lock_version: "2" } })
      publish_request = stub_publishing_api_publish(content_id, { update_type: nil, locale: "en", previous_version: "2" })

      result = described_class.update_live(content_config)

      expect(result).to eq(Result.live_updated(content_config))
      expect(put_content_request).to have_been_made
      expect(publish_request).to have_been_made
    end

    it "retries if the Publishing API has a conflict" do
      allow(contentful_client).to receive(:entry).and_return(contentful_entry)
      allow(content_state).to receive(:needs_live_update?).and_return(true)

      stub_publishing_api_put_content(content_id, {})
      publish_request = stub_any_publishing_api_publish.to_return(status: 409).then.to_return(status: 200)

      result = described_class.update_live(content_config)

      expect(result).to eq(Result.live_updated(content_config))
      expect(publish_request).to have_been_made.times(2)
    end
  end
end
