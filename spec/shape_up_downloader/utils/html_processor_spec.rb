# frozen_string_literal: true

require "spec_helper"

RSpec.describe ShapeUpDownloader::Utils::HTMLProcessor do
  describe ".should_process_node?" do
    it "returns true for element nodes" do
      doc = Nokogiri::HTML("<div>Test</div>")
      expect(described_class.should_process_node?(doc.at_css("div"))).to be true
    end

    it "returns true for non-empty text nodes" do
      doc = Nokogiri::HTML("<div>Test</div>")
      expect(described_class.should_process_node?(doc.at_css("div").children.first)).to be true
    end

    it "returns false for empty text nodes" do
      doc = Nokogiri::HTML("<div>  </div>")
      expect(described_class.should_process_node?(doc.at_css("div").children.first)).to be false
    end
  end

  describe ".process_node" do
    let(:builder) { Nokogiri::XML::Builder.new }

    it "processes text nodes" do
      doc = Nokogiri::HTML("<div>Test</div>")
      builder.root do |xml|
        described_class.process_node(doc.at_css("div").children.first, xml)
      end
      expect(builder.doc.root.text).to eq("Test")
    end

    it "processes element nodes with attributes" do
      doc = Nokogiri::HTML('<div class="test">Content</div>')
      builder.root do |xml|
        described_class.process_node(doc.at_css("div"), xml)
      end
      div = builder.doc.root.at_xpath(".//div")
      expect(div["class"]).to eq("test")
      expect(div.text).to eq("Content")
    end

    it "processes nested nodes" do
      doc = Nokogiri::HTML("<div>Hello <span>World</span></div>")
      builder.root do |xml|
        described_class.process_node(doc.at_css("div"), xml)
      end
      result = builder.doc.root.to_xml
      expect(result).to include("Hello")
      expect(result).to include("World")
    end

    it "skips nodes that should not be processed" do
      doc = Nokogiri::HTML("<div>  </div>")
      builder.root do |xml|
        described_class.process_node(doc.at_css("div").children.first, xml)
      end
      expect(builder.doc.root.text.strip).to be_empty
    end
  end

  describe ".should_add_spacing?" do
    it "returns true for block-level elements" do
      block_elements = %w[p h1 h2 h3 h4 h5 h6 ul ol li blockquote pre]
      doc = Nokogiri::HTML(block_elements.map { |el| "<#{el}>Test</#{el}>" }.join)

      block_elements.each do |el|
        expect(described_class.should_add_spacing?(doc.at_css(el))).to be true
      end
    end

    it "returns false for inline elements" do
      inline_elements = %w[span a strong em code]
      doc = Nokogiri::HTML(inline_elements.map { |el| "<#{el}>Test</#{el}>" }.join)

      inline_elements.each do |el|
        expect(described_class.should_add_spacing?(doc.at_css(el))).to be false
      end
    end

    it "returns false for non-element nodes" do
      doc = Nokogiri::HTML("<div>Test</div>")
      expect(described_class.should_add_spacing?(doc.at_css("div").children.first)).to be false
    end
  end

  describe ".process_html" do
    it "removes navigation elements" do
      html = <<~HTML
        <nav>Navigation</nav>
        <div class="navigation">Nav</div>
        <div class="menu">Menu</div>
        <div class="nav">Nav</div>
        <div class="hamburger">Menu</div>
        <header>Header</header>
        <div class="header">Header</div>
        <div class="content">Content</div>
      HTML

      result = described_class.process_html(html)
      doc = Nokogiri::HTML(result)

      expect(doc.at_css("nav")).to be_nil
      expect(doc.at_css(".navigation")).to be_nil
      expect(doc.at_css(".menu")).to be_nil
      expect(doc.at_css(".nav")).to be_nil
      expect(doc.at_css(".hamburger")).to be_nil
      expect(doc.at_css("header")).to be_nil
      expect(doc.at_css(".header")).to be_nil
      expect(doc.at_css(".content")).not_to be_nil
    end
  end

  describe ".create_image_node" do
    let(:doc) { Nokogiri::XML::Document.new }
    let(:img_node) { Nokogiri::HTML("<img src='test.jpg' alt='Test Image'>").at_css("img") }

    it "creates an image node with src attribute" do
      result = described_class.create_image_node(img_node, doc)
      expect(result.name).to eq("img")
      expect(result["src"]).to eq("test.jpg")
    end

    it "includes alt attribute when present" do
      result = described_class.create_image_node(img_node, doc)
      expect(result["alt"]).to eq("Test Image")
    end

    it "handles images without alt attribute" do
      img_node = Nokogiri::HTML("<img src='test.jpg'>").at_css("img")
      result = described_class.create_image_node(img_node, doc)
      expect(result["alt"]).to be_nil
    end
  end

  describe ".create_paragraph_with_image" do
    let(:doc) { Nokogiri::XML::Document.new }
    let(:img_node) { Nokogiri::HTML("<img src='test.jpg' alt='Test Image'>").at_css("img") }

    it "creates a paragraph containing the image" do
      result = described_class.create_paragraph_with_image(img_node, doc)
      expect(result.name).to eq("p")
      expect(result.children.first.name).to eq("img")
      expect(result.children.first["src"]).to eq("test.jpg")
      expect(result.children.first["alt"]).to eq("Test Image")
    end
  end
end
