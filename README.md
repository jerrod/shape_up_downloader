# Shape Up Downloader (Ruby Version)

## What does it do?
This is a simple CLI application that downloads [Basecamp's excellent free Shape Up book](https://basecamp.com/shapeup)
into a single, self-contained HTML file.
* uses base64 images
* uses document-internal links
* only the bare minimum of CSS

## Why does this exist?
The book is currently available in an HTML format, where every chapter is one document and a PDF document where all
chapters are in one self-contained file. While reading the book I was yearning for a way to read it on my e-book reader,
but reading PDF on a Kindle sucks and converting PDFs to epub or mobi is wonky at best. The software used to generate
this particular PDF combined some character combination (e.g. "tf") into a single UTF-8 codepoint with ligatures. This
however trips up most converting software.

Thus, this project was born to download and combine all web documents into a single self-contained file without styling.
You are not intended to read the book in that HTML format - but it can be used as a basis for further conversion steps.

To convert the file into more useful formats I recommend using calibre's `ebook-convert` utility:
```bash
$ ebook-convert shape-up.html shape-up.epub \
    --authors "Ryan Singer" \
    --title "Shape Up: Stop Running in Circles and Ship Work that Matters" \
    --book-producer "Basecamp" \
    --publisher "Basecamp" \
    --language "en"
```

## Where can I download this HTML/EPUB/MOBI single page version?
I am not quite sure about the legal implications of hosting these files - thus I am not doing it.
The code to download it yourself is here, but you must use it yourself.

## Usage

### Local Ruby

1. [Install Ruby](https://www.ruby-lang.org/en/documentation/installation/)
2. [Install Bundler](https://bundler.io/)
3. Run `bundle install`
4. Run `bundle exec bin/shape_up_downloader download:single-html`

This will create a `shape-up.html` file in your current directory.
That's it.

### Docker way

There is a way to not deal with Ruby at all. For that it is enough to have docker engine installed.

Usage
```bash
docker run -it --rm -v $(pwd)/output:/app/output thej6s/shape-up-downloader
```

This will create a `shape-up.html` file in ./output directory
