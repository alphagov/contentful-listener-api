RSpec.describe "Rake tasks" do
  describe "sync_content_item" do
    let(:content_config) { instance_double("ContentConfig") }

    before do
      allow(ContentConfig).to receive(:find).and_return(content_config)
      Rake::Task["sync_content_item"].reenable
    end

    it "updates draft and live content" do
      content_id = SecureRandom.uuid
      locale = "en"
      live_result = Result.new("live update")
      draft_result = Result.new("draft update")

      allow(PublishingApi::Updater).to receive(:update_live).and_return(live_result)
      allow(PublishingApi::Updater).to receive(:update_draft).and_return(draft_result)

      expect { Rake::Task["sync_content_item"].invoke(content_id, locale) }
        .to output("live update\ndraft update\n").to_stdout

      expect(ContentConfig).to have_received(:find).with(content_id, locale)
      expect(PublishingApi::Updater).to have_received(:update_draft)
      expect(PublishingApi::Updater).to have_received(:update_live)
    end

    it "defaults to an 'en' locale" do
      content_id = SecureRandom.uuid
      allow(PublishingApi::Updater).to receive(:update_live)
      allow(PublishingApi::Updater).to receive(:update_draft)

      expect { Rake::Task["sync_content_item"].invoke(content_id) }
        .to output.to_stdout

      expect(ContentConfig).to have_received(:find).with(content_id, "en")
    end

    it "aborts if there isn't content configured for the content id" do
      content_id = SecureRandom.uuid
      locale = "en"
      allow(ContentConfig).to receive(:find).and_return(nil)

      expect { Rake::Task["sync_content_item"].invoke(content_id, locale) }
        .to output("A content item is not configured for #{content_id}:#{locale}\n").to_stderr
        .and raise_error(SystemExit)
    end
  end
end
