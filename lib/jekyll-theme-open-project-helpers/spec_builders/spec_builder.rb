require 'forwardable'

module Jekyll
  module OpenProjectHelpers
    class SpecBuilder

      attr_reader :built_pages

      def initialize(site, spec_index_doc, spec_source_base, spec_out_base, engine, opts)
        require_relative engine
        extend Builder  # adds the build_spec_pages method

        @site = site
        @spec_index_doc = spec_index_doc
        @spec_source_base = spec_source_base
        @spec_out_base = spec_out_base
        @opts = opts

        @built_pages = []
      end

      def build()
        @built_pages = build_spec_pages(
          @site,
          @spec_index_doc,
          @spec_source_base,
          @spec_out_base,
          @opts)
      end

    end
  end
end
