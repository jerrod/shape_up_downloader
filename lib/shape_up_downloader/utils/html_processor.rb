# frozen_string_literal: true

module ShapeUpDownloader
  module Utils
    class HTMLProcessor
      def self.should_process_node?(node)
        node.element? || (node.text? && node.text.strip != "")
      end

      def self.process_node(node, xml)
        return unless should_process_node?(node)

        if node.text?
          xml.text(node.text)
        else
          xml.send(node.name, node.attributes) do
            node.children.each do |child|
              process_node(child, xml)
            end
          end
        end
      end

      def self.should_add_spacing?(node)
        return false unless node&.element?

        case node.name
        when "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "blockquote", "pre"
          true
        else
          false
        end
      end

      def self.process_html(html)
        doc = Nokogiri::HTML(html)
        doc.css('nav, .navigation, .menu, .nav, [class*="menu"], [class*="nav"], .hamburger, .hamburger-menu, header, .header').remove
        doc.to_html
      end

      def self.create_image_node(img_node, doc)
        img = Nokogiri::XML::Node.new("img", doc)
        img["src"] = img_node["src"]
        img["alt"] = img_node["alt"] if img_node["alt"]
        img
      end

      def self.create_paragraph_with_image(img_node, doc)
        p = Nokogiri::XML::Node.new("p", doc)
        p.add_child(create_image_node(img_node, doc))
        p
      end
    end
  end
end
