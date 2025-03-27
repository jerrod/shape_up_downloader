# frozen_string_literal: true

require "thor"
require "nokogiri"
require "http"
require "active_support"
require "active_support/core_ext"
require "progress_bar"
require "base64"
require "fileutils"
require "digest"
require "gepub"

require_relative "shape_up_downloader/utils/styles"
require_relative "shape_up_downloader/constants"
require_relative "shape_up_downloader/core/cache"
require_relative "shape_up_downloader/core/downloader"
require_relative "shape_up_downloader/utils/html_processor"
require_relative "shape_up_downloader/utils/epub_generator"
require_relative "shape_up_downloader/cli"

module ShapeUpDownloader
  # Version information and other module-level constants can go here
end
