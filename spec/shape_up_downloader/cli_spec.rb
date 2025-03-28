# frozen_string_literal: true

require "spec_helper"

RSpec.describe ShapeUpDownloader::CLI do
  include ShapeUpDownloader::Constants

  let(:cli) { described_class.new }
  let(:dist_dir) { "dist" }
  let(:html_file) { File.join(dist_dir, "shape-up.html") }
  let(:epub_file) { File.join(dist_dir, "shape_up.epub") }

  before(:all) do
    # Force Thor to load commands
    ShapeUpDownloader::CLI.start([])
  end

  before do
    FileUtils.rm_rf(dist_dir) if File.directory?(dist_dir)
  end

  after do
    FileUtils.rm_rf(dist_dir) if File.directory?(dist_dir)
  end

  describe "download_single_html", :vcr do
    it "creates the dist directory" do
      cli.invoke(:download_single_html)
      expect(File.directory?(dist_dir)).to be true
    end

    it "downloads and saves the HTML file" do
      VCR.use_cassette("shape_up_download") do
        cli.invoke(:download_single_html)
        expect(File.exist?(html_file)).to be true
        expect(File.read(html_file)).to include("Shape Up")
      end
    end
  end

  describe "convert_to_epub" do
    context "when HTML file exists" do
      before do
        FileUtils.mkdir_p(dist_dir)
        File.write(html_file, <<~HTML)
          <div class="chapter" id="chapter-1">
            <div class="chapter-title">Test Chapter</div>
            <div class="content">Test content</div>
          </div>
          <div class="chapter" id="chapter-2">
            <div class="chapter-title">Another Chapter</div>
            <div class="content">More test content</div>
          </div>
        HTML
      end

      it "converts HTML to EPUB" do
        cli.invoke(:convert_to_epub)
        expect(File.exist?(epub_file)).to be true
      end

      it "handles custom input and output paths" do
        custom_input = File.join(dist_dir, "custom_input.html")
        custom_output = "custom_output.epub"
        FileUtils.cp(html_file, custom_input)

        cli.invoke(:convert_to_epub, [], {input: custom_input, output: custom_output})
        expect(File.exist?(File.join(dist_dir, custom_output))).to be true
      end
    end

    context "when HTML file doesn't exist" do
      it "shows error message" do
        expect { cli.invoke(:convert_to_epub) }.to output(/Error: Input file/).to_stdout
      end
    end
  end

  describe "validate_epub" do
    context "when EPUB file exists" do
      before do
        FileUtils.mkdir_p(dist_dir)
        File.write(html_file, <<~HTML)
          <div class="chapter" id="chapter-1">
            <div class="chapter-title">Test Chapter</div>
            <div class="content">Test content</div>
          </div>
          <div class="chapter" id="chapter-2">
            <div class="chapter-title">Another Chapter</div>
            <div class="content">More test content</div>
          </div>
        HTML
        cli.invoke(:convert_to_epub)
      end

      it "attempts to validate the EPUB file" do
        allow_any_instance_of(ShapeUpDownloader::CLI).to receive(:run_epubcheck).with(File.expand_path(epub_file)).and_return(true)
        expect { cli.invoke(:validate_epub) }.to output(/Validation successful/).to_stdout
      end

      it "handles custom input path" do
        custom_epub = File.join(dist_dir, "custom.epub")
        FileUtils.cp(epub_file, custom_epub)

        allow_any_instance_of(ShapeUpDownloader::CLI).to receive(:run_epubcheck).with(File.expand_path(custom_epub)).and_return(true)
        expect { cli.invoke(:validate_epub, [], input: custom_epub) }.to output(/Validation successful/).to_stdout
      end

      it "shows error message when validation fails" do
        allow_any_instance_of(ShapeUpDownloader::CLI).to receive(:run_epubcheck).with(File.expand_path(epub_file)).and_return(false)
        expect { cli.invoke(:validate_epub) }.to output(/Validation failed/).to_stdout
      end
    end

    context "when EPUB file doesn't exist" do
      it "shows error message" do
        expect { cli.invoke(:validate_epub) }.to output(/Error: Input file/).to_stdout
      end
    end

    context "when epubcheck is not installed" do
      before do
        FileUtils.mkdir_p(dist_dir)
        File.write(html_file, <<~HTML)
          <div class="chapter" id="chapter-1">
            <div class="chapter-title">Test Chapter</div>
            <div class="content">Test content</div>
          </div>
          <div class="chapter" id="chapter-2">
            <div class="chapter-title">Another Chapter</div>
            <div class="content">More test content</div>
          </div>
        HTML
        cli.invoke(:convert_to_epub)
      end

      it "shows installation instructions" do
        allow_any_instance_of(ShapeUpDownloader::CLI).to receive(:run_epubcheck).with(File.expand_path(epub_file)).and_raise(Errno::ENOENT)
        expect { cli.invoke(:validate_epub) }.to output(/Error: epubcheck is not installed/).to_stdout
      end
    end
  end
end
