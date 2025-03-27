# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "fileutils"

module ShapeUpDownloader
  module Utils
    class EPUBGenerator
      include ShapeUpDownloader::Constants

      def self.create_book
        book = GEPUB::Book.new
        book.primary_identifier("https://basecamp.com/shapeup")
        book.language = "en"
        book.title = "Shape Up: Stop Running in Circles and Ship Work that Matters"
        book.creator = "Ryan Singer"
        book.publisher = "Basecamp"
        book.date = Time.now
        book
      end

      def self.add_cover(book, cover_image_path)
        return unless File.exist?(cover_image_path)

        # Add cover image
        cover_item = book.add_item("images/cover.png", id: "cover-image")
        cover_item.add_content(File.open(cover_image_path))
        cover_item.cover_image

        # Create cover page
        cover_html = <<~HTML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html>
          <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <head>
            <title>Cover</title>
            <link rel="stylesheet" type="text/css" href="../styles/style.css" />
          </head>
          <body>
            <div class="cover">
              <img src="../#{cover_item.href}" alt="Cover" />
            </div>
          </body>
          </html>
        HTML
        cover_page = book.add_item("text/cover.xhtml", id: "cover")
        cover_page.add_content(StringIO.new(cover_html))
        book.spine << cover_page
      end

      def self.add_style(book)
        book.add_item("styles/style.css", content: StringIO.new(STYLE_CSS))
      end

      def self.add_table_of_contents(book, doc)
        # Create an array of all chapters with their titles and process images
        processed_images = {}
        chapters = doc.css(".chapter").map.with_index do |chapter, idx|
          num = format("%02d", idx + 1)
          title = chapter.at_css(".chapter-title")&.text&.strip || "Chapter #{num}"
          # Handle special cases for conclusion and appendices
          title = case chapter['id']
          when /conclusion/
            "Conclusion"
          when /4\.0-appendix-01/
            "How to Implement Shape Up in Basecamp"
          when /4\.1-appendix-02/
            "Adjust to Your Size"
          when /4\.2-appendix-03/
            "How to Begin to Shape Up"
          when /4\.5-appendix-06/
            "Glossary"
          when /4\.6-appendix-07/
            "About the Author"
          else
            title
          end
          # Ensure proper chapter numbering for all chapters
          chapter_num = if chapter['id'] =~ /(\d+\.\d+)-(?:chapter|appendix)-(\d+)/
            $2.to_i.to_s.rjust(2, "0")
          elsif chapter['id'] =~ /conclusion/
            "16"
          else
            num
          end

          # Process images in the chapter
          processed_chapter = process_images_in_chapter(chapter, book, processed_images)

          [chapter_num, title, processed_chapter]
        end

        # Sort chapters by number to ensure correct order
        chapters.sort_by! { |num, _, _| num.to_i }

        # Generate HTML table of contents
        toc_html = <<~HTML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html>
          <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <head>
            <title>Table of Contents</title>
            <link rel="stylesheet" type="text/css" href="../styles/style.css" />
          </head>
          <body>
            <div class="table-of-contents">
              <h1>Table of Contents</h1>
              <nav epub:type="toc" id="toc">
                <ol>
                  #{chapters.map { |num, title, _| "<li><a href='chapter_#{num}.xhtml'>#{title}</a></li>" }.join("\n")}
                </ol>
              </nav>
            </div>
          </body>
          </html>
        HTML

        # Add HTML table of contents to the book
        toc_item = book.add_item("text/toc.xhtml", id: "toc")
        toc_item.add_content(StringIO.new(toc_html))
        book.spine << toc_item

        # Add chapters to the spine in order
        added_chapters = {}
        chapters.each do |num, title, chapter_content|
          next if added_chapters[num] # Skip if chapter already added

          # Process chapter content
          processed_chapter = process_chapter_content(chapter_content, num)

          # Create chapter XHTML
          chapter_html = <<~HTML
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
            <head>
              <title>#{title}</title>
              <link rel="stylesheet" type="text/css" href="../styles/style.css" />
            </head>
            <body>
              <div class="chapter" id="chapter_wrapper_#{num}">
                #{processed_chapter}
              </div>
            </body>
            </html>
          HTML

          # Add chapter to the book
          item = book.add_item("text/chapter_#{num}.xhtml", id: "chapter_#{num}")
          item.add_content(StringIO.new(chapter_html))
          item.add_property('svg') # Add SVG property
          book.spine << item
          item.toc_text(title)

          added_chapters[num] = true
        end
      end

      def self.process_images_in_chapter(chapter, book, processed_images)
        doc = Nokogiri::HTML.fragment(chapter.to_html)
        
        # Create images directory if it doesn't exist
        FileUtils.mkdir_p("dist/images")

        doc.css("img").each do |img|
          begin
            src = img["src"]
            next unless src&.start_with?('http')

            # Check if we've already processed this image
            if processed_images[src]
              img["src"] = "../#{processed_images[src]}"
              img["alt"] ||= "Image"
              # Convert to self-closing tag for XHTML compliance
              img.replace(img.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML))
              next
            end

            uri = URI.parse(src)
            response = Net::HTTP.get_response(uri)
            
            if response.is_a?(Net::HTTPSuccess)
              # Determine content type and extension
              content_type = response.content_type
              ext = case content_type
                    when 'image/jpeg', 'image/jpg' then '.jpg'
                    when 'image/png' then '.png'
                    when 'image/gif' then '.gif'
                    else File.extname(uri.path)
                    end

              # Generate unique filename
              filename = "image_#{processed_images.size + 1}#{ext}"
              filepath = "dist/images/#{filename}"
              epub_path = "images/#{filename}"

              # Save the image to disk
              File.binwrite(filepath, response.body)
              puts "Saved image to #{filepath}"

              # Add the image to the EPUB container
              item = book.add_item(epub_path)
              item.add_content(StringIO.new(response.body))
              item.media_type = content_type

              # Update the image source to use the relative path in EPUB
              processed_images[src] = epub_path
              img["src"] = "../#{epub_path}"
              img["alt"] ||= "Image"

              # Convert to self-closing tag for XHTML compliance
              img.replace(img.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML))

              puts "Successfully processed image #{processed_images.size}"
            end
          rescue StandardError => e
            puts "Error processing image #{src}: #{e.message}"
          end
        end

        # Update the chapter content with the processed images
        chapter.inner_html = doc.to_html
        chapter
      end

      def self.process_chapter_content(chapter, chapter_num)
        # Clean up the chapter structure
        chapter = chapter.dup # Create a copy to avoid modifying the original
        chapter.css('nav, .navigation, .menu, .nav, [class*="menu"], [class*="nav"], .hamburger, .hamburger-menu, header, .header').remove

        # Remove all existing IDs from the chapter content to prevent duplicates
        chapter.css("[id]").each do |elem|
          elem.remove_attribute("id")
        end

        # Process chapter heading
        if (heading = chapter.at_css("h1"))
          heading_id = "chapter_#{chapter_num}_heading"
          heading["id"] = heading_id
          # Remove any existing links in the heading
          if (link = heading.at_css("a"))
            link.replace(link.text)
          end
        end

        # Process internal links and preserve fragment identifiers
        chapter.css("a[href]").each do |link|
          next unless link.parent
          href = link["href"]
          next unless href

          # Handle links to other chapters
          if href.start_with?("/shapeup/") || href.start_with?("#")
            href = href.sub(/^\/shapeup\//, "").sub(/^#/, "")
            
            # Extract chapter number and fragment
            if href =~ /(\d+\.\d+)-(?:chapter|appendix)-(\d+)(?:#(.+))?/
              chapter_num = $2.to_i.to_s.rjust(2, "0")
              fragment = $3
              link["href"] = "chapter_#{chapter_num}.xhtml" + (fragment ? "##{fragment.gsub('#', '-')}" : "")
            elsif href =~ /(?:\d+\.\d+)?-?conclusion(?:#(.+))?/
              fragment = $1
              link["href"] = "chapter_16.xhtml" + (fragment ? "##{fragment.gsub('#', '-')}" : "")
            end
          end

          # Clean up any remaining fragment identifiers
          if link["href"] =~ /#/
            link["href"] = link["href"].gsub(/#(?=.*#)/, "-")
          end
        end

        # Create new IDs for headings and sections
        chapter.css("section, h1, h2, h3, h4, h5, h6").each do |elem|
          # Generate an ID based on the text content
          text = elem.text.strip
          id = text.downcase.gsub(/[^a-z0-9]+/, '-')
          elem["id"] = id unless id.empty?
        end

        # Fix HTML issues
        chapter.css("hr, br, img").each do |elem|
          # Replace with self-closing tag
          elem.replace(elem.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML))
        end

        # Fix unclosed paragraph tags and other elements
        chapter.css("p, div, span, a, h1, h2, h3, h4, h5, h6").each do |elem|
          next unless elem.parent
          # Ensure element has proper closing tag
          elem.replace(elem.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML))
        end

        # Return the processed chapter content
        chapter.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML)
      end
    end
  end
end
