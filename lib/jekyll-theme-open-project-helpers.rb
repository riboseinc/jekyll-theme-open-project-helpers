require 'digest/md5'

module Jekyll
  # Monkey-patching Site to add a custom property holding combined blog post array
  # and speed up generation.

  class Site
    attr_accessor :posts_combined

    def posts_combined
      @posts_combined
    end
  end
end

def is_hub(site)
  # If there’re projects defined, we assume it is indeed
  # a Jekyll Open Project hub site.
  if site.collections.key? 'projects'
    if site.collections['projects'] != nil
      if site.collections['projects'].docs.length > 0
        return true
      end
    end
  end

  return false
end

module OpenProjectHelpers

  # On an open hub site, Jekyll Open Project theme assumes the existence of two types
  # of item indexes: software and specs, where items are gathered
  # from across open projects in the hub.
  #
  # The need for :item_test arises from our data structure (see Jekyll Open Project theme docs)
  # and the fact that Jekyll doesn’t intuitively handle nested collections.
  INDEXES = {
    "software" => {
      :item_test => lambda { |item| item.url.include? '_software' and not item.url.include? '_docs' },
    },
    "specs" => {
      :item_test => lambda { |item| item.url.include? '_specs' and not item.url.include? '_docs' },
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
      if is_hub(site)

        INDEXES.each do |index_name, params|
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


  # Below passes the `items` variable to normal (unfiltered)
  # index page layout.

  class IndexPageGenerator < Jekyll::Generator
    safe true

    def generate(site)
      if is_hub(site)

        INDEXES.each do |index_name, params|
          items = site.collections['projects'].docs.select { |item| params[:item_test].call(item) }
          page = site.site_payload["site"]["pages"].detect { |p| p.url == "/#{index_name}/" }
          page.data['items'] = items
        end

      end
    end
  end


  # Below passes an array of posts of open hub blog
  # and from each individual project blog, combined and sorted by date,
  # to open hub blog index page.
  #
  # (It also does some processing on the posts.)

  class BlogIndexGenerator < Jekyll::Generator
    safe true

    def generate(site)
      site_posts = site.posts.docs

      if is_hub(site)
        # Get documents representing projects
        projects = site.collections['projects'].docs.select do |item|
          pieces = item.url.split('/')
          pieces[3] == 'index.html' && pieces[1] == 'projects'
        end
        # Add project name (matches directory name, may differ from title)
        projects = projects.map do |project|
          project.data['name'] = project.url.split('/')[2]
          project
        end

        # Get documents representnig posts from each project’s blog
        project_posts = site.collections['projects'].docs.select { |item| item.url.include? '_posts' }

        # Add parent project’s data hash onto each
        project_posts = project_posts.map do |post|
          project_name = post.url.split('/')[2]
          post.data['parent_project'] = projects.detect { |p| p.data['name'] == project_name }
          post
        end

        posts_combined = (project_posts + site_posts).sort_by(&:date).reverse

      else
        posts_combined = site_posts

      end

      # On each post, replace authors’ emails with corresponding md5 hashes
      # suitable for hotlinking authors’ Gravatar profile pictures.
      posts_combined = posts_combined.map do |post|
        if post.data.key? 'author'
          email = post.data['author']['email']
          hash = Digest::MD5.hexdigest(email)
          post.data['author']['email'] = hash
        end
        post
      end

      blog_index = site.site_payload["site"]["pages"].detect { |page| page.url == '/blog/' }
      blog_index.data['posts_combined'] = posts_combined

      site.posts_combined = posts_combined
    end
  end
end
