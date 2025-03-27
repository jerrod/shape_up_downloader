# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "fileutils"
require "set"

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
        fragment_map = {}
        
        # First pass: collect all fragments from all chapters
        doc.css(".chapter").each do |chapter|
          original_id = chapter['id']
          chapter.css("[id]").each do |elem|
            fragment_map[elem["id"]] = original_id
          end
          
          # Add IDs to all headings
          chapter.css("h1, h2, h3, h4, h5, h6").each do |heading|
            next if heading["id"]
            clean_id = heading.text.strip.downcase.gsub(/[^a-zA-Z0-9]+/, '-')
            clean_id = "heading-#{clean_id}" unless clean_id.match?(/^[a-zA-Z]/)
            heading["id"] = clean_id
            fragment_map[clean_id] = original_id
          end
        end

        # Create chapter array
        chapters = doc.css(".chapter").map do |chapter|
          # Extract the original ID and clean it for file naming
          original_id = chapter['id']
          file_id = original_id.gsub(/[^a-zA-Z0-9_-]/, '-')
          
          # Extract title
          title = if (title_elem = chapter.at_css(".chapter-title"))
            title_elem.text.strip
          else
            case original_id
            when /conclusion/
              "Conclusion"
            when /4\.0-appendix-01/
              "Appendix 1: How to Implement Shape Up in Basecamp"
            when /4\.1-appendix-02/
              "Appendix 2: Adjust to Your Size"
            when /4\.2-appendix-03/
              "Appendix 3: How to Begin to Shape Up"
            when /4\.5-appendix-06/
              "Appendix 4: Glossary"
            when /4\.6-appendix-07/
              "Appendix 5: About the Author"
            else
              "Chapter #{original_id}"
            end
          end

          # Process images in the chapter
          processed_chapter = process_images_in_chapter(chapter, book, processed_images)

          [file_id, title, processed_chapter, original_id]
        end

        # Sort chapters by their position in the document
        chapters.sort_by! { |_, _, _, id| doc.css(".chapter").find_index { |c| c['id'] == id } }

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
                  #{chapters.map { |id, title, _, _| "<li><a href='chapter-#{id}.xhtml'>#{title}</a></li>" }.join("\n")}
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
        chapters.each do |file_id, title, chapter_content, original_id|
          # Process chapter content
          processed_chapter = process_chapter_content(chapter_content, original_id, fragment_map)

          # Create unique IDs for chapter elements
          clean_id = "chapter-#{file_id}"
          content_id = "content-#{clean_id}"
          title_id = "title-#{clean_id}"

          # Create chapter XHTML
          chapter_html = <<~HTML
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
            <head>
              <title>#{title}</title>
              <meta charset="utf-8"/>
              <link rel="stylesheet" type="text/css" href="../styles/style.css"/>
            </head>
            <body>
              <div class="chapter" id="#{clean_id}">
                <h1 id="#{title_id}">#{title}</h1>
                <div class="chapter-content" id="#{content_id}">
                  #{processed_chapter}
                </div>
              </div>
            </body>
            </html>
          HTML

          # Add chapter to the book with cleaned ID
          item = book.add_item("text/#{clean_id}.xhtml", id: clean_id)
          item.add_content(StringIO.new(chapter_html))
          item.add_property('svg')
          book.spine << item
          item.toc_text(title)
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

        # Return the chapter content with properly formatted images
        doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML)
      end

      def self.process_chapter_content(chapter, original_id, fragment_map)
        # Create a Nokogiri fragment from the input
        doc = if chapter.is_a?(String)
          Nokogiri::HTML.fragment(chapter)
        else
          Nokogiri::HTML.fragment(chapter.to_html)
        end

        # Remove all style elements
        doc.css("style").remove

        # Remove navigation elements but keep all content
        doc.css(".intro__sections, .intro__masthead").remove

        # Convert chapter titles to H2
        doc.css(".chapter-title").each do |title_elem|
          h2 = Nokogiri::XML::Node.new("h2", doc)
          h2.content = title_elem.content
          h2["class"] = "chapter-title"
          title_elem.replace(h2)
        end

        # First pass: Collect all existing IDs and headings
        existing_ids = Set.new
        doc.css("[id]").each do |elem|
          clean_id = elem["id"].gsub(/[^a-zA-Z0-9_-]/, '-')
          existing_ids.add(clean_id)
          elem["id"] = clean_id
        end

        # Add IDs to all headings that don't have them
        doc.css("h1, h2, h3, h4, h5, h6").each do |heading|
          next if heading["id"]
          clean_id = heading.text.strip.downcase.gsub(/[^a-zA-Z0-9]+/, '-')
          clean_id = "heading-#{clean_id}" unless clean_id.match?(/^[a-zA-Z]/)
          # Ensure uniqueness
          base_id = clean_id
          counter = 1
          while existing_ids.include?(clean_id)
            clean_id = "#{base_id}-#{counter}"
            counter += 1
          end
          heading["id"] = clean_id
          existing_ids.add(clean_id)
        end

        # Add IDs to all paragraphs that don't have them
        doc.css("p").each do |para|
          next if para["id"]
          # Create an ID based on the first few words of the paragraph
          words = para.text.strip.split(/\s+/)[0..4].join(' ').downcase
          clean_id = "p-#{words}".gsub(/[^a-zA-Z0-9]+/, '-')
          # Ensure uniqueness
          base_id = clean_id
          counter = 1
          while existing_ids.include?(clean_id)
            clean_id = "#{base_id}-#{counter}"
            counter += 1
          end
          para["id"] = clean_id
          existing_ids.add(clean_id)
        end

        # Process internal links
        doc.css("a[href]").each do |link|
          href = link["href"]
          next unless href

          if href.start_with?("#")
            # Internal fragment link
            fragment = href[1..]
            clean_fragment = fragment.gsub(/[^a-zA-Z0-9_-]/, '-')
            
            # Check if this fragment exists in another chapter
            if target_chapter = fragment_map[fragment]
              if target_chapter != original_id
                # Cross-chapter reference
                clean_target = "chapter-#{target_chapter.gsub(/[^a-zA-Z0-9_-]/, '-')}"
                link["href"] = "#{clean_target}.xhtml##{clean_fragment}"
              else
                # Same chapter reference
                link["href"] = "##{clean_fragment}"
              end
            else
              # Try to find or create a target for the fragment
              target = doc.at_css("[id='#{clean_fragment}']")
              unless target
                # Look for text that matches the original fragment
                text_nodes = doc.xpath(".//text()").select do |n| 
                  # Skip text nodes that are part of a link
                  next false if n.ancestors("a").any?
                  
                  # Normalize text for comparison
                  node_text = n.text.strip.downcase
                  fragment_text = fragment.strip.downcase
                  
                  # Try exact match first
                  next true if node_text == fragment_text
                  
                  # Then try substring match
                  next true if node_text.include?(fragment_text)
                  
                  # Try matching first few words
                  node_words = node_text.split(/\s+/)[0..4].join(' ')
                  fragment_words = fragment_text.split(/\s+/)[0..4].join(' ')
                  next true if node_words == fragment_words
                  
                  # Finally try fuzzy match
                  next true if node_text.gsub(/[^a-zA-Z0-9]+/, '') == fragment_text.gsub(/[^a-zA-Z0-9]+/, '')
                  
                  false
                end

                if text_node = text_nodes.first
                  # Find the closest block-level ancestor
                  ancestor = text_node.ancestors("p, div, section, article, h1, h2, h3, h4, h5, h6").first
                  
                  if ancestor
                    # If ancestor already has an ID, use it
                    if ancestor["id"]
                      link["href"] = "##{ancestor['id']}"
                      next
                    end
                    
                    # Otherwise, create a new ID
                    clean_id = clean_fragment
                    base_id = clean_id
                    counter = 1
                    while existing_ids.include?(clean_id)
                      clean_id = "#{base_id}-#{counter}"
                      counter += 1
                    end
                    ancestor["id"] = clean_id
                    existing_ids.add(clean_id)
                    link["href"] = "##{clean_id}"
                  else
                    # Create a span around the text if no suitable ancestor found
                    span = Nokogiri::XML::Node.new("span", doc)
                    span["id"] = clean_fragment
                    text_node.wrap(span)
                    existing_ids.add(clean_fragment)
                    link["href"] = "##{clean_fragment}"
                  end
                else
                  # If we can't find matching text, try to find a nearby heading or paragraph
                  parent = link.ancestors("section, article, div").first || doc
                  
                  # First try to find a heading with similar text
                  headings = parent.css("h1, h2, h3, h4, h5, h6").select do |h|
                    heading_text = h.text.strip.downcase
                    fragment_text = fragment.strip.downcase
                    heading_text.include?(fragment_text) || fragment_text.include?(heading_text)
                  end
                  
                  if heading = headings.first
                    unless heading["id"]
                      clean_id = heading.text.strip.downcase.gsub(/[^a-zA-Z0-9]+/, '-')
                      clean_id = "heading-#{clean_id}" unless clean_id.match?(/^[a-zA-Z]/)
                      base_id = clean_id
                      counter = 1
                      while existing_ids.include?(clean_id)
                        clean_id = "#{base_id}-#{counter}"
                        counter += 1
                      end
                      heading["id"] = clean_id
                      existing_ids.add(clean_id)
                    end
                    link["href"] = "##{heading['id']}"
                  else
                    # If no suitable heading found, create an anchor at the nearest paragraph
                    nearest = parent.at_css("p")
                    if nearest
                      unless nearest["id"]
                        words = nearest.text.strip.split(/\s+/)[0..4].join(' ').downcase
                        clean_id = "p-#{words}".gsub(/[^a-zA-Z0-9]+/, '-')
                        base_id = clean_id
                        counter = 1
                        while existing_ids.include?(clean_id)
                          clean_id = "#{base_id}-#{counter}"
                          counter += 1
                        end
                        nearest["id"] = clean_id
                        existing_ids.add(clean_id)
                      end
                      link["href"] = "##{nearest['id']}"
                    end
                  end
                end
              end
            end
          elsif href =~ /shapeup\/([0-9.]+(?:-(?:chapter|appendix)-\d+|conclusion))/
            # Convert shapeup/X.X-chapter-XX or shapeup/X.X-appendix-XX links
            target_id = $1
            clean_id = "chapter-#{target_id.gsub(/[^a-zA-Z0-9_-]/, '-')}"
            link["href"] = "#{clean_id}.xhtml"
          elsif href =~ /([0-9.]+(?:-(?:chapter|appendix)-\d+|conclusion))(?:\.xhtml)?(?:#(.+))?/
            # Handle direct chapter/appendix links
            target_id = $1
            fragment = $2
            clean_id = "chapter-#{target_id.gsub(/[^a-zA-Z0-9_-]/, '-')}"
            new_href = "#{clean_id}.xhtml"
            new_href += "##{fragment.gsub(/[^a-zA-Z0-9_-]/, '-')}" if fragment
            link["href"] = new_href
          elsif href =~ /#(.+)#(.+)/
            # Handle links with multiple hash fragments - use only the last one
            fragment = $2
            clean_fragment = fragment.gsub(/[^a-zA-Z0-9_-]/, '-')
            
            # Check if this fragment exists in another chapter
            if target_chapter = fragment_map[fragment]
              if target_chapter != original_id
                # Cross-chapter reference
                clean_target = "chapter-#{target_chapter.gsub(/[^a-zA-Z0-9_-]/, '-')}"
                link["href"] = "#{clean_target}.xhtml##{clean_fragment}"
              else
                # Same chapter reference
                link["href"] = "##{clean_fragment}"
              end
            else
              # Try to find or create a target for the fragment using the same logic as above
              target = doc.at_css("[id='#{clean_fragment}']")
              unless target
                # Look for text that matches the original fragment
                text_nodes = doc.xpath(".//text()").select do |n| 
                  # Skip text nodes that are part of a link
                  next false if n.ancestors("a").any?
                  
                  # Normalize text for comparison
                  node_text = n.text.strip.downcase
                  fragment_text = fragment.strip.downcase
                  
                  # Try exact match first
                  next true if node_text == fragment_text
                  
                  # Then try substring match
                  next true if node_text.include?(fragment_text)
                  
                  # Try matching first few words
                  node_words = node_text.split(/\s+/)[0..4].join(' ')
                  fragment_words = fragment_text.split(/\s+/)[0..4].join(' ')
                  next true if node_words == fragment_words
                  
                  # Finally try fuzzy match
                  next true if node_text.gsub(/[^a-zA-Z0-9]+/, '') == fragment_text.gsub(/[^a-zA-Z0-9]+/, '')
                  
                  false
                end

                if text_node = text_nodes.first
                  # Find the closest block-level ancestor
                  ancestor = text_node.ancestors("p, div, section, article, h1, h2, h3, h4, h5, h6").first
                  
                  if ancestor
                    # If ancestor already has an ID, use it
                    if ancestor["id"]
                      link["href"] = "##{ancestor['id']}"
                      next
                    end
                    
                    # Otherwise, create a new ID
                    clean_id = clean_fragment
                    base_id = clean_id
                    counter = 1
                    while existing_ids.include?(clean_id)
                      clean_id = "#{base_id}-#{counter}"
                      counter += 1
                    end
                    ancestor["id"] = clean_id
                    existing_ids.add(clean_id)
                    link["href"] = "##{clean_id}"
                  else
                    # Create a span around the text if no suitable ancestor found
                    span = Nokogiri::XML::Node.new("span", doc)
                    span["id"] = clean_fragment
                    text_node.wrap(span)
                    existing_ids.add(clean_fragment)
                    link["href"] = "##{clean_fragment}"
                  end
                else
                  # If we can't find matching text, try to find a nearby heading or paragraph
                  parent = link.ancestors("section, article, div").first || doc
                  
                  # First try to find a heading with similar text
                  headings = parent.css("h1, h2, h3, h4, h5, h6").select do |h|
                    heading_text = h.text.strip.downcase
                    fragment_text = fragment.strip.downcase
                    heading_text.include?(fragment_text) || fragment_text.include?(heading_text)
                  end
                  
                  if heading = headings.first
                    unless heading["id"]
                      clean_id = heading.text.strip.downcase.gsub(/[^a-zA-Z0-9]+/, '-')
                      clean_id = "heading-#{clean_id}" unless clean_id.match?(/^[a-zA-Z]/)
                      base_id = clean_id
                      counter = 1
                      while existing_ids.include?(clean_id)
                        clean_id = "#{base_id}-#{counter}"
                        counter += 1
                      end
                      heading["id"] = clean_id
                      existing_ids.add(clean_id)
                    end
                    link["href"] = "##{heading['id']}"
                  else
                    # If no suitable heading found, create an anchor at the nearest paragraph
                    nearest = parent.at_css("p")
                    if nearest
                      unless nearest["id"]
                        words = nearest.text.strip.split(/\s+/)[0..4].join(' ').downcase
                        clean_id = "p-#{words}".gsub(/[^a-zA-Z0-9]+/, '-')
                        base_id = clean_id
                        counter = 1
                        while existing_ids.include?(clean_id)
                          clean_id = "#{base_id}-#{counter}"
                          counter += 1
                        end
                        nearest["id"] = clean_id
                        existing_ids.add(clean_id)
                      end
                      link["href"] = "##{nearest['id']}"
                    end
                  end
                end
              end
            end
          end
        end

        # Fix XHTML formatting for self-closing tags
        doc.css("img, hr, br").each do |elem|
          # Create a new XML node with the same attributes
          new_node = Nokogiri::XML::Node.new(elem.name, doc)
          elem.attributes.each do |name, attr|
            new_node[name] = attr.value
          end
          # Replace the old node with the properly formatted self-closing tag
          elem.replace(new_node.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML))
        end

        # Return the processed chapter content with proper XHTML formatting
        doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XHTML)
      end
    end
  end
end
