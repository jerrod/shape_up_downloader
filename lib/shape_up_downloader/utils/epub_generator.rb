# frozen_string_literal: true

require "net/http"

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
              <nav epub:type="toc">
                <ol>
                  #{doc.css(".chapter").map.with_index do |chapter, idx|
                    num = format("%02d", idx + 1)
                    title = chapter.at_css(".chapter-title")&.text&.strip || "Chapter #{num}"
                    "<li><a href='chapter_#{num}.xhtml'>#{title}</a></li>"
                  end.join("\n")}
                </ol>
              </nav>
            </div>
          </body>
          </html>
        HTML
        toc_item = book.add_item("text/toc.xhtml", id: "toc")
        toc_item.add_content(StringIO.new(toc_html))
        book.spine << toc_item
      end

      def self.add_chapter(book, chapter, index, processed_images)
        # Clean up the chapter structure
        chapter.css('nav, .navigation, .menu, .nav, [class*="menu"], [class*="nav"], .hamburger, .hamburger-menu, header, .header').remove

        # Get chapter ID from the div.chapter element
        chapter_id = chapter['id']

        # Determine chapter type and title
        chapter_title = if (title_elem = chapter.at_css(".chapter-title, h1.title"))
          title_elem.name = "h1"
          title_elem.remove_attribute("class")
          title_elem.text.strip
        else
          # Default title based on chapter type and ID pattern
          case chapter_id
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
          when /conclusion/
            "Conclusion"
          else
            "Chapter #{index + 1}"
          end
        end

        # Process chapter heading
        if (heading = chapter.at_css("h1"))
          heading_id = "chapter_#{index + 1}_heading"
          heading["id"] = heading_id
          # Remove any existing links in the heading
          if (link = heading.at_css("a"))
            link.replace(link.text)
          end
        end

        # Special handling for appendix, glossary, and about sections
        if chapter_id&.match?(/appendix|glossary|about/)
          # Remove any navigation or menu elements specific to these sections
          chapter.css('.appendix-nav, .glossary-nav, .about-nav').remove
          
          # For glossary, ensure terms are properly formatted
          if chapter_id&.include?('glossary')
            chapter.css('.term').each do |term|
              term.name = 'dt'
              term.next_element.name = 'dd' if term.next_element
            end
          end
          
          # For about section, ensure proper formatting of author info
          if chapter_id&.include?('about')
            if (bio = chapter.at_css('.author-bio'))
              bio.name = 'div'
              bio['class'] = 'author-biography'
            end
          end
        end

        # Process images in the chapter
        chapter.css("img").each do |img|
          src = img["src"]
          next unless src

          if processed_images[src]
            img["src"] = "../images/#{processed_images[src]}"
          else
            begin
              uri = URI.parse(src)
              response = Net::HTTP.get_response(uri)

              if response.is_a?(Net::HTTPSuccess)
                image_data = response.body
                content_type = response["Content-Type"]

                # Determine extension from content type or URL
                extension = case content_type
                when "image/jpeg", "image/jpg" then "jpg"
                when "image/png" then "png"
                when "image/gif" then "gif"
                else File.extname(uri.path)[1..] || "jpg"
                end

                new_filename = "image_#{processed_images.size + 1}.#{extension}"
                processed_images[src] = new_filename

                # Add image to EPUB with correct media type
                image_item = book.add_item("images/#{new_filename}")
                image_item.content = image_data
                image_item.media_type = content_type

                img["src"] = "../images/#{new_filename}"
              end
            rescue => e
              puts "Warning: Failed to download image from #{src}: #{e.message}"
            end
          end

          # Convert to proper XHTML self-closing tag
          img.replace(img.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML))
        end

        # Process internal links to fix multiple hash fragments and convert absolute paths to relative
        chapter.css("a[href]").each do |link|
          href = link["href"]
          if href
            if href.start_with?("/shapeup/")
              # Convert absolute paths to relative chapter links
              case href
              when /4\.0-appendix-01/
                link["href"] = "chapter_#{index + 1}.xhtml"
              when /4\.1-appendix-02/
                link["href"] = "chapter_#{index + 1}.xhtml"
              when /4\.2-appendix-03/
                link["href"] = "chapter_#{index + 1}.xhtml"
              when /4\.5-appendix-06/
                link["href"] = "chapter_#{index + 1}.xhtml"
              when /4\.6-appendix-07/
                link["href"] = "chapter_#{index + 1}.xhtml"
              else
                chapter_num = href.match(/\d+\.\d+/)&.to_s&.tr(".", "_") || "01"
                link["href"] = "chapter_#{format("%02d", chapter_num.to_i)}.xhtml"
              end
            elsif href.include?("#")
              # Keep only the first hash fragment and ensure it exists
              base_href = href.split("#").first
              fragment = href.split("#")[1]
              if fragment
                # Create an anchor if it doesn't exist
                target_id = "chapter_#{index + 1}_#{fragment}"
                unless chapter.at_css("[id='#{target_id}']")
                  # Find nearest heading or section
                  nearest_node = link.ancestors("section, h1, h2, h3, h4, h5, h6").first
                  if nearest_node
                    nearest_node["id"] = target_id
                  else
                    # Create a span with the ID if no suitable container is found
                    span = Nokogiri::XML::Node.new("span", chapter)
                    span["id"] = target_id
                    link.add_previous_sibling(span)
                  end
                end
                link["href"] = "#{base_href}##{target_id}"
              else
                link["href"] = base_href
              end
            elsif href == "/"
              # Replace root URLs with chapter 1
              link["href"] = "chapter_01.xhtml"
            end
          end
        end

        # Add IDs to all headings and sections for internal links
        chapter.css("h1, h2, h3, h4, h5, h6, section").each do |element|
          if element["id"]
            element["id"] = "chapter_#{index + 1}_#{element["id"]}"
          end
        end

        # Create chapter file
        chapter_num = format("%02d", index + 1)
        chapter_html = <<~HTML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html>
          <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <head>
            <title>#{chapter_title}</title>
            <link rel="stylesheet" type="text/css" href="../styles/style.css" />
          </head>
          <body>
            #{chapter.to_xhtml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML)}
          </body>
          </html>
        HTML
        chapter_item = book.add_item("text/chapter_#{chapter_num}.xhtml", id: "chapter_#{chapter_num}")
        chapter_item.add_content(StringIO.new(chapter_html))
        book.spine << chapter_item
      end
    end
  end
end
