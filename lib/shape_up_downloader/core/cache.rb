# frozen_string_literal: true

require "digest"
require "fileutils"

module ShapeUpDownloader
  class Cache
    def initialize
      @cache_dir = File.join(Dir.pwd, ".cache")
      FileUtils.mkdir_p(@cache_dir)
    end

    def fetch(key)
      cache_file = cache_path(key)
      if File.exist?(cache_file)
        File.read(cache_file)
      else
        content = yield
        File.write(cache_file, content)
        content
      end
    end

    private

    def cache_path(key)
      File.join(@cache_dir, Digest::MD5.hexdigest(key))
    end
  end
end
