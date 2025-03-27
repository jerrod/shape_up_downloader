# frozen_string_literal: true

module ShapeUpDownloader
  class CLI < Thor
    include Constants
    include Thor::Actions

    desc "download_single_html", "Download the Shape Up book as a single HTML file"
    def download_single_html
      puts "Downloading Shape Up book from https://basecamp.com/shapeup..."

      # Create dist directory if it doesn't exist
      FileUtils.mkdir_p("dist")

      # Download and combine chapters
      downloader = Downloader.new
      content = downloader.download

      # Write the combined content to a file
      output_file = "dist/shape-up.html"
      File.write(output_file, content)
      puts "Done! The book has been saved to #{output_file}"
    end

    desc "convert_to_epub", "Convert the downloaded HTML file to EPUB format"
    method_option :input, type: :string, default: "dist/shape-up.html", desc: "Input HTML file path"
    method_option :output, type: :string, default: "shape_up.epub", desc: "Output EPUB file path"
    def convert_to_epub
      input_file = options[:input]
      output_file = options[:output]

      # Ensure input/output files are in the dist directory
      input_file = File.join("dist", File.basename(input_file)) unless input_file.start_with?("dist/")
      output_file = File.join("dist", File.basename(output_file))

      unless File.exist?(input_file)
        puts "Error: Input file '#{input_file}' not found. Run 'download_single_html' first."
        return
      end

      puts "Converting #{input_file} to #{output_file}..."

      # Parse the HTML file
      content = File.read(input_file)
      doc = Nokogiri::HTML(content)

      # Create a new EPUB book
      book = Utils::EPUBGenerator.create_book

      # Add cover image if it exists
      cover_image_path = File.join(File.dirname(__FILE__), "..", "shape-up-cover.png")
      Utils::EPUBGenerator.add_cover(book, cover_image_path)

      # Add style.css
      Utils::EPUBGenerator.add_style(book)

      # Add table of contents
      Utils::EPUBGenerator.add_table_of_contents(book, doc)

      # Track processed images to avoid duplicates
      processed_images = {}

      # Process each chapter
      doc.css(".chapter").each_with_index do |chapter, index|
        Utils::EPUBGenerator.add_chapter(book, chapter, index, processed_images)
      end

      # Generate the EPUB file
      book.generate_epub(output_file)
      puts "Done! The EPUB has been saved to #{output_file}"
    end

    desc "validate_epub", "Validate the generated EPUB file"
    method_option :input, type: :string, default: "dist/shape_up.epub", desc: "Input EPUB file path"
    def validate_epub
      input_file = options[:input]
      input_file = File.join("dist", File.basename(input_file)) unless input_file.start_with?("dist/")

      unless File.exist?(input_file)
        say "Error: Input file '#{input_file}' not found. Run 'convert_to_epub' first."
        return
      end

      say "Validating #{input_file}..."

      # Use epubcheck to validate the EPUB file
      begin
        if run_epubcheck(File.expand_path(input_file))
          say "Validation successful! The EPUB file is valid."
        else
          say "Validation failed. Please check the errors above."
        end
      rescue Errno::ENOENT
        say "Error: epubcheck is not installed. Please install it first:"
        say "  brew install epubcheck"
      end
    end

    private

    def run_epubcheck(file_path)
      system("epubcheck", file_path)
      $CHILD_STATUS.success?
    end
  end
end
