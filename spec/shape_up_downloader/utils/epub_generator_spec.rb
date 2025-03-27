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
        <div class="chapter">
          <div class="chapter-title">Chapter 1</div>
        </div>
        <div class="chapter">
          <div class="chapter-title">Chapter 2</div>
        </div>
      HTML
    end

    it "adds table of contents to the book" do
      described_class.add_table_of_contents(book, doc)
      expect(book.manifest.items.size).to eq(1)
      expect(book.manifest.items.values.first.href).to eq("text/toc.xhtml")
      expect(book.spine.itemref_list.size).to eq(1)
    end
  end

  describe ".add_chapter" do
    let(:chapter) do
      Nokogiri::HTML(<<~HTML)
        <div class="chapter">
          <nav>Navigation</nav>
          <div class="chapter-title">Test Chapter</div>
          <div class="content">Test content</div>
        </div>
      HTML
    end
    let(:processed_images) { {} }

    it "adds chapter to the book" do
      described_class.add_chapter(book, chapter, 0, processed_images)
      expect(book.manifest.items.size).to eq(1)
      expect(book.manifest.items.values.first.href).to eq("text/chapter_01.xhtml")
      expect(book.spine.itemref_list.size).to eq(1)
    end

    it "removes navigation elements" do
      described_class.add_chapter(book, chapter, 0, processed_images)
      expect(chapter.at_css("nav")).to be_nil
    end

    it "cleans up chapter title" do
      described_class.add_chapter(book, chapter, 0, processed_images)
      title = chapter.at_css("h1")
      expect(title).not_to be_nil
      expect(title.text).to eq("Test Chapter")
      expect(title["class"]).to be_nil
    end
  end
end
