RSpec.describe "Rake tasks" do
  include GdsApi::TestHelpers::PublishingApi

  describe "content_item:sync" do
    let(:content_config) { instance_double("ContentConfig") }

    before do
      allow(ContentConfig).to receive(:find).and_return(content_config)
      Rake::Task["content_item:sync"].reenable
    end

    it "updates draft and live content" do
      content_id = SecureRandom.uuid
      locale = "en"
      live_result = Result.new("live update")
      draft_result = Result.new("draft update")

      allow(PublishingApi::Updater).to receive(:update_live).and_return(live_result)
      allow(PublishingApi::Updater).to receive(:update_draft).and_return(draft_result)

      expect { Rake::Task["content_item:sync"].invoke(content_id, locale) }
        .to output("live update\ndraft update\n").to_stdout

      expect(ContentConfig).to have_received(:find).with(content_id, locale)
      expect(PublishingApi::Updater).to have_received(:update_draft)
      expect(PublishingApi::Updater).to have_received(:update_live)
    end

    it "defaults to an 'en' locale" do
      content_id = SecureRandom.uuid
      allow(PublishingApi::Updater).to receive(:update_live)
      allow(PublishingApi::Updater).to receive(:update_draft)

      expect { Rake::Task["content_item:sync"].invoke(content_id) }
        .to output.to_stdout

      expect(ContentConfig).to have_received(:find).with(content_id, "en")
    end

    it "aborts if there isn't content configured for the content id" do
      content_id = SecureRandom.uuid
      locale = "en"
      allow(ContentConfig).to receive(:find).and_return(nil)

      expect { Rake::Task["content_item:sync"].invoke(content_id, locale) }
        .to output("A content item is not configured for #{content_id}:#{locale}\n").to_stderr
        .and raise_error(SystemExit)
    end

    it "reserves a path if RESERVE_PATH is set" do
      content_id = SecureRandom.uuid
      locale = "en"
      base_path = "/test"
      allow(PublishingApi::Updater).to receive(:update_live)
      allow(PublishingApi::Updater).to receive(:update_draft)
      allow(content_config).to receive(:base_path).and_return(base_path)

      put_path_endpoint = "#{GdsApi::TestHelpers::PublishingApi::PUBLISHING_API_ENDPOINT}/paths"
      put_path_request = stub_request(:put, "#{put_path_endpoint}#{base_path}")
        .with(body: { publishing_app: "contentful-listener" }.to_json)

      ClimateControl.modify(RESERVE_PATH: "true") do
        expect { Rake::Task["content_item:sync"].invoke(content_id, locale) }
          .to output(/Reserved #{base_path} for #{content_id}:#{locale}/).to_stdout
      end

      expect(put_path_request).to have_been_made
    end

    it "aborts if RESERVE_PATH is set but the content doesn't have a base_path" do
      content_id = SecureRandom.uuid
      locale = "en"
      allow(PublishingApi::Updater).to receive(:update_live)
      allow(PublishingApi::Updater).to receive(:update_draft)
      allow(content_config).to receive(:base_path).and_return(nil)

      ClimateControl.modify(RESERVE_PATH: "true") do
        expect { Rake::Task["content_item:sync"].invoke(content_id, locale) }
          .to output("A base_path isn't configured for #{content_id}:#{locale}\n").to_stderr
          .and raise_error(SystemExit)
      end
    end
  end

  describe "content_item:unpublish" do
    before do
      Rake::Task["content_item:unpublish"].reenable
    end

    it "unpublishes content from GOV.UK defaulting to a type of gone" do
      content_id = SecureRandom.uuid
      locale = "en"

      unpublish_request = stub_publishing_api_unpublish(
        content_id,
        { body: { type: "gone", discard_drafts: true, locale: } },
      )

      expect { Rake::Task["content_item:unpublish"].invoke(content_id, locale) }
        .to output("Unpublished #{content_id}:#{locale} from GOV.UK with a type of gone\n").to_stdout

      expect(unpublish_request).to have_been_made
    end

    it "defaults to a locale of 'en'" do
      content_id = SecureRandom.uuid

      unpublish_request = stub_publishing_api_unpublish(
        content_id,
        { body: { type: "gone", discard_drafts: true, locale: "en" } },
      )

      expect { Rake::Task["content_item:unpublish"].invoke(content_id) }
        .to output.to_stdout

      expect(unpublish_request).to have_been_made
    end

    it "can be configured to for a redirect" do
      content_id = SecureRandom.uuid
      locale = "en"

      unpublish_request = stub_publishing_api_unpublish(
        content_id,
        { body: { type: "redirect", alternative_path: "/other", discard_drafts: true, locale: } },
      )

      ClimateControl.modify(TYPE: "redirect", URL: "/other") do
        expect { Rake::Task["content_item:unpublish"].invoke(content_id, locale) }
          .to output.to_stdout
      end

      expect(unpublish_request).to have_been_made
    end

    it "can accept an explanation" do
      content_id = SecureRandom.uuid
      locale = "en"
      explanation = "This is why this page is gone"

      unpublish_request = stub_publishing_api_unpublish(
        content_id,
        { body: { type: "gone", explanation:, discard_drafts: true, locale: } },
      )

      ClimateControl.modify(EXPLANATION: explanation) do
        expect { Rake::Task["content_item:unpublish"].invoke(content_id, locale) }
          .to output.to_stdout
      end

      expect(unpublish_request).to have_been_made
    end
  end
end
