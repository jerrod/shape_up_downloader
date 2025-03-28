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

        .chapter-number {
          margin: 0.25em 0 0;
          font-weight: 500;
          padding: 0;

        }
        .glossary__entry-title {
        font-size: 1rem;
        font-weight: 600;
        }

        /* Chapter titles */
        h1 {
          font-size: 2.0em;
          font-weight: 700;
          margin: 0 0 0.5em;
          line-height: 1.0;
        }

        /* Chapter titles (h2) */
        h2.chapter-title {
          font-size: 2.0em;
          font-weight: 700;
          margin: 0.25em 0 0.5em;
          line-height: 1.2;
          text-align: left;
          color: #000;
        }

        /* Regular h2 (not chapter titles) */
        h2:not(.chapter-title) {
          font-size: 1.4em;
          font-weight: 600;
          margin: 1.5em 0 0.5em;
          line-height: 1.3;
        }

        /* Subheadings within chapters */
        h3 {
          font-size: 1.65em; /* 75% of chapter title size (2.2em) */
          font-weight: 600;
          margin: 1.2em 0 0.5em;
          line-height: 1.3;
          color: #333;
        }

        /* Smaller headings */
        h4 {
          font-size: 1.4em;
          font-weight: 600;
          margin: 1.2em 0 0.5em;
          line-height: 1.3;
        }

        h5, h6 {
          font-size: 1.2em;
          font-weight: 600;
          margin: 1em 0 0.5em;
          line-height: 1.3;
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
          font-size: 1.3em;
          margin-bottom: 0.5em;
        }

        .table-of-contents ul {
          list-style: none;
          padding: 0;
        }

        .table-of-contents li {
          margin: 0.15em 0;
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
