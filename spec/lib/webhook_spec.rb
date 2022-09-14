RSpec.describe Webhook do
  describe "#event_of_interest?" do
    let(:payload) { {} }

    it "returns true for a ContentManagement topic that updates an entry" do
      instance = described_class.new("ContentManagement.Entry.save", payload)

      expect(instance.event_of_interest?).to be(true)
    end

    it "returns true for a ContentManagement topic that updates an asset" do
      instance = described_class.new("ContentManagement.Asset.save", payload)

      expect(instance.event_of_interest?).to be(true)
    end

    it "returns false for a ContentManagement topic that updates something else" do
      instance = described_class.new("ContentManagement.ContentType.save", payload)

      expect(instance.event_of_interest?).to be(false)
    end

    it "returns false for a ContentManagement topic that isn't an entry/asset update" do
      instance = described_class.new("ContentManagement.Entry.different", payload)

      expect(instance.event_of_interest?).to be(false)
    end

    it "returns false for a topic that isn't ContentManagement" do
      instance = described_class.new("SomethingDifferent.Asset.save", payload)

      expect(instance.event_of_interest?).to be(false)
    end
  end

  describe "#entity_id" do
    let(:topic) { "ContentManagement.Entry.save" }

    it "returns a string combining space_id, type and entity_id fields" do
      payload = {
        "sys" => {
          "id" => "entry-1",
          "type" => "Entry",
          "space" => {
            "sys" => { "id" => "space-1" },
          },
        },
      }

      instance = described_class.new(topic, payload)

      expect(instance.entity_id).to eq("space-1:Entry:entry-1")
    end

    it "raises an error if not all space_id, type and entity_id fields are set" do
      payload = {
        "sys" => {
          "id" => "entry-1",
          "type" => "Entry",
        },
      }

      instance = described_class.new(topic, payload)

      expect { instance.entity_id }.to raise_error("Unable to identify entity id")
    end
  end

  describe "#live_change?" do
    let(:payload) { {} }

    it "returns true if the webhook described an update that affects live content" do
      instance = described_class.new("ContentManagement.Asset.publish", payload)

      expect(instance.event_of_interest?).to be(true)
    end

    it "returns false if the webhook describes any other update" do
      instance = described_class.new("ContentManagement.Asset.auto_save", payload)

      expect(instance.event_of_interest?).to be(true)
    end
  end

  describe "#environment" do
    let(:topic) { "ContentManagement.Entry.save" }

    it "fetches the environment from the webhook payload" do
      payload = {
        "sys" => {
          "environment" => {
            "sys" => { "id" => "testing" },
          },
        },
      }

      instance = described_class.new(topic, payload)

      expect(instance.environment).to eq("testing")
    end
  end

  describe "#expected_environment?" do
    let(:topic) { "ContentManagement.Entry.save" }

    it "returns true if the environment matches the contentful environment" do
      payload = {
        "sys" => {
          "environment" => {
            "sys" => { "id" => "master" },
          },
        },
      }

      instance = described_class.new(topic, payload)

      expect(instance.expected_environment?).to be(true)
    end

    it "returns false if the environment doesn't match the contentful environment" do
      payload = {
        "sys" => {
          "environment" => {
            "sys" => { "id" => "testing" },
          },
        },
      }

      instance = described_class.new(topic, payload)

      expect(instance.expected_environment?).to be(false)
    end

    it "can match the environment based on a CONTENTFUL_ENVIRONMENT env var" do
      payload = {
        "sys" => {
          "environment" => {
            "sys" => { "id" => "testing" },
          },
        },
      }

      instance = described_class.new(topic, payload)

      ClimateControl.modify(CONTENTFUL_ENVIRONMENT: "testing") do
        expect(instance.expected_environment?).to be(true)
      end
    end
  end
end
