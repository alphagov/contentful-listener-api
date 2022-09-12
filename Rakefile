begin
  require "rubocop/rake_task"
  require "rspec/core/rake_task"

  RuboCop::RakeTask.new
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # These gems will fail to load outside of dev/test environments
end

require_relative "app"

desc "Sync a content item with the Publishing API"
task :sync_content_item, :content_id, :locale do |_, args|
  args.with_defaults(locale: "en")

  content_config = ContentConfig.find(args[:content_id], args[:locale])

  abort "A content item is not configured for #{args[:content_id]}:#{args[:locale]}" unless content_config

  live_result = PublishingApi::Updater.update_live(content_config)
  puts live_result.to_s
  draft_result = PublishingApi::Updater.update_draft(content_config)
  puts draft_result.to_s
end

task default: %I[rubocop spec]
