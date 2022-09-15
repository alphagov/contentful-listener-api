RSpec.describe Healthcheck::ContentfulCheck do
  def healthy_client
    instance_double("Contentful::Client", space: nil)
  end

  def unhealthy_client
    raw = OpenStruct.new(body: "access denied", status: 403)
    contentful_response = instance_double("ContentfulResponse", raw:, load_json: {})
    client = instance_double("Contentful::Client")
    allow(client).to receive(:space).and_raise(Contentful::AccessDenied, contentful_response)
    client
  end

  describe "#status" do
    it "returns :ok when it's healthy" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return(%w[space-id])
      allow(ContentfulClient).to receive(:draft_client).and_return(healthy_client)
      allow(ContentfulClient).to receive(:live_client).and_return(healthy_client)

      expect(described_class.new.status).to eq(:ok)
    end

    it "returns :warning when there are no clients" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return([])

      expect(described_class.new.status).to eq(:warning)
    end

    it "returns :critical when there is an unhealthy client" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return(%w[space-id])
      allow(ContentfulClient).to receive(:draft_client).and_return(healthy_client)
      allow(ContentfulClient).to receive(:live_client).and_return(unhealthy_client)

      expect(described_class.new.status).to eq(:critical)
    end
  end

  describe "#details" do
    it "returns a hash showing each individual space health" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return(%w[space-1 space-2])

      allow(ContentfulClient).to receive(:draft_client).with("space-1").and_return(healthy_client)
      allow(ContentfulClient).to receive(:live_client).with("space-1").and_return(unhealthy_client)
      allow(ContentfulClient).to receive(:draft_client).with("space-2").and_return(unhealthy_client)
      allow(ContentfulClient).to receive(:live_client).with("space-2").and_return(healthy_client)

      expect(described_class.new.details).to match({
        space_connectivity: [
          {
            space_id: "space-1",
            draft_communication: { success: true },
            live_communication: hash_including(success: false, message: instance_of(String)),
          },
          {
            space_id: "space-2",
            draft_communication: hash_including(success: false, message: instance_of(String)),
            live_communication: { success: true },
          },
        ],
      })
    end
  end

  describe "#message" do
    it "returns a string explaining when things are healthy" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return(%w[space-id])
      allow(ContentfulClient).to receive(:draft_client).and_return(healthy_client)
      allow(ContentfulClient).to receive(:live_client).and_return(healthy_client)

      expect(described_class.new.message).to eq("successfully connected to each Contentful space")
    end

    it "returns a string explaining when there are no clients" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return([])

      expect(described_class.new.message).to eq("no Contentful spaces configured")
    end

    it "explains when a space has a problem" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return(%w[bb8])
      allow(ContentfulClient).to receive(:draft_client).and_return(healthy_client)
      allow(ContentfulClient).to receive(:live_client).and_return(unhealthy_client)

      expect(described_class.new.message).to eq("failed to connect to Contentful spaces: space bb8 (live)")
    end

    it "can explain when multiple spaces have problems" do
      allow(ContentfulClient).to receive(:configured_spaces).and_return(%w[r2d2 c3po])

      allow(ContentfulClient).to receive(:draft_client).with("r2d2").and_return(unhealthy_client)
      allow(ContentfulClient).to receive(:live_client).with("r2d2").and_return(unhealthy_client)
      allow(ContentfulClient).to receive(:draft_client).with("c3po").and_return(unhealthy_client)
      allow(ContentfulClient).to receive(:live_client).with("c3po").and_return(healthy_client)

      expect(described_class.new.message).to eq("failed to connect to Contentful spaces: space r2d2 (draft and live), space c3po (draft)")
    end
  end
end
