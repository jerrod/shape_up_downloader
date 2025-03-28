# frozen_string_literal: true

require "spec_helper"

RSpec.describe ShapeUpDownloader::Downloader do
  let(:downloader) { described_class.new }

  describe "#initialize" do
    it "creates a new cache instance" do
      expect { described_class.new }.not_to raise_error
    end

    it "sets up HTTP client with headers and timeout" do
      downloader = described_class.new
      expect(downloader.instance_variable_get(:@http)).to be_a(HTTP::Client)
    end
  end

  describe "#fetch_document" do
    let(:url) { "https://basecamp.com/shapeup/test" }
    let(:html_content) { "<html><body>Test content</body></html>" }

    before do
      allow_any_instance_of(HTTP::Client).to receive(:get).with(url).and_return(double(to_s: html_content))
    end

    it "fetches and parses HTML content from cache or HTTP" do
      doc = downloader.send(:fetch_document, url)
      expect(doc).to be_a(Nokogiri::HTML::Document)
      expect(doc.text).to include("Test content")
    end
  end

  describe "#extract_chapter_urls" do
    context "with table of contents" do
      let(:toc_html) do
        <<~HTML
          <div class="table-of-contents">
            <a href="/shapeup/1.1-chapter-1">Chapter 1</a>
            <a href="/shapeup/1.2-chapter-2">Chapter 2</a>
            <a href="/shapeup/1.3-conclusion">Conclusion</a>
            <a href="/other/not-a-chapter">Not a chapter</a>
          </div>
        HTML
      end
      let(:doc) { Nokogiri::HTML(toc_html) }

      it "extracts chapter URLs from table of contents and includes appendices" do
        urls = downloader.send(:extract_chapter_urls, doc)
        expect(urls).to include(
          "https://basecamp.com/shapeup/1.1-chapter-1",
          "https://basecamp.com/shapeup/1.2-chapter-2",
          "https://basecamp.com/shapeup/1.3-conclusion",
          "https://basecamp.com/shapeup/4.0-appendix-01",
          "https://basecamp.com/shapeup/4.1-appendix-02",
          "https://basecamp.com/shapeup/4.2-appendix-03",
          "https://basecamp.com/shapeup/4.5-appendix-06",
          "https://basecamp.com/shapeup/4.6-appendix-07"
        )
      end

      it "ignores non-chapter URLs" do
        urls = downloader.send(:extract_chapter_urls, doc)
        expect(urls).not_to include("https://basecamp.com/other/not-a-chapter")
      end
    end

    context "with alternative table of contents class" do
      let(:toc_html) do
        <<~HTML
          <div class="toc">
            <a href="/shapeup/1.1-chapter-1">Chapter 1</a>
            <a href="/shapeup/1.2-chapter-2">Chapter 2</a>
          </div>
        HTML
      end
      let(:doc) { Nokogiri::HTML(toc_html) }

      it "extracts chapter URLs from alternative TOC and includes appendices" do
        urls = downloader.send(:extract_chapter_urls, doc)
        expect(urls).to include(
          "https://basecamp.com/shapeup/1.1-chapter-1",
          "https://basecamp.com/shapeup/1.2-chapter-2",
          "https://basecamp.com/shapeup/4.0-appendix-01",
          "https://basecamp.com/shapeup/4.1-appendix-02",
          "https://basecamp.com/shapeup/4.2-appendix-03",
          "https://basecamp.com/shapeup/4.5-appendix-06",
          "https://basecamp.com/shapeup/4.6-appendix-07"
        )
      end
    end

    context "when no table of contents is found" do
      let(:content_html) do
        <<~HTML
          <div class="content">
            <h1><a href="/shapeup/1.1-chapter-1">Chapter 1</a></h1>
            <h2><a href="/shapeup/1.2-chapter-2">Chapter 2</a></h2>
            <h3><a href="/other/not-a-chapter">Not a chapter</a></h3>
          </div>
        HTML
      end
      let(:doc) { Nokogiri::HTML(content_html) }

      it "returns an empty array" do
        urls = downloader.send(:extract_chapter_urls, doc)
        expect(urls).to eq([])
      end
    end
  end

  describe "#modify_content" do
    let(:content_html) do
      <<~HTML
        <div>
          <img src="/images/test.png" />
          <img src="http://example.com/test.jpg" />
          <img src="http://ads.linkedin.com/ad.jpg" />
          <a href="/shapeup/1.1-chapter-1">Chapter 1</a>
          <a href="/shapeup/1.1-chapter-1#section">Section</a>
        </div>
      HTML
    end
    let(:doc) { Nokogiri::HTML(content_html) }
    let(:urls) { ["https://basecamp.com/shapeup/1.1-chapter-1"] }

    before do
      allow_any_instance_of(HTTP::Client).to receive(:get).with("https://basecamp.com/images/test.png").and_return(double(to_s: "\x89PNG\r\n\x1A\n"))
      allow_any_instance_of(HTTP::Client).to receive(:get).with("http://example.com/test.jpg").and_return(double(to_s: "JPEG content"))
    end

    it "converts images to base64" do
      modified_doc = downloader.send(:modify_content, doc, urls)
      images = modified_doc.css("img")
      expect(images[0]["src"]).to eq("https://basecamp.com/images/test.png")
      expect(images[1]["src"]).to eq("http://example.com/test.jpg")
    end

    it "ignores images from ignored domains" do
      modified_doc = downloader.send(:modify_content, doc, urls)
      images = modified_doc.css("img")
      expect(images[2]["src"]).to eq("http://ads.linkedin.com/ad.jpg")
    end

    it "updates internal links" do
      modified_doc = downloader.send(:modify_content, doc, urls)
      links = modified_doc.css("a")
      expect(links[0]["href"]).to eq("#1.1-chapter-1")
      expect(links[1]["href"]).to eq("#1.1-chapter-1#section")
    end
  end

  describe "#convert_image_to_base64" do
    let(:png_url) { "https://example.com/image.png" }
    let(:jpeg_url) { "https://example.com/image.jpg" }
    let(:png_content) { "\x89PNG\r\n\x1A\n" } # PNG magic number

    it "converts PNG images to base64" do
      allow_any_instance_of(HTTP::Client).to receive(:get).with(png_url).and_return(double(to_s: png_content))
      result = downloader.send(:convert_image_to_base64, png_url)
      expect(result).to start_with("data:image/png;base64,")
    end

    it "converts JPEG images to base64" do
      allow_any_instance_of(HTTP::Client).to receive(:get).with(jpeg_url).and_return(double(to_s: "not a PNG image"))
      result = downloader.send(:convert_image_to_base64, jpeg_url)
      expect(result).to start_with("data:image/jpeg;base64,")
    end
  end
end
