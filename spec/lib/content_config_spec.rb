RSpec.describe ContentConfig do
  include StubConfig

  describe ".find" do
    before do
      stub_content_items_config(space_id: "space-id",
                                entry_id: "entry-id",
                                content_id: "content-id",
                                locale: "en")
    end

    it "returns a ContentConfig instance if content_id and locale match one" do
      result = described_class.find("content-id", "en")

      expect(result).to be_an_instance_of(described_class)

      expect(result).to have_attributes(contentful_space_id: "space-id",
                                        contentful_entry_id: "entry-id",
                                        content_id: "content-id")
    end

    it "returns nil if there isn't a corresponding ContentConfig item" do
      result = described_class.find("content-id", "cy")

      expect(result).to be_nil
    end
  end

  describe ".all" do
    it "returns an array of all ContentConfig items" do
      expect(described_class.all).to be_an(Array)
    end
  end

  describe "#locale" do
    it "defaults to a locale of english" do
      instance = described_class.new({
        "contentful_space_id" => "space-id",
        "contentful_entry_id" => "entry-id",
        "content_id" => "content-id",
      })

      expect(instance.locale).to eq("en")
    end

    it "can be overriden by passing locale in the publishing_api_attributes hash" do
      instance = described_class.new({
        "contentful_space_id" => "space-id",
        "contentful_entry_id" => "entry-id",
        "content_id" => "content-id",
        "publishing_api_attributes" => {
          "locale" => "cy",
        },
      })

      expect(instance.locale).to eq("cy")
    end
  end

  describe "#base_path" do
    it "returns a base_path if one is set" do
      instance = described_class.new({
        "contentful_space_id" => "space-id",
        "contentful_entry_id" => "entry-id",
        "content_id" => "content-id",
        "publishing_api_attributes" => {
          "base_path" => "/my-path",
        },
      })

      expect(instance.base_path).to eq("/my-path")
    end

    it "returns nil if there isn't a set base_path" do
      instance = described_class.new({
        "contentful_space_id" => "space-id",
        "contentful_entry_id" => "entry-id",
        "content_id" => "content-id",
      })

      expect(instance.base_path).to be_nil
    end
  end
end
