# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "shape_up_downloader"
  spec.version       = "0.1.0"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]

  spec.summary       = "Download and convert Basecamp's Shape Up book to EPUB format"
  spec.description   = "A CLI tool to download Basecamp's Shape Up book and convert it to a well-formatted EPUB file"
  spec.homepage      = "https://github.com/yourusername/shape-up-downloader"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("{bin,lib}/**/*") + %w[README.md LICENSE.md]
  spec.bindir        = "bin"
  spec.executables   = ["shape_up_downloader"]
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", "~> 1.15"
  spec.add_dependency "http", "~> 5.1"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "activesupport", "~> 7.1"
  spec.add_dependency "progress_bar", "~> 1.3"
  spec.add_dependency "gepub"
  spec.add_dependency "epubcheck-ruby"

  spec.add_development_dependency "standardrb", "~> 1.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "vcr", "~> 6.2"
  spec.add_development_dependency "webmock", "~> 3.19"
end 