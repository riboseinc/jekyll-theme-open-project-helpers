module OpenProjectHelpers
  # On an open hub site, Jekyll Open Project theme assumes the existence of two types
  # of item indexes: software and specs, where items are gathered
  # from across open projects in the hub.
  #
  # Each item can have its tags, and the theme allows to filter each index by a tag.
  # To facilitate that, the below generates an additional index page
  # for each tag in an index, like software/Ruby.
  #
  # Note: this expects "_pages/<index page>.html" to be present in site source,
  # so it would fail if theme setup instructions were not followed fully.

  class FilteredIndexPage < Jekyll::Page
    def initialize(site, base, dir, tag, items, index_page)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_pages'), "#{index_page}.html")
      self.data['tag'] = tag
      self.data['items'] = items
    end
  end

  class FilteredIndexPageGenerator < Jekyll::Generator
    safe true

    def generate(site)

      # If there’s a “projects” collection, we assume it is indeed
      # a Jekyll Open Project hub site.
      if site.collections.key? 'projects'

        # The need for :item_test arises from our data structure (see Jekyll Open Project theme docs)
        # and the fact that Jekyll doesn’t intuitively handle nested collections.
        indexes = {
          "software" => {
            :item_test => lambda { |item| item.url.include? '_software' },
          },
          "specs" => {
            :item_test => lambda { |item| item.url.include? '_specs' },
          },
        }

        indexes.each do |index_name, params|
          items = site.collections['projects'].docs.select { |item| params[:item_test].call(item) }

          # Creates a data structure like { tag1: [item1, item2], tag2: [item2, item3] }
          tags = {}
          items.each do |item|
            item.data['tags'].each do |tag|
              unless tags.key? tag
                tags[tag] = []
              end
              tags[tag].push(item)
            end
          end

          # Creates a filtered index page for each tag
          tags.each do |tag, tagged_items|
            site.pages << FilteredIndexPage.new(
              site,
              site.source,

              # The filtered page will be nested under /<index page>/<tag>.html
              File.join(index_name, tag),

              tag,
              tagged_items,
              index_name)
          end
        end
      end
    end
  end
end
