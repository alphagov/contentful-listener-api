RSpec.describe ContentfulClient do
  def stub_space(space_id)
    allow(File).to receive(:read).with("config/access_tokens.yaml.erb").and_return <<~YAML
      - space_id: #{space_id}
        draft_access_token: draft-token
        live_access_token: live-token
    YAML
  end

  before { described_class.reset }

  describe ".live_client" do
    it "returns a Contentful::Client" do
      stub_space("test")
      expect(described_class.live_client("test")).to be_a(Contentful::Client)
    end

    it "raises an error when a space isn't configured" do
      expect { described_class.live_client("test") }
        .to raise_error("No access token configuration for space: test")
    end
  end

  describe ".draft_client" do
    it "returns a Contentful::Client" do
      stub_space("test")
      expect(described_class.draft_client("test")).to be_a(Contentful::Client)
    end

    it "raises an error when a space isn't configured" do
      expect { described_class.draft_client("test") }
        .to raise_error("No access token configuration for space: test")
    end
  end
end
