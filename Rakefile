begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # Gems will fail to load outside of dev/test environments
end

task default: %I[rubocop]
