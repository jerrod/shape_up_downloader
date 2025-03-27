# frozen_string_literal: true

require "spec_helper"

RSpec.describe ShapeUpDownloader::Cache do
  let(:cache) { described_class.new }
  let(:cache_dir) { File.join(Dir.pwd, ".cache") }
  let(:test_key) { "test_key" }
  let(:test_content) { "test content" }

  before do
    # Ensure cache directory exists
    FileUtils.mkdir_p(cache_dir)
  end

  after do
    # Clean up test files
    FileUtils.rm_rf(cache_dir)
  end

  describe "#initialize" do
    it "creates the cache directory if it doesn't exist" do
      FileUtils.rm_rf(cache_dir)
      expect { described_class.new }.to change { Dir.exist?(cache_dir) }.from(false).to(true)
    end
  end

  describe "#fetch" do
    context "when the cache is empty" do
      it "yields the block and stores the result" do
        result = cache.fetch(test_key) { test_content }
        expect(result).to eq(test_content)
        expect(File.read(cache.send(:cache_path, test_key))).to eq(test_content)
      end

      it "returns the yielded content" do
        expect(cache.fetch(test_key) { test_content }).to eq(test_content)
      end

      it "yields control to the block" do
        expect { |b| cache.fetch(test_key, &b) }.to yield_control
      end
    end

    context "when the cache has content" do
      before do
        File.write(cache.send(:cache_path, test_key), test_content)
      end

      it "returns the cached content without yielding" do
        expect { |b| cache.fetch(test_key, &b) }.not_to yield_control
        expect(cache.fetch(test_key) { "new content" }).to eq(test_content)
      end
    end
  end

  describe "#cache_path" do
    it "generates a consistent path for the same key" do
      path1 = cache.send(:cache_path, test_key)
      path2 = cache.send(:cache_path, test_key)
      expect(path1).to eq(path2)
    end

    it "generates different paths for different keys" do
      path1 = cache.send(:cache_path, "key1")
      path2 = cache.send(:cache_path, "key2")
      expect(path1).not_to eq(path2)
    end

    it "generates paths within the cache directory" do
      path = cache.send(:cache_path, test_key)
      expect(path).to start_with(cache_dir)
    end
  end
end
