module Jekyll
  module OpenProjectHelpers

    # On an open hub site, Jekyll Open Project theme assumes the existence of two types
    # of item indexes: software and specs, where items are gathered
    # from across open projects in the hub.
    #
    # The need for :item_test arises from our data structure (see Jekyll Open Project theme docs)
    # and the fact that Jekyll doesn’t intuitively handle nested collections.
    INDEXES = {
      "software" => {
        :item_test => lambda { |item| item.path.include? '/_software' and not item.path.include? '/docs' },
      },
      "specs" => {
        :item_test => lambda { |item| item.path.include? '/_specs' and not item.path.include? '/docs' },
      },
    }


    # Each software or spec item can have its tags,
    # and the theme allows to filter each index by a tag.
    # The below generates an additional index page
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
        if site.config['is_hub']
          INDEXES.each do |index_name, params|
            items = get_all_items(site, 'projects', params[:item_test])

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


    # Below passes the `items` variable to normal (unfiltered)
    # index page layout.

    class IndexPageGenerator < Jekyll::Generator
      safe true

      def generate(site)
        site.config['max_featured_software'] = 3
        site.config['max_featured_specs'] = 3
        site.config['max_featured_posts'] = 3

        INDEXES.each do |index_name, params|
          if site.config['is_hub']
            collection_name = 'projects'
          else
            collection_name = index_name
          end

          if site.collections.key? collection_name
            # Filters items from given collection_name through item_test function
            # and makes items available in templates via e.g. site.all_specs, site.all_software

            items = get_all_items(site, collection_name, params[:item_test])

            site.config["all_#{index_name}"] = items
            site.config["num_all_#{index_name}"] = items.size

            featured_items = items.select { |item| item.data['feature_with_priority'] != nil }
            site.config["featured_#{index_name}"] = featured_items
            site.config["num_featured_#{index_name}"] = featured_items.size

            non_featured_items = items.select { |item| item.data['feature_with_priority'] == nil }
            site.config["non_featured_#{index_name}"] = non_featured_items
            site.config["num_non_featured_#{index_name}"] = non_featured_items.size
          end
        end
      end
    end

  end
end


def get_all_items(site, collection_name, filter_func)
  # Fetches items of specified type, ordered and prepared for usage in index templates

  items = site.collections[collection_name].docs.select { |item|
    filter_func.call(item)
  }

  items.sort! { |i1, i2|
    (i2.data['last_update'] <=> i1.data['last_update']) || 0
  }

  if site.config['is_hub']
    items.map! do |item|
      project_name = item.url.split('/')[2]
      project_path = "_projects/#{project_name}/index.md"

      item.data['project_name'] = project_name
      item.data['project_data'] = site.collections['projects'].docs.select {
        |proj| proj.path.end_with? project_path
      } [0]

      item
    end
  end

  return items
end
