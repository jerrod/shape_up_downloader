# frozen_string_literal: true

module ShapeUpDownloader
  module Utils
    module Styles
      STYLE_CSS = <<~CSS
        /* Base styles */
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          line-height: 1.6;
          padding: 1em;
          max-width: 45em;
          margin: 0 auto;
        }

        /* Chapter titles */
        h1 {
          font-size: 2.5em;
          font-weight: 700;
          margin: 1.5em 0 1em;
          line-height: 1.2;
        }

        /* Subheadings */
        h2 {
          font-size: 2em;
          margin: 1.5em 0 0.5em;
        }

        h3 {
          font-size: 1.5em;
          margin: 1.5em 0 0.5em;
        }

        /* Images */
        img {
          max-width: 100%;
          height: auto;
          margin: 1.5em 0;
          display: block;
        }

        figure {
          margin: 2em 0;
          text-align: center;
        }

        figure img {
          margin: 0 auto;
        }

        /* Lists */
        ul, ol {
          margin: 1em 0;
          padding-left: 2em;
        }

        li {
          margin: 0.5em 0;
        }

        /* Links */
        a {
          color: #0066cc;
          text-decoration: none;
          padding: 0 0.2em;
          margin: 0 0.1em;
        }

        a:hover {
          text-decoration: underline;
        }

        /* Table of contents */
        .table-of-contents {
          margin: 2em 0;
        }

        .table-of-contents h2 {
          font-size: 2em;
          margin-bottom: 1em;
        }

        .table-of-contents ul {
          list-style: none;
          padding: 0;
        }

        .table-of-contents li {
          margin: 0.5em 0;
        }

        /* Cover page */
        .cover {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          padding: 2em;
          text-align: center;
        }

        .cover img {
          max-width: 100%;
          height: auto;
          margin-bottom: 2em;
        }
      CSS
    end
  end
end
