# frozen_string_literal: true

module ShapeUpDownloader
  module Constants
    VERSION = "0.1.0"
    # Updated pattern to match all content types including chapters, appendices, glossary, and about
    CHAPTER_PATTERN = %r{/shapeup/(?:\d+\.\d+(?:-chapter-\d+|-conclusion)|appendix|glossary|about)}
    STYLE_CSS = Utils::Styles::STYLE_CSS

    # URLs and domains
    BASE_URL = "https://basecamp.com"
    INDEX_URL = "#{BASE_URL}/shapeup"
    IGNORED_DOMAINS = ["ads.linkedin.com", "google-analytics.com", "doubleclick.net"]
  end
end
