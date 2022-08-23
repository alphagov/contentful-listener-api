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

  def self.draft_access_token(space_id)
    config = access_token_config.find { |c| c["space_id"] == space_id }

    raise "No access token configuration for space: #{space_id}" unless config

    config["draft_access_token"]
  end

  def self.live_access_token(space_id)
    config = access_token_config.find { |c| c["space_id"] == space_id }

    raise "No access token configuration for space: #{space_id}" unless config

    config["live_access_token"]
  end

  def self.access_token_config
    @access_token_config ||= begin
                               contents = File.read("config/access_tokens.yaml.erb")
                               interpolated = ERB.new(contents).result
                               YAML.safe_load(interpolated)
                             end
  end
end
