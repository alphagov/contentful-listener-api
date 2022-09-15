require "contentful"
require "yaml"

module ContentfulClient
  def self.draft_client(space_id)
    Contentful::Client.new(access_token: draft_access_token(space_id),
                           api_url: "preview.contentful.com",
                           environment: ENV.fetch("CONTENTFUL_ENVIRONMENT", "master"),
                           space: space_id)
  end

  def self.live_client(space_id)
    Contentful::Client.new(access_token: live_access_token(space_id),
                           environment: ENV.fetch("CONTENTFUL_ENVIRONMENT", "master"),
                           space: space_id)
  end

  def self.configured_spaces
    access_token_config.map { |c| c["space_id"] }
  end

  def self.reset
    @access_token_config = nil
  end

  def self.draft_access_token(space_id)
    config = access_token_config.find { |c| c["space_id"] == space_id }

    raise "No access token configuration for space: #{space_id}" unless config

    config["draft_access_token"]
  end

  private_class_method :draft_access_token

  def self.live_access_token(space_id)
    config = access_token_config.find { |c| c["space_id"] == space_id }

    raise "No access token configuration for space: #{space_id}" unless config

    config["live_access_token"]
  end

  private_class_method :live_access_token

  def self.access_token_config
    @access_token_config ||= begin
      contents = File.read("config/access_tokens.yaml.erb")
      interpolated = ERB.new(contents).result
      YAML.safe_load(interpolated)
    end
  end

  private_class_method :access_token_config
end
