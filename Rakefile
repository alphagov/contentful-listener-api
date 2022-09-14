begin
  require "rubocop/rake_task"
  require "rspec/core/rake_task"
  require "vcr"

  RuboCop::RakeTask.new
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # These gems will fail to load outside of dev/test environments
end

require_relative "app"

namespace :content_item do
  desc "Sync a content item with the Publishing API"
  task :sync, :content_id, :locale do |_, args|
    args.with_defaults(locale: "en")

    content_config = ContentConfig.find(args[:content_id], args[:locale])

    abort "A content item is not configured for #{args[:content_id]}:#{args[:locale]}" unless content_config

    if ENV["RESERVE_PATH"]
      if content_config.base_path
        GdsApi.publishing_api.put_path(
          content_config.base_path,
          { publishing_app: PublishingApi::PUBLISHING_APP_NAME },
        )
        puts "Reserved #{content_config.base_path} for #{args[:content_id]}:#{args[:locale]}"
      else
        abort "A base_path isn't configured for #{args[:content_id]}:#{args[:locale]}"
      end
    end

    live_result = PublishingApi::Updater.update_live(content_config)
    puts live_result.to_s
    draft_result = PublishingApi::Updater.update_draft(content_config)
    puts draft_result.to_s
  end

  desc "Unpublish content from Publishing API"
  task :unpublish, :content_id, :locale do |_, args|
    args.with_defaults(locale: "en")
    type = ENV.fetch("TYPE", "gone")

    GdsApi.publishing_api.unpublish(args[:content_id],
                                    locale: args[:locale],
                                    type:,
                                    explanation: ENV["EXPLANATION"],
                                    alternative_path: ENV["URL"])

    puts "Unpublished #{args[:content_id]}:#{args[:locale]} from GOV.UK with a type of #{type}"
  end
end

namespace :vcr do
  desc "Generate a new cassette to mock Contentful API responses for tests"
  task :record_contentful_api_response do
    File.delete("spec/fixtures/vcr_cassettes/contentful_api_response.yml") if File.exist?("spec/fixtures/vcr_cassettes/contentful_api_response.yml")

    content_config = ContentConfig.all.last
    contentful_client = ContentfulClient.live_client(content_config.contentful_space_id)

    VCR.configure do |config|
      config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
      config.hook_into(:webmock)
      config.filter_sensitive_data("<ACCESS_TOKEN>") { contentful_client.configuration[:access_token] }
    end

    VCR.use_cassette("contentful_api_response", decode_compressed_response: true) do
      contentful_client.entry(content_config.contentful_entry_id, include: 10)
    end

    puts "Recorded new Contentful API response cassette"
  end
end

task default: %I[rubocop spec]
