# Shape Up Downloader (Ruby Version)

## What does it do?
This is a CLI application that downloads [Basecamp's excellent free Shape Up book](https://basecamp.com/shapeup)
and converts it into either:
* A single, self-contained HTML file
* An EPUB file suitable for e-readers

Features:
* Downloads and combines all chapters into a single file
* Preserves all images (base64-encoded in HTML version)
* Maintains internal navigation links between chapters
* Clean, minimal CSS styling optimized for readability
* Proper EPUB structure with table of contents and chapter hierarchy
* Validates EPUB output using epubcheck

## Why does this exist?
The book is currently available in an HTML format (separate chapters) and a PDF document (single file).
While the PDF version is convenient, it's not ideal for e-readers like Kindle due to:
* Poor PDF rendering on e-ink displays
* Inconsistent conversion results from PDF to epub/mobi
* Issues with ligatures (combined characters like "tf") in the PDF that break most conversion tools

This tool solves these issues by working directly with the HTML source, ensuring proper formatting and structure.

## Usage

### Prerequisites

1. [Install Ruby](https://www.ruby-lang.org/en/documentation/installation/) (3.2.4)
2. [Install Bundler](https://bundler.io/)
3. Install Java Development Kit (JDK) - required for epubcheck
   ```bash
   brew install openjdk  # On macOS
   ```
4. Install epubcheck for EPUB validation
   ```bash
   brew install epubcheck  # On macOS
   ```
5. Run `bundle install`

### Generating the Book

The simplest way to generate the EPUB is to use the publish script:
```bash
bin/publish
```

This will:
1. Download the book content
2. Convert it to EPUB format
3. Validate the EPUB
4. Open the generated file (on macOS only)

The script will create:
* `dist/shape-up.html` - A single HTML file with embedded images
* `dist/shape_up.epub` - A properly formatted EPUB file

### Manual Steps

If you need more control over the process, you can run the steps manually:

1. Download the HTML version:
   ```bash
   bundle exec bin/shape_up_downloader download_single_html
   ```

2. Convert to EPUB:
   ```bash
   bundle exec bin/shape_up_downloader convert_to_epub
   ```

3. Validate the EPUB:
   ```bash
   bundle exec bin/shape_up_downloader validate_epub
   ```

Note: All files must be in the `dist` directory. The paths are relative to that directory.

## Legal Note

This tool is provided for personal use to facilitate reading the freely available Shape Up book.
Please respect Basecamp's copyright and do not distribute the generated files.
Instead, share this tool so others can generate their own copies from the source material.

## Development

To run the test suite:
```bash
bundle exec rspec
```

To validate generated EPUB files:
```bash
bundle exec bin/shape_up_downloader validate_epub
```

Note: EPUB validation requires epubcheck to be installed:
```bash
brew install epubcheck  # On macOS
```
