RSpec.describe ContentfulClient do
  include StubConfig

  describe ".live_client" do
    it "returns a Contentful::Client" do
      stub_access_tokens_config(space_id: "test")
      expect(described_class.live_client("test")).to be_a(Contentful::Client)
    end

    it "raises an error when a space isn't configured" do
      expect { described_class.live_client("test") }
        .to raise_error("No access token configuration for space: test")
    end
  end

  describe ".draft_client" do
    it "returns a Contentful::Client" do
      stub_access_tokens_config(space_id: "test")
      expect(described_class.draft_client("test")).to be_a(Contentful::Client)
    end

    it "raises an error when a space isn't configured" do
      expect { described_class.draft_client("test") }
        .to raise_error("No access token configuration for space: test")
    end
  end

  describe ".configured_spaces" do
    it "returns an array of each configured space id" do
      stub_access_tokens_config(space_id: "test")
      expect(described_class.configured_spaces).to eq(%w[test])
    end
  end
end
