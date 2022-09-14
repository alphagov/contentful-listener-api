ENV["APP_ENV"] = "test"

require "simplecov"
SimpleCov.start

require_relative "../app"
require "climate_control"
require "gds_api/test_helpers/publishing_api"
require "webmock/rspec"
require "vcr"

Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |f| require f }

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4.
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3).
  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.order = :random
  Kernel.srand(config.seed)

  config.before do
    ContentConfig.reset
    ContentfulClient.reset
  end

  # Turn off VCR by default and only turn it on in specific tests
  VCR.turn_off!

  config.around(vcr: true) do |example|
    VCR.turn_on!
    example.run
    VCR.turn_off!
  end
end
