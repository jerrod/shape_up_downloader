# frozen_string_literal: true

require "bundler/setup"
require "fileutils"
require "vcr"
require "webmock/rspec"
require_relative "../lib/shape_up_downloader"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive data
  config.filter_sensitive_data("<FILTERED_URL>") { ShapeUpDownloader::Constants::BASE_URL }

  # Ignore localhost requests (for epubcheck)
  config.ignore_localhost = true
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Ensure Thor commands are loaded
  config.before(:suite) do
    ShapeUpDownloader::CLI.start([])
  end
end
