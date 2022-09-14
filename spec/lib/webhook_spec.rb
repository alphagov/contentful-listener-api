RSpec.describe Webhook do
  describe "#event_of_interest?" do
    it "returns true for a ContentManagement topic that updates an entry" do

    end

    it "returns true for a ContentManagement topic that updates an asset" do

    end

    it "returns false for a ContentManagement topic that updates something else" do

    end

    it "returns false for a ContentManagement topic that isn't an entry/asset update" do

    end

    it "returns false for a topic that isn't ContentManagement" do

    end
  end

  describe "#entity_id" do
    it "returns a string combining space_id, type and entity_id fields" do

    end

    it "raises an error if not all space_id, type and entity_id fields are set" do

    end
  end

  describe "#live_change?" do
    it "returns true if the webhook described an update that affects live content" do

    end

    it "returns false if the webhook describes any other update" do

    end
  end

  describe "#environment" do
    it "fetches the environment from the webhook payload" do

    end
  end

  describe "#expected_environment?" do
    it "returns true if the environment matches the contentful environment" do

    end

    it "returns false if the environment doesn't match the contentful environment" do

    end

    it "can match the environment based on a CONTENTFUL_ENVIRONMENT env var" do

    end
  end
end
