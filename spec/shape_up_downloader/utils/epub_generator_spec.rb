# frozen_string_literal: true

require "spec_helper"

RSpec.describe ShapeUpDownloader::Utils::EPUBGenerator do
  include ShapeUpDownloader::Constants

  let(:book) { GEPUB::Book.new }

  describe ".create_book" do
    it "creates a new EPUB book with correct metadata" do
      result = described_class.create_book
      expect(result).to be_a(GEPUB::Book)
      expect(result.identifier).to eq("https://basecamp.com/shapeup")
      expect(result.metadata.language.content).to eq("en")
      expect(result.metadata.title.content).to eq("Shape Up: Stop Running in Circles and Ship Work that Matters")
      expect(result.metadata.creator.content).to eq("Ryan Singer")
      expect(result.metadata.publisher.content).to eq("Basecamp")
      expect(result.metadata.date).to be_a(GEPUB::DateMeta)
    end
  end

  describe ".add_cover" do
    let(:cover_image_path) { "spec/fixtures/cover.png" }

    before do
      FileUtils.mkdir_p("spec/fixtures")
      File.write(cover_image_path, "fake image content")
    end

    after do
      FileUtils.rm_rf("spec/fixtures")
    end

    it "adds cover image and page when cover exists" do
      described_class.add_cover(book, cover_image_path)
      expect(book.manifest.items.size).to eq(2) # cover image and cover page
      expect(book.spine.itemref_list.size).to eq(1) # cover page in spine
      expect(book.manifest.items.values.map { |i| i.href }).to include("images/cover.png", "text/cover.xhtml")
    end

    it "does nothing when cover doesn't exist" do
      described_class.add_cover(book, "nonexistent.png")
      expect(book.manifest.items.size).to eq(0)
      expect(book.spine.itemref_list.size).to eq(0)
    end
  end

  describe ".add_style" do
    it "adds style.css to the book" do
      described_class.add_style(book)
      expect(book.manifest.items.size).to eq(1)
      expect(book.manifest.items.values.first.href).to eq("styles/style.css")
    end
  end

  describe ".add_table_of_contents" do
    let(:doc) do
      Nokogiri::HTML(<<~HTML)
        <div class="chapter" id="1.1-chapter-01">
          <div class="chapter-title">Chapter 1</div>
        </div>
        <div class="chapter" id="1.2-chapter-02">
          <div class="chapter-title">Chapter 2</div>
        </div>
      HTML
    end

    it "adds table of contents to the book" do
      described_class.add_table_of_contents(book, doc)
      expect(book.manifest.items.size).to eq(3) # toc.xhtml, chapter-1-1-chapter-01.xhtml, chapter-1-2-chapter-02.xhtml
      expect(book.manifest.items.values.map(&:href)).to include("text/toc.xhtml", "text/chapter-1-1-chapter-01.xhtml", "text/chapter-1-2-chapter-02.xhtml")
      expect(book.spine.itemref_list.size).to eq(3)
    end
  end

  describe ".process_chapter_content" do
    let(:chapter) do
      Nokogiri::HTML(<<~HTML)
        <div class="chapter" id="1.1-chapter-01">
          <div class="intro__masthead">
            <nav>Navigation</nav>
          </div>
          <div class="chapter-title">Test Chapter</div>
          <div class="chapter-content">Test content</div>
        </div>
      HTML
    end
    let(:original_id) { "1.1-chapter-01" }
    let(:fragment_map) { {} }
    let(:chapter_id_map) { { original_id => "chapter-1-1-chapter-01" } }
    let(:section_to_chapter_map) { {} }

    it "processes chapter content and removes navigation" do
      result = described_class.process_chapter_content(chapter, original_id, fragment_map, chapter_id_map, section_to_chapter_map)
      processed_doc = Nokogiri::HTML(result)
      expect(processed_doc.at_css(".intro__masthead")).to be_nil
      expect(processed_doc.at_css("nav")).to be_nil
      expect(processed_doc.at_css(".chapter-content")).not_to be_nil
    end

    it "cleans up chapter title" do
      result = described_class.process_chapter_content(chapter, original_id, fragment_map, chapter_id_map, section_to_chapter_map)
      processed_doc = Nokogiri::HTML(result)
      expect(processed_doc.at_css(".chapter-title")).to be_nil
      expect(processed_doc.at_css(".chapter-content")).not_to be_nil
    end

    it "processes internal links correctly" do
      chapter = Nokogiri::HTML(<<~HTML)
        <div class="chapter" id="1.1-chapter-01">
          <div class="chapter-title">Test Chapter</div>
          <div class="content">
            <p>Test content with <a href="#1.2-chapter-02">link to chapter 2</a></p>
          </div>
        </div>
      HTML
      chapter_id_map = {
        "1.1-chapter-01" => "chapter-1-1-chapter-01",
        "1.2-chapter-02" => "chapter-1-2-chapter-02"
      }
      
      result = described_class.process_chapter_content(chapter, "1.1-chapter-01", {}, chapter_id_map, {})
      processed_doc = Nokogiri::HTML(result)
      link = processed_doc.at_css("a")
      expect(link["href"]).to eq("chapter-1-2-chapter-02.xhtml")
    end

    it "processes section links correctly" do
      chapter = Nokogiri::HTML(<<~HTML)
        <div class="chapter" id="1.1-chapter-01">
          <div class="chapter-title">Test Chapter</div>
          <div class="content">
            <p>Test content with <a href="#section">link to section</a></p>
            <h2 id="section">Section Title</h2>
          </div>
        </div>
      HTML
      
      result = described_class.process_chapter_content(chapter, "1.1-chapter-01", {}, { "1.1-chapter-01" => "chapter-1-1-chapter-01" }, {})
      processed_doc = Nokogiri::HTML(result)
      link = processed_doc.at_css("a")
      expect(link["href"]).to eq("#section")
    end
  end
end
