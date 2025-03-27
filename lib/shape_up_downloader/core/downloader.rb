# frozen_string_literal: true

module ShapeUpDownloader
  class Downloader
    include ShapeUpDownloader::Constants

    def initialize
      @cache = Cache.new
      @http = HTTP.headers(
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"
      ).timeout(connect: 5, read: 10)
    end

    def download
      puts "Downloading Shape Up book from #{INDEX_URL}..."
      overview_page = fetch_document(INDEX_URL)
      urls = extract_chapter_urls(overview_page)

      puts "Found #{urls.size} chapters to download."
      progress = ProgressBar.new(urls.size)

      body = "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Shape Up</title>#{get_style}</head><body>"
      body += "<div class='book-content'>"
      body += extract_table_of_contents(overview_page)

      copyright_notice = nil

      urls.each_with_index do |url, index|
        puts "\nDownloading chapter from #{url}"
        begin
          document = fetch_document(url)
          puts "  - Document fetched, size: #{document.to_html.size} bytes"
          document = modify_content(document, urls)
          puts "  - Content modified, size: #{document.to_html.size} bytes"

          # Store the copyright notice from the first chapter that has it
          if !copyright_notice && (footer = document.at_css("footer, .copyright"))
            copyright_notice = footer.to_html
            puts "  - Found copyright notice"
          end

          body += "<div class='chapter' id='#{url.split("/").last}'>"
          body += extract_title(document)
          body += extract_body_text(document)
          body += "</div>"

          # Add copyright notice only at the end of the last chapter
          if index == urls.size - 1 && copyright_notice
            body += "<footer class='book-copyright'>#{copyright_notice}</footer>"
          end

          puts "  - Chapter content added, current body size: #{body.size} bytes"

          File.write("dist/shape-up.html", body) # Save progress after each chapter
          puts "  - Progress saved to dist/shape-up.html"
          progress.increment!
        rescue => e
          puts "Error downloading chapter #{url}: #{e.message}"
          puts e.backtrace
        end
      end

      body += "</div></body></html>"

      puts "\nWriting final content to dist/shape-up.html (size: #{body.size} bytes)..."
      File.write("dist/shape-up.html", body)
      puts "Done! The book has been saved to dist/shape-up.html"
      body
    end

    private

    def fetch_document(url)
      content = @cache.fetch(url) do
        @http.follow.get(url).to_s
      end
      Nokogiri::HTML(content)
    end

    def extract_chapter_urls(document)
      # Find all chapter links in the table of contents
      seen_urls = Set.new
      urls = []

      # First, try to find the main table of contents
      toc = document.at_css(".table-of-contents") || document.at_css(".toc")
      return [] unless toc

      # Extract chapter links from the TOC
      toc.css("a").each do |link|
        href = link["href"]
        next unless href&.match?(CHAPTER_PATTERN)

        # Remove hash fragment and query parameters
        base_url = href.split("#").first.split("?").first
        full_url = base_url.start_with?("http") ? base_url : "#{BASE_URL}#{base_url}"
        next if seen_urls.include?(full_url)

        seen_urls.add(full_url)
        urls << full_url
      end

      # If no TOC links found, try finding chapter links in the main content
      if urls.empty?
        document.css("h1 a, h2 a, h3 a").each do |link|
          href = link["href"]
          next unless href&.match?(CHAPTER_PATTERN)

          # Remove hash fragment and query parameters
          base_url = href.split("#").first.split("?").first
          full_url = base_url.start_with?("http") ? base_url : "#{BASE_URL}#{base_url}"
          next if seen_urls.include?(full_url)

          seen_urls.add(full_url)
          urls << full_url
        end
      end

      # Add appendices, glossary, and about sections if they're not already included
      additional_sections = [
        "#{BASE_URL}/shapeup/4.0-appendix-01",
        "#{BASE_URL}/shapeup/4.1-appendix-02",
        "#{BASE_URL}/shapeup/4.2-appendix-03",
        "#{BASE_URL}/shapeup/4.5-appendix-06",
        "#{BASE_URL}/shapeup/4.6-appendix-07"
      ]

      additional_sections.each do |url|
        next if seen_urls.include?(url)
        seen_urls.add(url)
        urls << url
      end

      # Sort URLs to ensure proper order:
      # 1. Main chapters (numbered)
      # 2. Conclusion
      # 3. Appendices (in order)
      # 4. Glossary
      # 5. About
      urls.sort_by do |url|
        if url.include?("4.0-appendix-01")
          [2, 1]  # First appendix
        elsif url.include?("4.1-appendix-02")
          [2, 2]  # Second appendix
        elsif url.include?("4.2-appendix-03")
          [2, 3]  # Third appendix
        elsif url.include?("4.5-appendix-06")
          [2, 4]  # Fourth appendix
        elsif url.include?("4.6-appendix-07")
          [2, 5]  # Fifth appendix
        elsif url.include?("-conclusion")
          [1, 0]  # First priority after chapters
        else
          # Extract chapter number for proper sorting
          # Put regular chapters first (priority 0)
          numbers = url.match(/(\d+)\.(\d+)/)
          if numbers
            [0, numbers[1].to_i, numbers[2].to_i]
          else
            [5, 0]  # Unknown format goes last
          end
        end
      end
    end

    def modify_content(document, urls)
      # Process images
      document.css("img").each do |img|
        next unless img["src"]
        begin
          if !img["src"].start_with?("http")
            img_url = "#{BASE_URL}#{img["src"]}"
            img["src"] = img_url
          end
          # Remove any remote images that might cause EPUB validation issues
          if img["src"].start_with?("http")
            img.remove
          end
        rescue => e
          puts "Warning: Failed to process image #{img["src"]}: #{e.message}"
          img.remove
        end
      end

      # Update internal links
      document.css("a").each do |link|
        href = link["href"]
        next unless href

        # Remove problematic links in appendix, glossary, and about sections
        if href == "/" && (document.at_css("[class*='appendix']") || document.at_css("[class*='glossary']") || document.at_css("[class*='about']"))
          link.replace(link.text)
          next
        end

        # Handle chapter links
        if href.match?(CHAPTER_PATTERN)
          # Extract the base chapter ID and any hash fragment
          base_url = href.split("#").first.split("?").first
          hash = href.include?("#") ? "#" + href.split("#").last : ""
          chapter_id = base_url.split("/").last + hash

          link["href"] = "##{chapter_id}"
        end
      end

      document
    end

    def convert_image_to_base64(url)
      content = @cache.fetch("image:#{url}") do
        @http.follow.get(url).to_s
      end
      mime_type = content.start_with?("\x89PNG") ? "image/png" : "image/jpeg"
      base64 = Base64.strict_encode64(content)
      "data:#{mime_type};base64,#{base64}"
    end

    def extract_table_of_contents(document)
      # Find the main table of contents
      toc_element = document.at_css(".table-of-contents") || document.at_css(".toc")
      return "" unless toc_element

      # Create TOC wrapper
      toc = "<div class='table-of-contents'><h2>Table of Contents</h2><ul>"

      # Find all chapter links and their titles, but only within the TOC
      seen_entries = Set.new

      toc_element.css("a").each do |link|
        href = link["href"]
        next unless href&.match?(CHAPTER_PATTERN)

        # Skip subchapter links (ones with hash fragments)
        next if href.include?("#")

        # Extract chapter ID and title
        base_url = href.split("?").first
        chapter_id = base_url.split("/").last
        chapter_title = link.text.strip
        next if chapter_title.empty?

        entry = "#{chapter_id}|#{chapter_title}"
        next if seen_entries.include?(entry)
        seen_entries.add(entry)

        # Use proper EPUB internal link format
        toc += "<li><a href='chapter_#{seen_entries.size}.xhtml'>#{chapter_title}</a></li>"
      end

      toc += "</ul></div>"
      toc
    end

    def extract_title(document)
      # Try to find the title in this order:
      # 1. intro__title class (main chapter title)
      # 2. First h1 or h2
      title = document.at_css(".intro__title") || document.at_css("h1, h2")
      return "" unless title

      # Clean up the title and preserve any links
      title_html = title.inner_html.strip
      "<div class='chapter-title'>#{title_html}</div>"
    end

    def extract_body_text(document)
      # Try to find the main content
      content = document.at_css("article") || document.at_css("main") || document.at_css("body")
      return "" unless content

      # Store the copyright notice before cleaning
      content.css(".copyright, footer").map(&:inner_html).join("\n")

      # Remove the specific Shape Up button/header
      content.css('.intro__book-title, button[aria-label="Shape Up Table Of Contents"]').each(&:remove)

      # Remove navigation, headers, and unnecessary elements
      content.css('nav, .navigation, .menu, script, style, .hamburger, .hamburger-menu, [class*="menu"], [class*="nav"], header, .header, .intro__header, .intro__masthead, .intro__title, .warning, .shape-up-header, [class*="header"], [class*="masthead"], footer, .footer, .copyright, .intro__next').each(&:remove)

      # Remove any elements containing "Shape Up" in the header area or with specific attributes
      content.css("*").each do |element|
        if (element.text.include?("Shape Up") && element.path.include?("header")) ||
            element["data-action"]&.include?("sidebar#open") ||
            element["aria-label"]&.include?("Shape Up")
          element.remove
        end
      end

      # Remove the chapter's internal table of contents and other unnecessary elements
      content.css(".intro__sections, .toc").each(&:remove)

      # Handle duplicate images
      seen_images = Set.new
      content.css("img").each do |img|
        src = img["src"]
        if seen_images.include?(src)
          # If we've seen this image before, remove it
          img.remove
        else
          seen_images.add(src)
        end
      end

      # Process each top-level element
      main_content = []

      # Process each top-level element, skipping any that look like headers or navigation
      content.children.each do |node|
        next unless node.element?

        # Skip header-like elements and specific buttons
        next if node["class"]&.match?(/header|masthead|nav|menu|intro__book-title|copyright|footer/)
        next if node.name == "header" || (node.name == "button" && node["aria-label"]&.include?("Shape Up"))
        next if node["data-action"]&.include?("sidebar#open")

        # Skip if it's a list item that's already part of a list
        next if node.name == "li" && node.parent&.name == "ul" || node.parent&.name == "ol"

        # Convert div.chapter-title to h1 for better EPUB rendering
        if node["class"]&.include?("chapter-title")
          node.name = "h1"
          node.remove_attribute("class")
        end

        # Add the element and its content
        main_content << node.to_html
      end

      # Return the content
      "<div class='chapter-content'>#{main_content.join("\n")}</div>"
    end

    def get_style
      <<~CSS
        <style type="text/css">
        #{STYLE_CSS}
        </style>
      CSS
    end
  end
end
